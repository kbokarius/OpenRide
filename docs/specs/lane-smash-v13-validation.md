# Lane Smash revision 13 — validation

Validated locally on November 13, 2026 with Godot 4.7.2 (GL Compatibility) on an Apple M4 Max. **No ride of this revision has been made on the Bike.** Revision 12 (code 20) is what the owner rode there; this revision answers what that ride showed. A separate session built code 21 from this source and installed it on the Bike the same evening ([installation record](../research/lanebreak/10-revision-13-installation.md)): it launches and reports the bike connected, and nothing more has been checked there. Whether the interruptions are gone, and the tablet's frame rate with the new picture, can only be confirmed by riding it.

## Results

| Check | Result |
| --- | --- |
| Godot unit tests | 180 tests in 19 suites passed; no errors, failures, skips or orphans (167 in 18 suites in revision 12) |
| Android JVM/Robolectric | 995 passed (994 before, plus the hitch-is-caught-up test); no failures, errors or skips |
| Application lifecycle (`play_neon_vector.gd`) | 54 checks passed, including sensor loss and automatic recovery |
| Full catalog (`audit_lane_smash_tracks.gd`) | 116 tracks (100 named, 16 seeded) on generator 6, 36.25 simulated riding hours, four speed traces, five difficulties; no failures |
| Calibration (`calibrate_lane_smash_scores.gd`) | 25 named 20-minute Challenging tracks: mean 159,008.08, minimum 151,819, maximum 168,648 (generator 5: 173,216.08; generator 4: 147,760.88). About a third of every block is now empty road, which lowers it; the simulated rider holds the middle of every range and so collects the whole sweet-spot bonus, which raises it |
| Repeated start/end (`soak_lane_smash.gd`) | Ten cycles: exactly 804 nodes after each return to the selector (801 before: the scroll helpers), 80.8–84.0 MiB. Memory steps up about 2 MiB at the first 30-minute track and stays there; fourteen further 30-minute cycles added 0.5 MiB in all, about 40 KB a ride, which is the saved rides themselves (the history keeps 50) |
| Render-loop CPU (`profile_lane_smash.gd`, headless) | Ordinary riding: mean 0.156 ms, p95 0.212 ms, maximum 1.49 ms per update. Incoming Fire: mean 0.194 ms, p95 0.282 ms, maximum 1.47 ms. Route preparation 52 ms. Script time only |
| Picture cost by part (`profile_lane_smash_gpu.gd`, desktop GPU) | Before the change, at about 120 times the tablet's pixel count: engine bloom and grade 48% of the frame, sky shader 22%, road deck 9%, everything else within the noise. See "The performance audit" |
| Shader and script errors | None in any of the logs above or in the demo render |
| Demo video | 200.3 s, 1920×1080 at 30 fps, 49.3 MB (two-pass H.264 High@4.1 at 1.83 Mbit/s, BT.709; AAC-LC 128 kbit/s; fast-start; soundtrack one frame later than the master, as measured in revision 12). VMAF against the master 85.9. Decoded end to end without error; audio mean −18.4 dBFS, peak −0.7 dBFS |

Suites: catalog (20), sweet spot, gauge, celebration, governor and tiers (10), space (5), HUD (3), path (7), audio (13), jukebox (16), gunfire (9), barrage (12), menu layout (4), rules (14), records (9), course (7), input (4), AudioDirector (19), point rollup (4), Effort (7), EffortMeter (10), hub music (7).

## What the new and changed tests pin down

- **Display stalls** (`NeonTimelineTest.kt`, `neon_vector_input_test.gd`): a gap of exactly one second between polls is caught up with the clock still running and the elapsed time advanced; one millisecond more pauses with reason `stall`; a stall is told apart from sensor loss by the samples that kept arriving.
- **Governor** (`lane_smash_sweet_spot_test.gd`): a steady 60 fps never steps down; one 0.9 s frame in smooth riding does not; one slow window between good ones does not; a steady 40 fps steps down after two windows, about 11 s into the ride.
- **Scrolling** (`lane_smash_menu_layout_test.gd`): a pointer pressed on the third track card and dragged 420 px scrolls the library by more than 200 px and does not select that card or the one under the release; a press and release in place selects a card.
- **Separated sections** (`lane_smash_catalog_test.gd`): for every named track and seeded samples, each gap between consecutive sections is 2–5 road-seconds; a gap in which the lane changes is at least 3; every block has exactly two sections of different kinds and none spills into the next block; one track uses at least five different gap lengths; all tracks of a duration still carry identical effort budgets; lane changes come within 22 road-seconds.
- **Sweet spot** (`lane_smash_sweet_spot_test.gd`): the centre of the range earns 19–20% on top of the section's points; both edges of the sweet spot earn a bonus; one rpm outside it, and both ends of the range, earn the points with no bonus; base (star) credit differs by under two points between a centred ride and an edge ride; a course 8 snapshot has no bonus state and no bonus; the bonus and the score are identical at 10, 30, 50 and 100 ms steps. Records accept scoring 8 and reject 9 on both sides.
- **Gauge**: `cadence_target()` is empty before a section, reports it three road-seconds ahead as not yet active, then active with the rider in range and in the sweet spot, then out of range, and drops it afterwards; the gauge maps rpm to the track (0 at the minimum, 1 at the maximum, capped a little beyond either end), names ahead / sweet / in / slow / fast correctly, sits on the outer side of the bike, stays inside the play area at the screen's corners, fades over a fifth of a second, and treats the middle as plain "in" for a ride without the bonus.
- **Celebration**: a finished burst starts it with the section's points and suppresses the small floating number; the word follows the output against the reference; it is fully opaque by 0.1 s and gone by its 1.3 s life; the number overshoots to between 1.1 and 1.35 times its size and settles at 1.
- **Music fades** (`lane_smash_jukebox_test.gd`): a start comes up from under −12 dB to full in the fade time; a seek and a track change leave the old sound playing on the second player while the new one rises from silence, and that player stops and lets go of its track afterwards; Music Off reports stopped at once, with the position held, while the sound fades out; Music On fades back in.
- **Tiers and sky**: each tier's view size, off-screen sky size, bloom source (engine, lens or none), lens bloom strength, grade and edge smoothing are as tabled; the bike's tier is larger than 0.72 of the screen; the off-screen sky's view transform is the identity when the camera looks straight down the tunnel and turns with the camera; its size follows the view's.

## The interruption on the Bike

Not reproduced, because it depends on the tablet's long frames. What was established by reading the code on both sides: the only thing that puts the recovery card (the one with End Ride) on screen during a ride and then removes it by itself is a pause for sensor loss, a sample overflow or a display stall, followed by the automatic recovery. The stall limit was 250 ms, in `NeonTimeline.poll` and in the game's frame check, and upstream's own notes on this tablet record frames far longer than that under load. The limit is now one second. If the card still appears on code 21, the cause is in the log: `adb logcat -s godot | grep "lane_smash pause"` prints the reason (`stall`, `sensor`, `overflow`), the ride time and the age of the last sensor sample for every pause.

## The performance audit

**Method.** The desktop cannot be made to behave like the tablet, but it can show where the pixels' cost goes. `profile_lane_smash_gpu.gd` renders a ride with the 3D view 11 times the tablet's size each way and measures the frame with each part switched off. (At smaller sizes this machine's frame time is locked to the display's refresh and shows nothing.) Engine counters at the tablet's own view size: 74 draw calls, 181 objects, 26,585 primitives; the rules and the view's update take 0.33 ms a frame in script here.

**Findings and what was done.**

| Finding | Action |
| --- | --- |
| Engine bloom and grade: 48% of the fill cost | The bike's tier uses a two-pass quarter-size bloom and grades in the lens pass; the engine's are kept for the desktop tier |
| Sky shader: 22% | Drawn at half size each way into an off-screen image |
| The sky's material changed every frame, so the engine re-filtered the sky every frame (several extra passes) | The sky material is now constant; only the off-screen pass's material changes |
| Road deck: 9%, with a six-step loop per pixel in three shaders added in revision 12 | Four steps |
| No anti-aliasing in effect (the engine's FXAA is a no-op in this renderer; MSAA unusable on the tablet) | Edge smoothing in the lens pass |
| One long frame could drop the graphics tier for good | Governor ignores long frames, needs two slow windows, and the stored tier is reset once |
| A 250 ms stall limit paused the ride | One second |
| Script time, draw calls and primitives | Already small; left alone |

**What that buys, and what it costs.** By construction the bike's tier now does far less work per pixel than it did (no high-range buffer, no bloom chain, the sky's maths on a quarter of the pixels) and spends some of it on 23% more pixels in the 3D view (0.80 of the screen against 0.72) and on the smoothing's five to seven texture reads per screen pixel. It also renders three small extra views a frame (the sky and two bloom passes), and upstream's notes say each rendered view costs CPU time on this tablet. Whether the net is faster on the tablet is **not known**. If it is not, Auto falls to Performance (0.66 of the screen, smoothed, no bloom) after about eleven seconds of low frame rate, and that tier is lighter than the old one in every respect but the smoothing.

## Faults found and fixed during the work

- The sky shader's built-in screen coordinate is not a usable 0–1 coordinate in this renderer (it read as one everywhere); the off-screen sky is placed by pixel position instead.
- The engine's shader compiler objects to the 3D view's texture being passed to a function; the smoothing is written inline.
- The first lens bloom thresholded on the strongest colour channel and lit up the sky's ribbons; it now uses luminance, which separates the near-white lights from saturated colour.
- A three-pass bloom was cut to two after reading upstream's finding that every rendered view costs the tablet CPU time.
- The first generator-6 layout gave burst blocks 14 road-seconds of sections and other blocks 13, which broke the equal-effort property; both are 13.
- A test helper that advanced the ride in 50 ms chunks could never advance at a 100 ms step and hung its suite.

## Not verified

- **Everything on the Bike**: that the interruptions are gone, the frame rate on each tier, how the smoothed picture looks on that panel, touch scrolling with a real finger, the fades through its speakers, and whether the gauge is readable from the saddle.
- **The missing attacker and the attacker that did not fire.** No fault was found in the attack or gunfire code paths; the working explanation is the interruption card covering the moment they appeared. Unconfirmed.
- **The workout with gaps**: about a third of the road in each block is now empty. That is what was asked for; whether the ride still feels dense enough is a judgement for the rider.
- **Lanebreak's own sweet spot.** The gauge is confirmed from footage; a bonus zone in its middle is not (see the research note).
- **The installed build.** This session did not build or install anything. Code 21 / `1.2.0-lane-smash.13` was built from this working tree and installed by a separate session before these changes were committed; its record states that no production source changed between that build and this commit.

## Demo

`Lane-Smash-demo-v13.mp4` is rendered by `games/tests/demo_lane_smash_showcase.gd` under Movie Maker on the **Balanced** tier (the bike's), so it shows the picture the bike draws: the real selector and settings, then the real renderer, HUD, effects and soundtrack driven by deterministic simulated sensors, with captions. It is not a recording from a bike.

| Scene | Shows |
| --- | --- |
| Selector, settings | Track library, difficulty, music track picker and seek slider |
| Collect, Clear sections | Gold bars; the empty road after them |
| Cadence gauge, Sweet spot | The gauge beside the bike near the bottom of the range, then in the middle band |
| Ghost | The best-ride projection, in the gap before the next section |
| Too fast | Above the range: the gauge turns red, rounds land |
| Power burst | The zone charging, then the celebration |
| Incoming Fire | Passing the blast (+1,800), then staying behind the next one |
| Too slow | Below the range |
| Caught in the blast | Holding pace: up to −1,800 |
| Audio, On the beat | The in-ride audio panel; seam pulses on each kick |
| Road mines | One passed, one hit |
| Speed | The same road at 52 rpm and at 134 rpm |
| The road | A loop |
| Three other tracks | Amber/Kaleidoscope, Ember/Liquid aurora, Copper/Vortex |

## Reproduction

As in [revision 11's validation](lane-smash-v11-validation.md#reproduction). Picture cost: `godot --path games -s res://tests/profile_lane_smash_gpu.gd -- --scale=11 --frames=50`. Tier comparison stills: `capture_lane_smash_look.gd -- --out=<dir> --quality=high|balanced|performance [--aa=none|msaa4] [--passes]` (`--passes` also saves the off-screen sky and bloom images).
