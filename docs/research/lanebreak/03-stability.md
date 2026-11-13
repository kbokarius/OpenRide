# Stability and maintenance assessment

Snapshot: November 13, 2026. Source: public GitHub repository metadata, all issue/PR metadata, release metadata, relevant issue discussions, and source at `bb8a764012972611761c3fc5839436dd1cf4acfc`.

## Assessment

**Suitable for a controlled evaluation and as a development base. Insufficient evidence to promise daily reliability on an untested bike.** The central uncertainty is real-device behavior and game tuning, not the absence of a sensor or game architecture.

## Project activity

| Signal | Snapshot | Interpretation |
| --- | --- | --- |
| Repository created | July 19, 2026 | About four months old |
| Latest release | [v1.2.0](https://github.com/digitalducktape/OpenRide/releases/tag/v1.2.0), November 12 | Actively maintained; newest games have very little release exposure |
| Release inventory | 8 releases, including 1 prerelease | More informative than a single initial release, but still young |
| Issues | 65 total, 6 open, 59 closed | Includes project tasks and feature requests, not just bugs |
| Pull requests | 25 total, 1 open | The open [#70](https://github.com/digitalducktape/OpenRide/pull/70) adds FTMS/controller support; not in reviewed main |
| Stars/forks before this fork | 23 / 13 | Small community; not a reliability score |
| Contributors API | digitalducktape 511 commits; eggdev 1; claude 1 | Strong dependence on one maintainer; commit count is not a measure of independent review |
| Latest APK downloads | v1.2.0: 106; v1.1.0: 1,766 at capture | Downloads are not active riders or completed rides |
| CI visibility | No workflow files in `.github/workflows`; Actions API returned no runs | No independent green CI result established in this review |

Sources: [repository](https://github.com/digitalducktape/OpenRide), [issues](https://github.com/digitalducktape/OpenRide/issues), [releases](https://github.com/digitalducktape/OpenRide/releases), [contributors](https://github.com/digitalducktape/OpenRide/graphs/contributors), [Actions](https://github.com/digitalducktape/OpenRide/actions).

## Issues that matter most

| Issue | Current state | Evidence and practical implication |
| --- | --- | --- |
| [#49: game tuning/follow-ups](https://github.com/digitalducktape/OpenRide/issues/49) | Open | Explicitly says difficulty was estimated and little had been ridden on a real bike. Lists resistance lag, difficulty and full-circuit checks. Later code/releases implemented some listed items; do not treat every checkbox as current. Real-bike tuning remains an unresolved concern. |
| [#71: camera sensitivity](https://github.com/digitalducktape/OpenRide/issues/71) | Open | Rider reports over-sensitive steering and difficulty returning to center. A knob-controlled game can avoid depending on this subsystem. |
| [#63: newer g700 tablet](https://github.com/digitalducktape/OpenRide/issues/63) | Open | Live metrics and saving a ride reported working on Android 13; stock Peloton overlay subsequently covers the launcher. The disable-app workaround was not followed by a confirmed live ride in that comment. A newer-tablet report is not a guarantee for all firmware. |
| [#47: launcher activation](https://github.com/digitalducktape/OpenRide/issues/47) | Closed | Shell command failed on Android 10/11; current in-app Home screen toggle replaces that path. Do not follow old `pm enable` instructions blindly. |
| [#56: silent sensors](https://github.com/digitalducktape/OpenRide/issues/56) | Closed | Sensor board stopped answering until power cycle. Current source adds frame-silence detection and shared warnings. That improves detection, not the reliability of Peloton's underlying service. |
| [#57: game display size](https://github.com/digitalducktape/OpenRide/issues/57) | Closed | Some original Bike firmware exposes a 1920×1008 app window. Layout now expands the game view; a new game must respect this shape. |
| [#78: Watt Lane](https://github.com/digitalducktape/OpenRide/issues/78) | Closed | Revised from a road concept to a vertical power cursor. Acceptance originally included measuring real-bike response lag. Current code and screenshots establish what shipped, not every acceptance measurement. |
| [#69: feedback](https://github.com/digitalducktape/OpenRide/issues/69) | Closed | Closed after splitting into #71/#72/#73. It does not mean all reported problems were fixed. |
| [#73: video quality](https://github.com/digitalducktape/OpenRide/issues/73) | Closed | Current release changes codec preference for the old tablet. Mostly irrelevant to a bundled silent game. |

Other open issues: [#29 local-network video](https://github.com/digitalducktape/OpenRide/issues/29), [#68 FTMS trainers](https://github.com/digitalducktape/OpenRide/issues/68), and [#85 usage telemetry](https://github.com/digitalducktape/OpenRide/issues/85). They are feature requests, not evidence of six outstanding crash bugs. Telemetry is proposed work; it is not proof that the current app collects those events.

Issues #18, #23 and #24 were closed as not planned. This is another reason not to equate closed issue count with delivered, verified functionality.

## Positive engineering evidence

- Sensor abstraction with two competing service paths and a polling fallback.
- Tests for frame-silence detection, session plans and lifecycle, backups, database migrations, scoring, game logic and layout.
- Game scoring is centrally gated by pause and sensor status.
- Room migrations and versioned backup data; game results are included in backups.
- Hardware notes identify specific tested tablets and firmware, rather than making an unrestricted compatibility claim.
- The source includes performance work for the older tablet, including preloading and GPU-budget improvements.

These are source-level findings. No tests were executed and no physical bike was connected in this pass. There is no measured crash rate, full audit or certification here.

## Documentation drift discovered

1. The README summary still says five mini-games in one place, although the registry has twelve.
2. `INSTALL.md` still mentions generic debug APK paths in older sections; that build uses simulated sensors. The README and Gradle configuration establish `assembleDebugReal` for a real bike.
3. `INSTALL.md` discusses backup as future work in one rollback paragraph, although backup and game-result export are implemented.
4. The original #49 checklist predates later changes such as circuit shuffling. Read current code and release notes alongside it.

## Evaluation before replacing the daily routine

First record tablet model, Android version and build. Install upstream as an app before deciding whether to make it the home screen. Compare live cadence, resistance and power, then perform several full rides at the intended duration. Verify pause/resume, reboot, offline play, ride persistence, scores after relaunch, and backup restore into a disposable test profile/app. Measure knob-to-screen response and sustained frame rate before tuning course timing.

Do not use this research report alone as the reason to cancel the existing subscription. The decision point is whether the actual installed alternative reliably delivers the daily workout experience.

## Complete issue index

The index below records issue state and reason at capture; PRs are excluded. Titles are identifiers from the tracker, not claims that their acceptance criteria were met.

| Issue | State | Reason | Title |
| --- | --- | --- | --- |
| [#1](https://github.com/digitalducktape/OpenRide/issues/1) | closed | completed | T1: Project scaffold (Kotlin + Compose, minSdk 30) |
| [#2](https://github.com/digitalducktape/OpenRide/issues/2) | closed | completed | T2: BikeDataSource abstraction + MockBikeDataSource |
| [#3](https://github.com/digitalducktape/OpenRide/issues/3) | closed | completed | T3: PelotonBikeDataSource — bind the Gen 2 internal system service (grupetto technique) |
| [#4](https://github.com/digitalducktape/OpenRide/issues/4) | closed | completed | T4: Room data layer — Profile / Ride / RideSample |
| [#5](https://github.com/digitalducktape/OpenRide/issues/5) | closed | completed | T5: Ride engine — session manager, timer, sampler, keep-awake |
| [#6](https://github.com/digitalducktape/OpenRide/issues/6) | closed | completed | T6: Profile select & create screens |
| [#7](https://github.com/digitalducktape/OpenRide/issues/7) | closed | completed | T7: In-ride screen — Peloton-style metrics layout |
| [#8](https://github.com/digitalducktape/OpenRide/issues/8) | closed | completed | T8: Ride summary + history screens |
| [#9](https://github.com/digitalducktape/OpenRide/issues/9) | closed | completed | T9: Content layer — YouTube RSS channel feeds |
| [#10](https://github.com/digitalducktape/OpenRide/issues/10) | closed | completed | T10: Classes browse UI + playback |
| [#11](https://github.com/digitalducktape/OpenRide/issues/11) | closed | completed | T11: Home screen + navigation shell |
| [#12](https://github.com/digitalducktape/OpenRide/issues/12) | closed | completed | T12: Launcher integration + sideload docs |
| [#13](https://github.com/digitalducktape/OpenRide/issues/13) | closed | completed | T13: Ride goals + power zones (P1-3) |
| [#14](https://github.com/digitalducktape/OpenRide/issues/14) | closed | completed | T14: Workout export — FIT/TCX + CSV (P1-1, P1-2) |
| [#15](https://github.com/digitalducktape/OpenRide/issues/15) | closed | completed | T15: Local backup & restore (P1-8) |
| [#16](https://github.com/digitalducktape/OpenRide/issues/16) | closed | completed | T16: Profile-switch confirmation (P1-6) |
| [#17](https://github.com/digitalducktape/OpenRide/issues/17) | closed | completed | T17: BLE heart-rate monitor pairing (P1-4) |
| [#18](https://github.com/digitalducktape/OpenRide/issues/18) | closed | not_planned | T18: Historical import from Peloton cloud (P1-7) — TIME-SENSITIVE |
| [#19](https://github.com/digitalducktape/OpenRide/issues/19) | closed | completed | T19: Bluetooth headphone audio routing (P1-9) |
| [#20](https://github.com/digitalducktape/OpenRide/issues/20) | closed | completed | T20: Auto-pause / auto-resume on freewheel (P2) |
| [#21](https://github.com/digitalducktape/OpenRide/issues/21) | closed | completed | T21: GPX route simulation (P2) |
| [#22](https://github.com/digitalducktape/OpenRide/issues/22) | closed | completed | T22: In-app self-updater (P2) |
| [#23](https://github.com/digitalducktape/OpenRide/issues/23) | closed | not_planned | T23: Strava sync (P2) — needs user's Strava API app |
| [#24](https://github.com/digitalducktape/OpenRide/issues/24) | closed | not_planned | T24: Companion iOS app for automatic Apple Health sync (P2) — separate platform |
| [#25](https://github.com/digitalducktape/OpenRide/issues/25) | closed | completed | Expand Classes catalog: new creators, filters, playlists, custom sources |
| [#29](https://github.com/digitalducktape/OpenRide/issues/29) | open | — | Feature Request - Add support for SMB/NAS local video playback |
| [#31](https://github.com/digitalducktape/OpenRide/issues/31) | closed | completed | Mini-games epic: a game-based way to ride |
| [#32](https://github.com/digitalducktape/OpenRide/issues/32) | closed | completed | Mini-games: Godot host, bridge and packaging foundation |
| [#33](https://github.com/digitalducktape/OpenRide/issues/33) | closed | completed | Mini-games: HeadTracker (camera lean, depth, standing, calibration) |
| [#34](https://github.com/digitalducktape/OpenRide/issues/34) | closed | completed | Mini-games: Godot game framework (Game base, HUD kit, calibration UI, audio) |
| [#35](https://github.com/digitalducktape/OpenRide/issues/35) | closed | completed | Mini-games: session engine, Just Ride, FTP scaling and ride recording |
| [#36](https://github.com/digitalducktape/OpenRide/issues/36) | closed | completed | Mini-games: generated music and sound effects (MusicGen + SfxSynth) |
| [#37](https://github.com/digitalducktape/OpenRide/issues/37) | closed | completed | Mini-games: Circuit mode (chain games into one workout) |
| [#38](https://github.com/digitalducktape/OpenRide/issues/38) | closed | completed | Mini-games: Games hub tab (Compose) |
| [#39](https://github.com/digitalducktape/OpenRide/issues/39) | closed | completed | Mini-games: Dodge Ball (work game, camera lean) |
| [#40](https://github.com/digitalducktape/OpenRide/issues/40) | closed | completed | Mini-games: Tug of War (work game, power) |
| [#41](https://github.com/digitalducktape/OpenRide/issues/41) | closed | completed | Mini-games: Safe Cracker (recovery game, resistance knob) |
| [#42](https://github.com/digitalducktape/OpenRide/issues/42) | closed | completed | Mini-games: Cadence Karaoke (warm-up / recovery / cool-down, cadence + music) |
| [#43](https://github.com/digitalducktape/OpenRide/issues/43) | closed | completed | Mini-games: Kart Race (phase 2, long-form 5-60 min) |
| [#45](https://github.com/digitalducktape/OpenRide/issues/45) | closed | completed | Mini-games: remove the Godot boot splash when entering games |
| [#47](https://github.com/digitalducktape/OpenRide/issues/47) | closed | completed | INSTALL.md: `pm enable …HomeLauncherAlias` fails on Android 10 (Bike+) with SecurityException |
| [#49](https://github.com/digitalducktape/OpenRide/issues/49) | open | — | Mini-games follow-up: bike tuning and the pieces not built yet |
| [#55](https://github.com/digitalducktape/OpenRide/issues/55) | closed | completed | Mini-games: produced music and SFX pass for the existing games |
| [#56](https://github.com/digitalducktape/OpenRide/issues/56) | closed | completed | Alert when the bike's sensor board isn't responding |
| [#57](https://github.com/digitalducktape/OpenRide/issues/57) | closed | completed | Games: widen the view to fill the bike's 1920x1008 window (no side bars) |
| [#60](https://github.com/digitalducktape/OpenRide/issues/60) | closed | completed | Restyle In-ride, metrics bar and Video ride on the design system (main UI refresh phase 7) |
| [#63](https://github.com/digitalducktape/OpenRide/issues/63) | open | — | Works on newer Peloton bike tablet (g700 / PLTN-RTR01, Android 13): V1 denied "while attached to TITAN", IBikeInterface delivers live data |
| [#68](https://github.com/digitalducktape/OpenRide/issues/68) | open | — | Support for FTMS smart trainers |
| [#69](https://github.com/digitalducktape/OpenRide/issues/69) | closed | completed | Feedback |
| [#71](https://github.com/digitalducktape/OpenRide/issues/71) | open | — | Camera lean steering is too sensitive and hard to return to center |
| [#72](https://github.com/digitalducktape/OpenRide/issues/72) | closed | completed | Option to mute class audio and play your own music |
| [#73](https://github.com/digitalducktape/OpenRide/issues/73) | closed | completed | Video resolution picker (playback downscales too much) |
| [#74](https://github.com/digitalducktape/OpenRide/issues/74) | closed | completed | Mini-games wave 2: seven new games |
| [#75](https://github.com/digitalducktape/OpenRide/issues/75) | closed | completed | Mini-games: Framework: circuits and the hub for a bigger game list |
| [#76](https://github.com/digitalducktape/OpenRide/issues/76) | closed | completed | Mini-games: Balloon Pump — wave A |
| [#77](https://github.com/digitalducktape/OpenRide/issues/77) | closed | completed | Mini-games: Keepy Uppy — wave A |
| [#78](https://github.com/digitalducktape/OpenRide/issues/78) | closed | completed | Mini-games: Watt Lane — wave A |
| [#79](https://github.com/digitalducktape/OpenRide/issues/79) | closed | completed | Mini-games: The Pull — wave A |
| [#80](https://github.com/digitalducktape/OpenRide/issues/80) | closed | completed | Mini-games: Gate Crasher — wave B |
| [#81](https://github.com/digitalducktape/OpenRide/issues/81) | closed | completed | Mini-games: Power Grid — wave B |
| [#82](https://github.com/digitalducktape/OpenRide/issues/82) | closed | completed | Mini-games: Ready for Launch — wave B |
| [#83](https://github.com/digitalducktape/OpenRide/issues/83) | closed | completed | Feature request: Import Peloton workout history (CSV export) into OpenRide |
| [#84](https://github.com/digitalducktape/OpenRide/issues/84) | closed | completed | Delete a ride from history |
| [#85](https://github.com/digitalducktape/OpenRide/issues/85) | open | — | Add privacy-respecting app telemetry to understand usage |
| [#86](https://github.com/digitalducktape/OpenRide/issues/86) | closed | completed | Add Buy Me a Coffee support link on GitHub and in the app |
