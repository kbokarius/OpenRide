# Architecture

## Ownership

| Component | Responsibility |
| --- | --- |
| Android `NeonSettings`, `NeonRecords` and game bridge | Validate plans/records; deliver ordered sensor batches and active clock; persist attempts in Room |
| `NeonSetup` | Sole landing screen, track/duration/difficulty selection, settings and ride history |
| `LaneSmashCatalog`, `NeonCourse` | Generate seeded content, validate snapshots and calculate comparison fingerprints |
| `NeonRules` | Authoritative 10 ms scoring, distance, lane settling, sensor validation and star credit |
| `LaneSmashBarrage` | Fixed incoming-shot targets, impact timing, hit/pass/held-back outcomes |
| `NeonVector` | Coordinate input, rules, render state, HUD, sound, ghost and saves |
| `NeonTrack`, `NeonSpace` and `LaneSmash*` render components | Draw fixed road, cyclist, backgrounds, targets, warnings, explosions and popups |
| `Hud`, `NeonStatus`, `PointRollup` | Display metrics/instructions and animate counters without changing authoritative points |
| `GameOptions`, `LaneSmashAudioControls`, `AudioDirector`, `LaneSmashSound` | Persist shared switches; route music/effects; play event cues and power bed |

Rules contain no scene nodes or wall clocks. Renderers cannot award points. Contact signals drive effects/sounds; the rules independently apply lane, cadence, power and collision eligibility. The game synchronizes the exact **net** rules total to `Effort`, including decreases after bombs. Only positive deltas emit its award signal.

## Input and timing

The native/local bridge supplies ordered samples with delivery sequence, received timestamp, cadence, watts and resistance. Repeated values still need fresh delivery timestamps. Input batches also carry active elapsed time, epoch and overflow/freshness flags. The bridge contract and JNI details are in [GAMES.md](../GAMES.md).

Rules advance in 10 ms steps, integrate distance with fractional carry and record a ghost sample every 100 ms. There is a one-second power smoothing window for presentation; power points integrate measured input, not the animated meter. Rendering at 30/60/120 fps must not change outcomes.

The user finishes the selected duration or ends early. Stopping pedalling consumes time; no rider-controlled pause exists. Audio settings and End Ride confirmation do not pause. Sensor loss, invalid/overflowed batches or a display stall freeze rules and native time. Fresh stable input triggers automatic recovery and an unscored countdown. See the player guide for visible prompts.

## Storage and replay

An attempt saves before play, every five active seconds, on interruption and before results. Pending attempts recovered after a process exit become interrupted. Final saves are idempotent; a late checkpoint cannot rewrite a finished attempt. Storage failure exposes Retry save. Android uses Room schema 9; desktop uses isolated JSON records through the same request protocol.

Records contain the exact course snapshot, scoring/envelope versions, difficulty, result, penalties and ghost trace. Summary history omits detailed event/shot traces. The latest 50 attempts are shown; per-track last/best queries are independent of that list limit. Only completed eligible rides replace the best ghost. Partial rides remain visible in history.

Comparison identity includes rider, course fingerprint, difficulty, scoring version, envelope version and reference power. Visual `presentation` data is excluded from the scoring fingerprint. New courses use **course 7 / generator 4 / scoring 6 / envelope 1**. Old course snapshots retain their original point scale and dodge rules; existing bests are not multiplied or compared against the new scale. Both storage implementations accept scoring versions 1–6. No database migration is needed.

## Settings

Music and sound effects use `shared/lane_smash_audio` in `user://game_options.cfg`, shared across screens and riders. Existing per-rider music is migrated once when read. Ghost and motion preferences remain per-rider. A failed write rolls back the cached choice and presents an error. These local preferences are separate from ride backups.

AudioDirector applies persistent mute gates independently of host/segment volume refreshes. Sound effects gates both SFX and spoken countdown cues; music uses its own bus. Re-enabling a switch resumes future effects/current power charge rather than replaying missed events.

## Resource boundaries and validation

The renderer retains bounded target/effect pools and reuses meshes. Audio uses pre-rendered short WAVs, the existing effect player pool and one power-loop player; it does not synthesize or allocate a new player per contact. Score counters reuse two small interpolation objects. In-ride audio controls are removed when the game exits.

Use the focused gdUnit4 suites, `play_neon_vector.gd`, `audit_lane_smash_tracks.gd`, `calibrate_lane_smash_scores.gd`, `soak_lane_smash.gd`, Android unit tests and signed export verification. Tests/captures use isolated storage. Physical Original Bike compatibility, GPU performance and thermals remain unverified; desktop success is not a crash-free device guarantee.
