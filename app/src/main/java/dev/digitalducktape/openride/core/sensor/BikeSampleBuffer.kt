package dev.digitalducktape.openride.core.sensor

/** One actual delivery, including unchanged values (StateFlow conflates those). */
data class BikeSample(val sequence: Long, val receivedMs: Long, val metrics: BikeMetrics)

data class BikeSampleBatch(
    val nowMs: Long,
    val latestSequence: Long,
    val sampleAgeMs: Long,
    val overflow: Boolean,
    val samples: List<BikeSample>,
)

/**
 * A bounded, thread-safe delivery log for deterministic game input. Record at the callback /
 * successful poll, never when a UI reads metrics. Five seconds accommodates a slow renderer;
 * the independent 1.5 s freshness and 250 ms stall rules still pause NEON VECTOR sooner.
 * The injected monotonic clock makes silence, identical samples and expiry testable.
 */
class BikeSampleBuffer(
    private val nowMs: () -> Long = { System.nanoTime() / 1_000_000L },
    private val retainMs: Long = 5_000L,
    private val capacity: Int = 512,
) {
    init {
        require(retainMs > 0 && capacity > 0)
    }

    private val deliveries = ArrayDeque<BikeSample>()
    private var sequence = 0L

    @Synchronized
    fun record(metrics: BikeMetrics): BikeSample {
        val now = nowMs()
        check(deliveries.lastOrNull()?.receivedMs?.let { now >= it } != false) { "Sensor clock moved backwards" }
        val sample = BikeSample(++sequence, now, metrics)
        deliveries.addLast(sample)
        while (deliveries.size > capacity || deliveries.first().receivedMs < now - retainMs) {
            deliveries.removeFirst()
        }
        return sample
    }

    @Synchronized
    fun readAfter(afterSequence: Long): BikeSampleBatch {
        val now = nowMs()
        val latest = deliveries.lastOrNull()
        // Keep the last sample to report its real age, even after the entire ring is stale.
        while (deliveries.size > 1 && deliveries.first().receivedMs < now - retainMs) {
            deliveries.removeFirst()
        }
        val oldest = deliveries.firstOrNull()?.sequence ?: 1L
        return BikeSampleBatch(
            nowMs = now,
            latestSequence = sequence,
            sampleAgeMs = latest?.let { (now - it.receivedMs).coerceAtLeast(0) } ?: Long.MAX_VALUE,
            // -1 means an initial snapshot: the consumer intentionally ignores past history.
            overflow = afterSequence >= 0 && afterSequence < oldest - 1,
            samples = if (afterSequence < 0) listOfNotNull(latest)
                else deliveries.filter { it.sequence > afterSequence },
        )
    }
}
