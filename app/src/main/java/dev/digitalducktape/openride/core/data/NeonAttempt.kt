package dev.digitalducktape.openride.core.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow
import kotlinx.serialization.Serializable

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
        require(row.elapsedMs >= old.elapsedMs && row.scoreUnits >= old.scoreUnits) { "Checkpoint moved backwards" }
        update(row)
        return row
    }

    // On a new process, pending attempts become history, never resumable gameplay or records.
    @Query("UPDATE neon_attempts SET status = 'interrupted' WHERE status = 'pending'")
    abstract suspend fun recoverInterrupted()

    @Query("SELECT * FROM neon_attempts WHERE profileId IS :profileId ORDER BY updatedMs DESC, attemptId DESC LIMIT 50")
    abstract suspend fun history(profileId: Long?): List<NeonAttempt>

    @Query("SELECT * FROM neon_attempts WHERE profileId IS :profileId AND comparisonKey = :key AND status = 'completed' ORDER BY scoreUnits DESC, updatedMs ASC LIMIT 1")
    abstract suspend fun best(profileId: Long?, key: String): NeonAttempt?

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
