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
| `NeonSpace` | The 3D scene: fixed road chunks, chase camera, marker pools, shards and shockwaves; owns the components below |
| `LaneSmashBike` | The rider's motorcycle and the ghost's projection of it; cadence-driven rotors, wheels, thrusters and lean |
| `LaneSmashScenery`, `LaneSmashEnvironment` | Gantries and light streaks fixed along the route; the music-reactive sky |
| `LaneSmashSections`, `LaneSmashBombs`, `LaneSmashBarrageSpace`, `LaneSmashGunfire`, `LaneSmashAttacker` | Section floors and gates, road mines, Incoming Fire, machine-gun fire, and the raider model both attacks share |
| `LaneSmashFx` | Bounded pools of sparks, energy blasts and beams |
| `LaneSmashLook`, `LaneSmashMenuTheme` | Art direction (meaning colours, palette lift, shared materials) and the one interface theme |
| `Hud`, `NeonStatus`, `PointRollup` | Display metrics/instructions and animate counters without changing authoritative points |
| `Jukebox` (autoload), `LaneSmashMusicPanel` | The persistent soundtrack, its live spectrum analysis, and the track picker and seek slider |
| `GameOptions`, `LaneSmashAudioControls`, `AudioDirector`, `LaneSmashSound` | Persist shared switches and the automatic graphics tier; route music/effects; play event cues and the power, engine, charge and gun beds |

Rules contain no scene nodes or wall clocks. Renderers cannot award points. The machine-gun view reads `NeonRules.gunfire()` and `gun_hits`; the jukebox's analysis values reach only shaders and effects. Contact signals drive effects/sounds; the rules independently apply lane, cadence, power and collision eligibility. The game synchronizes the exact **net** rules total to `Effort`, including decreases after bombs. Only positive deltas emit its award signal.

## Input and timing

The native/local bridge supplies ordered samples with delivery sequence, received timestamp, cadence, watts and resistance. Repeated values still need fresh delivery timestamps. Input batches also carry active elapsed time, epoch and overflow/freshness flags. The bridge contract and JNI details are in [GAMES.md](../GAMES.md).

Rules advance in 10 ms steps, integrate distance with fractional carry and record a ghost sample every 100 ms. There is a one-second power smoothing window for presentation; power points integrate measured input, not the animated meter. Rendering at 30/60/120 fps must not change outcomes.

The user finishes the selected duration or ends early. Stopping pedalling consumes time; no rider-controlled pause exists. Audio settings and End Ride confirmation do not pause. Sensor loss, invalid/overflowed batches or a display stall freeze rules and native time. Fresh stable input triggers automatic recovery and an unscored countdown. See the player guide for visible prompts.

## Storage and replay

An attempt saves before play, every five active seconds, on interruption and before results. Pending attempts recovered after a process exit become interrupted. Final saves are idempotent; a late checkpoint cannot rewrite a finished attempt. Storage failure exposes Retry save. Android uses Room schema 9; desktop uses isolated JSON records through the same request protocol.

Records contain the exact course snapshot, scoring/envelope versions, difficulty, result, penalties and ghost trace. Summary history omits detailed event/shot traces. The latest 50 attempts are shown; per-track last/best queries are independent of that list limit. Only completed eligible rides replace the best ghost. Partial rides remain visible in history.

Comparison identity includes rider, course fingerprint, difficulty, scoring version, envelope version and reference power. Visual `presentation` data is excluded from the scoring fingerprint. New courses use **course 8 / generator 4 / scoring 7 / envelope 1**: the layout generator is unchanged, and the course version alone selects machine-gun fire, so every new track has a new fingerprint and separate last/best records. Course 7 snapshots keep scoring 6 (no gunfire); older ones keep their original point scale and dodge rules. Existing bests are not multiplied or compared against a newer rule set. Both storage implementations accept scoring versions 1–7. The result adds `gunfire: {hits, penaltyUnits}` inside the existing versioned JSON payload; no database migration is needed.

## Settings

Music and sound effects use `shared/lane_smash_audio` in `user://game_options.cfg`, shared across screens and riders. Existing per-rider music is migrated once when read. Ghost, motion and the Graphics choice (Auto / High / Performance) remain per-rider; the tier Auto last settled on is stored per device under `shared/lane_smash_graphics`. A failed write rolls back the cached choice and presents an error. These local preferences are separate from ride backups.

AudioDirector applies persistent mute gates independently of host/segment volume refreshes. Sound effects gates both SFX and spoken countdown cues; music uses its own bus. Re-enabling a switch resumes future effects/current power charge rather than replaying missed events.

## Resource boundaries and validation

The renderer retains bounded target/effect pools and reuses meshes: 112 markers per kind, 192 shards, 12 shockwaves, 192 sparks, 8 blasts, 8 beams, 12 mines, 36 tracers, 8 gantries and 96 light streaks. Scenery slots are rewritten only when a piece enters the window. Every surface is unshaded and lit in its shader; the scene has no engine lights or fog. Audio uses pre-rendered short WAVs, the existing effect player pool and one player per bed (power, engine, charge, gun); it does not synthesize or allocate a new player per contact. The jukebox streams one track at a time, loaded on a worker thread. Score counters reuse two small interpolation objects. In-ride audio controls are removed when the game exits.

Use the focused gdUnit4 suites, `play_neon_vector.gd`, `audit_lane_smash_tracks.gd`, `calibrate_lane_smash_scores.gd`, `soak_lane_smash.gd`, Android unit tests and signed export verification. For the look, `capture_lane_smash_look.gd` renders stills of any moment of any track with simulated sensors (optionally with synthetic music), and `capture_lane_smash_models.gd` renders the models on a turntable. Tests/captures use isolated storage. Physical Original Bike compatibility, GPU performance and thermals remain unverified; desktop success is not a crash-free device guarantee.
