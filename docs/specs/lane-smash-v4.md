# Lane Smash — revision 4

## Product boundary

Lane Smash is the only available game. Android's launcher provisions or restores the existing local rider, opens the persistent Godot activity, and finishes the lightweight launcher. The ride selector is the Godot root screen. There are no game cards, circuits, FTP/profile setup, class players, or workout tabs in the reachable UI. Exiting returns to the tablet launcher without destroying Godot's task. The installed app is named Lane Smash and has its own road icon. This does not configure the Peloton tablet's default HOME app.

Kotlin and Godot production catalogs contain only `neon_vector` (retained internal ID for data compatibility). Other game assets are excluded from the exported pack. Archived source and explicit upstream test fixtures remain in the repository. Existing profiles and attempts are retained. Initial backup restoration finishes before creating a first-install rider. No database schema change.

## Selector

Four equal-width duration controls: 10, 15, 20, 30 minutes. Selecting a duration preserves the font size and does not scale the selected button. Difficulty uses three controls on the first row and two on the second, so Challenging fits without overlap. Clean-theme horizontal padding is 12 logical pixels; controls retain a minimum 120-pixel height. Track list and history may scroll; scrollbars remain hidden. Only Settings & history, Exit, and the ride controls are exposed.

## Course generator v2 / course version 4

Distance-based gameplay remains capped at 60 km/h (37.3 mph), reached at 140 rpm. Courses remain long enough for the entire selected duration at that speed, plus 300 metres. Lane blocks now span 20 road-seconds: 20 seconds at 140 rpm, 35 seconds at 80 rpm, or 46.7 seconds at 60 rpm. Below 60 rpm lane changes naturally take longer because travel follows cadence; stopping does not pause the ride timer.

Every lane block changes target lane, by at most two lanes. A three-road-second gap between blocks allows the knob change. All scoring targets occupy a single lane. The repeating four-minute road pattern is:

| Road minute | Lane inventory | Shape |
| --- | --- | --- |
| 1 | 0, 1, 2 | Start low, build |
| 2 | 3, 4, 5 | Climb / work; order varies |
| 3 | 4, 3, 2 | Ease back; order varies |
| 4 | 1, 2, 1 | Recovery |

Lane numbers above are internal zero-based indices. The first block is warm-up; later low-lane blocks are recovery. Track seeds vary route permutations and target placement. Every complete road minute has the same resistance exposure, cadence-target exposure, scoring duration and power-target duration across tracks. Actual energy output is measured from the rider and is not guaranteed equal. A rider finishing between road-minute boundaries can see small differences in encountered work.

Cadence holds are six road-seconds (6–14 real seconds at 60–140 rpm). Target bands increase gradually with lane: 60–80 rpm in lane 1 through 80–100 rpm in lane 6. Power bursts last six road-seconds and occur once per road minute except recovery minutes, with at least 30 road-seconds between bursts. The versioned validator allows six-second bursts for version 4; older course rules remain unchanged. Gold bars fill the remaining active sections. Adjacent gold spans are merged into one section.

The five resistance envelopes remain Light 15–56, Moderate 20–61, Hard 25–66, Challenging 30–71 and Extreme 35–76. No scoring formula, hidden 150 W star reference, or star threshold changes. Content hashes distinguish the revised routes; saved older snapshots remain replayable with their original comparison keys.

## Presentation

- The road surface and lane boundaries are indexed continuous meshes sharing spline samples and normals. There are no overlapping road boxes, transverse seams, side posts or colored section-underlay ribbons. The road material is matte.
- The cyclist uses smooth torso, pelvis, helmet, limbs and joints with a matte non-emissive suit. No rear fins, thrusters, light pods or cadence-driven body highlights. Crank rotation still follows measured rpm.
- Front-wheel contact shatters bars, arrows and power crystals immediately. A collision is visual feedback; scoring remains in the timestamped rules engine.
- Completing a scored section creates a larger 36-shard explosion and a two-second floating message: SECTION COMPLETE, CADENCE COMPLETE, or POWER BURST COMPLETE, with the exact whole points earned in that section. The number is fixed for the message's lifetime. No additional bonus is awarded by the animation.
- Existing 8 palettes, 4 reactive psychedelic backgrounds, original Night Drive music, real-distance best ghost, one-second numeric HUD updates, no manual Pause, and automatic sensor recovery remain.

## Two-minute demonstration

`games/tests/demo_lane_smash.gd` starts a 15-minute Nightfall ride, follows all targets with simulated cadence/resistance, and seeds an isolated completed best ride for the ghost. It captures the first 120 active seconds, asserts that all three section types completed, and ends the demonstration attempt early. Demo records never touch real rider history. Frame timestamps preserve real playback timing when encoding the video. The video includes the game's original soundtrack.

## Validation and device boundary

See [revision 4 validation](lane-smash-v4-validation.md). Desktop simulation and Android builds do not establish physical sensor compatibility, touchscreen behavior, or sustained thermal/GPU performance on the user's original Bike. The signed ARM64 APK requires Android 10/API 29 or later. Installing it replaces the prior fork APK in place; it does not replace Peloton's operating system or choose a default launcher.
