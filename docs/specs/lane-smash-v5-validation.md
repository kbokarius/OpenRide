# Lane Smash revision 5 — validation

Validated November 13, 2026 on macOS / Apple M4 Max, Godot 4.7.2 and Android Studio JBR. Physical Peloton testing remains outstanding.

## Results

| Check | Result |
| --- | --- |
| Android unit tests | 991 passed, zero failures/errors; final build reuses their unchanged results |
| Focused Godot suites | 51 passed: catalog 16, rules 11, records 5, course 6, space 1, HUD layout 12 |
| Real-renderer geometry suites | 17 passed; actual marker transforms, boundary clearance and fades checked with OpenGL |
| Final visibility regression | Catalog and space: 17 passed after the last ghost/power-zone fade adjustments |
| Rendered lifecycle/layout | 50 checks passed: all 20 duration/difficulty combinations, direct entry, sole game, no circuits, scoring, ghost, music, no manual Pause, automatic sensor recovery, early-end persistence |
| Route and horizon | Two complete 1,800 m route cycles checked; exact tunnel alignment, continuous frames, full inversions, and bounded horizon movement at 0.25 m increments |
| Section boundaries | Bars/arrows contact at their scoring endpoint; incoming boundary targets do not overlap the outgoing finish; targets rest 0.05 m above the road reference plane |
| Power effect | Fill responds to actual joules; brightness responds to eligible watts; final gate disappears once at the endpoint; rendering awards no points |
| Exported pack | Only Lane Smash available; all 13 other game scenes absent |
| Builds | Debug and signed ARM64 neonReal successful |
| Recorded demo | Exactly 120 seconds; 2,400 output frames, 1280×720 at 20 fps, H.264/AAC; original Night Drive soundtrack |
| Demo coverage | 9 gold, 4 cadence and 1 power section completed; 123 impact/completion bursts; ghost near, alongside and behind; 419 rendered frames fully inverted |
| Demo tunnel alignment | Zero difference between the projected road tip and shader portal center throughout; largest per-frame center change 0.00664 in shader projection units |
| Crash reports | No new Godot macOS crash report during this revision; latest existing report remains 12:15:40 |
| Diff whitespace | Clean |

The unchanged course generator and scoring engine retain revision 4's 132 completed full-course simulation runs (40.25 simulated hours), including all 100 named tracks, random tracks, maximum speed and frame-rate/difficulty invariance. Those long simulations were not repeated for this presentation-only revision.

## Problems found and resolved

An early horizon implementation truncated the mesh at discrete viewport boundaries. The user observed visible cutovers. It was replaced by a continuous distance/curvature budget, a smoothed horizon and a render-rate vertex-shader taper. Road samples remain anchored; shader uniforms move the endpoint continuously. All four background styles use the exact endpoint projection.

The final marker of one section initially occupied the same boundary as the next section's first marker. The next section now skips that shared-boundary marker, while the outgoing final marker remains aligned with the scoring endpoint. Bars and arrows were lowered from a floating hover to the surface, and wheel-contact distance now accounts for tire curvature at their actual height. Completion text stays fixed to the outgoing final target.

Headless Godot reports a small physical viewport and dummy MultiMesh transforms. Projection tests now use the logical visible rectangle; actual marker transforms are additionally verified using the real renderer. All final tests pass.

## Signed artifact

- File: `openride-neon-13.apk` (62.0 MiB)
- Package: `dev.digitalducktape.openride.neon`
- Version code: 13
- Version name: `1.2.0-lane-smash.5`
- Label: Lane Smash
- ABI: arm64-v8a; real sensors
- Minimum SDK: 29 (Android 10); target SDK 34
- Signature: verified; same signing identity as revisions 3 and 4
- Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`
- APK SHA-256: `35d037719bc8cb293d11724c774d536593f66fae3cb91ee815359a96e3c08347`

## Reproduction and limits

Use `:app:testDebugUnitTest :app:assembleDebug :app:assembleNeonReal` with JAVA_HOME, ANDROID_HOME, GODOT_BIN and the private NEON_SIGNING_PROPERTIES path set. Never commit signing credentials.

Run focused suites through `addons/gdUnit4/bin/GdUnitCmdTool.gd`; use the actual rendering driver for `lane_smash_catalog_test` and `neon_vector_space_test` in addition to headless coverage. `tests/play_neon_vector.gd` checks the UI/lifecycle; `tests/demo_lane_smash.gd -- --out=<absolute-directory>` records an isolated simulated ride. Its timestamps are preserved during video encoding; duplicate capture timestamps are collapsed before conversion to 20 fps.

Desktop logs showed approximately 59–60 fps during sampled gameplay, with no gameplay hitch above the logger's 500 ms threshold. Recording still introduces capture overhead; this is not a Bike GPU/thermal benchmark. The intro warms resources before scoring starts. Command-line shutdown may report retained resources; no new OS crash dialog was observed. Physical sensor compatibility, touch behavior and sustained performance on the user's original Bike remain unverified. No APK was installed on the Bike, no membership was changed, and no GitHub release was published. Package, signing key, course/scoring comparison identity and Room schema remain unchanged.
