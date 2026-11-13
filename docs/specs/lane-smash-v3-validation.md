# Lane Smash revision 3 — validation

Validated November 13, 2026. Package `dev.digitalducktape.openride.neon`, version code 11, `1.2.0-lane-smash.3`.

## Automated results

| Check | Result |
| --- | --- |
| Android `:app:testDebugUnitTest` | **989 tests, zero failures/errors** |
| Debug + signed real-sensor APK | `:app:assembleDebug :app:assembleNeonReal` successful; vital lint passed |
| Focused Godot suites | **113 distinct passing cases** across catalog (10), rules (11), records (5), course (6), 3D space (1), hub layout (17), HUD layout (12), options (8), session director (43) |
| Full-course simulation | **132 runs / 40.25 simulated hours**, all completed and valid |
| Rendered real host lifecycle | **28 checks passed**, hub → setup → saved ghost → ride → sensor recovery → early end → history |
| Formatting | `git diff --check` clean |

The focused suites ran in several processes. An initial selector-layout run caught five 32 px buttons below the shared 34 px minimum; the fix was rerun with all 17 hub layout cases passing. A comparison-key test's old four-tier count was updated for five current plus four preserved historical tiers; all six course cases passed.

Simulation covers all 100 named tracks, 12 generated tracks, all four durations at over-limit cadence, and identical traces at 30/60/120 FPS for all five current difficulty ranges. Maximum-speed coverage includes the road buffer. Exact resistance boundaries, out-of-range input, pause/recovery integrity, output-based scoring and old scoring identities remain covered.

## Latest behavior checks

- Front-wheel overlap shatters gold bars, cadence arrows and power crystals exactly once. Wrong-lane objects do not shatter. A visual hit never creates points independently of the rules.
- Background flow speeds up with cadence and changes with resistance; reduced motion lowers animation intensity. All four shader modes compile/render with the actual GL Compatibility backend.
- No Pause control. A manual pause request is ignored; End Ride stays available. End confirmation does not stop the clock. Zero cadence consumes time without points/distance.
- Native freewheel opt-out is scoped to the active Lane Smash plan and restored afterwards. Tests cover continued coasting time and the return of normal freewheel behavior.
- Sensor silence freezes scoring; one fresh frame cannot bypass recovery. Healthy readings trigger automatic recovery/countdown without a manual Resume button.
- Last/best stats remain available beyond the latest-50 history window, with partial attempts excluded from best ghosts.

## Visual demonstration

The visible simulator starts a 15-minute Carbon Ridge ride on Challenging, with a completed 100-rpm best ride stored in isolated demo data. The current rider varies from 60 to 140 rpm. Logs confirmed nearby, alongside, behind and far-ahead ghost states. The 90-second capture contains 893 frames and 86 object impacts. A recording with the new soundtrack accompanies the build; recorded frames are 10 FPS, while the visible game targets 60 FPS.

The demo never writes artificial scores to normal rider history. UI captures cover setup, settings/history, riding, sensor interruption and early-end results. The selector and all shared hub screens were checked for visible text, touch sizes and overflow. Lane Smash shows five difficulty choices, with Challenging selected, no duplicate lane-range instruction and no Pause button.

## Performance and crash observations

On the development Mac (Apple M4 Max), the Vortex shader capture measured a 16.67 ms median frame interval and 17.13 ms p95, with 138 draw calls p95 and approximately 58.7 MiB engine static memory. This is desktop evidence, not a Peloton performance claim.

Earlier macOS crash dialogs corresponded to GdUnit shutdown/resource-disposal failures; the unchanged baseline had reproduced that engine failure. Focused revision-3 tests and rendered play completed without new macOS Godot crash reports. Some test shutdowns still report ObjectDB/resource leaks. We did not disable crash reporting or claim to fix the upstream engine shutdown bug.

## Artifact identity

- File: `openride-neon-11.apk`.
- Manifest label: **Lane Smash**.
- ABI: **arm64-v8a** only.
- Minimum Android: **10 / API 29**; target/compile API 34.
- Real Peloton sensor flavor; same package/signing identity as the previous fork build.
- Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`.
- APK SHA-256: `e0714ada4abea9e6b36e512e15d9d4ac9ac8a606eec5ece7a8882afd5905eb95`.

## Not yet verified

No installation or sensor test on the user's physical Original Bike. Its non-rotating screen alone does not determine Android version or tablet generation. Sustained GPU performance, temperature, actual knob/sensor behavior, audio routing and background recovery need a real-device ride. The upstream hardware and issue assessment remains in [research](../research/lanebreak/03-stability.md).

No GitHub release has been published. Use the signed local APK and [installation guide](../LANE_SMASH.md#installing-the-fork-on-the-bike); the release updater only applies after an appropriate release exists. No Room schema change or Drizzle migrations were introduced.
