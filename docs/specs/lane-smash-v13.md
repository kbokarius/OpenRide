# Lane Smash revision 13 — first ride on the Bike: interruptions, clear sections, a cadence gauge, a sharper and lighter picture

Builds on [revision 12](lane-smash-v12.md), which is the build (code 20) the owner rode on the Bike. APK code 21, `1.2.0-lane-smash.13`. **Course version 9, generator version 6, scoring version 8.**

## What the owner reported after riding it

1. The track list only scrolls from the gaps between cards; it should scroll from the cards too.
2. The End Ride screen popped up now and then during the ride and went away again, flickering.
3. Once, an attacker and its bomb seemed not to appear; once, an attacker appeared without firing.
4. Sections should be separated by a little empty road (3 to 9 seconds), so each has a clear start and end.
5. The motorcycle and graphics looked jagged; raise the resolution or detail, and improve performance across the board with a full audit.
6. Music should fade in and out whenever it starts, stops or changes.
7. It is not clear what cadence to hold. Lanebreak shows a small panel with the rider's cadence and the range; add that, with a spot towards the middle that pays a slight bonus.
8. Finishing a power burst should show the points in an explosive way that comes and goes quickly.

## What was found

**The interruption (2, and probably 3).** The ride pauses itself when the display stalls, so that a frozen screen cannot be scored with stale input. The limit was 250 ms between two polls of the ride clock, in the app and in the game. On the tablet an ordinary long frame is longer than that: the first time an attacker, a blast or a new effect is drawn its shader is compiled; a music track loads; the automatic graphics tier changes. Each of those brought up the recovery card (which carries End Ride) and the ride then resumed by itself after a second of healthy input and a three-second count. That is the screen that flickered. It is also the likeliest reason an attacker or its shot went unseen: the long frame is the one in which it first appears, and the card covered it. That link is an inference, not something reproduced on the Bike.

The same hitches had a second effect. The graphics governor stepped the picture down a tier whenever a four-second window averaged under 50 fps, and remembered it for later rides. One long frame is enough to pull a window under 50, so the picture could be on the lowest tier (0.62 of the screen, stretched to fit, no smoothing) for no lasting reason. That is the jaggedness in (5), or a large part of it.

**Anti-aliasing (5).** The engine's FXAA setting does nothing in the renderer the bike uses: a frame captured with it on is identical, pixel for pixel, to one without. Upstream measured MSAA on this tablet at half the frame rate and a black 3D view. So nothing was smoothing the picture.

**Where the picture's cost is (5).** `tests/profile_lane_smash_gpu.gd` renders the ride at about 120 times the tablet's pixel count, so fill cost swamps everything else, and switches parts off in turn. On the desktop GPU that ran it: the engine's bloom and grade were about 48% of the frame, the sky's shader 22%, the road deck 9%, and everything else together within the noise. Upstream's notes on the tablet add that every rendered view costs CPU time there and that pixels cost frame rate.

## Design decisions

Reported before building, as `CLAUDE.md` asks. The `godot-prompter` skills were read from disk, not invoked, because they are not registered in the session that did this work.

| Area | Pattern | Rejected alternative, and why |
| --- | --- | --- |
| Display stalls | Raise the stall limit to one second in the app's ride clock and the game; shorter hitches are caught up from the timestamped sample buffer | Removing the stall pause: a genuinely frozen or backgrounded app should still stop the clock. Pre-compiling every shader variant instead: worth doing, but it cannot cover a track loading or a slow frame from heat, and cannot be verified without the tablet |
| Graphics governor | Its own class; a long frame is left out; two slow windows in a row before stepping down; the previously stored tier is forgotten once | Stepping back up mid-ride: changing the view's size is itself a long frame, and oscillation is worse than a steady lower tier |
| Edge smoothing | The FXAA method inside the lens pass that already scales the 3D view to the screen | A separate full-screen pass (one more view for the tablet's CPU); MSAA (measured unusable upstream); only raising the resolution (stepped edges remain at any size the tablet can afford) |
| Bloom on the bike's tier | Two quarter-size passes (keep what is bright, blur) added in the lens pass | The engine's bloom: about half the fill cost. Bloom inside the lens pass alone: eight or more extra reads on every screen pixel |
| Sky | Drawn into a half-size off-screen image that the sky reads | Simplifying the tunnel's shader: it is the look. A full-size sky: a fifth of the fill cost for an image that is smooth anyway |
| Section gaps | A new generator: two sections a block, with the block's spare road split at random between the gap before and the gap between | Random gaps of any length: tracks would stop carrying equal effort, which is a tested property; gaps inside the old three-section block: no room without shrinking sections to a few seconds |
| Sweet spot | A rules-side bonus on the section's own distance credit, versioned as scoring 8, score only | A bonus that counts toward stars: stars rate hitting the range, and a narrow target would make three stars depend on a cadence sensor that reports whole numbers once a second |
| Cadence gauge | A panel beside the bike, as Lanebreak attaches its gauge to the wheel | A gauge in the top panel: that is where the range already was, and it was not being read |
| Music fades | A second player: the outgoing sound fades there while the new one fades in | Fading one player down before switching: the switch would wait, and the game reports stopped only after the fade |
| Scrolling | Our own drag handler on the list | The engine's touch scrolling: it only starts on the gaps (a button keeps the press) and only where the engine detects a touchscreen, so it cannot be tested off the tablet |

## What changed

**Interruptions.** `NeonTimeline.STALL_MS` (app) and `NeonLocalInput.STALL_MS` (game and desktop stand-in) are 1,000 ms; the game's own frame-time check uses the same value. Every pause logs its reason, the ride time and the sensor sample age. `LaneSmashGovernor` replaces the inline governor.

**Tracks (generator 6).** Each 20-road-second block is two sections and seven road-seconds of empty road: a 3–5 second gap that opens the block (the lane changes there) and a 4–2 second gap between the sections. A burst block is a cadence section then the burst; any other block is gold bars and a cadence section in either order. Cadence sections are 7 road-seconds (9–13 real seconds in range), gold bars 6, bursts 6. Lanes, cadence targets, burst spacing, attacks and mines follow revision 12's rules. See [Rules](../lane-smash/RULES.md#course-selection).

**Sweet spot (scoring 8).** The middle of a cadence section's range, 3 rpm either side, pays 20% more on the road covered there. See [Rules](../lane-smash/RULES.md#the-cadence-sweet-spot).

**Cadence gauge, power-burst celebration, scrolling.** See [Presentation](../lane-smash/PRESENTATION.md#interface).

**Music.** Starts, stops, track changes and seeks fade (0.6 s in, 0.4 s out, overlapping).

**Picture.** New tiers (the bike's default goes from 0.72 to 0.80 of the screen), edge smoothing on every tier, the two-pass bloom on the bike's tier, the off-screen sky, four road pulses instead of six. See [Presentation](../lane-smash/PRESENTATION.md#graphics-tiers).

## Compatibility

- Tracks generated now are course 9 / generator 6: new fingerprints, so no previous best or ghost. Rides saved earlier replay their own stored course under the rules they were ridden with (no gaps, no sweet spot).
- The app accepts scoring versions 1–8. No storage schema change.
- The app must be rebuilt for the stall limit to change on the Bike: the limit lives on both sides and the app's applies first.

## Acceptance criteria

1. A hitch of up to one second is caught up without pausing; a longer stall pauses; sensor loss still pauses at 1.5 s.
2. One long frame, or one slow window, never steps the graphics tier down; a sustained low frame rate does, after two windows.
3. A drag that starts on a track card scrolls the library and does not pick the card; a tap picks it.
4. Every pair of consecutive sections is 2–5 road-seconds apart; a lane change always has at least 3; no block holds two sections of the same kind; every track keeps the same effort budget.
5. Riding the middle of a cadence range earns the section's points and 19–20% more; anywhere else in the range earns the points only; the bonus never changes star credit; course 8 snapshots have no bonus; the outcome is identical at 10, 30, 50 and 100 ms steps.
6. The gauge is told of a section three road-seconds ahead, names the five states correctly, stays inside the play area, and fades rather than vanishing.
7. A finished burst starts the celebration with the section's points and suppresses the small number; it is fully visible within 0.1 s and gone within 1.5 s.
8. Every start, seek, track change and stop of the soundtrack fades; the game still reports stopped immediately.
9. Each tier sets its view size, sky size, bloom source and grade as tabled; edges are smoothed on every tier.
10. Every named and seeded track passes the full-duration audit on all five difficulties.
