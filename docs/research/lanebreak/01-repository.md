# Repository and reuse analysis

Date: 2026-11-13. Baseline: `bb8a764012972611761c3fc5839436dd1cf4acfc`.

## Architecture verified in source

| Area | Implementation | Relevance |
| --- | --- | --- |
| Android shell | Kotlin, Jetpack Compose, Material 3 | Profiles, home, navigation, history, settings |
| Hardware | `BikeDataSource`, `AffernetBikeDataSource`, two internal service bindings | Reads cadence, watts and resistance without implementing new sensor hardware |
| Game host | Godot 4.7.2, GL Compatibility, `GameHostActivity` | Existing renderer and Android integration |
| Bridge | `InputBus`, `Session`, `OpenRideBridge` | Per-frame sensor values; session events; score/results reporting |
| Sessions | `GameVisitManager`, `GameSessionManager`, `SessionPlan`, `GameCatalog` | Timing, pause, plans, difficulty and recording |
| Persistence | Room, database version 8; `Profile`, `Ride`, `RideSample`, `GameResult` | Workout and game history already local |
| Bests | `GameResultDao` | Groups by game, variant, plan and difficulty; no new backend needed |
| Audio | `AudioDirector`, music switch and separate effects volume | Can support a fully silent game |
| Updates | `UpdateRepository`, `UpdateChecker` | GitHub release lookup and user-confirmed APK installation |

Build facts: `minSdk = 29` (Android 10), `compileSdk/targetSdk = 34`, versionCode 9. The `debugReal` build reads real sensors and uses package `dev.digitalducktape.openride.real`. Ordinary debug uses simulated sensors and a different package. The checked-in `release` build does not enable real sensors; merely choosing a task named release is not sufficient for the bike.

Sources: [build configuration](../../../app/build.gradle.kts), [game integration documentation](../../GAMES.md), [sensor arbitration](../../../app/src/main/java/dev/digitalducktape/openride/core/sensor/AffernetBikeDataSource.kt), [database](../../../app/src/main/java/dev/digitalducktape/openride/core/data/OpenRideDatabase.kt).

## Existing game inventory

The [registry](../../../games/games/Registry.gd) contains twelve user-facing games and `demo`:

| Game | Main interaction | Fit for the requested experience |
| --- | --- | --- |
| Watt Lane | Power moves a cursor vertically into a scrolling target band | Closest sustained-target game; not resistance lane selection |
| Cadence Karaoke | Keep cadence within a target band | Reusable cadence-scoring concepts |
| Safe Cracker | Turn resistance to dial targets under a power cap | Reusable knob-input experience; not a continuous course |
| Tug of War | Power against a simulated opponent | Output challenge, different presentation |
| Dodge Ball | Camera lean and cadence | Not needed for this project |
| Kart Race | Pedaling, camera steering, resistance-assisted drifting | Racing, not Lanebreak-style lane control |
| Balloon Pump | Power fills balloons | Short effort challenge |
| Keepy Uppy | Power keeps a balloon aloft; optional lean | Different game loop |
| Power Grid | Match a town's power demand | Power targets, different presentation |
| Ready for Launch | Fuel and launch a rocket | Output challenge |
| The Pull | Pull an increasingly heavy sled | Output challenge |
| Gate Crasher | Pedal and stand for jumps; camera | Not needed for this project |

Watt Lane uses a three-second power average. It awards points for time inside a band and a streak multiplier. Current Standard target centers are approximately 22–40% of the rider's FTP, before course adjustments and rounding. FTP is a stored reference power used to scale difficulty; missing FTP defaults to 150 W. This is deliberately gentle after rider feedback. Its name should not be mistaken for a Lanebreak clone. See [rules](../../../games/games/watt_lane/WattLaneLogic.gd), [catalog scaling](../../../app/src/main/java/dev/digitalducktape/openride/games/session/GameCatalog.kt), and [issue #78 revisions](https://github.com/digitalducktape/OpenRide/issues/78).

## What a new game can reuse

1. Read cadence, power and resistance from `InputBus`; no second sensor reader.
2. Extend the existing `Game` base, register its scene, and add a matching Kotlin catalog entry.
3. Use the shared pause, intro, HUD and results flows. Award through `Effort` so paused/offline sessions cannot score once the shared offline flag is set.
4. Save course results with existing game-result records if their metadata can represent the new format; evaluate before changing Room schemas.
5. Use the desktop sensor simulator for development, then validate physical knob latency and frame rate on the Bike.

## Gaps that need design work

- **Resistance-to-lane mapping:** separate from wattage. Add stable boundaries, tolerance around boundaries and previewed transitions; evaluate sensor lag on hardware.
- **Repeatable rides:** current games/circuits can use random seeds. A personal-best course must retain course ID, version, difficulty and seed where applicable.
- **Comparable scores:** existing general plan IDs and difficulty may be insufficient after changing a course or rider scaling. Persist the scoring/course version and relevant target configuration.
- **Challenge scheduling:** one continuous course needs an internal timeline for lane pickups, cadence holds and output pushes. It should not switch to another mini-game at every challenge.
- **Sensor loss:** the shared implementation detects a silent sensor source after 3 s and then applies a 10 s offline delay. Before relying on it for precision scoring, measure the combined behavior and decide how the new game handles stale input and resumption.
- **Difficulty:** the shared enum currently has Easy/Standard/Hard. More levels require an explicit model change or game-specific configuration, not just an extra visual button.
- **Updates:** upstream URL is a constant; the fork does not inherit an independent release channel automatically.

## Existing UI reviewed

Inspected Home, Games hub, Watt Lane and Cadence Karaoke screenshots, plus the hub/framework source. Keep the current Home/Games entry points, large saddle-readable controls, sensor status, familiar Pause/End behavior and result flow. Reuse the existing game visual framework while making the track artwork original. The bundled hub screenshot still shows five games; the registry/catalog establish the current twelve.

![Existing Watt Lane screen](../../screenshots/game_watt_lane.png)

## Development and evidence limits

The repository has Apache-2.0 licensing and third-party notices. Preserve those and record any new asset provenance. This is not a legal assessment of copying another product; the proposal uses original code, visuals and content.

`CLAUDE.md` directs Godot implementation work to the matching GodotPrompter skills and asks for a pattern decision before building. No Godot system was changed here. Resolve that tool/skill requirement when implementation begins.

No build or tests were run. Source inspection found 116 Kotlin files under unit-test sources, 3 instrumented-test Kotlin files, and 91 Godot unit-test scripts. These are file counts, not passing-test counts. This project uses Room, not Drizzle; no schema or migration changes were made.
