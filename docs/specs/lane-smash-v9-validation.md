# Lane Smash revision 9 — validation

Validated locally on November 13, 2026 with Godot 4.7.2, GL Compatibility and Apple M4 Max. Incoming Fire adds a pace challenge with original armored attackers, fixed blast locations, arcing energy shots, a prediction gauge and scored hits/evades. Physical Original Bike testing remains outstanding.

## Acceptance results

| Check | Evidence |
| --- | --- |
| Rules and regression suites | 69 tests passed; zero failures, errors, skips or orphans |
| Android JVM/Robolectric | 993 tests passed; zero failures, errors or skips |
| Entire track catalog | 100 named + 16 seeded random tracks, 36.25 simulated riding hours; all completed with three stars and every incoming shot evaded |
| Speed and bounds | Four complete 30-minute traces at 0, 60, 140 and 200 rpm; expected distance, bounded sample/ghost buffers and sufficient road length |
| Difficulty | All five tiers and all 42 resistance values per tier verified |
| Actual application lifecycle | 50 checks passed across menu, start, controls, sensor recovery, finish and saved data |
| Repeated start/end | Ten cycles, 765 nodes after every return to menu; no growing game-node or viewport count |
| Visual review | All six attacker positions; material fades, muzzle charge, arcing shots, landing zone, fast/slow evades and negative popup checked in real rendering |
| Exported pack | Only Lane Smash registered; all 13 other game scenes absent; packed scoring v5 rules resolve two incoming impacts |
| Signed APK | Code 17, version 1.2.0-lane-smash.9; signature verified with unchanged certificate |
| Video | Four real-renderer chapters; standard scoring, road bomb, fast/slow evades and incoming hit; final stream checked for 3,600 frames and full decode |

The ordinary lane audit enforces the 60-second maximum between scoring-lane changes. It resets that timer during the explicit 35-second Incoming Fire section, when pace replaces the lane target. Each generated duration has the same attack count across named tracks. The simulation checks achievable outcomes, not identical physical effort for every rider.

## Gameplay checks

- A 40 rpm change after a two-second reaction and four-second gradual ramp evades both speeding-up and slowing-down cases. Holding cadence, steering to another lane, changing only 15 rpm immediately, or making a delayed 25 rpm change gets hit.
- Recommended targets remain within 45–120 rpm with at least a 35 rpm difference for every baseline from 0–140 rpm. These are game tuning values; individual exercise comfort has not been established on the Bike.
- Identical sensor input at 30/60/120 render rates produces identical locked targets, outcomes, scores, distance and ghost traces.
- A mid-flight sensor interruption freezes the active clock, position and target. Fresh input after recovery produces the same eventual collision outcome.
- The rendered quadratic arc ends at the exact locked ground target. Its world-space source stays fixed after launch. Each impact creates feedback once.
- New scoring version 5 accepts declining net scores while rejecting rollback of gross earnings or accumulated penalties. Full records retain shot details; summary history omits them. Older bomb courses preserve scoring version 4 and their original comparison identity.
- Malformed attack schedules are rejected without unsafe Variant comparisons. Ordinary targets and road bombs fade during attacks and do not award points or penalties while suppressed.
- Separate captures recorded two successful evades (+100 each), two intentional hits (−100 each), and a road-bomb hit (−100). The regular scoring chapter completed gold, cadence and power sections.

## Performance and stability

Headless CPU render-update measurements exclude GPU time and tablet hardware. They are not FPS guarantees.

| Measurement | Ordinary road | Incoming Fire |
| --- | ---: | ---: |
| Samples | 1,767 | 1,750 |
| Mean update | 0.120 ms | 0.149 ms |
| 95th percentile | 0.152 ms | 0.203 ms |
| Maximum observed | 1.429 ms | 1.427 ms |

Route preparation took 51.13 ms in this run. The attack uses one reusable armored rig, one landing mesh, 40 path markers, 32 trail particles and two orb slots. Existing impact pools remain capped at 192 particles and 12 shockwaves. Construction buffers are discarded after mesh creation. Tiny intro draws warm the new shaders before active riding; dedicated captures had no first-shot hitch after warm-up.

Retained menu memory was 76.95 MiB after cycle two and 77.27 MiB after cycle ten, with a 77.61 MiB peak among those measurements. Menus retain compact attempt history. The desktop lifecycle/soak harnesses still report existing resource-cleanup warnings on immediate process exit (five/seven resources respectively). No runtime script or shader errors occurred in the effect captures, and no growing retained scene count was observed. These results cannot establish crash-free operation, thermals, sensor correctness or sustained FPS on an untested Peloton.

## Code review

### Critical

No unresolved critical issue found in the reviewed change. Fixed-clock collision ownership, immutable shot targets, sensor interruption, score checkpoint validation and legacy identity have explicit regression coverage.

### Improvements addressed

- Reused bounded meshes and effects rather than creating projectile nodes every frame.
- Warmed armor, warning and projectile materials during the intro.
- Removed temporary geometry buffers after construction.
- Preserved a smooth normal-target fade when the attack cursor advances.
- Changed a safe prediction prompt to **Keep This Pace**, without showing a contradictory target rpm.
- Kept HUD numbers at one refresh per second while the position gauge and animation stay smooth.

### Positive

Rules, presentation and UI are separate components. The renderer cannot award points; storage and replay retain deterministic inputs/outcomes. Existing menu, typography and lane controls remain consistent.

Reviewed against GodotPrompter's Godot 4.3+ code-review, animation, 3D and effects guidance. Physical-device profiling remains the next external validation step.

## Demo

`Lane-Smash-demo-v9.mp4` is a two-minute montage at 1280 × 720, 30 fps, H.264/AAC, with the original Night Drive music. It uses the actual renderer and deterministic simulated sensor input, without writing personal ride history. The regular-target chapter uses a completed simulated previous ride for its ghost. Chapter cuts are labeled; it is not one continuous two-minute course or a recording from the Peloton.

| Time | Content |
| --- | --- |
| 0:00 | Gold bars and section completion |
| 0:05 | Cadence arrows and highlighted floor |
| 0:44 | Power section charging and finish explosion |
| 0:55 | Road bomb; hit and −100 around 0:59 |
| 1:03 | Incoming Fire; speed up, then slow down; +100 per evade |
| 1:43 | Intentional incoming-fire hit; explosion and −100 around 1:57 |

The final encode keeps a fixed output size even if macOS resizes a capture window. Both the video frame count and full-stream decode are checked so audio duration cannot conceal truncated video.

## Installer

- File: `openride-neon-17.apk`
- Package: `dev.digitalducktape.openride.neon`
- Version code: 17; version name: `1.2.0-lane-smash.9`
- Size: 65,064,505 bytes
- SHA-256: `bb5df72d941803205875baeeedcc77f94ba944d80a901e2159ceba39b3bdf843`
- Signing certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`
- Android 10+ / ARM64; real-sensor build; install over the existing fork without clearing data.

No database migration, Peloton installation or GitHub release publication was performed. Instructions remain in the [installation guide](../LANE_SMASH.md).

## Reproduction

Run gdUnit4 against the seven revision 8 suites plus `lane_smash_barrage_test.gd`. Use `audit_lane_smash_tracks.gd`, `profile_lane_smash.gd`, `play_neon_vector.gd` and `soak_lane_smash.gd` for the full-content, CPU and lifecycle checks. Build with `:app:testDebugUnitTest :app:assembleNeonReal` and the existing private signing configuration.

Capture helpers accept `-- --out=<absolute-directory>`:

- `capture_lane_smash_sections.gd --seconds=55`: standard sections and completed simulated ghost.
- `capture_lane_smash_bomb.gd`: eight-second road contact chapter.
- `capture_lane_smash_barrage.gd --mode=success`: forty seconds with both evades.
- `capture_lane_smash_barrage.gd --mode=hit`: forty seconds with two intentional hits; the montage uses seconds 5–22.
- `capture_lane_smash_barrage.gd --slots-only`: six attacker-placement stills.

See the [specification](lane-smash-v9.md) for the schedule, collision rules, scoring and presentation contract.
