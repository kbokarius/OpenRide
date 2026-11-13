# Lane Smash — revision 5

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

## Roller-coaster route and tunnel

The route is a distance-sampled 3D centerline with quaternion orientations. Every two-metre sample advances by exactly two metres along the midpoint tangent. Orientation remains continuous through upright, vertical and inverted spans; there is no world-up cross product that becomes singular at the top of a loop. Shape reads the course seed and motion preference, never target lanes or resistance. Changing resistance still selects the scoring lane and changes the background pattern, not road steepness.

Normal motion repeats a 1,800-metre sequence: an opening approach, a full vertical loop over 100–700 m, a full twisting roll over 760–1,180 m, and another vertical loop over 1,220–1,800 m. Broad seeded bends and subtle banks run throughout. Smooth transitions avoid abrupt angular velocity changes. Reduced motion substitutes gentle curves and no full inversions. The camera and cyclist use the same route frame. The HUD remains upright and fixed on screen.

The visible horizon uses a continuous distance-plus-curvature budget, with a small time-based smoothing filter. It never switches between discrete viewport cutoff segments. A vertex shader moves the distant taper every rendered frame while the underlying road samples remain anchored. The taper uses a smooth quintic curve and collapses the hidden tail to the exact portal point. The sky shader takes the exact camera-space projection of that point as the center of all four psychedelic styles. Thus the road leads into the moving tunnel hole through climbs, inversions and twists. Targets, section beds and ghosts are clipped/faded before the taper, avoiding floating items beyond the road. The full scoring route continues beyond the visible endpoint.

Road and lane lines remain continuous indexed meshes. No roadside posts, transverse seams, thrusters, light pods or rider-body glow. The smooth matte cyclist and crank animation from revision 4 remain.

## Cadence and power sections

Cadence sections have static mint gradient beds under their raised arrows. Their vertices and UVs are anchored to absolute course distance. Gradient edges and subtle texture do not scroll separately from the road. The entire section passes under the rider.

Power sections replace rows of purple crystals with violet ground zones and a triangular finish gate. Accumulated valid joules fill the zone toward an internal 150 W × section-length visual reference. Current eligible watts increase brightness and moving filaments; cadence advances the pulse animation. Five concentric triangular outlines expand as accumulated energy rises. Visual fill saturates at its reference, while scoring remains uncapped at one point per five valid joules. No new multiplier, fake energy or extra bonus is introduced. Geometry remains anchored as the camera moves.

The video reference was visually reviewed around 1:10–1:27; [research notes](../research/lanebreak/07-power-zone-reference.md) distinguish observations from our implementation. All new assets and shaders are original.

## Final-target feedback

Gold bars and cadence arrows sit just above the road surface, without vertical hover. Tire contact uses the circular wheel’s reach at each target’s actual top height. Each section includes a final physical marker placed so its rear face meets the front wheel exactly at the scoring endpoint. When two sections share a boundary, only the previous section owns that boundary target. The next section skips its zero-offset marker, leaving more than six metres between the outgoing finish and the next target. The next gradient bed begins beyond the shared scoring boundary. The power gate uses the same contact boundary. A contact removes the item immediately. Scored completion creates a larger road-oriented shard burst and a fixed +points label anchored at that last target. The label rises and fades over up to 1.4 seconds, leaving the view as the rider passes it. It no longer appears as a top-center banner at the next section. Inversions rotate the particle velocity/gravity with the local road frame.

Visual collisions do not themselves award points. A missed cadence target can shatter while earning zero; a partially earned section displays only its actual whole points. The rules engine remains independent of rendering.

## Data and compatibility

Eight palettes, four reactive backgrounds, original Night Drive music, real-distance best ghost, one-second numeric HUD updates, no manual Pause and automatic sensor recovery remain. Course version 4, generator version 2 and scoring identity are unchanged from revision 4. Existing scores and ghosts continue to compare directly. There is no database migration.

## Two-minute demonstration

`games/tests/demo_lane_smash.gd` starts a 15-minute Nightfall ride, follows all targets with simulated cadence/resistance, and seeds an isolated completed best ride for the ghost. It captures the first 120 active seconds, asserts that all three section types completed and that full inversions occurred, checks exact tunnel/road-tip alignment throughout the capture, and ends the demonstration attempt early. Demo records never touch real rider history. Frame timestamps preserve real playback timing when encoding the video. The video includes the game's original soundtrack.

## Validation and device boundary

See [revision 5 validation](lane-smash-v4-validation.md). Desktop simulation and Android builds do not establish physical sensor compatibility, touchscreen behavior, or sustained thermal/GPU performance on the user's original Bike. The signed ARM64 APK requires Android 10/API 29 or later. Installing it replaces the prior fork APK in place; it does not replace Peloton's operating system or choose a default launcher.
