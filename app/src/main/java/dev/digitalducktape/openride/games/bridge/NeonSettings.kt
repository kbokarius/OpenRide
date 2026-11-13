package dev.digitalducktape.openride.games.bridge

import java.time.LocalDate
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*

/** Locked scoring settings; cosmetics are deliberately excluded from the comparison key. */
@Serializable
data class NeonSettings(val courseId: String, val laneDifficulty: String, val referencePower: Int, val replayAttemptId: String = "") {
    val minutes: Int get() = when {
        courseId.startsWith("ls_r_") -> courseId.split("_").getOrNull(2)?.toIntOrNull() ?: 0
        courseId.startsWith("ls_") -> courseId.split("_").getOrNull(1)?.toIntOrNull() ?: 0
        courseId == "tutorial" -> 5
        courseId.startsWith("daily_") -> 20
        else -> courseId.substringAfterLast('_').toIntOrNull() ?: 0
    }

    fun valid(): Boolean {
        if (replayAttemptId.isNotEmpty() && !Regex("[a-f0-9]{32}").matches(replayAttemptId)) return false
        if (laneDifficulty !in listOf("light", "moderate", "hard", "challenging", "extreme", "beginner", "intermediate", "advanced", "expert") || referencePower !in 1..2000) return false
        if (courseId.startsWith("ls_")) {
            if (referencePower != 150) return false
            if (Regex("ls_(10|15|20|30)_(0[1-9]|1[0-9]|2[0-5])").matches(courseId)) return true
            return Regex("ls_r_(10|15|20|30)_[1-9][0-9]{0,9}").matches(courseId) &&
                (courseId.substringAfterLast('_').toLongOrNull() ?: 0L) in 1L..2147483646L
        }
        if (courseId == "tutorial") return true
        if (Regex("(steady_flow|intervals|rolling_climb)_(10|20|30)").matches(courseId)) return true
        if (!Regex("daily_\\d{4}-\\d{2}-\\d{2}_g[12]").matches(courseId)) return false
        return runCatching { LocalDate.parse(courseId.removePrefix("daily_").substringBeforeLast("_g")) }.isSuccess
    }

    fun planId() = "neon:$courseId:v${if (courseId.startsWith("ls_")) 3 else 2}:$laneDifficulty:f$referencePower:e1:s${if (courseId.startsWith("ls_")) 3 else 2}"

    fun params() = buildJsonObject {
        put("course_id", courseId)
        put("lane_difficulty", laneDifficulty)
        put("reference_power", referencePower)
        if (replayAttemptId.isNotEmpty()) put("replay_attempt_id", replayAttemptId)
    }

    companion object {
        fun parse(value: JsonElement?): NeonSettings? {
            val obj = value as? JsonObject ?: return null
            fun text(key: String) = (obj[key] as? JsonPrimitive)?.takeIf { it.isString }?.content ?: ""
            val power = (obj["reference_power"] as? JsonPrimitive)?.takeIf { !it.isString }?.doubleOrNull ?: return null
            if (!power.isFinite() || power != power.toInt().toDouble()) return null
            return NeonSettings(text("course_id"), text("lane_difficulty"), power.toInt(), text("replay_attempt_id")).takeIf { it.valid() }
        }
    }
}
