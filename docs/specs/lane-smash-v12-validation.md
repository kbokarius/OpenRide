# Lane Smash revision 12 — validation

Validated locally on November 13, 2026 with Godot 4.7.2 (GL Compatibility) on an Apple M4 Max. **Nothing here was run on the bike's tablet**, and nobody rode or listened to it: how fast it feels, how the mix sounds and whether the cadence targets suit a real rider are judged from numbers and rendered frames only.

## Results

| Check | Result |
| --- | --- |
| Godot unit tests | 167 tests in 18 suites passed; no errors, failures, skips or orphans (160 in revision 11, plus seven new) |
| Android JVM/Robolectric | 994 passed; no failures, errors or skips (only the app version changed on that side) |
| Application lifecycle (`play_neon_vector.gd`) | 54 checks passed |
| Full catalog (`audit_lane_smash_tracks.gd`) | 116 tracks (100 named, 16 seeded) on generator 5, 36.25 simulated riding hours, four speed traces, five difficulties; no failures |
| Calibration (`calibrate_lane_smash_scores.gd`) | 25 named 20-minute Challenging tracks: mean 173,216.08, minimum 166,285, maximum 179,849 (generator 4: 147,760.88, 137,462–156,977) |
| Repeated start/end (`soak_lane_smash.gd`) | Ten cycles: exactly 801 nodes after each return to the selector (799 before; the two extra are the header's meter and nothing accumulates); 80.5–81.6 MiB across the cycles |
| Render-loop CPU (`profile_lane_smash.gd`, headless) | Ordinary riding: mean 0.165 ms, p95 0.212 ms, maximum 1.42 ms per update (revision 11: 0.167 / 0.21 / 1.44). Incoming Fire: mean 0.206 ms, p95 0.295 ms, maximum 1.44 ms. Route preparation 50 ms. This is script time only and says nothing about GPU cost |
| Shader and script errors | None in any of the logs above or in the demo render |
| Demo video | 176.8 s, 1920×1080 at 30 fps, 49.3 MB (two-pass H.264 High@4.1 at 2.09 Mbit/s, four reference frames, BT.709; AAC-LC 128 kbit/s; fast-start), chosen for phones. VMAF against the master 87.5 (a 720p encode at the same size scored 85.7, so 1080p was kept). Decoded end to end without error; audio mean −18.3 dBFS, peak −0.9 dBFS; its soundtrack is exactly 1,600 samples later than the master's |
| Demo sound-to-picture sync (`probe_lane_smash_sync.gd`) | A kick is on screen −28 to +32 ms from when it is heard, median +2 ms (details below) |

Suites: catalog (19), space (5), HUD (3), path (7), audio (13), jukebox (15), gunfire (9), barrage (12), menu layout (3), rules (14), records (9), course (7), input (4), AudioDirector (19), point rollup (4), Effort (7), EffortMeter (10), hub music (7). Tests use isolated settings and history.

## What the new and changed tests pin down

- **Speed is presentation only** (`neon_vector_space_test.gd`): one rules-metre is three world metres at four points along a route, and ten seconds at 140 rpm is still exactly 166.67 rules-metres. The saved-route test builds its expected route with the same stretch.
- **Contact** (`lane_smash_catalog_test.gd`, existing tests with the tyre's reach divided by the stretch): every marker type still shatters at the front tyre and the final marker at the scoring boundary.
- **Arches** (`neon_vector_space_test.gd`): every arch from the camera to 90% of the pool's reach stands on the route for a 400 m ride; arches are kept well behind the camera and the row reaches more than 400 world metres ahead.
- **Seam pulses** (`neon_vector_space_test.gd`): in silence a soft pulse every 0.9 s; with a 120 BPM kick exactly one pulse per kick, at more than 0.9 strength with strong bass; in Reduced motion only the soft rhythm; every new pulse starts 2–12 m ahead of the bike at under 15% brightness; every pulse is ahead of the bike and never brighter than its launch strength.
- **Seam colour** (same suite): on a full-scale step no seam level moves more than a quarter of its range in a frame at 30 fps; it reaches the top within two seconds and returns to zero within three.
- **Interface colour** (`lane_smash_hud_test.gd`): exactly the designed colour in silence, alpha preserved, and only ever toward the companion hue; the meter rests flat and stays in range.
- **Lanebreak table** (`lane_smash_catalog_test.gd`): the five published ranges, all thirty seven-value lanes with no gaps, every resistance value mapping to its lane, values just outside mapping to none, and the six observed Lanebreak lanes (Expert 34–40, 41–47, 48–54; Intermediate 24–30, 38–44; Advanced 51–57).
- **Workout** (same suite): cadence sections are eight road-seconds with 20-wide bands between 65 and 115; each band is the table's value for its lane, or 75–95 in the warm-up block and recovery minutes; bursts are never in a recovery minute, never under 30 road-seconds apart, and number one per minute with two in the hardest; the recovery minute uses only lanes 1 and 2; lane changes, lane jumps, all six lanes, all three section types in the first 50 road-seconds and equal budgets across tracks still hold.
- **Mix** (`lane_smash_audio_test.gd`): the default effects level is between 1.5 and 4 dB under the music (measured ratio −2.3 dB).

## Lanebreak research, in brief

Full note: [difficulty ranges](../research/lanebreak/06-difficulty-ranges.md). The five ranges in the game were already the ones Pelo Buddy published for the June 2023 Bike update, with a screenshot of Peloton's selector. Repeating the search found no newer figures and no full lane table anywhere. Pelo Buddy's review video (a screen recording of the game) was then watched in a browser: it shows the original selector with its four ranges and, during play, the number the game prints at each edge of the rider's lane. Five lanes were read from it (Expert 34–40, 41–47, 48–54; Intermediate 24–30, 38–44) and a sixth from a beta screenshot (51–57). Every one is seven values wide and exactly on this game's grid, so **no resistance value needed changing**. What remains unseen is the lane edges on the five current level names: that footage is from February 2022, before the rename.

## Faults found and fixed during the work

- A second burst in the block after the first broke the course validator's 30-second rule; bursts in the hardest minute moved to its first and last blocks, which also spaces every burst 40 road-seconds apart.
- The stopped-rider gunfire test assumed the lead-in to the first cadence section earned less than 900 points; with longer lead-ins it did not. The test now rides the lead-in mostly in the wrong lane, so it no longer depends on the layout.
- Road ticks every three metres and rail lights every four would have appeared to stand still or run backwards at top speed at 30 fps (1.6 m a frame). They are now six and eight metres.
- A seam pulse first appeared at full strength right beside the bike, twice a second. It now brightens over 0.16 s as it pulls away.
- One showcase caption was wider than the screen.
- The showcase recorded every musical response two frames after the sound (see "Sound and picture in the demo video").
- The demo's encode left the colour matrix untagged (BT.601 values in an HD file, which players read as BT.709); it is now converted and tagged BT.709.

## Sound and picture in the demo video

The seam pulses, the meters and the colours all follow the jukebox's analysis of the music, so the recording has to keep sound and picture together to show that honestly. Measured with a controlled recording rather than by eye: `games/tests/probe_lane_smash_sync.gd` plays a click track (a 70 Hz burst every 0.51 s, so the clicks fall at every position within a frame) through the jukebox under Movie Maker and flashes a square on the frame the jukebox counts each kick; the flashes are then timed against the clicks in the recording's own soundtrack.

| Recording | Kick on screen after it is heard |
| --- | --- |
| Showcase as first rendered (stepped from `SceneTree.process_frame`) | 39 to 99 ms, median 69 ms: two frames |
| Stepped after the autoloads have processed, as the game itself runs | 5 to 65 ms, median 35 ms: one frame |
| The same, with the soundtrack delayed one frame (1,600 samples) when encoding | **−28 to +32 ms, median +2 ms** |

Two causes, both in how the demo was recorded and neither in the game. The showcase script advanced the ride from `process_frame`, which fires before any node has processed, so it read the jukebox's analysis from the previous frame; it now steps from a node that processes after the autoloads, which is where the game reads it. And Movie Maker mixes a frame's audio after that frame's scripts have run, so a recording can only show a sound on the following frame; delaying the soundtrack by one frame in the encode centres that. The effects are delayed by the same frame (33 ms), well under what can be noticed. The final file therefore has the kicks within one frame either side of the picture's response.

This is the delay until the analysis registers a kick. The responses themselves are eased on purpose (a seam pulse brightens over 0.16 s as it leaves the bike; the sky swells over about half a second), so they bloom just after the beat rather than snapping on it.

The showcase also fades sound and picture together at every cut: about 0.3 s out, a beat of black and silence while the ride skips ahead, and 0.3 s back in. The soundtrack fades in with the selector at the start and out under the closing card. Measured in the recording: the level falls from about −15 dBFS to silence and returns within 0.8 s at each cut.

## Not verified

- **The bike's tablet**: frame rate with the longer view and the six-pulse loop in the road shaders, and whether Auto still holds Balanced.
- **Feel**: whether three times is the right speed, whether the pulses read as on the beat through the bike's speakers (the analysis is delayed by the reported output latency, which is 0 ms on this machine), and whether 2.3 dB is the right gap for the effects.
- **The workout on real legs**: the cadence targets were chosen from Lanebreak's reported bands and ordinary indoor-cycling practice, not from a ride. At Challenging and Extreme the heavy lanes at 65–90 rpm are hard efforts by design.
- **Kick detection on all three mixes**: the pulses follow the jukebox's existing bass-onset detector, which revision 11 tested with synthetic kicks; passages without a clear kick fall back to the 0.9 s rhythm.
- **Installer**: no APK was built, signed or installed. The version is set to code 20 / `1.2.0-lane-smash.12` for the next build.
- **Upstream hub suites** `hub_layout_test.gd` and `hub_options_test.gd` still do not apply to this fork (see revision 11's validation).

## Demo

`Lane-Smash-demo-v12.mp4` (under 50 MB, for phones) is rendered by `games/tests/demo_lane_smash_showcase.gd` under Movie Maker: the real selector and settings, then the real renderer, HUD, effects and soundtrack driven by deterministic simulated sensors, with captions. It is not a recording from a bike. Between scenes the ride is fast-forwarded through the rules alone.

| Scene | Shows |
| --- | --- |
| Selector, settings | Track library, difficulty, the meter beside Now playing, music track picker and seek slider |
| Collect | Gold bars in the marked lane |
| Cadence | Holding the range: the fire stays ahead and behind |
| Ghost, Audio | The best-ride projection; the in-ride audio panel |
| On the beat | Seam pulses on each kick; colours following the music |
| Too fast | Above the range: rounds land, −60 each |
| Power burst | The zone charging and its finish |
| Incoming Fire | Passing the blast (+1,800), then staying behind the next one (no bonus) |
| Too slow | Below the range: rounds land |
| Caught in the blast | Holding pace: up to −1,800 |
| Road mines | One passed, one hit |
| Speed | The same road at 52 rpm (about 42 mph) and then 134 rpm (about 107 mph) |
| The road | A loop |
| Three other tracks | Amber/Kaleidoscope, Ember/Liquid aurora, Copper/Vortex |

## Reproduction

As in [revision 11's validation](lane-smash-v11-validation.md#reproduction). Stills with the music driven deterministically: `godot --path games -s res://tests/capture_lane_smash_look.gd -- --out=<dir> --music [--begin=<ms>] [--frames=N] [--every=N]`; the tool now also drives the eight bands and the kick counter.
