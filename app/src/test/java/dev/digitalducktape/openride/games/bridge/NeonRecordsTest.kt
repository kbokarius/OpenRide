package dev.digitalducktape.openride.games.bridge

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import dev.digitalducktape.openride.core.backup.BackupRepository
import dev.digitalducktape.openride.core.data.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NeonRecordsTest {
    private lateinit var db: OpenRideDatabase
    private lateinit var dao: NeonAttemptDao
    private var rider = 0L
    private var other = 0L

    @Before fun setUp() = runTest {
        db = Room.inMemoryDatabaseBuilder(ApplicationProvider.getApplicationContext(), OpenRideDatabase::class.java).build()
        dao = db.neonAttemptDao()
        rider = db.profileDao().insert(Profile(name = "Rider", avatarEmoji = "R", avatarColor = 0, weightKg = null, ftp = 150))
        other = db.profileDao().insert(Profile(name = "Other", avatarEmoji = "O", avatarColor = 0, weightKg = null, ftp = 150))
    }

    @After fun tearDown() { db.close() }

    private fun record(id: String = "a", profile: Long? = rider, course: String = "steady_flow_10", key: String = "b", status: String = "pending", score: Long = 0, elapsed: Long = 0): NeonAttempt {
        val data = buildJsonObject {
            put("version", 1); put("attemptId", id.repeat(32)); put("comparisonKey", key.repeat(64)); put("riderId", profile.toString())
            put("course", buildJsonObject { put("courseId", course); put("durationMs", 600000.0) })
            put("result", buildJsonObject {
                put("courseId", course); put("status", status); put("scoreUnits", score); put("activeDurationMs", elapsed); put("stars", if (status == "completed") 3 else 0)
            })
            put("ghost", buildJsonArray { if (status == "completed") add(buildJsonArray { add(600000); add(2); add(score) }) })
        }
        return NeonRecords.decode(data, profile, 1000)
    }

    @Test fun `finalization is atomic idempotent and wins against late checkpoints`() = runTest {
        dao.save(record())
        dao.save(record(elapsed = 20000, score = 50))
        val final = record(status = "completed", elapsed = 600000, score = 100)
        val saves = coroutineScope { (1..8).map { async(Dispatchers.IO) { dao.save(final) } }.awaitAll() }
        assertTrue(saves.all { it.status == "completed" })
        assertEquals(final, dao.save(record(elapsed = 20000, score = 50)))
        assertEquals(1, dao.completions(rider))
        assertEquals(1, dao.getAllOnce().size)
        assertEquals(final, dao.best(rider, final.comparisonKey))
    }

    @Test fun `crash recovery preserves partial history and excludes it from records`() = runTest {
        dao.save(record())
        dao.save(record(elapsed = 30000, score = 500))
        dao.recoverInterrupted()
        val interrupted = dao.history(rider).single()
        assertEquals("interrupted", interrupted.status)
        assertEquals(500L, interrupted.scoreUnits)
        assertEquals("interrupted", NeonRecords.payload(interrupted)["result"]!!.jsonObject["status"]!!.jsonPrimitive.content)
        assertNull(dao.best(rider, interrupted.comparisonKey))
        assertEquals(0, dao.completions(rider))
        assertEquals("interrupted", dao.save(record()).status)
    }

    @Test fun `profiles comparison keys and tutorial unlock counts are isolated`() = runTest {
        for (row in listOf(record(), record("c", other), record("d", course = "tutorial", key = "d"), record("e", key = "e"))) {
            dao.save(row)
            dao.save(row.copy(status = "completed", elapsedMs = 600000, scoreUnits = 100))
        }
        assertEquals(2, dao.completions(rider))
        assertEquals(1, dao.completions(other))
        assertEquals("a".repeat(32), dao.best(rider, "b".repeat(64))?.attemptId)
        assertEquals("c".repeat(32), dao.best(other, "b".repeat(64))?.attemptId)
        assertNull(dao.best(rider, "f".repeat(64)))
    }

    @Test fun `checkpoints cannot move backwards or transfer ownership`() = runTest {
        dao.save(record())
        dao.save(record(elapsed = 10000, score = 50))
        suspend fun rejected(row: NeonAttempt) {
            var threw = false
            try { dao.save(row) } catch (_: IllegalArgumentException) { threw = true }
            assertTrue(threw)
        }
        rejected(record(elapsed = 9000, score = 50))
        rejected(record(elapsed = 10000, score = 49))
        rejected(record(profile = other, elapsed = 10000, score = 50))
        rejected(record(key = "c", elapsed = 10000, score = 50))
        assertEquals(50L, dao.get("a".repeat(32))!!.scoreUnits)
    }

    @Test fun `backup restores exact course and ghost and marks pending attempts interrupted`() = runTest {
        dao.save(record())
        val completed = record(status = "completed", elapsed = 600000, score = 120)
        dao.save(completed)
        dao.save(record("c"))
        val backup = BackupRepository(db, db.profileDao(), db.rideDao(), gameResultDao = db.gameResultDao(), neonAttemptDao = dao)
        val snapshot = backup.parse(backup.exportJson())
        dao.deleteAll()
        backup.restore(snapshot)
        assertEquals(completed, dao.get(completed.attemptId))
        assertEquals("interrupted", dao.get("c".repeat(32))!!.status)
        assertEquals(1, dao.completions(rider))
        val oldJson = """{"version":1,"exportedAtEpochMs":1,"profiles":[],"rides":[],"samples":[]}"""
        assertTrue(backup.parse(oldJson).neonAttempts.isEmpty())
    }

    @Test fun `incomplete game results remain in history but not any record query`() = runTest {
        val ride = Ride(profileId = rider, startEpochMs = 0, durationSec = 60, avgCadence = 80, maxCadence = 90, avgPower = 150, maxPower = 200, avgResistance = 40, outputKj = 9.0, calories = null, gamePlan = "neon:test")
        val id = RideRepository(db, db.rideDao()).saveRide(ride, emptyList())
        val results = db.gameResultDao()
        results.insertAll(listOf(GameResult(id, 0, "neon_vector", "free", "standard", 0, 60, 1000.0, 0, null, false, "{}", recordEligible = false)))
        assertEquals(1, results.getForRide(id).size)
        assertTrue(results.observePersonalBests(rider).first().isEmpty())
        assertTrue(results.leaderboard("neon_vector", "standard", "neon:test").isEmpty())
        assertTrue(results.planBests(rider).isEmpty())
        assertNull(results.planBest(rider, "neon:test", "standard", -1).bestScore)
    }

    @Test fun `malformed completion and backwards ghost are rejected before writing`() {
        assertThrows(IllegalArgumentException::class.java) { record(status = "completed", elapsed = 10) }
        val data = Json.parseToJsonElement(record().payloadJson).jsonObject.toMutableMap()
        data["ghost"] = Json.parseToJsonElement("[[100,0,0],[90,0,0]]")
        assertThrows(IllegalArgumentException::class.java) { NeonRecords.decode(JsonObject(data), rider, 0) }
        data["ghost"] = JsonArray(emptyList())
        data["attemptId"] = JsonPrimitive("../escape")
        assertThrows(IllegalArgumentException::class.java) { NeonRecords.decode(JsonObject(data), rider, 0) }
    }

    @Test fun `native plan exit interrupts pending history without changing completed rides`() = runTest {
        dao.save(record())
        dao.save(record(elapsed = 20000, score = 100))
        dao.save(record("c"))
        dao.save(record("c", status = "completed", elapsed = 600000, score = 500))
        val records = NeonRecords(dao, backgroundScope, { rider })
        records.execute("""{"action":"interrupt"}""", rider)
        val rows = dao.getAllOnce().associateBy { it.attemptId }
        assertEquals("interrupted", rows.getValue("a".repeat(32)).status)
        assertEquals(20000L, rows.getValue("a".repeat(32)).elapsedMs)
        assertEquals("completed", rows.getValue("c".repeat(32)).status)
        assertEquals(1, dao.completions(rider))
    }
    @Test fun `distance ghosts validate monotonic bounded movement and legacy ghosts remain valid`() {
        val source = Json.parseToJsonElement(record(status = "completed", elapsed = 600000, score = 100).payloadJson).jsonObject
        fun decode(trace: String) = NeonRecords.decode(JsonObject(source.toMutableMap().apply { put("ghost", Json.parseToJsonElement(trace)) }), rider, 0)
        assertNotNull(decode("[[100,0,0,1000],[200,1,20,2000]]"))
        assertNotNull(decode("[[100,0,0],[200,1,20]]"))
        assertThrows(IllegalArgumentException::class.java) { decode("[[100,0,0,1000],[200,1,20]]") }
        assertThrows(IllegalArgumentException::class.java) { decode("[[100,0,0],[200,1,20,2000]]") }
        assertThrows(IllegalArgumentException::class.java) { decode("[[100,0,0,1000],[200,1,20,900]]") }
        assertThrows(IllegalArgumentException::class.java) { decode("[[100,0,0,2000]]") }
    }

    @Test fun `track stats retain last partial and completed best beyond the history limit`() = runTest {
        dao.save(record(id = "a"))
        dao.save(record(id = "a", status = "completed", elapsed = 600000, score = 800))
        dao.save(record(id = "c"))
        dao.save(record(id = "c", status = "ended", elapsed = 30000, score = 100).copy(updatedMs = 2000))
        val stats = dao.trackStats(rider).single()
        assertEquals(100L, stats.lastScoreUnits)
        assertEquals("ended", stats.lastStatus)
        assertEquals(800L, stats.bestScoreUnits)
        assertTrue(dao.trackStats(other).isEmpty())
        repeat(51) { index ->
            val extra = record(id = "d", key = "e").copy(attemptId = index.toString(16).padStart(32, '0'), updatedMs = 3000L + index)
            dao.save(extra)
            dao.save(extra.copy(status = "ended"))
        }
        assertFalse(dao.history(rider).any { it.comparisonKey == stats.comparisonKey })
        assertTrue(dao.trackStats(rider).any { it.comparisonKey == stats.comparisonKey && it.bestScoreUnits == 800L })
    }
    @Test fun `menu history excludes heavy traces and matches history ordering`() = runTest {
        val row = record(status = "completed", elapsed = 600000, score = 100)
        val data = Json.parseToJsonElement(row.payloadJson).jsonObject.toMutableMap()
        data["result"] = JsonObject(data.getValue("result").jsonObject.toMutableMap().apply {
            put("events", Json.parseToJsonElement("[{\"eventId\":\"sample\",\"scoreUnits\":100}]"))
        })
        val detailed = row.copy(payloadJson = JsonObject(data).toString())
        dao.save(record())
        dao.save(detailed)
        assertEquals(dao.history(rider).map { it.attemptId }, dao.historyIds(rider))
        val records = NeonRecords(dao, backgroundScope, { rider })
        val history = records.execute("""{"action":"state"}""", rider).getValue("history").jsonArray.single().jsonObject
        assertFalse(history.containsKey("ghost"))
        assertFalse(history.containsKey("course"))
        assertFalse(history.getValue("result").jsonObject.containsKey("events"))
        assertTrue(NeonRecords.payload(detailed).getValue("result").jsonObject.containsKey("events"))
    }

    @Test fun `state exposes old version benchmark identity beyond history without copying heavy payloads`() = runTest {
        val source = record(course = "ls_20_07", status = "completed", elapsed = 600000, score = 154321)
        val data = Json.parseToJsonElement(source.payloadJson).jsonObject.toMutableMap()
        data["result"] = JsonObject(data.getValue("result").jsonObject.toMutableMap().apply {
            put("difficulty", JsonPrimitive("hard")); put("referencePower", JsonPrimitive(150))
            put("scoreScale", JsonPrimitive(18)); put("envelopeVersion", JsonPrimitive(1))
            put("laneBands", Json.parseToJsonElement("[[25,31],[32,38],[39,45],[46,52],[53,59],[60,66]]"))
        })
        dao.save(record(course = "ls_20_07"))
        dao.save(source.copy(payloadJson = JsonObject(data).toString()))
        repeat(51) { index ->
            val row = record(id = "c", key = "d").copy(attemptId = index.toString(16).padStart(32, '0'), updatedMs = 3000L + index)
            dao.save(row); dao.save(row.copy(status = "ended"))
        }
        val records = NeonRecords(dao, backgroundScope, { rider })
        val state = records.execute("""{"action":"state"}""", rider)
        assertEquals(50, state.getValue("history").jsonArray.size)
        val stat = state.getValue("trackStats").jsonObject.getValue(source.comparisonKey).jsonObject
        val best = stat.getValue("best").jsonObject
        assertEquals(source.attemptId, best.getValue("attemptId").jsonPrimitive.content)
        assertEquals("ls_20_07", best.getValue("courseId").jsonPrimitive.content)
        assertEquals("hard", best.getValue("difficulty").jsonPrimitive.content)
        assertEquals(18, best.getValue("scoreScale").jsonPrimitive.int)
        assertEquals(600000.0, best.getValue("durationMs").jsonPrimitive.double, 0.0)
        assertFalse(best.containsKey("course")); assertFalse(best.containsKey("ghost"))
        assertTrue(records.execute("""{"action":"state"}""", other).getValue("trackStats").jsonObject.isEmpty())
        val restored = records.execute("""{"action":"get","attemptId":"${source.attemptId}"}""", rider).getValue("record").jsonObject
        assertFalse(restored.getValue("ghost").jsonArray.isEmpty())
    }

    @Test fun `current and historical scoring versions are accepted and unknown versions are rejected`() = runTest {
        fun versioned(version: Int): JsonObject {
            val source = Json.parseToJsonElement(record(status = "pending", elapsed = 1000, score = 140).payloadJson).jsonObject
            return JsonObject(source.toMutableMap().apply {
                put("result", JsonObject(source.getValue("result").jsonObject.toMutableMap().apply {
                    put("scoringVersion", JsonPrimitive(version)); put("earnedScoreUnits", JsonPrimitive(200L)); put("penaltyUnits", JsonPrimitive(60L))
                }))
            })
        }
        assertEquals(140L, NeonRecords.decode(versioned(7), rider, 0).scoreUnits)
        // Scoring version 8 adds the cadence sweet-spot bonus; the stored totals have the same shape.
        assertEquals(140L, NeonRecords.decode(versioned(8), rider, 0).scoreUnits)
        // Scoring 9 adds lane-checked bombs and a timer-driven cooldown.
        assertEquals(140L, NeonRecords.decode(versioned(9), rider, 0).scoreUnits)
        var rejected = false
        assertEquals(140L, NeonRecords.decode(versioned(10), rider, 0).scoreUnits)
        // Scoring 11 honors announced lanes across attack/cooldown handoffs.
        assertEquals(140L, NeonRecords.decode(versioned(11), rider, 0).scoreUnits)
        // Scoring 12 guards between-section gaps while keeping older snapshots readable.
        assertEquals(140L, NeonRecords.decode(versioned(12), rider, 0).scoreUnits)
        try { NeonRecords.decode(versioned(13), rider, 0) } catch (_: IllegalArgumentException) { rejected = true }
        assertTrue(rejected)
    }

    @Test fun `bomb losses save and replay while earned and penalty totals cannot roll back`() = runTest {
        fun bombRow(earned: Long, penalty: Long, elapsed: Long, status: String = "pending"): NeonAttempt {
            val source = Json.parseToJsonElement(record(status = status, elapsed = elapsed, score = earned - penalty).payloadJson).jsonObject
            val data = JsonObject(source.toMutableMap().apply {
                put("result", JsonObject(source.getValue("result").jsonObject.toMutableMap().apply {
                    put("scoringVersion", JsonPrimitive(6)); put("earnedScoreUnits", JsonPrimitive(earned)); put("penaltyUnits", JsonPrimitive(penalty))
                }))
                if (elapsed >= 2000) put("ghost", Json.parseToJsonElement("[[1000,0,200,1000],[2000,1,100,2000]]"))
            })
            return NeonRecords.decode(data, rider, 0)
        }
        dao.save(bombRow(0, 0, 0))
        dao.save(bombRow(200, 0, 1000))
        dao.save(bombRow(200, 100, 2000))
        assertEquals(100L, dao.get("a".repeat(32))!!.scoreUnits)
        var rejected = false
        try { dao.save(bombRow(200, 90, 2100)) } catch (_: IllegalArgumentException) { rejected = true }
        assertTrue(rejected)
        // Keep the historical ghost maximum valid while decreasing only gross earnings.
        dao.save(bombRow(220, 100, 2200))
        rejected = false
        try { dao.save(bombRow(210, 100, 2300)) } catch (_: IllegalArgumentException) { rejected = true }
        assertTrue(rejected)
        val final = bombRow(220, 100, 600000, "completed")
        dao.save(final)
        assertEquals(final, dao.best(rider, final.comparisonKey))
        assertEquals(final.payloadJson, dao.get(final.attemptId)!!.payloadJson)
    }

}
