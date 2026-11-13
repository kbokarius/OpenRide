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
}
