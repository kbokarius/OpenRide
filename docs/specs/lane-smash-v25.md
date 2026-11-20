# Revision 25 — pre-ride score targets and persistent ghosts

Implemented November 19, 2026. Signed build 33 / revision 25 was installed on the Peloton on November 20, 2026.

## Request and diagnosis

Show the previous high score and score to beat during the track preview. Investigate a missing Iron Horizon / Hard ghost after an update.

The old selector and ride loader queried only the exact comparison key. Build 32 changed course 12 / generator 9 / scoring 11 into course 13 / generator 10 / scoring 12 by adding gap mines. A completed build-31 ride therefore disappeared from the new track's last/best lookup even though its immutable snapshot and ghost remained in storage. This is reproducible with an Iron Horizon / Hard fixture; the rider's private device database was not extracted, so this is not a claim that their particular recording was inspected.

A separate renderer issue hid every ghost within 1.4 rules-metres longitudinally, even alongside the rider in a different lane.

## Implementation decisions

Use the existing Room/JSON record store, exact comparison keys and immutable course snapshots. Add a shared personal-benchmark selector and a visual block in the existing intro card. Reject rewriting old keys or merging changed course results into one exact-version leaderboard: that would damage replay identity and obscure rule changes.

The same `NeonBenchmark` logic feeds the menu, countdown target and ghost selection. It chooses the highest completed compatible score and the latest final attempt. A lower new score does not remove the old best. Ties use oldest achievement time, then attempt ID. Partial/interrupted rides can be the latest attempt but cannot become the best.

## Eligibility and compatibility

For cross-version matching, require all of:

- Same rider and course ID, including the selected duration and random seed.
- Same difficulty, duration in milliseconds, reference power and point scale.
- Same bridge envelope, six resistance bands and Kid cadence percentage.

Compare persisted lane-band numbers numerically, because JSON restores them as floats. Exact-key historical matches remain supported. Do not manufacture scores, scale old point units or overwrite old snapshots. Course/scoring versions and Room schema remain **13 / 12 / 9**; generator remains **10**, envelope **1**.

Earlier-version benchmarks are useful personal targets, not assertions that different rules/layouts provide identical scoring opportunities. The menu adds “different version,” the preview says **Different track version**, and the ride HUD uses **PRIOR BEST**. A same-version ghost uses **BEST RIDE**. Historical `best` requests still use their original exact-key semantics.

## Storage contract

`state.trackStats[key]` retains `lastScoreUnits`, `lastStatus`, `bestScoreUnits`, and adds compact `last` and `best` summaries. Each includes:

`attemptId`, `riderId`, `comparisonKey`, `courseId`, `durationMs`, `kidCadencePercent`, `status`, `scoreUnits`, `updatedMs`, and any saved `difficulty`, `referencePower`, `scoreScale`, `envelopeVersion`, `laneBands`.

The DAO selects the latest and winning attempt IDs across all history, not just the latest 50. Android parses the associated snapshots one at a time on the existing IO worker. Desktop derives equivalent summaries before stripping heavy data. Summaries contain no full course, event list or ghost array. The existing owner-bound `get` action fetches only the chosen full trace for play. No table or migration changes are required.

## Preview and lifecycle

- **PREVIOUS BEST:** completed compatible score, grouped as whole points.
- **SCORE TO BEAT:** that displayed score plus one point.
- No completed benchmark: **Set your first high score** and a note about saving the motorcycle ghost on completion.
- Ghost disabled: **Ghost is off in Settings**.
- Best has no recording: an explicit missing-recording message; no synthetic replacement.
- Async prepare loads any replay snapshot, then summaries and the selected ghost. `Game.intro_ready()` holds the countdown while storage is pending. The independent game clock and pending attempt still start through the existing save/start flow.
- The visual uses the shared Lane Smash theme and fixed 1120 × 174 logical-pixel space. Short two-line instructions preserve room for the countdown. Score-card text has bounded width and ellipsis for unusually large values.
- Storage failures use the existing error/retry flow. No manual Pause control is introduced.

## Ghost presentation

The existing motorcycle hologram, 100 ms trace, distance/lane interpolation and cadence animation remain. Before the first stored sample, no motorcycle is drawn.

Overlap alpha is the greater of longitudinal clearance (1.4–4.5 rules-metres) and lateral clearance (0.15–0.65 lanes). This hides a true overlap while retaining the ghost in a neighboring lane. Existing near/far/portal fades remain: the model is bounded to −5 to +85 rules-metres, with the distance/points HUD still available out of view. HUD values retain their one-second update interval.

## Validation

- **17 Godot cases passed:** six benchmark regressions, ten durable-record regressions, and the current registered game's intro layout test at both countdown sizes.
- **14 Android `NeonRecordsTest` cases passed:** includes real Room queries and cross-version summary identity beyond the 50-entry history limit, profile isolation, lightweight responses and full ghost retrieval.
- Native GL Compatibility capture exercises the real menu → prepare → intro path with an isolated synthetic **Iron Horizon / Hard** course-12 record. It loads all **12,000** stored ghost samples, shows previous best **154,321** / goal **154,322**, verifies the countdown does not advance while loading, checks intro bounds, and checks nearby/alongside/overlapping/far-ahead/far-behind model visibility. These numbers are test data, not the rider's score.
- Menu, preview and nearby/alongside ghost screenshots were visually inspected at 1280 × 720. The capture uses separate history/settings and does not modify personal records.
- Android lint passed with **0 errors / 79 existing warnings**. Final Godot import, whitespace and changed-document link checks passed. Logs and captures are stored outside the repository under `work/revision25-*`.

The final native capture passed every assertion and exited with code 0, then emitted shutdown diagnostics for four remaining ObjectDB instances/two resources. No in-session script error was logged. The headless test run reported zero orphans. This capture-exit diagnostic has not been established as a physical-device runtime leak; no claim of physical ride stability is made by this visual test.

The initial broader framework run also encountered obsolete tests that require the removed `demo`/`kart_race` registrations (`intro_touch_test` / one `intro_card_countdown_test` case). They were not changed or counted in the passing set; the active Lane Smash layout and native lifecycle were checked directly instead. An initial benchmark test exposed JSON float-versus-int nested-array comparison, fixed with numeric lane-band comparisons before the passing run.

## Release state and limits

Signed build 33 is installed and startup/sensor connectivity were verified as recorded below. No physical ride was started for verification. A completed recording must exist in its saved data, and **Best-ride ghost** must be On. No code change can reconstruct a deleted or never-completed ride. Changing point units, lane bands or Kid cadence mode intentionally keeps incompatible benchmarks separate.


## Build and installation

Signed and installed November 20, 2026 at the owner's request. The existing `neonReal` pipeline packages source `223509f` plus the Android version bump: code **33**, version **1.2.0-lane-smash.25**. Package `dev.digitalducktape.openride.neon` remains ARM64, non-debuggable, real-sensor enabled, minimum API 29 / target 34. Graphics default remains Auto; course 13 / generator 10 / scoring 12 / envelope 1 are unchanged.

- `assembleNeonReal`, `lintNeonReal` and **18 Android tests** (14 records + 4 settings) passed. Lint: 0 errors / 79 existing warnings.
- APK v2 signature verified. Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`, matching earlier installed releases.
- Artifact `openride-neon-33.apk`: **204,218,333 bytes**. SHA-256: `6d2eec06e7b6f045211c27e250d79c57b33033f8cc25fbc24341464fb4f545d7`.
- Embedded `assets/games.pck` is uncompressed and byte-for-byte equal to the fresh export. PCK SHA-256: `45738a1944bf5955d64112732b3c94223389cdb0b7c7d65facb9785e4df87526`.
- An independent run loaded the extracted APK pack and verified an old-version ghost benchmark, its one-point-higher target, countdown loading gate, Auto graphics and the retained course/scoring/gap-mine constants. The first verification command used incorrect relative paths; the corrected absolute-path command passed against the extracted pack.

The Original Bike was at the selector before packaging and immediately before installation. The laptop's ADB server restarted during the build/checks; reconnecting to the already-authorized Wi-Fi device succeeded. `adb install -r` returned **Success**. Android reports code **33** / `1.2.0-lane-smash.25`; its package user ID and original first-install timestamp are unchanged. No uninstall, data clear, launcher change or active-ride interruption occurred.

Cold launch returned **Status: ok**. The selector rendered, showed **Bike connected · ready**, and displayed existing saved scores, including a completed prior record. The captured application startup log contained no FATAL EXCEPTION, SCRIPT ERROR or ERROR: entries. Screenshots/logs and the APK remain outside the repository; private connection details and personal score values are not committed.

This verifies installation, startup, sensor connectivity and visible record retention. It does not constitute a new physical endurance ride or direct inspection of the device's private database/ghost arrays. The previous source tests and packaged-code check establish ghost selection behavior; the actual motorcycle replay will appear when the rider starts the matching course with Best-ride ghost On.
