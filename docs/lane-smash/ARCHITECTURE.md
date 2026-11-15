# Architecture

## Ownership

| Component | Responsibility |
| --- | --- |
| Android `NeonSettings`, `NeonRecords` and game bridge | Validate plans/records; deliver ordered sensor batches and active clock; persist attempts in Room |
| `NeonSetup` | Sole landing screen, track/duration/difficulty selection, settings and ride history |
| `LaneSmashCatalog`, `NeonCourse` | Generate seeded content, validate snapshots and calculate comparison fingerprints |
| `NeonRules` | Authoritative 10 ms scoring, distance, lane settling, sensor validation, machine-gun fire over cadence sections and star credit |
| `LaneSmashBarrage` | Fixed incoming-shot targets, impact timing, hit/pass/held-back outcomes |
| `NeonVector` | Coordinate input, rules, render state, HUD, sound, ghost, saves and the automatic graphics tier |
| `NeonTrack` | The 3D view's SubViewport and its tier (resolution, MSAA, bloom), the lens pass, and the drawn HUD pieces: lane dock, track chip, progress line, floating numbers |
| `LaneSmashSteering` | Smooth within-lane resistance position, fast threshold shifts, target-lane fade weights and left/right HUD cues; presentation only |
| `NeonSpace` | The 3D scene: fixed road chunks, chase camera, marker pools, shards and shockwaves; owns the components below |
| `LaneSmashBike` | The rider's motorcycle and the ghost's projection of it; cadence-driven rotors, wheels, thrusters and lean |
| `LaneSmashScenery`, `LaneSmashEnvironment` | Gantries and light streaks fixed along the route; the music-reactive sky |
| `LaneSmashSections`, `LaneSmashBombs`, `LaneSmashBarrageSpace`, `LaneSmashGunfire`, `LaneSmashAttacker` | Section floors and gates, road mines, Incoming Fire, machine-gun fire, and the raider model both attacks share |
| `LaneSmashFx` | Bounded pools of sparks, energy blasts and beams |
| `LaneSmashCadenceGauge`, `LaneSmashCelebration` | The cadence gauge beside the bike and the power-burst celebration; state and drawing only, fed by `NeonRules.cadence_target()` and section completions |
| `LaneSmashGovernor`, `LaneSmashDragScroll` | When the automatic graphics tier steps down; finger scrolling for lists of buttons |
| `LaneSmashLook`, `LaneSmashMenuTheme`, `LaneSmashSpectrum` | Art direction (meaning colours, palette lift, shared materials, the eased music levels and the colour pulse the interface uses), the one interface theme, and the eight-bar music meter |
| `Hud`, `NeonStatus`, `PointRollup` | Display metrics/instructions and animate counters without changing authoritative points |
| `Jukebox` (autoload), `LaneSmashMusicPanel` | The persistent soundtrack, its live spectrum analysis, and the track picker and seek slider |
| `GameOptions`, `LaneSmashAudioControls`, `AudioDirector`, `LaneSmashSound` | Persist shared switches and the automatic graphics tier; route music/effects; play event cues and the power, engine, charge and gun beds |

Rules contain no scene nodes or wall clocks. Renderers cannot award points. The machine-gun view reads `NeonRules.gunfire()` and `gun_hits`; the jukebox's analysis values reach only shaders and effects. Contact signals drive effects/sounds; the rules independently apply lane, cadence, power and collision eligibility. The game synchronizes the exact **net** rules total to `Effort`, including decreases after bombs. Only positive deltas emit its award signal.

## Input and timing

The native/local bridge supplies ordered samples with delivery sequence, received timestamp, cadence, watts and resistance. Repeated values still need fresh delivery timestamps. Input batches also carry active elapsed time, epoch and overflow/freshness flags.

**What pauses a ride.** Sensor silence of more than 1.5 s, a sample-buffer overflow, or a display stall: more than `STALL_MS` between two polls of the ride clock (`NeonTimeline` in the app, `NeonLocalInput` on a desktop, and the same limit on the game's own frame time). `STALL_MS` is **1,000 ms**. Until revision 13 it was 250 ms, which on the bike's tablet treated ordinary long frames (a shader compiling the first time an attacker or a blast is drawn, a track loading, the graphics tier changing) as interruptions: the recovery card, with End Ride on it, flashed up and the ride resumed by itself a few seconds later. A shorter hitch loses nothing: every sensor delivery during it is still in the five-second sample buffer with its own timestamp and is replayed in order. Every pause is logged (`OPENRIDE_GAMES lane_smash pause reason=… at_ms=… sample_age_ms=…`) so an interruption on the bike can be explained from `adb logcat`. The bridge contract and JNI details are in [GAMES.md](../GAMES.md).

Rules advance in 10 ms steps, integrate distance with fractional carry and record a ghost sample every 100 ms. There is a one-second power smoothing window for presentation; power points integrate measured input, not the animated meter. Rendering at 30/60/120 fps must not change outcomes.

The user finishes the selected duration or ends early. Stopping pedalling consumes time; no rider-controlled pause exists. Audio settings and End Ride confirmation do not pause. Sensor loss, invalid/overflowed batches or a display stall freeze rules and native time. Fresh stable input triggers automatic recovery and an unscored countdown. See the player guide for visible prompts.

## Storage and replay

An attempt saves before play, every five active seconds, on interruption and before results. Pending attempts recovered after a process exit become interrupted. Final saves are idempotent; a late checkpoint cannot rewrite a finished attempt. Storage failure exposes Retry save. Android uses Room schema 9; desktop uses isolated JSON records through the same request protocol.

Records contain the exact course snapshot, scoring/envelope versions, difficulty, result, penalties and ghost trace. Summary history omits detailed event/shot traces. The latest 50 attempts are shown; per-track last/best queries are independent of that list limit. Only completed eligible rides replace the best ghost. Partial rides remain visible in history.

Comparison identity includes rider, course fingerprint, difficulty, scoring version, envelope version and reference power. Visual `presentation` data is excluded from the scoring fingerprint. New courses use **course 11 / generator 8 / scoring 10 / envelope 1**. Course 10 introduces lane-checked rapid drops and an active-time cooldown. `NeonRules.events`, `NeonRules.hazards` and the barrage schedule are runtime copies used by scoring, visuals, sound and recaps; reflowing a full-section attack handoff or creating the cooldown tail never modifies the stored `course.events` or its fingerprint. Course 9 selects the cadence sweet spot (scoring 8) and generator 6 separates the sections with empty road (revision 13); both storage implementations accept scoring versions 1–10. Course 8 selects machine-gun fire (scoring 7); generator 5 (revision 12) changed the layout itself (cadence targets, section lengths, burst placement, the recovery lanes), so every track generated now has a new fingerprint and separate last/best records, and rides saved on generator 4 keep replaying their own snapshot. The world's three-to-one stretch is presentation only and is not part of any fingerprint. Course 7 snapshots keep scoring 6 (no gunfire); older ones keep their original point scale and dodge rules. Existing bests are not multiplied or compared against a newer rule set. The result adds `gunfire: {hits, penaltyUnits}` and `sweetSpot: {bonusUnits}` inside the existing versioned JSON payload; no database migration is needed.

## Settings

Music and sound effects use `shared/lane_smash_audio` in `user://game_options.cfg`, shared across screens and riders. Existing per-rider music is migrated once when read. Ghost, motion and the Graphics choice (Auto / High / Performance; Auto by default from revision 18) remain per-rider; the tier Auto last settled on is stored per device under `shared/lane_smash_graphics`. A failed write rolls back the cached choice and presents an error. These local preferences are separate from ride backups.

AudioDirector applies persistent mute gates independently of host/segment volume refreshes. Sound effects gates both SFX and spoken countdown cues; music uses its own bus. Re-enabling a switch resumes future effects/current power charge rather than replaying missed events.

## Resource boundaries and validation

The renderer retains bounded target/effect pools and reuses meshes: 112 markers per kind, 192 shards, 12 shockwaves, 192 sparks, 8 blasts, 8 beams, 40 mines, 36 tracers, 8 gantries and 96 light streaks. Scenery slots are rewritten only when a piece enters the window. Every surface is unshaded and lit in its shader; the scene has no engine lights or fog. Audio uses pre-rendered short WAVs, the existing effect player pool and one player per bed (power, engine, charge, gun); it does not synthesize or allocate a new player per contact. The jukebox streams one track at a time, loaded on a worker thread. Score counters reuse two small interpolation objects. In-ride audio controls are removed when the game exits.

Use the focused gdUnit4 suites, `play_neon_vector.gd`, `audit_lane_smash_tracks.gd`, `calibrate_lane_smash_scores.gd`, `soak_lane_smash.gd`, Android unit tests and signed export verification. For the look, `capture_lane_smash_look.gd` renders stills of any moment of any track with simulated sensors (optionally with synthetic music), and `capture_lane_smash_models.gd` renders the models on a turntable. Tests/captures use isolated storage. Physical Original Bike compatibility, GPU performance and thermals remain unverified; desktop success is not a crash-free device guarantee.


Revision 19 separates the pass-resolution timestamp from the physical impact timestamp. The rules tick awards once at clearance, while the view and sound observe resolution/impact separately. Generator 8 changes section lengths, paired cadence bands and mine coverage; therefore last/best/ghost comparisons are intentionally separate from older layouts. History remains readable, and the test-only generator-7 fixture exercises old snapshot rules without regenerating them with new content. No Room or Drizzle schema change is involved.
