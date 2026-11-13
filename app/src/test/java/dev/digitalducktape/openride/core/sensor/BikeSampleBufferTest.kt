package dev.digitalducktape.openride.core.sensor

import org.junit.Assert.*
import org.junit.Test

class BikeSampleBufferTest {
    @Test fun `identical deliveries renew freshness but reads never do`() {
        var now = 0L
        val buffer = BikeSampleBuffer(nowMs = { now })
        buffer.record(BikeMetrics.ZERO)
        now = 1000
        assertEquals(1000, buffer.readAfter(1).sampleAgeMs)
        assertTrue(buffer.readAfter(1).samples.isEmpty())
        buffer.record(BikeMetrics.ZERO)
        assertEquals(0, buffer.readAfter(1).sampleAgeMs)
        assertEquals(listOf(2L), buffer.readAfter(1).samples.map { it.sequence })
        now = 2501
        assertEquals(1501, buffer.readAfter(2).sampleAgeMs)
    }

    @Test fun `ordered snapshots and overflow are explicit`() {
        var now = 0L
        val buffer = BikeSampleBuffer(nowMs = { now }, capacity = 3)
        repeat(6) { buffer.record(BikeMetrics.ZERO); now += 50 }
        val batch = buffer.readAfter(1)
        assertTrue(batch.overflow)
        assertEquals(listOf(4L, 5L, 6L), batch.samples.map { it.sequence })
        assertEquals(listOf(150L, 200L, 250L), batch.samples.map { it.receivedMs })
        assertFalse(buffer.readAfter(3).overflow)
        assertFalse(buffer.readAfter(-1).overflow)
        assertEquals(1, buffer.readAfter(-1).samples.size)
    }

    @Test fun `time expiry detects lost input and preserves actual age`() {
        var now = 0L
        val buffer = BikeSampleBuffer(nowMs = { now })
        repeat(120) { buffer.record(BikeMetrics.ZERO); now += 50 }
        assertTrue(buffer.readAfter(1).overflow)
        now = 20000
        val stale = buffer.readAfter(120)
        assertEquals(14050, stale.sampleAgeMs)
        assertTrue(stale.samples.isEmpty())
        assertEquals(120L, stale.latestSequence)
    }

    @Test fun `absent sample cannot masquerade as a live zero reading`() {
        val batch = BikeSampleBuffer(nowMs = { 1000L }).readAfter(-1)
        assertEquals(Long.MAX_VALUE, batch.sampleAgeMs)
        assertEquals(0, batch.latestSequence)
        assertTrue(batch.samples.isEmpty())
    }

    @Test fun `two producers retain unique ordered deliveries`() {
        val buffer = BikeSampleBuffer(nowMs = { 1000L }, capacity = 1000)
        val threads = List(2) { Thread { repeat(400) { buffer.record(BikeMetrics.ZERO) } } }
        threads.forEach { it.start() }
        threads.forEach { it.join() }
        val batch = buffer.readAfter(0)
        assertFalse(batch.overflow)
        assertEquals((1L..800L).toList(), batch.samples.map { it.sequence })
    }
}
