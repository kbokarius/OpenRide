# Lane Smash revision 21 — clear lane commitments and beside-bike feedback

November 16, 2026. **Source changes and local tests only. No APK was built for release, no installation was performed, and the Peloton remains on build 28 / revision 20.** A later release must increment the Android build/version before signing. Current source creates course 12 / generator 9 / scoring 11; envelope 1 and all resistance bands remain unchanged.

## Requests and decisions

1. Move the bomb meter beside the motorcycle, styled like the cadence meter. Use red in the middle, green above, and a quiet dark color below.
2. Remove lane requests that are immediately withdrawn without delivering a section, including Nightfall and the random generator.
3. Prevent brief/empty cadence sections; synchronize the prompt, physical section, cadence gauge and firing gunner. A short advance warning is allowed.
4. Indicate proximity to an inner lane edge with a muted-red line; exclude the two exterior edges and do not change steering.
5. Make a complete Power Burst reward higher speed generously and proportionally, rather than rewarding slow traversal for taking longer.
6. Keep structured mechanics/parameter notes current and test locally without updating the Bike.

The implementation reuses the existing screen-space HUD, fonts, panel shape, rules projections, seeded generator and road shader. A shared bounded anchor keeps both gauges beside the motorcycle at a constant readable size. A world-space meter was rejected because perspective/roll would change its readability. Rendering remains observational: scoring, lane thresholds and measured sensor values are never written by the HUD or warning shader.

## Root causes and lane-flow changes

The initial Nightfall sweep reproduced **59 empty lane visits** across four durations and five pace profiles. Some lasted only 700 ms; others lasted most of an approach. Incoming Fire previously waited only when the ordinary section was already active, so it could replace a section whose lane had just been announced. During the final-marker fade, the event cursor also exposed the next ordinary lane briefly before the attack took over. The exact-minute cooldown could similarly replace an unplayed approach or cut a just-started cadence section short.

Scoring 11 now treats an announced approach as a commitment:

- Incoming Fire waits through both the current approach and its complete section.
- During the following 700 ms recap/fade, `completing_section` retains that completed event/lane. Scoring is idle, but its final-marker celebration can finish normally. The next instruction goes directly to the attack lane.
- At the one-minute cooldown request, an active section finishes before the descent. If an approach is already announced, the first cooldown Collect delivers ten road-seconds in that lane, preserving the remaining approach, before stepping down by at most three lanes.
- The fixed ride finish still ends the ride on time. Slow or stopped riding can leave less time for the cooldown descent; the clock is not extended.
- Attack-return reflow, full ten-road-second Collect/cadence sections, five/six/seven-second bursts, mine-free adjustment gaps and the maximum three-lane jump are retained.

These changes apply identically to named and random tracks. Runtime event/hazard/attack copies can move; the saved course snapshot and fingerprint remain immutable during a ride.

## Cadence timing and clear prompts

The old cadence preview was three **road** seconds and the gunner used a separate 2.2-road-second threshold. At 65 rpm, three road seconds take about 6.46 actual seconds, making the meter appear long before firing.

Both now use `NeonRules.cadence_target()` with a **1,200 ms active-time estimate** at current speed. Only the currently approached section can preview; the gauge cannot look across another ordinary section. The preview disappears while stopped before the section. It is labeled **NEXT · RPM / GET READY**.

The top prompt says **UP NEXT · PEDAL SPEED** and shows the remaining distance during approach; **NOW · PEDAL SPEED** begins at the actual section boundary, without waiting for the next one-second text refresh. On the first active rendered frame the gunner fires immediately; if the preview was skipped by acceleration or a render gap, presence is raised to 0.9 rather than delaying firing for the fade. The existing two-second damage grace, cadence bands and hit limits are unchanged.

## Beside-bike bomb meter

`LaneSmashBarrageGauge` is now a view-owned `RefCounted` painter beside the motorcycle; the horizontal meter is removed from `NeonStatus`.

- Panel: 244 × 400 stage pixels; shared `LaneSmashBikeGaugeAnchor` with the cadence gauge, including inward placement at screen edges, hysteresis and at least 132 px clearance from the projected bike anchor.
- Vertical scale: projected position at impact from −60 to +60 rules-metres. The exact blast clearance limits are ±21.5 m.
- Above: green `#70efb4`, **PASS / + POINTS**. Middle: red `#ff5268`, **BLAST**. Below: dark slate `#293b50`, **BEHIND / NO POINTS**.
- White rider marker, restrained gradient, countdown, pace instruction and rpm target. Marker follows at 10/s; fade takes 0.2 s; position follows at 7/s.
- Before lock: preparation countdown without a projected marker. During flight: prediction only. After resolution: **PASSED**, **AVOIDED** or **BOMB HIT**, with actual earned/lost points. A wrong-lane rapid drop explicitly says **WRONG LANE**.
- Sensor interruptions fade it out. The cadence and bomb panels do not draw over one another.

## Inner-edge warning

`LaneSmashSteering.edge_warning()` reads the existing resistance band and returns the nearby internal seam plus strength. The outer quarter of the inclusive band is the warning region, using smoothstep toward full strength at the edge. It fades over 0.3 s and clears toward the middle. Crossing a band threshold continues highlighting the same boundary rather than flashing another line.

The existing deck shader mixes a muted rose, RGB `(0.66, 0.25, 0.29)`, onto that seam near the rider: from −18 to +65 world metres, fully present from −4 to +18, softly fading at each end. There are exactly five weights for the five interior boundaries. No exterior warning, beep, flashing, additional geometry, resistance adjustment, lane hysteresis or scoring change is introduced.

## Power Burst speed reward

The former energy-only formula rewarded longer traversal at the same watts. New bursts integrate:

`weighted joules = integral(measured watts × (clamped cadence / 90)² × valid seconds)`

`points = weighted joules × 18 / 5`

Because traversing a fixed spatial section takes inversely as long at higher cadence, a **complete** burst at constant watts earns points proportional to cadence. Doubling cadence doubles its full-section reward. More measured power adds proportionally as well. Cadence is capped at the same 140-rpm game-speed limit; wrong lane, zero power and cadence below 20 do not earn burst points.

For a six-road-second burst at 150 W, ideal complete-pass totals are approximately:

| Cadence | Game speed | Points |
| --- | --- | --- |
| 45 rpm | 36 mph | 2,520 |
| 60 rpm | 48 mph | 3,360 |
| 90 rpm | 72 mph | 5,040 |
| 120 rpm | 96 mph | 6,720 |
| 140 rpm | 112 mph | 7,840 |

At 90 rpm the previous energy reward is unchanged. Tick/contact rounding can move the displayed total slightly. The per-tick weighted duration is an integer at 1,000 subdivisions per millisecond; weighted energy is accumulated in integer microjoules. Raw measured joules are still stored for ride statistics. The floor charge and power meter read weighted reward energy. Available and earned burst star credit use the same speed factor and 150 W reference, so extra power cannot replace missed base credit elsewhere.

The updated representative 25-track, 20-minute Challenging calibration is **156,973.6 mean points**, range **140,149–173,334**. It uses 90 rpm Collect, cadence-band midpoint, 110 rpm bursts, resistance-dependent watts, modest misses and gradual attack responses. Its attack lane now follows the authored highlighted lane rather than the obsolete lane-1 assumption. This is a reproducible simulated rider, not normalization of real scores.

## Compatibility and release separation

Course 12 / generator 9 / scoring 11 isolates the new timing and reward rules. Course 11 explicitly maps to scoring 10; its original attack, exact-minute cooldown and unweighted energy outcomes remain unchanged. Older history remains readable, while new-layout last/best/ghost comparisons are separate. Both Kotlin and Godot record validators accept scoring versions 1–11 and reject future unknown versions. No database schema or migration changes are involved.

All six difficulty mappings, saved settings, package/signing identity and Auto graphics default are unchanged. The device and signed APK remain build 28. Local test tools use simulated input and isolated preferences/history; no device commands were used for this work.

## Validation

- Reproduced the original empty-visit defect before the fix; the initial handoff regression failed because an announced lane received zero section credit before attack replacement.
- Full-course audit: **116 courses / 36.25 simulated hours**, all 100 named duration/name combinations plus 16 random seeds; all six resistance mappings; four additional 30-minute speed traces. **2,880 lane changes** and **804,662 active cadence checks** passed without empty lane visits, missing meter/fire state, truncated played sections, invalid transition gaps, jumps over three lanes or mutated snapshots. Nightfall's maximum measured ordinary approach remains 19.4 active seconds on the target-following trace.
- Separate Nightfall handoff audit: **28 full rides / 8.75 hours**, all durations at 20/45/60/80/100/140 rpm plus a target-following profile. **637 lane changes**, no empty/brief visits before another lane request.
- Focused Godot regression suites cover new/legacy handoffs, cooldown boundaries, bomb projections/outcomes, gauge bounds/fades, six-lane gunner visibility and immediate fire, prompt boundary timing, all difficulty edge warnings, burst speed/power ratios, batching determinism, authored/random content, records and the existing HUD.
- Android record tests passed: **13 tests**, including versions 10/11 acceptance and version 12 rejection. No signed installer was generated.
- Native Compatibility-renderer captures checked the bomb meter in flight and after a pass, Nightfall lane-6 cadence preview/start/fire, and the muted internal edge warning. No script/shader errors occurred in those captures. This is desktop validation, not a claim about physical tablet performance.

**Final regression run: 118 Godot cases across 13 suites; zero errors, failures or reported test orphans.** Together the two full-ride audits cover 144 rides / 45 simulated hours, plus the four speed traces. Test-loop hitch messages reflect accelerated headless simulation, not measured tablet frame times.

### Commands

```sh
godot --headless --path games -s res://tests/audit_lane_smash_tracks.gd
godot --headless --path games -s res://tests/audit_lane_smash_handoffs.gd
godot --headless --path games -s res://tests/calibrate_lane_smash_scores.gd
godot --headless --path games -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit/lane_smash_handoff_test.gd -a res://tests/unit/lane_smash_local_gauges_test.gd -a res://tests/unit/lane_smash_burst_speed_test.gd -a res://tests/unit/lane_smash_steering_test.gd
./gradlew :app:testDebugUnitTest --tests 'dev.digitalducktape.openride.games.bridge.NeonRecordsTest'
```

### Code review

**Critical:** no outstanding findings after the focused fixes and regression checks.

**Improvements addressed:** shared gauge placement instead of duplicate positioning; a single cadence-preview contract; bounded warning/gauge rendering; explicit snapshot versioning; separate raw/weighted burst energy; audit assertions that detect empty lane visits and incomplete sections.

**Positive:** timestamped rules remain deterministic; renderers do not award points; existing device/install state is kept distinct from source state. Reviewed with the repository's Godot HUD, shader, procedural-generation, testing and code-review guidance.
