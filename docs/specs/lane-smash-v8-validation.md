# Lane Smash revision 8 — validation

Validated locally on November 13, 2026 with Godot 4.7.2, GL Compatibility and an Apple M4 Max. These results establish local behavior, not a crash-free guarantee on an untested Peloton tablet.

## Checks completed

| Check | Result |
| --- | --- |
| Godot import and script parsing | Passed |
| Focused Godot suites | 59 tests, zero errors, failures, skips or orphans |
| Android JVM/Robolectric suite | 993 tests, zero errors, failures or skips |
| Full-duration track simulation | All 100 named tracks plus 16 seeded random tracks passed; 36.25 riding hours |
| Full-length speed traces | 30 minutes each at 0, 60, 140 and 200 rpm; bounded movement and buffers |
| Difficulty checks | All five current tiers and every resistance value in their six lanes |
| Live hub → ride → result | 50 checks passed, including layout, ghosts, music, pause rejection, sensor recovery and saves |
| Repeated start/end/menu cycles | 10 cycles passed; 765 nodes after every return, zero orphan nodes or remaining game viewports |
| Bomb visual/rules capture | One 100-point deduction, negative popup, disappearing bomb and bounded fading effects |
| Two-minute section showcase | Gold, cadence, power and bomb paths all exercised; real completed simulated ghost trace |
| Signed release | Built and signature verified; code 16, unchanged package/certificate |
| Exported game pack | Lane Smash is the sole registered game; 13 other game scenes absent |

The full-track audit follows targets with fresh 20 Hz simulated sensor values. It checks all six lanes, all three scoring-section types, frequent lane changes, complete duration, stars, road length and ghost bounds. Independent content tests verify equal authored effort budgets, deterministic random content, short cadence zones, single-lane targets and clear bomb placement. They do not assert identical physical output for different riders.

Bomb tests cover exact contact timing, one-time penalties, frame-rate independence at 30/60/120 fps, safe lanes, the zero-score floor, save/checkpoint score decreases, rejection of earned/penalty rollback, and ghost replay. Legacy comparison identities remain covered. The final saved-path type guard also passed a targeted rerun of 14 course/path tests. Additional regression tests reproduce the saved-route cache bug, reject mixed ghost row formats and invalid geometry, verify exact shared road-chunk vertices and keep history payloads compact.

## Performance observations

The same headless CPU benchmark updates the 30-minute course near 0, 14,000 and 29,000 metres, excluding initial setup and the first ten frames of each segment. It measures 1,767 render-update calls, not GPU time or tablet FPS.

| CPU measurement | Previous implementation | Revision 8, with bombs/effects |
| --- | ---: | ---: |
| Route preparation | 99.05 ms | 50.65 ms |
| Mean update | 0.976 ms | 0.105 ms |
| Median update | 0.105 ms | 0.109 ms |
| 95th percentile | 4.891 ms | 0.132 ms |
| Maximum observed | 5.752 ms | 1.415 ms |

Average update cost fell about 89%, mainly by removing repeated full-road mesh rebuilding. Small per-frame hazard/effect checks slightly increased the median. The measurement is a local benchmark, not a universal speedup claim.

Repeated real lifecycle cycles returned to exactly 765 menu nodes. Static memory was 76.57 MiB after cycle two and 76.89 MiB after cycle ten, with a 77.23 MiB peak in the retained menu measurements. This includes accumulating compact attempt history. No sustained game-node or viewport growth was observed.

The desktop lifecycle harness still reports resource cleanup warnings on immediate process exit, as in revision 7. No runtime script/shader errors occurred in the final lifecycle or showcase runs. The dedicated effect captures explicitly free their scenes and exit without those warnings. Physical Bike installation, sensor accuracy, thermal behavior and a full sustained tablet ride remain untested.

## Video

`Lane-Smash-demo-v8.mp4`: 120 seconds, H.264, 1280 × 720, 30 fps, AAC audio using the existing original Night Drive loop. It renders the actual game classes with deterministic simulated input and a completed simulated prior-ride trace; it does not alter personal saved rides.

- Gold collection and first section completion: opening seconds; first popup at 0:05.
- Cadence arrows: approximately 0:05–0:17.
- First power zone and finish explosion: approximately 0:45–0:52.
- Deliberate bomb hit and −100 popup: approximately **1:22**.

## Installer

- File: `openride-neon-16.apk`
- Package: `dev.digitalducktape.openride.neon`
- Version: `1.2.0-lane-smash.8`, code 16
- Size: 65,035,833 bytes
- SHA-256: `e40cd40167312cfd96175b78c2f1198ac98fa715c23de40bcf62a3bc2feb33c1`
- Signature: v2 verified
- Signing certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773` (unchanged)

Install in place without uninstalling or clearing app data. Older bomb-free attempts stay in history and replay with their original rules; new bomb courses begin separate comparisons. No database migration or GitHub release publication was performed.

## Reproduction

Use the gdUnit4 runner on `lane_smash_catalog_test.gd`, `lane_smash_path_test.gd`, `neon_vector_course_test.gd`, `neon_vector_rules_test.gd`, `neon_vector_records_test.gd`, `neon_vector_input_test.gd` and `neon_vector_space_test.gd`.

- `tests/audit_lane_smash_tracks.gd`: complete content/speed audit, headless.
- `tests/profile_lane_smash.gd`: repeatable CPU probe, headless.
- `tests/play_neon_vector.gd`: actual application lifecycle and control checks.
- `tests/soak_lane_smash.gd`: ten actual start/end/menu cycles, isolated storage.
- `tests/capture_lane_smash_bomb.gd`: focused contact review.
- `tests/capture_lane_smash_sections.gd`: two-minute showcase frames and event timestamps; pass `-- --out=<absolute-directory>`.
- `./gradlew :app:testDebugUnitTest :app:assembleNeonReal`: Android verification/build, with Java, Android SDK, matching Godot and private signing configuration set as described in the guide.

See the [specification](lane-smash-v8.md) and [installation guide](../LANE_SMASH.md).
