# Lane Smash revision 6 — validation

Validated November 13, 2026 on macOS / Apple M4 Max, Godot 4.7.2 (GL Compatibility) and Android Studio JBR. Physical Peloton testing remains outstanding.

## Final checks

| Check | Result |
| --- | --- |
| Focused Godot tests | 55 passed, zero errors/failures: path 5, catalog 15, rules 11, records 5, course 6, space 1, HUD 12 |
| Real-renderer tests | 16 passed: catalog and arrow anchoring/solid geometry/fade checks with OpenGL |
| Stored route coverage | All 100 named tracks plus 12 random duration/seed combinations reproduce; stored JSON reproduces world positions within 1 cm |
| Fixed geometry | Near and distant world poses remain identical while the camera moves through 100–1,100 m; cadence changes do not move geometry |
| Width and continuity | Constant 18 m width, valid orientation frames and continuous neighboring frames over 10,400 m, including inversions |
| Reduced motion | No inversions across the checked route |
| History compatibility | Removing the new presentation field reproduces the old course hash and comparison key exactly; gameplay changes still change identity |
| Android unit tests | 991 passed, zero failures/errors/skips; unchanged native results reused by the final build |
| Exported pack | Lane Smash only; all 13 other game scenes absent; new route resource included |
| Build | Debug and signed ARM64 neonReal succeeded |
| Signature | APK signature verified; same signing certificate |
| Diff whitespace | Clean |

## Rendered demonstration

The final isolated run completed 120 active seconds, captured 2,400 frames and completed 9 gold, 4 cadence and 1 power section. It includes 123 impact/completion bursts, the best-ride ghost near/alongside/behind, and 168 rendered frames fully inverted. All assertions passed. The projected road endpoint and background axis agreed within 0.00000047 projection units.

Sampled gameplay remained at 60 fps. There were no gameplay hitches, automatic recovery interruptions, script errors or crash dialogs in this final recording. Resource warm-up occurred during the hub/intro before scoring started. Two duplicate capture timestamps are collapsed during conversion to the 20 fps video. The delivered video is H.264/AAC at 1280×720, with the original Night Drive soundtrack.

The opening's observed position ranged approximately from x=0.39–0.62 and y=−0.07–0.50 in this particular two-minute sample. It naturally moves beyond the upper edge during part of the loop. The earlier forced all-corners circuit has been removed in favor of following the real course; this recording does not claim to visit all four corners.

## Corrections verified

The endpoint-driven deformation was removed entirely. The road shader now only shades/fades its immutable world geometry; it does not move a vertex. The cyclist, ghost, targets and camera share one saved, distance-based 3D route. The background reference frame aims down that actual course. No independent waypoint circuit pulls the far road around the screen.

The road uses 74% opacity and the lane lines 94%, with depth handling and explicit draw order. Representative rendered captures show the background through the road while targets and section overlays remain clear. The horizon fades gradually without squeezing the road width.

The headless renderer returns dummy MultiMesh transforms. A previous test compared camera distance against that dummy origin; its distance/fade assertions now run with the real renderer. World-position invariance is separately covered by the new fixed-route test, including distant positions. All final checks pass.

One earlier capture, recorded concurrently with another rendered test window, encountered a 293 ms display stall and exercised automatic sensor recovery. The delivered recording is captured separately after the rendered tests and build finish. This is distinct from a crash and does not add a manual Pause control.

## Signed artifact

- File: `openride-neon-14.apk` (65,014,781 bytes)
- Package: `dev.digitalducktape.openride.neon`
- Version code: 14
- Version name: `1.2.0-lane-smash.6`
- Label: Lane Smash
- ABI: arm64-v8a; real sensors
- Minimum SDK: 29 (Android 10); target SDK 34
- Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`
- APK SHA-256: `17891c8a7914c26f50032e2941fbd8aaa978f90e053cb6192cc102718ac57ac2`

## Reproduction and limits

Run the listed Godot suites through `addons/gdUnit4/bin/GdUnitCmdTool.gd`; additionally run catalog and space suites with the actual rendering driver. `tests/demo_lane_smash.gd -- --out=<absolute-directory>` records an isolated simulated ride with a seeded best-ride ghost, without changing real history. Preserve its capture timestamps when encoding; collapse duplicate timestamps before conversion to 20 fps.

Build with `:app:testDebugUnitTest :app:assembleDebug :app:assembleNeonReal`, setting JAVA_HOME, ANDROID_HOME, GODOT_BIN and the private NEON_SIGNING_PROPERTIES file path. Do not commit signing credentials.

Revision 4's 132 full-course scoring simulations (40.25 simulated hours) and revision 5's 50 lifecycle/layout checks remain the baseline for their unchanged systems; those broader runs were not repeated here. New path generation, snapshot round trips, fixed geometry, comparison identity and rendering are covered above.

Desktop capture performance is not a Peloton GPU/thermal benchmark. Physical sensors, touch behavior and sustained performance on the user's original Bike remain unverified. No APK was installed on the Bike, no membership was changed, and no GitHub release was published. Package, signing identity and Room schema remain unchanged.
