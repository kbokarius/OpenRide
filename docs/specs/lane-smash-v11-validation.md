# Lane Smash revision 11 — validation

Validated locally on November 13, 2026 with Godot 4.7.2 (GL Compatibility) on an Apple M4 Max. **Nothing here was run on the bike's tablet**: frame rate, the cost of bloom, heat, memory and audio latency there are unmeasured.

## Results

| Check | Result |
| --- | --- |
| Godot unit tests | 160 tests in 18 suites passed; no errors, failures, skips or orphans |
| Android JVM/Robolectric | 994 passed (993 before, plus the scoring-version test); no failures, errors or skips |
| Application lifecycle (`play_neon_vector.gd`) | 54 checks passed: selector layout, start, saved ghost, audio switches without pausing, the jukebox playing, sensor loss and automatic recovery, end and results |
| Full catalog (`audit_lane_smash_tracks.gd`) | 116 tracks (100 named, 16 seeded), 36.25 simulated riding hours, four speed traces, five difficulties; no failures |
| Calibration (`calibrate_lane_smash_scores.gd`) | 25 named 20-minute Challenging tracks: mean 147,760.88, minimum 137,462, maximum 156,977 — identical to revision 10, because a rider who holds each cadence band is never hit |
| Repeated start/end (`soak_lane_smash.gd`) | Ten cycles: exactly 799 nodes after each return to the selector; 80.4–81.4 MiB |
| Render-loop CPU (`profile_lane_smash.gd`, headless) | Ordinary riding: mean 0.167 ms, p95 0.21 ms, maximum 1.44 ms per update. Incoming Fire: mean 0.195 ms, p95 0.227 ms, maximum 1.45 ms. Route preparation 49 ms |
| Shader and script errors | None in any of the logs above or in the demo render |
| Demo video | 157.9 s, 1920×1080 at 30 fps, H.264/AAC; decoded end to end; audio mean −17.6 dBFS, peak −0.7 dBFS |

Suites: catalog (17), space (2), HUD (2), path (7), audio (12), jukebox (15), gunfire (9), barrage (12), menu layout (3), rules (14), records (9), course (7), input (4), AudioDirector (19), point rollup (4), Effort (7), EffortMeter (10), hub music (7). Tests use isolated settings and history.

The CPU profile has no revision 10 figure to compare against (none was recorded before the change); it shows only that the scene's per-frame script work is small on this machine. It says nothing about GPU cost.

## What the new tests pin down

- **Machine-gun rule** (`lane_smash_gunfire_test.gd`): new tracks are course 8 / scoring 7; holding the band is never hit and reports live fire with a warning phase; both band edges are safe; too slow and too fast each take no round in the first two seconds, the first at 0.6 s outside, then one every 0.5 s, each exactly 60 points; a stopped rider takes 15 rounds in a section and no more, never goes below zero, and the ride does not pause; four brief slips cost nothing; course 7 snapshots keep scoring 6 with no gunfire state; the outcome is identical when the rules advance every 10, 30, 50 or 100 ms; records accept scoring 7 and reject 8.
- **Scenery** (`neon_vector_space_test.gd`): every arch between the chase camera and 250 m ahead is present and standing on the fixed route for a 600 m ride. This covers a fault found in review, where arches were retired about 18 m ahead of the bike instead of behind the camera.
- **Menus** (`lane_smash_menu_layout_test.gd`): for every duration and difficulty, each touch target is at least 120 px and 24 px from the others and on the stage; no text is under 34 px; the ride controls stay inside the setup panel's padded column; header elements never overlap and sit on the 56 px margin; track cards keep their text inside their padding; the settings screen has all five option rows and the music panel.
- **Soundtrack** (`lane_smash_jukebox_test.gd`): random start inside the track with the end margin; auto-advance to a different track; select and seek clamp; fallback playlist; Music Off holds the position and stops the phase; analysis falls to zero when nothing is audible; nothing starts by itself headless; the calm values the scenery reads never move more than 0.09 per frame at 30 fps under a 120 BPM kick, and a kick peaks below half depth.
- **Existing render contracts** still pass unchanged: fixed world anchors, shared chunk boundary vertices, bounded pools that expire, front-wheel contact at the scoring boundary, the road tip inside the tunnel, sky travel equal to road distance.

## Faults found and fixed during the work

- Arches vanished ahead of the bike (above).
- The light streaks faded out before reaching the screen's edge for the same reason.
- The first music response was abrupt: the sky read the fast analysis values and the raw beat flag, the tunnel's depth changed by 10% on bass and the phase that turns it jumped on every kick. The scenery now reads values eased over about half a second up and a second down, with reduced gains.
- Attackers slid into place and faded in under half a second, with the scan light at full strength from the first frame. They now fade in and out where they stand over about a second, and the fire lines and the shot's arc fade with them.
- The dock's scrim stopped short of the window's edges on the bike's wider screen, and the 3D image was a fixed 16:9 size stretched to that screen.
- The duration row ran 14 px past its panel and the Exit button overlapped the title once the buttons were restyled.
- Blasts close to the camera filled the screen with white. A blast now fades where it is right in front of the camera.
- A face-normal error in the attacker's plates (hidden by the old two-sided lit material) made every plate take the rim colour.
- `play_neon_vector.gd` saved its screenshots on the main thread; with the more detailed picture the PNG encode exceeded the 250 ms display-stall limit and paused the ride it was testing. It now encodes on a worker thread.

## Not verified

- **The bike's tablet.** Upstream measurements for other games on that GPU (docs/GAMES.md, "On the tablet") shaped the design: no engine lights or fog, no MSAA there, a smaller 3D view, and a governor that steps the tier down. Whether Balanced holds 50 fps there, and what bloom costs, is unknown; Auto falls to Performance (no bloom) if it does not.
- **Memory on the tablet** with the 78 MB track loaded (about +89 MB here).
- **Audio latency compensation** with a non-zero output latency (macOS reports 0 ms).
- **How it sounds and feels.** Levels, spectra and lengths were measured; nobody listened critically or rode it.
- **Installer.** No APK was built, signed or installed in this revision. The version is set to code 19 / `1.2.0-lane-smash.11` for the next build, which will be about 133 MB larger.
- **Upstream hub suites** `hub_layout_test.gd` and `hub_options_test.gd` expect the upstream home and game screens, which this fork replaced with the selector in revision 4. They fail for that reason, as they did before this revision; the one Lane Smash test in `hub_options_test.gd` passes. `lane_smash_menu_layout_test.gd` applies the same layout rules to the selector.

## Soundtrack and effects, measured

Track loading on this machine (worker thread): 59–65 ms for the 27–28 MB tracks and 154–175 ms for the 78 MB track, with the longest frame during a load 20–47 ms; memory about +32 MB and +89 MB, released on switching track. A seek landed within 0.1 s of its target; Music Off held the position; end-of-track handed over to a different track five times out of five.

| Cue | Length (s) | Peak (dBFS) | Cue | Length (s) | Peak (dBFS) |
| --- | --- | --- | --- | --- | --- |
| collect | 0.115 | −9 | pass | 0.34 | −8 |
| cadence | 0.135 | −10 | avoid | 0.28 | −12 |
| lane | 0.092 | −16 | gun_hit | 0.26 | −5 |
| ui_tap | 0.085 | −14 | charge | 1.95 | −9 |
| ui_confirm | 0.24 | −11 | power_loop | 1.0 | −14 |
| section | 0.42 | −7 | engine_loop | 2.0 | −12 |
| power_finish | 0.58 | −5 | gun_loop | 1.0 | −7 |
| warning | 0.44 | −8 | launch | 0.36 | −6 |
| impact | 0.59 | −3 | bomb | 0.48 | −3.5 |

## Demo

`Lane-Smash-makeover-demo-v11.mp4` is rendered by `games/tests/demo_lane_smash_showcase.gd` under Movie Maker: the real selector and settings, then the real renderer, HUD, effects and soundtrack driven by deterministic simulated sensors, with captions. It is not a recording from a bike. Between scenes the ride is fast-forwarded through the rules alone.

| Scene | Shows |
| --- | --- |
| Selector, settings | Track library, difficulty, music track picker and seek slider |
| Collect | Gold bars in the marked lane |
| Cadence | Holding the range: the fire stays ahead and behind |
| Ghost, Audio | The best-ride projection; the in-ride audio panel |
| Too fast | Above the range: rounds land, −60 each |
| Power burst | The zone charging and its finish |
| Incoming Fire | Passing the blast (+1,800), then staying behind the next one (no bonus) |
| Too slow | Below the range: rounds land |
| Caught in the blast | Holding pace: up to −1,800 |
| Road mines | One passed, one hit |
| The road | A loop |
| Three other tracks | Petrol/Kaleidoscope, Glacier/Liquid aurora, Titanium/Vortex |

## Reproduction

Unit suites: `godot --headless --path games -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -c -a res://tests/unit/<suite>.gd` (without `-d`: a script error then fails the suite instead of stopping at a debugger prompt). Lifecycle: `godot --audio-driver Dummy --path games -s res://tests/play_neon_vector.gd -- --hidden --out=<dir>`. Audit, calibration, soak and profile: `godot --headless --path games -s res://tests/<script>.gd`. Android: `./gradlew :app:testDebugUnitTest`.

Stills: `godot --path games -s res://tests/capture_lane_smash_look.gd -- --out=<dir> [--begin=<ms>] [--scenario=follow|bomb|hit|pass] [--music] [--quality=...]` and `capture_lane_smash_models.gd -- --out=<dir> --model=bike|ghost|attacker|mine`. The demo: see the header of `demo_lane_smash_showcase.gd` (it needs a temporary `games/override.cfg` for 1080p).
