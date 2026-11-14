# Lane Smash revision 16 — clearer bike, bomb lanes and workout progression

November 14, 2026. Version `1.2.0-lane-smash.16`, APK code 24. Course 10 / generator 7 / scoring 9. Builds on revision 15 and retains the existing resistance ranges and sensor mapping.

## Requested behavior and implementation

| Area | Change |
| --- | --- |
| Motorcycle front | Front hull half-width reduced about 22–26%; winglet half-span reduced from 0.98 to 0.64 design metres, about 35%. Wheels, contact reach and steering unchanged. |
| Boosters | Two independently positioned plume meshes grow from fixed nozzle mouths. Wider nozzle spacing and three crossed planes make the jets readable behind the middle lanes. The former whole-bike-origin scaling could pull a plume into the tail. |
| Bomb lane | Seeded targets vary through lanes 3–6, with no consecutive authored repeats. A first attack encountered during a slow warm-up is clamped to a maximum three-lane move. The road wash, dock and arrows use this same target. |
| Preparation | Nine seconds of unscored, clear preparation before the attack; the shooter charges over its last two seconds. |
| Rapid drop | Wrong lane at firing/zone entry, or on entering the pending marked blast footprint, triggers a strike within 450 ms, without postponing an earlier scheduled impact. The ball continues from its existing arc point toward a newly locked short target in the rider's lane. One ordinary bomb penalty, up to 1,800, is applied. |
| Correct-lane attack | Existing nine-second cadence-based flight and pass/hold-back scoring. The second shot fires 18 seconds after entry. |
| Work lanes | Two low opening blocks, then all work blocks in lanes 3–6. Each full four-block wave visits those four lanes once in a seeded order. |
| Lane changes | At most three lanes at once. At maximum speed, empty approaches are at least 6 / 7.5 / 9 seconds for one / two / three lanes; slower riders have longer. |
| Section layout | 24-road-second blocks: seven-second cadence plus six-second collect or burst; eleven seconds of gaps, with bursts in alternate work blocks. |
| Attack exit | Resume only after a full resistance-change gap. Skip interrupted targets, or retain a useful shortened remainder with a new explicit start. Renderers use the same adjusted event list. |
| Cooldown | Starts at exactly one active minute remaining, independent of distance. Closes the current section, returns at most three lanes left, then steps down through gold-bar sections into lane 1. No bursts, machine gun or mines. |

## Ownership, compatibility and bounds

`NeonRules` owns timing, lane eligibility and scores on its existing 10 ms clock. `LaneSmashBarrage` owns the lane check and rapid-strike record. Views read them; rendering cannot impose a penalty. `NeonRules.events` is a per-ride copy used for attack handoffs and cooldown, leaving `course.events` and the saved fingerprint immutable. Runtime arrays remain bounded by the original course plus ten cooldown sections. The model adds one plume draw, shares its mesh/material and uses existing effects pools; no new lights, viewports or per-frame node creation.

Both Android and desktop record validators accept scoring 9. Room schema is unchanged: the existing JSON payload carries the new fields. Historical snapshots keep their original rules. New layouts/rules have separate comparison identities, preserving old history without comparing unlike rides.

Implementation pattern: deterministic rule state plus a bounded runtime layout copy. A visual-only lane/impact patch was rejected because the HUD, collision, score and replay could disagree. The existing mesh/material path is used for the jets instead of adding a GPU particle dependency on the tablet.

## Research constraint

No changes to difficulty ranges, resistance decoding, calibration or cadence bands. See [Challenging resistance comparison](../research/lanebreak/10-resistance-feel.md) for established evidence, possible explanations and the unverified current Lanebreak lane endpoints.

## Verification

- Full-duration sensor traces: all 100 named tracks plus 16 random tracks, 36.25 simulated hours, passed. Additional 30-minute traces cover stopped, 60, 140 and 200 rpm.
- The full-ride audit checks required lane jumps, approach space including attacks/cooldown, actual highlighted-lane duration, exclusive work in lanes 3–6, normal safe attack responses, three-star completion, road coverage and bounded input/ghost buffers.
- Structural tests cover all 100 named plus 256 additional random layouts. Per-duration section, exposure and cadence budgets are within 4% in the representative budget test.
- The 103-test regression pass and final 26-test bomb/workout pass cover 107 distinct Godot tests, all passing.
- Real-renderer review includes the bike in both middle lanes and a wrong-lane launch/drop/impact. A large overlapping close-range blast found during review was replaced by a compact lane-sized effect.

## Release verification

- Malformed saved attack schedules are rejected before typed inspection; regression coverage includes invalid container/row types and missing lane/preparation fields.
- Signed `neonReal` build succeeded; 13 Android record compatibility tests passed. Android lint: 0 errors, 79 existing warnings.
- Package `dev.digitalducktape.openride.neon`, version `1.2.0-lane-smash.16`, code 24; ARM64 only, minimum Android 10, live bike sensors enabled, debug disabled.
- APK v2 signature verified against the existing installation certificate: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`.
- The APK's embedded `games.pck` exactly matches the final export; no development `override.cfg` was included.
- APK SHA-256: `211afd03e519d5fb8723f1855294d8d1cb324e4b363fa94b2d4f8480bf14376d` (204,193,605 bytes).
- A silent five-second real-renderer demo shows a wrong-lane shot, rapid drop and −1,800 popup using simulated sensors.
- No installation or on-bike verification was performed for revision 16. Desktop rendering and simulated sensor tests do not establish tablet performance under a real ride.

## Physical installation follow-up — November 14, 2026

At the owner's subsequent request, installed revision 16/code 24 over revision 15/code 23 using `adb install -r`. The original first-install timestamp was retained; no uninstall or data clear was performed. Package metadata confirmed `1.2.0-lane-smash.16`. MainActivity launched successfully, and the physical screen showed the track selector and **Bike connected · ready**. No ride was started. Revision 17 supersedes this installation at the owner's request to default to High graphics.
