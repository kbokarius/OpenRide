package dev.digitalducktape.openride.games.bridge

data class NeonClockState(
    val active: Boolean, val running: Boolean, val elapsedMs: Long,
    val originMs: Long, val epoch: Long, val pauseReason: String, val durationMs: Long,
)

/**
 * Monotonic course clock independent of rendering and the legacy one-second session timer.
 * Godot acknowledges completed 10 ms ticks. A pause discards unprocessed wall time, so an
 * OS/render stall can never be scored retroactively with the newest resistance reading.
 *
 * Only a stall of more than [STALL_MS] pauses. Shorter hitches (a shader compiling, a track
 * loading, the display changing quality) are simply caught up: every sensor delivery in that
 * time is still in the sample buffer with its own timestamp, so nothing is scored from a stale
 * reading. The limit was 250 ms, which on the bike's tablet put the recovery card on screen
 * for ordinary long frames.
 * Resume is explicit, after the game's fresh-input check and unscored countdown.
 */
class NeonTimeline(private val nowMs: () -> Long = { System.nanoTime() / 1_000_000L }) {
    private var active = false
    private var running = false
    private var duration = 0L
    private var acknowledged = 0L
    private var origin = 0L
    private var lastPoll = 0L
    private var epoch = 0L
    private var reason = ""

    @Synchronized fun begin(durationMs: Long): NeonClockState {
        require(durationMs in 10L..1_800_000L && durationMs % 10L == 0L)
        active = true
        running = true
        duration = durationMs
        acknowledged = 0
        origin = nowMs()
        lastPoll = origin
        epoch++
        reason = ""
        return snapshot()
    }

    @Synchronized fun acknowledge(processedMs: Long) {
        if (!active) return
        val available = if (running) (nowMs() - origin).coerceIn(0, duration) else acknowledged
        // Malformed, future and backward acknowledgements never manufacture course time.
        if (processedMs < acknowledged || processedMs > available || processedMs % 10L != 0L) return
        acknowledged = processedMs
    }

    @Synchronized fun poll(sensorFresh: Boolean = true, overflow: Boolean = false, observedMs: Long = nowMs()): NeonClockState {
        val now = observedMs
        if (running) {
            when {
                overflow -> pause("overflow")
                !sensorFresh -> pause("sensor")
                now - lastPoll > STALL_MS -> pause("stall")
            }
        }
        lastPoll = now
        return stateAt(now)
    }

    @Synchronized fun pause(why: String = "manual"): NeonClockState {
        if (active && running) {
            running = false
            reason = why
        }
        return snapshot()
    }

    @Synchronized fun resume(): NeonClockState {
        if (active && !running) {
            origin = nowMs() - acknowledged
            lastPoll = nowMs()
            epoch++
            running = true
            reason = ""
        }
        return snapshot()
    }

    @Synchronized fun stop() {
        active = false
        running = false
        reason = ""
    }

    @Synchronized fun snapshot(): NeonClockState = stateAt(nowMs())

    companion object {
        /** The longest gap between two polls that is caught up without pausing the ride. */
        const val STALL_MS = 1_000L
    }

    private fun stateAt(now: Long): NeonClockState = NeonClockState(
        active, running,
        if (active && running) (now - origin).coerceIn(0, duration) else acknowledged,
        origin, epoch, reason, duration,
    )
}
