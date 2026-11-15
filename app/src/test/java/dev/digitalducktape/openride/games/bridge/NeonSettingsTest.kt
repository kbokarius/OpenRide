package dev.digitalducktape.openride.games.bridge

import dev.digitalducktape.openride.games.session.*
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class NeonSettingsTest {
    @Test fun `all library choices produce a locked plan without effort scaling`() {
        val ids = listOf(10, 15, 20, 30).flatMap { m -> (1..25).map { "ls_${m}_${it.toString().padStart(2, '0')}" } } +
            listOf("ls_r_15_1", "ls_r_30_2147483646") + listOf("tutorial", "daily_2026-11-13_g1", "daily_2026-11-13_g2") +
            listOf("steady_flow", "intervals", "rolling_climb").flatMap { f -> listOf(10, 20, 30).map { "${f}_$it" } }
        val identities = mutableSetOf<String>()
        for (id in ids) for (tier in listOf("kid", "light", "moderate", "hard", "challenging", "extreme", "beginner", "intermediate", "advanced", "expert")) {
            val settings = NeonSettings(id, tier, 150)
            assertTrue(settings.valid())
            val request = SessionRequest.JustRide("neon_vector", JustRideMode.Timed(settings.minutes), Difficulty.HARD, settings)
            val plan = requireNotNull(SessionPlans.forRequest(request, FtpBasis.of(250), GameCatalog.DEFAULT))
            assertEquals(settings.minutes * 60, plan.segments.single().durationSec)
            assertEquals(3, plan.introSec)
            assertEquals(Difficulty.STANDARD, plan.difficulty)
            assertEquals(EndMode.GAME, plan.segments.single().endMode)
            assertFalse(plan.segments.single().effort)
            assertEquals(settings.params(), plan.segments.single().params)
            identities += plan.planId
        }
        assertEquals(ids.size * 10, identities.size)
    }

    @Test fun `bad dates unknown tiers and invalid targets are rejected`() {
        for (settings in listOf(
            NeonSettings("daily_2026-02-30_g1", "beginner", 150),
            NeonSettings("steady_flow_15", "beginner", 150),
            NeonSettings("steady_flow_20", "unknown", 150),
            NeonSettings("tutorial", "expert", 0),
            NeonSettings("tutorial", "expert", 2001),
            NeonSettings("ls_15_00", "beginner", 150),
            NeonSettings("ls_15_26", "beginner", 150),
            NeonSettings("ls_r_15_2147483647", "beginner", 150),
            NeonSettings("ls_15_01", "beginner", 175),
        )) assertFalse(settings.valid())
        for (target in listOf("150.1", "\"150\"", "null")) {
            assertNull(NeonSettings.parse(Json.parseToJsonElement("""{"course_id":"tutorial","lane_difficulty":"beginner","reference_power":$target}""")))
        }
    }

    @Test fun `native parser and mapper preserve settings and reject inconsistent duration`() {
        val json = """{"kind":"just_ride","game_id":"neon_vector","mode":"minutes","length":20,"neon":{"course_id":"steady_flow_20","lane_difficulty":"expert","reference_power":175.0}}"""
        val request = requireNotNull(BridgeMessages.parsePlanRequest(json))
        val mapped = request.toSessionRequest(false, GameCatalog.DEFAULT) as RequestMapping.Ok
        assertEquals(NeonSettings("steady_flow_20", "expert", 175), (mapped.request as SessionRequest.JustRide).neon)
        assertTrue(request.copy(length = 10).toSessionRequest(false, GameCatalog.DEFAULT) is RequestMapping.Rejected)
        assertTrue(request.copy(neon = null).toSessionRequest(false, GameCatalog.DEFAULT) is RequestMapping.Rejected)
    }

    @Test fun `kid selection crosses the native request bridge without changing duration or reference power`() {
        val json = """{"kind":"just_ride","game_id":"neon_vector","mode":"minutes","length":15,"neon":{"course_id":"ls_15_01","lane_difficulty":"kid","reference_power":150}}"""
        val request = requireNotNull(BridgeMessages.parsePlanRequest(json))
        val mapped = request.toSessionRequest(false, GameCatalog.DEFAULT) as RequestMapping.Ok
        val settings = (mapped.request as SessionRequest.JustRide).neon!!
        assertEquals("kid", settings.laneDifficulty)
        assertEquals(15, settings.minutes)
        assertEquals(150, settings.referencePower)
        assertEquals(settings, NeonSettings.parse(settings.params()))
        assertNotEquals(settings.planId(), settings.copy(laneDifficulty = "light").planId())
    }

}
