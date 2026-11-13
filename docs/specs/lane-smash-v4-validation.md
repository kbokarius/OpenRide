# Lane Smash revision 4 — validation

Validated November 13, 2026 on macOS / Apple M4 Max, Godot 4.7.2, Android Studio JBR and Android SDK 36.1.0 build tools. Physical Peloton testing remains outstanding.

## Results

| Check | Result |
| --- | --- |
| Android unit tests | 991 passed, zero failures/errors |
| Focused Godot suites | 46 passed: catalog 11, rules 11, records 5, course 6, space 1, HUD layout 12 |
| Rendered lifecycle and layout script | 50 checks passed, including all 20 duration/difficulty combinations, direct entry, sole game, no circuits, scoring, ghost, music, no manual Pause, automatic sensor recovery and early-end persistence |
| Full-course simulator | 132 completed runs, 40.25 simulated hours; all 100 named tracks, seeded random courses, maximum-speed bounds, ghost validation and frame-rate/difficulty invariance |
| Exported pack | Boots into Lane Smash; all 13 other game scenes absent |
| Builds | Debug and signed ARM64 neonReal successful |
| Recorded demo | Exactly 120 seconds, 2400 frames, 1280×720 at 20 fps, H.264/AAC; original Night Drive soundtrack |
| Demo coverage | 9 gold sections, 4 cadence sections, 1 power burst completed; 140 impact/completion bursts; matching ghost near, alongside and behind |
| Crash reports | No new Godot macOS crash reports during this revision's testing; most recent pre-existing report is 12:15:40 |
| Diff whitespace | Clean |

The duration bug involved both a font reset on selection and excessive minimum content padding. Selection now keeps 34-pixel text, equal duration widths, and no scale pop; the five difficulty buttons use separate three/two-button rows.

Early validation found repeated lanes at a permutation boundary and old course validation rejecting the new short bursts. Both were fixed, then the catalog and full-course suites passed. The older whole-upstream UI suite is not a product acceptance suite for this single-game fork. Archived Android circuit/game tests explicitly use the legacy fixture.

## Signed artifact

- File: `openride-neon-12.apk` (approximately 62 MiB)
- Package: `dev.digitalducktape.openride.neon`
- Version code: 12
- Version name: `1.2.0-lane-smash.4`
- Label: Lane Smash
- ABI: arm64-v8a; real sensors
- Minimum SDK: 29 (Android 10); target SDK 34
- Signature: APK v2 verified; same signing identity as revision 3
- Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`
- APK SHA-256: `da5d5e48c38d5f63242ea11e032a894d15ec9946ffcde83ebd25130fc537355c`

## Reproduction

Run `:app:testDebugUnitTest :app:assembleDebug :app:assembleNeonReal` with JAVA_HOME, ANDROID_HOME, GODOT_BIN and the private NEON_SIGNING_PROPERTIES path set. Never commit signing credentials.

Run focused GdUnit suites `lane_smash_catalog_test`, `neon_vector_rules_test`, `neon_vector_records_test`, `neon_vector_course_test`, `neon_vector_space_test`, and `hud_layout_test` through `addons/gdUnit4/bin/GdUnitCmdTool.gd` with `--ignoreHeadlessMode`. Run `tests/sim_lane_smash.gd` headlessly and `tests/play_neon_vector.gd` with the real renderer. `tests/demo_lane_smash.gd -- --out=<absolute-directory>` captures a two-minute simulated ride in isolated history.

## Limits

Desktop preview performance is not a Bike benchmark. Full-course simulations validate scoring/content/persistence formats, not hours of physical rendering. Godot sometimes reports a few retained resources on command-line shutdown; the passing gameplay run exited without an OS crash dialog. Headless export also reported stale generated-test-report image imports; the exported production pack was independently loaded and audited successfully. This does not establish original-Bike tablet/firmware compatibility, live sensor behavior, touch behavior, or sustained thermal performance. No APK was installed on the user's Bike and no GitHub release was published.
