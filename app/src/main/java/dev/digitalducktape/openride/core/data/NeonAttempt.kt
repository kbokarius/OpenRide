package dev.digitalducktape.openride.core.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

/** Independently durable: a course is saved before the enclosing Games visit ends. */
@Serializable
@Entity(tableName = "neon_attempts", foreignKeys = [ForeignKey(
    entity = Profile::class, parentColumns = ["id"], childColumns = ["profileId"], onDelete = ForeignKey.CASCADE,
)], indices = [Index("profileId"), Index(value = ["profileId", "comparisonKey"])])
data class NeonAttempt(
    @PrimaryKey val attemptId: String,
    val profileId: Long?,
    val comparisonKey: String,
    val courseId: String,
    val status: String,
    val scoreUnits: Long,
    val elapsedMs: Long,
    val updatedMs: Long,
    /** Versioned JSON: exact course, result, and (only on completion) a compact 10 Hz ghost. */
    val payloadJson: String,
)


/** Compact selector data, independent of the 50-row history limit. */
data class NeonTrackStat(val comparisonKey: String, val courseId: String, val lastScoreUnits: Long, val lastStatus: String, val bestScoreUnits: Long?, val lastAttemptId: String, val bestAttemptId: String?)

@Dao
abstract class NeonAttemptDao {
    @Query("SELECT * FROM neon_attempts WHERE attemptId = :id")
    abstract suspend fun get(id: String): NeonAttempt?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    abstract suspend fun insert(row: NeonAttempt)

    @Update
    abstract suspend fun update(row: NeonAttempt)

    /** One row changes from pending to final atomically; repeats cannot award a second completion. */
    @Transaction
    open suspend fun save(row: NeonAttempt): NeonAttempt {
        val old = get(row.attemptId)
        if (old == null) {
            require(row.status == "pending") { "Attempt must begin before saving a result" }
            insert(row)
            return row
        }
        require(old.profileId == row.profileId && old.comparisonKey == row.comparisonKey && old.courseId == row.courseId) { "Attempt identity changed" }
        if (old.status != "pending") return old
        val before = checkpointTotals(old)
        val after = checkpointTotals(row)
        require(row.elapsedMs >= old.elapsedMs && after.first >= before.first && after.second >= before.second) { "Checkpoint moved backwards" }
        update(row)
        return row
    }

    private fun checkpointTotals(row: NeonAttempt): Pair<Long, Long> {
        val result = Json.parseToJsonElement(row.payloadJson).jsonObject.getValue("result").jsonObject
        if ((result["scoringVersion"]?.jsonPrimitive?.int ?: 1) < 4) return row.scoreUnits to 0L
        val earned = result.getValue("earnedScoreUnits").jsonPrimitive.long
        val penalty = result.getValue("penaltyUnits").jsonPrimitive.long
        require(earned >= 0 && penalty in 0..earned && earned - penalty == row.scoreUnits)
        return earned to penalty
    }

    // On a new process, pending attempts become history, never resumable gameplay or records.
    @Query("UPDATE neon_attempts SET status = 'interrupted' WHERE status = 'pending'")
    abstract suspend fun recoverInterrupted()

    @Query("SELECT * FROM neon_attempts WHERE profileId IS :profileId ORDER BY updatedMs DESC, attemptId DESC LIMIT 50")
    abstract suspend fun history(profileId: Long?): List<NeonAttempt>

    // Load full snapshots one at a time when producing the lightweight menu history.
    @Query("SELECT attemptId FROM neon_attempts WHERE profileId IS :profileId ORDER BY updatedMs DESC, attemptId DESC LIMIT 50")
    abstract suspend fun historyIds(profileId: Long?): List<String>

    @Query("SELECT * FROM neon_attempts WHERE profileId IS :profileId AND comparisonKey = :key AND status = 'completed' ORDER BY scoreUnits DESC, updatedMs ASC LIMIT 1")
    abstract suspend fun best(profileId: Long?, key: String): NeonAttempt?

    @Query("""SELECT n.comparisonKey, n.courseId, n.scoreUnits AS lastScoreUnits, n.status AS lastStatus,
        (SELECT MAX(b.scoreUnits) FROM neon_attempts b WHERE b.profileId IS :profileId AND b.comparisonKey = n.comparisonKey AND b.status = 'completed') AS bestScoreUnits,
        n.attemptId AS lastAttemptId,
        (SELECT b.attemptId FROM neon_attempts b WHERE b.profileId IS :profileId AND b.comparisonKey = n.comparisonKey AND b.status = 'completed' ORDER BY b.scoreUnits DESC, b.updatedMs ASC, b.attemptId ASC LIMIT 1) AS bestAttemptId
        FROM neon_attempts n WHERE n.profileId IS :profileId AND n.status != 'pending'
        AND NOT EXISTS (SELECT 1 FROM neon_attempts newer WHERE newer.profileId IS :profileId AND newer.comparisonKey = n.comparisonKey AND newer.status != 'pending'
        AND (newer.updatedMs > n.updatedMs OR (newer.updatedMs = n.updatedMs AND newer.attemptId > n.attemptId)))""")
    abstract suspend fun trackStats(profileId: Long?): List<NeonTrackStat>

    @Query("SELECT COUNT(*) FROM neon_attempts WHERE profileId IS :profileId AND status = 'completed' AND courseId != 'tutorial'")
    abstract suspend fun completions(profileId: Long?): Int

    @Query("SELECT * FROM neon_attempts")
    abstract suspend fun getAllOnce(): List<NeonAttempt>

    // Checkpoints don't trigger large automatic exports; finalization does, even at equal row count.
    @Query("SELECT COUNT(*) FROM neon_attempts WHERE status != 'pending'")
    abstract fun observeFinalCount(): Flow<Int>

    @Insert
    abstract suspend fun insertAll(rows: List<NeonAttempt>)

    @Query("DELETE FROM neon_attempts")
    abstract suspend fun deleteAll()
}
