# Current gameplay and presentation parameters

Verified against source November 15, 2026, including the revision-19 ride changes (`9555d62`) and superbike rear tyre (`7b56a12`), followed by the Kid difficulty addition. This is a tuning reference; [Rules](RULES.md) explains behavior, [Presentation](PRESENTATION.md) explains the look/audio, and [Architecture](ARCHITECTURE.md) explains ownership and persistence.

## Units and release state

- Player-facing lanes are **1–6**; stored `laneIndex` values are **0–5**.
- **Active seconds** are the ride clock. Stopping pedalling consumes them; a sensor interruption freezes them.
- **Road seconds** are distance divided by the maximum rules speed, 60 km/h. One road-second is 16⅔ rules-metres, drawn as 50 world metres. At a constant cadence below 140 rpm, actual seconds = road seconds × 140 / rpm. At zero cadence the road does not advance. Section lengths and mine spacing use road time; attack timers and the final-minute cooldown use active time.
- The model uses design units, multiplied by `LaneSmashBike.SCALE = 1.3`. These dimensions describe game geometry, not a real motorcycle specification.
- Current rules: course **11**, generator **8**, scoring **10**, envelope **1**. The rear-tyre change is visual only. Kid adds its own difficulty identity; the course, generator and scoring versions and all existing difficulty identities remain unchanged.
- Latest prepared signed APK: **27 / 1.2.0-lane-smash.19**, built from `9555d62`; it includes the ride changes but **not** the subsequent rear-tyre mesh or Kid difficulty. Latest source includes all three changes. Last verified device installation: **26 / revision 18**. See the [build record](../specs/lane-smash-v19.md) and [installation record](../specs/lane-smash-v18.md). No newer build or installation is implied by this documentation update.

## Course generation and pacing

Source: [LaneSmashCatalog.gd](../../games/games/neon_vector/LaneSmashCatalog.gd), [NeonRules.gd](../../games/games/neon_vector/NeonRules.gd).

| Parameter | Current value / behavior |
| --- | --- |
| Durations and catalog | 10 / 15 / 20 / 30 minutes; 25 named courses per duration, plus seeded random courses |
| Random selections | Seed determines layout, palette, background and fixed route; eight palettes and four backgrounds |
| Warm-up | Lane 1 Collect, then lane 2 Pedal speed; 10 road-seconds each; initial approaches 3 and 6 road-seconds; total 29 road-seconds |
| Work lanes | Lanes 3–6, each visited once per complete shuffled four-block wave; no consecutive identical work lane at a wave boundary |
| Maximum required lane jump | Three, including attack preparation, return and cooldown |
| Collect / Pedal speed length | 10 road-seconds each; at least 10 actual seconds at the speed cap |
| Power Burst length | Deterministic 5 / 6 / 7 road-second rotation; bursts in alternate work blocks |
| Ordinary block approach | 9 road-seconds before changing lanes |
| Same-lane inter-section gap | 2 road-seconds |
| Return after Incoming Fire | 6 / 7.5 / 9 road-seconds for a change of at most one / two / three lanes |
| Ordinary block budget | 31 road-seconds: 9 approach + 10 section + 2 gap + 10 section |
| Burst block budget | 26 / 27 / 28 road-seconds, using a 5 / 6 / 7-second burst instead of Collect |
| Partial final authored block | Never emits a shortened section; a section that cannot fit is omitted |
| Cooldown | Begins with exactly 60 active seconds remaining; replaces future work with low-lane 10-road-second Collect sections; no mines, bursts or gunfire |
| Boundary exception | The fixed cooldown boundary and ride finish can close the current section; ordinary attack handoffs preserve the full section |
| Road length | `minutes × 1,000 + 300` rules-metres; sufficient for the 140-rpm speed cap |
| Latest full-course audit | 116 tracks, 36.25 simulated hours; four additional speed traces; all six difficulty mappings, including full Kid rides. Target-following ordinary gaps below 22 active seconds; Nightfall maximum 19.4 seconds for all durations. This is a measured trace, not a guarantee while stopped. |

## Resistance, cadence and guidance

Source: [NeonRules.gd](../../games/games/neon_vector/NeonRules.gd) (`lane_step`, `band`, `lane_for`, `clamped_lane_for`), [LaneSmashSteering.gd](../../games/games/neon_vector/LaneSmashSteering.gd), [NeonSpace.gd](../../games/games/neon_vector/NeonSpace.gd).

| Parameter | Current value |
| --- | --- |
| Difficulty ranges | **Kid 0–20**; Light 15–56; Moderate 20–61; Hard 25–66; Challenging 30–71; Extreme 35–76 |
| Default difficulty | Challenging |
| Adult lane resistance | Seven inclusive integer values each; lane `n` begins at tier minimum + `7 × (n−1)` |
| Kid lane step | **3.5**, exactly 50% of the ordinary 7; starts at sensor resistance 0 |
| Kid lanes 1–6 | **0–3 / 4–6 / 7–10 / 11–13 / 14–17 / 18–20**; alternating four/three integer readings, no gaps or overlaps |
| Kid interval formula | Lane `n`: `ceil((n−1) × 3.5)` through `ceil(n × 3.5) − 1`; values outside 0–20 do not score |
| Kid scope | Resistance mapping only; same cadence bands, courses, speed, power reference, bombs and scoring. No automatic physical-knob adjustment. |
| Selector order | First row Kid / Light / Moderate; second row Hard / Challenging / Extreme; same existing button style, 34 px type, 120 px minimum height, 24 px gaps |
| Lane settling | 150 ms before scoring in a new lane |
| Work cadence, lanes 1–2 | 85–105 rpm |
| Work cadence, lanes 3–4 | 70–90 rpm |
| Work cadence, lanes 5–6 | 55–75 rpm |
| Warm-up cadence | 75–95 rpm; current generator's warm-up cadence section is in lane 2 |
| Cadence sweet spot | Band midpoint ±3 rpm inclusive, +20% cadence score; no change to stars |
| Minimum cadence for section points | 20 rpm |
| Speed cap | 140 rpm → 60 km/h in rules; visual stretch 3×, approximately 112 mph on the HUD |
| Lane width | 4.2 world metres |
| Within-lane travel | Centre ±28% of a lane (±1.176 world metres) |
| Steering follow rate | 11/s; 28/s for 0.18 s after crossing a lane threshold |
| Target highlight fade | 0.32 s; color `#c6ecff` |
| Target selection | Active attack lane, else current/next event lane, else last target; stays present through approaches and interruptions |
| Direction prompts | MOVE LEFT / LESS RESISTANCE; MOVE RIGHT / MORE RESISTANCE |

Cadence bands are Lane Smash tuning choices informed by [video research](../research/lanebreak/09-cadence-and-section-flow.md), not a claimed universal Peloton table. The five adult resistance ranges were not changed by either the cadence update or Kid addition. Kid is a custom Lane Smash option, not a published Lanebreak difficulty. Kid uses the same lane-index schedule and lower physical resistance. Current work targets use lanes 3–6; the lane-1/2 work band remains defined for consistency.

## Static off-lane mines

Source: [LaneSmashHazards.gd](../../games/games/neon_vector/LaneSmashHazards.gd), [LaneSmashBombs.gd](../../games/games/neon_vector/LaneSmashBombs.gd).

| Parameter | Current value / behavior |
| --- | --- |
| Eligible sections | Collect (`cruise`), Pedal speed (`hold`), Power Burst (`burst`) |
| Row coverage | Five mines: every lane except the section's target, even if the rider is elsewhere |
| First row | Section start +1,800 road-ms |
| Row spacing | 3,000 road-ms |
| End clearance | Last row no later than section end −1,800 road-ms |
| Example 10-second section | Rows at +1.8, +4.8 and +7.8 road-seconds; 15 mines total |
| Clear areas | All approach/lane-change gaps; target lane; Incoming Fire; cooldown |
| Penalty | Base 100 × score scale 18 = up to 1,800 points; zero score floor |
| Avoidance reward | None |
| Contact | Resolved once by rules in the crossed mine's lane; existing explosion, loss popup and sound |
| Pool / authored validation limit | 40 visible mines / 4,096 authored hazards |
| Render window | Look ahead 16,000 road-ms; retain up to 1,500 road-ms behind for contact clearance; inspect ten prior hazard slots for simultaneous-row fades |
| Post-attack rebuild | Future mines follow the shifted event copies; resolved states remain; new IDs include the return index to prevent duplicates |

These are fixed road objects, not projectiles that follow the rider. At 96 rpm, three road-seconds between rows takes approximately 4.38 active seconds.

## Incoming Fire and immediate rewards

Source: [LaneSmashBarrage.gd](../../games/games/neon_vector/LaneSmashBarrage.gd), [LaneSmashBarrageSpace.gd](../../games/games/neon_vector/LaneSmashBarrageSpace.gd), [LaneSmashSound.gd](../../games/games/neon_vector/LaneSmashSound.gd).

| Parameter | Current value / behavior |
| --- | --- |
| Authored start | 75 active seconds + seeded offset from −8 to +8 seconds; then 180-second intervals |
| Window / shots | 35-second authored window; two shots; returns after the last impact +1.2 seconds |
| Preparation | 9 active seconds, with the target lane highlighted |
| Target lanes | Work lanes 3–6; consecutive authored repeats avoided; clamped to within three lanes of the prior target |
| Charge / fire | Charge 2 s; first charge at zone start −2 s, fire at entry; second charge at +16 s, fire at +18 s |
| Normal flight | 9 s after firing, 11 s after lock |
| Baseline cadence | Previous 200 rules samples (2 seconds at a 10 ms tick) |
| Pace recommendation | Baseline +40 rpm for low baselines (bounded 70–120), otherwise −40 (bounded 45–100); the existing ordinal rule alternates near 80–85 rpm |
| Wrong-lane drop | At firing or entry into an unresolved blast footprint: strike within 450 ms, or earlier if the original impact is sooner; cannot be cancelled by steering afterward |
| Full-width footprint | Blast half-length 20 rules-metres plus rider margin 1.5 rules-metres |
| Successful pass | After launch, nonrapid shot, rider distance strictly greater than `targetMeters + 21.5`; +1,800 immediately, once |
| Holding behind | Safe at impact: zero points and full avoidance star credit |
| Hit | Up to −1,800 points, zero floor; no avoidance star credit |
| Reward versus impact | Popup/pass cue at resolution; projectile/explosion at impact. Separate state prevents early explosions or duplicate rewards/cues. |
| Active-section handoff | Delay preparation and its fade until the final marker; keep the current section fully visible, with 700 ms before preparation |
| Fade window | Normal road fades from prepare −700 ms to prepare +300 ms, returns from attack end −400 ms to end +300 ms |
| Cooldown protection | Omit a deferred attack if its window would enter the last active minute |

Older course snapshots keep their original impact-time reward and other versioned rules. Runtime event, hazard and attack schedules are copies; handoffs never rewrite the stored snapshot.

## Score display and scoring constants

Source: [PointRollup.gd](../../games/framework/ui/PointRollup.gd), [Hud.gd](../../games/framework/hud/Hud.gd), [NeonStatus.gd](../../games/games/neon_vector/NeonStatus.gd), [NeonRules.gd](../../games/games/neon_vector/NeonRules.gd).

| Parameter | Current value / behavior |
| --- | --- |
| Rules tick / subpoints | 10 ms / 100,000 subpoints per displayed point |
| Point scale | 18×; average-ride design target around 150k for 20 minutes, not enforced normalization |
| Collect / cadence | 180 points per valid road-second; cadence sweet spot adds 20% |
| Power | 18 points per 5 joules, with no score ceiling; 150 W internal star reference |
| Stars on completed rides | 25% / 60% / 90% base target completion → 1 / 2 / 3 stars; ended/interrupted attempts get zero |
| Counter animation | Analytic critically damped follower; target retaken every render frame |
| Gain / loss rates | 12/s / 18/s |
| Retargeting | Preserve velocity for continuing gains; clear opposing velocity when the target reverses; clamp overshoot |
| Final settling | Snap internally only when error <0.01 point and speed <0.05 point/s; visible result is rounded to a whole point |
| Other UI values | Ride metrics, speed and ghost gap keep one-second snapshots; section instructions change at boundaries |
| Completion popup | Exact section total at its final marker, a recap rather than an added award |
| Persistence | Save exact rules totals, never the animated display value |

## Superbike rear tyre

Source: [LaneSmashBike.gd](../../games/games/neon_vector/LaneSmashBike.gd). Implemented in `7b56a12`, after APK 27 was prepared. Separate cached front/rear meshes are shared by the rider and best-ride ghost. No added per-frame mesh generation or wheel draw calls.

| Geometry parameter | Front | Rear |
| --- | --- | --- |
| Rubber width, design units | 0.16 | **0.64 (4×)** |
| Rubber width after 1.3× model scale | 0.208 | **0.832 world units** |
| Torus inner / outer radius | 0.51 / 0.67 | 0.43 / 0.67 |
| Tyre axial stretch | 1× | `0.64 / (0.67 − 0.43)` = 2⅔×, after rotating the axle onto X |
| Tyre mesh rings / segments | 28 / 8 | 32 / 12 |
| Rim radius / width | 0.52 / 0.11 | 0.485 / 0.40 |
| Rim light face offset | ±0.060 | ±0.205 |
| Rim light inner / outer radius | 0.465 / 0.510 | 0.430 / 0.475 |
| Axle width / radius | 0.30 / 0.10 | 0.76 / 0.10 |
| Wheel centre Z | −1.05 | +1.50 |
| Wheel centre Y | 0.67 | 0.67 |

Rear swingarms run from `(±0.38, 0.67, 1.50)` at the axle to `(±0.40, 0.82, 0.52)` at the chassis, clearing the wider rubber. Both wheels retain three lit spokes per side and fourteen centre-tread dashes; each dash is 0.075 × 0.03 × 0.15 design units, centred at radius 0.666. The rolling radius stays **0.871 world units**, front axle distance **1.365**, axle-height constant **0.921**, and front contact reach **2.236**. These collision constants, front silhouette, cadence-driven rotation and lane-change lean were not changed.

Visual verification: native riding view and rear three-quarter close-up rendered without script errors. The rendered wheel assembly bounds are 0.30 wide front and 0.76 wide rear in design units (including axle), with identical Y/Z bounds. This verifies appearance and dimensions, not physical-tablet performance. Graphics remains **Auto** by default.
