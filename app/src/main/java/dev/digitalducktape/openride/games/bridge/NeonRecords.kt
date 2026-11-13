package dev.digitalducktape.openride.games.bridge

import dev.digitalducktape.openride.core.data.NeonAttempt
import dev.digitalducktape.openride.core.data.NeonAttemptDao
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.*
import kotlinx.coroutines.channels.Channel
import kotlinx.serialization.json.*

/** Serial IO mailbox. Godot polls replies without doing database work on its rendering thread. */
class NeonRecords(
    private val dao: NeonAttemptDao,
    scope: CoroutineScope,
    private val activeProfile: () -> Long?,
    private val epochMillis: () -> Long = System::currentTimeMillis,
) {
    private data class Request(val ticket: Long, val profile: Long?, val json: String, val needsReply: Boolean = true)
    private val sequence = AtomicLong()
    private val queuedClients = AtomicInteger()
    // Client requests are bounded below. Native lifecycle barriers must never wait behind
    // a suspended sender or be overtaken by a new course when that client limit is reached.
    private val requests = Channel<Request>(Channel.UNLIMITED)
    private val replies = ConcurrentHashMap<Long, String>()

    init {
        scope.launch(Dispatchers.IO) {
            // This instance is application scoped: recovery happens once, before any writes.
            val recovery = runCatching { dao.recoverInterrupted() }
            for (request in requests) {
                if (request.needsReply) queuedClients.decrementAndGet()
                val reply = try {
                    recovery.getOrThrow()
                    execute(request.json, request.profile)
                } catch (cancelled: CancellationException) {
                    throw cancelled
                } catch (_: Exception) {
                    buildJsonObject { put("ok", false); put("error", "Could not read or save ride data. Please retry.") }
                }
                if (request.needsReply) {
                    // Abandoned screens cannot grow the mailbox forever.
                    if (replies.size >= 64) replies.keys.minOrNull()?.let { replies.remove(it) }
                    replies[request.ticket] = reply.toString()
                }
            }
        }
    }

    fun submit(json: String): Long {
        if (json.length > 2_000_000) return -1
        if (queuedClients.incrementAndGet() > 16) {
            queuedClients.decrementAndGet()
            return -1
        }
        val ticket = sequence.incrementAndGet()
        if (requests.trySend(Request(ticket, activeProfile(), json)).isSuccess) return ticket
        queuedClients.decrementAndGet()
        return -1
    }

    fun poll(ticket: Long): String = replies.remove(ticket).orEmpty()

    /** A native plan can end without a Godot result (for example returning to the main app).
     * Queue cleanup behind existing checkpoints and ahead of the next plan's writes. */
    fun interruptPending() {
        requests.trySend(Request(0, activeProfile(), """{"action":"interrupt"}""", needsReply = false))
    }

    internal suspend fun execute(raw: String, profile: Long?): JsonObject {
        val request = Json.parseToJsonElement(raw).jsonObject
        return when (request["action"]?.jsonPrimitive?.content) {
            "interrupt" -> {
                dao.recoverInterrupted()
                buildJsonObject { put("ok", true) }
            }
            "state" -> buildJsonObject {
                put("ok", true)
                put("completions", dao.completions(profile))
                put("trackStats", buildJsonObject { dao.trackStats(profile).forEach { row ->
                    put(row.comparisonKey, buildJsonObject {
                        put("lastScoreUnits", row.lastScoreUnits); put("lastStatus", row.lastStatus)
                        put("bestScoreUnits", row.bestScoreUnits ?: -1)
                    })
                } })
                put("history", buildJsonArray { dao.history(profile).forEach { add(payload(it, details = false)) } })
            }
            "best" -> buildJsonObject {
                put("ok", true)
                put("record", dao.best(profile, request.getValue("key").jsonPrimitive.content)?.let { payload(it) } ?: JsonObject(emptyMap()))
            }
            "get" -> {
                val row = dao.get(request.getValue("attemptId").jsonPrimitive.content)
                require(row != null && row.profileId == profile)
                buildJsonObject { put("ok", true); put("record", payload(row)) }
            }
            "save" -> {
                val row = decode(request.getValue("record").jsonObject, profile, epochMillis())
                val saved = dao.save(row)
                buildJsonObject { put("ok", true); put("status", saved.status); put("attemptId", saved.attemptId) }
            }
            else -> error("Unknown record operation")
        }
    }

    companion object {
        internal fun decode(record: JsonObject, profile: Long?, now: Long): NeonAttempt {
            require(record["version"]?.jsonPrimitive?.intOrNull == 1)
            val id = record.getValue("attemptId").jsonPrimitive.content
            val key = record.getValue("comparisonKey").jsonPrimitive.content
            require(id.matches(Regex("[a-f0-9]{32}")) && key.matches(Regex("[a-f0-9]{64}")))
            val result = record.getValue("result").jsonObject
            val course = record.getValue("course").jsonObject
            val courseId = result.getValue("courseId").jsonPrimitive.content
            require(courseId == course.getValue("courseId").jsonPrimitive.content)
            val durationNumber = course.getValue("durationMs").jsonPrimitive.double
            require(durationNumber.isFinite() && durationNumber == durationNumber.toLong().toDouble())
            val duration = durationNumber.toLong()
            val elapsed = result.getValue("activeDurationMs").jsonPrimitive.long
            val score = result.getValue("scoreUnits").jsonPrimitive.long
            val status = result.getValue("status").jsonPrimitive.content
            require(duration in 300_000..1_800_000 && elapsed in 0..duration && score in 0..10_000_000_000_000L)
            require(status in setOf("pending", "completed", "ended", "interrupted"))
            require(status != "completed" || elapsed == duration)
            val ghost = record["ghost"]?.jsonArray.orEmpty()
            require(ghost.size <= 18_001)
            var last = -1L
            var lastScore = 0L
            var lastDistance = 0L
            ghost.forEach {
                val tick = it.jsonArray
                require(tick.size in 3..4)
                val t = tick[0].jsonPrimitive.long
                val lane = tick[1].jsonPrimitive.int
                val points = tick[2].jsonPrimitive.long
                require(t > last && t in 0..elapsed && lane in -1..5 && points in lastScore..score)
                if (tick.size == 4) {
                    val distance = tick[3].jsonPrimitive.long
                    require(distance in lastDistance..(kotlin.math.ceil(t * 60.0 / 3.6).toLong() + 2))
                    lastDistance = distance
                }
                last = t; lastScore = points
            }
            return NeonAttempt(id, profile, key, courseId, status, score, elapsed, now, record.toString())
        }

        /** SQL status is authoritative after crash recovery, even if the last payload said pending. */
        internal fun payload(row: NeonAttempt, details: Boolean = true): JsonObject {
            val data = Json.parseToJsonElement(row.payloadJson).jsonObject
            return JsonObject(data.toMutableMap().apply {
                put("updatedMs", JsonPrimitive(row.updatedMs))
                put("result", JsonObject(data.getValue("result").jsonObject.toMutableMap().apply {
                    put("status", JsonPrimitive(row.status))
                    if (row.status != "completed") put("stars", JsonPrimitive(0))
                }))
                if (!details) { remove("ghost"); remove("course") }
            })
        }
    }
}
