# Current gameplay and presentation parameters

Verified against revision-25 source November 20, 2026. Signed build 33 / revision 25 is installed on the Bike. This is a tuning reference; [Rules](RULES.md) explains behavior, [Presentation](PRESENTATION.md) explains the look/audio, and [Architecture](ARCHITECTURE.md) explains ownership and persistence.

## Units and release state

- Player-facing lanes are **1–6**; stored `laneIndex` values are **0–5**.
- **Active seconds** are the ride clock. Stopping pedalling consumes them; a sensor interruption freezes them.
- **Road seconds** are distance divided by the maximum rules speed, 60 km/h. One road-second is 16⅔ rules-metres, drawn as 50 world metres. At a constant cadence below 140 rpm, actual seconds = road seconds × 140 / rpm. At zero cadence the road does not advance. Section lengths and mine spacing use road time; attack timers and the final-minute cooldown use active time.
- The model uses design units, multiplied by `LaneSmashBike.SCALE = 1.3`. These dimensions describe game geometry, not a real motorcycle specification.
- Current source rules: course **13**, generator **10**, scoring **12**, envelope **1**. Added gap hazards create new comparison keys. Course 12 retains scoring 11 and mine-free gaps; course 11 retains scoring 10; older saved snapshots and histories remain readable. Kid and all adult resistance bands are unchanged.
- Latest signed APK and verified device installation: **33 / 1.2.0-lane-smash.25**, adding pre-ride personal score targets and compatible ghosts across updates. Installed in place over Wi-Fi on November 20, 2026. See the [build and installation record](../specs/lane-smash-v25.md#build-and-installation).

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
| Cooldown | Requested at 60 active seconds remaining; finish an active section before changing lanes. An already-announced approach gets a full 10-road-second Collect in that lane before stepping down by at most three lanes. Then descend toward lane 1; no mines, bursts or gunfire in the cooldown tail |
| Boundary exception | The fixed ride finish can end a section; attack and cooldown handoffs no longer shorten an active section. Very slow/stopped riding can reduce the available cooldown time |
| Road length | `minutes × 1,000 + 300` rules-metres; sufficient for the 140-rpm speed cap |
| Latest full-course audit | Revision 24: zero target-following mine hits; 116 tracks, 36.25 simulated hours; four additional speed traces; all six difficulty mappings, including full Kid rides. Adult target-following gaps below 22 active seconds; Nightfall 19.4 seconds. Half-cadence Kid uses twice the traversal-time budget (44-second approaches / 120-second lane visits); Kid Nightfall measured 38.15 seconds. Distances and speed mapping are unchanged. These are measured traces, not guarantees while stopped. |

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
| Kid scope | Resistance 0–20 plus 50% Pedal Speed targets on new rides, rounded to nearest whole rpm. Same track geometry, speed mapping, power reference, bombs and scoring formulas. No automatic physical-knob adjustment. |
| Kid cadence | Warm-up **38–48 rpm**; work lanes 1–2 **43–53**, lanes 3–4 **35–45**, lanes 5–6 **28–38**. Sweet spot remains midpoint ±3 rpm. Saved older rides keep their original bands. |
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
| Steering follow rate | **24/s**; **40/s** for 0.18 s after crossing a lane threshold. 90% response in about 96 ms / 58 ms after a received change; frame-rate independent, no prediction |
| Sensor reporting request | Original Bike V1 path: **100 ms / 10 Hz requested** in build 31 onward (previous build 30 requested 200 ms / 5 Hz). Firmware can limit/ignore this; actual delivery/measurement latency is not established by the request |
| Resistance readout | Checks current input every rendered frame; changes the cached label only when the rounded resistance changes. RPM, watts and heart-rate readouts retain the one-second text interval |
| Target highlight fade | 0.32 s; color `#c6ecff` |
| Target selection | Active attack lane, else current/next event lane, else last target; stays present through approaches and interruptions |
| Direction prompts | MOVE LEFT / LESS RESISTANCE; MOVE RIGHT / MORE RESISTANCE |
| Inner-edge warning | Outer 25% of a resistance band near an internal seam; smoothstep strength, 0.3 s fade. Five internal seams only; no exterior-edge warning or steering/scoring change |
| Warning color / extent | Brighter coral-red RGB (0.95, 0.34, 0.38), mixed at up to 92%; local road window −18 to +65 world metres, fully present −4 to +18; fades at ends |
| Cadence preview | Shared 1,200 active-ms estimate at current speed; current approached section only, no look-ahead across another section; none while stopped ahead of it |
| Cadence start | Active meter, section and gunfire agree on event ID; first active rendered frame fires, even after a skipped preview; ordinary two-second damage grace remains |
| Prompt state | UP NEXT with distance during approach; NOW at section start. Section boundaries and each changed resistance reading bypass the one-second text timer. STAY IN THIS LANE appears immediately inside the target band, independent of scoring’s 150 ms settling |

Cadence bands are Lane Smash tuning choices informed by [video research](../research/lanebreak/09-cadence-and-section-flow.md), not a claimed universal Peloton table. The five adult resistance ranges were not changed by either the cadence update or Kid addition. Kid is a custom Lane Smash option, not a published Lanebreak difficulty. Kid uses the same lane-index schedule and lower physical resistance. Current work targets use lanes 3–6; the lane-1/2 work band remains defined for consistency.

## Static off-lane mines

Source: [LaneSmashHazards.gd](../../games/games/neon_vector/LaneSmashHazards.gd), [LaneSmashBombs.gd](../../games/games/neon_vector/LaneSmashBombs.gd).

| Parameter | Current value / behavior |
| --- | --- |
| Eligible sections | Collect (`cruise`), Pedal speed (`hold`), Power Burst (`burst`) |
| Section row coverage | Five mines: every lane except the section's target, even if the rider is elsewhere |
| First row | Section start +1,800 road-ms |
| Row spacing | 3,000 road-ms |
| End clearance | Last row no later than section end −1,800 road-ms |
| Example 10-second section | Rows at +1.8, +4.8 and +7.8 road-seconds; 15 mines total |
| Gap rows | Start 1,000 road-ms after the previous section ends, repeat every 3,000 road-ms; stop at least 500 road-ms before the next section starts. No mines before the first section |
| Lane-change allowance | At least 4 / 5 / 6 road-seconds for a 1 / 2 / 3-lane change. The old lane, intervening lanes and target form a clear corridor until that deadline; the first row at/after it guards every non-target lane |
| Same-lane gap | Five mines in the other lanes, including the midpoint of the ordinary two-second gap; no adjustment is needed |
| Clear areas | Target lane always; adjustment corridor during the allowance; initial approach; Incoming Fire; cooldown |
| Penalty | Base 100 × score scale 18 = up to 1,800 points; zero score floor |
| Avoidance reward | None |
| Contact | Resolved once by rules in the crossed mine's lane; existing explosion, loss popup and sound |
| Pool / authored validation limit | 40 visible mines / 4,096 authored hazards |
| Render window | Look ahead 16,000 road-ms; retain up to 1,500 road-ms behind for contact clearance; inspect ten prior hazard slots for simultaneous-row fades |
| Post-attack rebuild | Future mines follow shifted event copies. First gap starts from the actual attack exit lane and road position, rounded up to the 10-ms grid; the same adjustment allowance applies. Resolved states remain; IDs include the return index. Course ≤12 retains its former mine-free gaps |

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
| Committed-section handoff | Delay preparation through both the announced approach and the full section; keep its lane during the following 700 ms recap/fade, then switch directly to the attack lane |
| Fade window | Normal road fades from prepare −700 ms to prepare +300 ms, returns from attack end −400 ms to end +300 ms |
| Cooldown protection | Omit a deferred attack if its window would enter the last active minute |

Older course snapshots keep their original impact-time reward and other versioned rules. Runtime event, hazard and attack schedules are copies; handoffs never rewrite the stored snapshot.

## Beside-bike bomb gauge

Source: [LaneSmashBarrageGauge.gd](../../games/games/neon_vector/LaneSmashBarrageGauge.gd), [LaneSmashBikeGaugeAnchor.gd](../../games/games/neon_vector/LaneSmashBikeGaugeAnchor.gd).

| Parameter | Value |
| --- | --- |
| Panel | 244 × 400 stage pixels, same dimensions/anchor as cadence; at least 132 px horizontal clearance from projected bike anchor |
| Placement | Chooses outward side with hysteresis, moves inward at screen edges, clamped between top cues and lane dock; no top bomb bar |
| Fade / follow | 0.2 s fade; marker exponential follow 10/s; position follows at 7/s |
| Vertical scale | Projected landing-time offset −60 to +60 rules-metres; ±21.5 m red blast interval |
| Colors | Above: green `#70efb4`; middle: red `#ff5268`; below: dark slate `#293b50`; white position marker |
| Meaning | Green: predicted safe pass; red: predicted overlap; slate: predicted safe hold-back. Only resolved outcomes claim PASSED / AVOIDED / BOMB HIT |
| Preparation / outcome | No projected marker before a shot locks; countdown and pace prompt during flight; actual points/outcome afterward; sensor interruption fades the meter out |

## Score display and scoring constants

Source: [PointRollup.gd](../../games/framework/ui/PointRollup.gd), [Hud.gd](../../games/framework/hud/Hud.gd), [NeonStatus.gd](../../games/games/neon_vector/NeonStatus.gd), [NeonRules.gd](../../games/games/neon_vector/NeonRules.gd).

| Parameter | Current value / behavior |
| --- | --- |
| Rules tick / subpoints | 10 ms / 100,000 subpoints per displayed point |
| Point scale | 18×; average-ride design target around 150k for 20 minutes, not enforced normalization |
| Collect / cadence | 180 points per valid road-second; cadence sweet spot adds 20% |
| Power Burst | Integrate power × (clamped rpm / 90)² over valid time, then award 18 points per 5 weighted joules; no score ceiling. At constant W over a complete spatial burst, points are proportional to rpm |
| Burst precision / cap | Per 10-ms tick: round(10 × 1,000 × (rpm / 90)²) weighted milliseconds; rpm capped at 140; energy accumulated in integer microjoules |
| Burst reference / stars | 90 rpm reproduces prior energy scoring. Available and earned star credit use the same speed weighting and 150 W reference; surplus output raises points only. Raw actual joules remain stored separately |
| Representative 20-minute calibration | Mean 156,973.6; range 140,149–173,334 across 25 Challenging tracks with the documented simulated rider; no fixed score normalization |
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

## Personal best preview and ghost (revision 25)

| Parameter | Value / behavior |
| --- | --- |
| Previous best | Highest completed compatible score for this rider, track, duration and difficulty |
| Score to beat | Displayed whole-number best + 1 point |
| Version boundary | Same point scale, envelope, reference power, six resistance bands and Kid cadence percentage; an older comparison key is explicitly labeled |
| Countdown | Existing countdown starts advancing only after benchmark/trace loading completes |
| Preview block | 1120 × 174 logical px; 36 px previous score, 52 px goal, 30 px explanation |
| Ghost samples | Existing 100 ms recording; interpolate distance/lane and derive cadence between samples |
| Nearby ghost | Visible from −5 to +85 rules-metres, with far/portal fades; distant gap remains in HUD |
| Overlap fade | Longitudinal fade 1.4–4.5 rules-metres; lateral clearance fade 0.15–0.65 lanes, using the larger visibility |
| Earlier-version HUD | PRIOR BEST; same-version HUD BEST RIDE; gap/points remain on the existing one-second refresh |
| First ride / unavailable trace | Explicit first-high-score or missing-recording message; no invented ghost |
