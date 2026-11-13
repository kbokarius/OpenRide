package dev.digitalducktape.openride.games.bridge

import org.junit.Assert.*
import org.junit.Test

class NeonTimelineTest {
    @Test fun `pause discards unprocessed time and resume excludes a long interruption`() {
        var now = 1000L
        val clock = NeonTimeline { now }
        clock.begin(600000)
        now += 27
        clock.acknowledge(20)
        assertEquals(27L, clock.poll().elapsedMs)
        clock.pause()
        now += 100000
        assertEquals(20L, clock.poll().elapsedMs)
        val resumed = clock.resume()
        assertEquals(20L, resumed.elapsedMs)
        assertEquals(2L, resumed.epoch)
        now += 30
        assertEquals(50L, clock.poll().elapsedMs)
    }

    @Test fun `a render stall pauses before catch up`() {
        var now = 0L
        val clock = NeonTimeline { now }
        clock.begin(10000)
        now = 200
        clock.poll()
        clock.acknowledge(200)
        now = 451
        val paused = clock.poll()
        assertFalse(paused.running)
        assertEquals("stall", paused.pauseReason)
        assertEquals(200L, paused.elapsedMs)
        now = 5000
        assertEquals(200L, clock.poll().elapsedMs)
    }

    @Test fun `input loss and overflow freeze at last acknowledged tick`() {
        var now = 0L
        val clock = NeonTimeline { now }
        clock.begin(10000)
        now = 100
        clock.acknowledge(90)
        assertEquals("sensor", clock.poll(sensorFresh = false).pauseReason)
        assertEquals(90L, clock.snapshot().elapsedMs)
        clock.resume()
        assertEquals("overflow", clock.poll(overflow = true).pauseReason)
    }

    @Test fun `invalid acknowledgements do not invent time`() {
        var now = 0L
        val clock = NeonTimeline { now }
        clock.begin(10000)
        now = 100
        clock.acknowledge(50)
        clock.acknowledge(40)
        clock.acknowledge(1000)
        clock.acknowledge(57)
        assertEquals(50L, clock.pause().elapsedMs)
    }

    @Test fun `duration caps course time and a new attempt resets it`() {
        var now = 0L
        val clock = NeonTimeline { now }
        clock.begin(100)
        now = 120
        assertEquals(100L, clock.poll().elapsedMs)
        clock.acknowledge(100)
        clock.stop()
        assertFalse(clock.snapshot().active)
        assertEquals(0L, clock.begin(100).elapsedMs)
    }
}
