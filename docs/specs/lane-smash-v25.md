# Revision 25 — pre-ride score targets and persistent ghosts

Date: November 19, 2026. Source change only. Build 32 / revision 24 remains installed on the Peloton.

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

The initial broader framework run also encountered obsolete tests that require the removed `demo`/`kart_race` registrations (`intro_touch_test` / one `intro_card_countdown_test` case). They were not changed or counted in the passing set; the active Lane Smash layout and native lifecycle were checked directly instead. An initial benchmark test exposed JSON float-versus-int nested-array comparison, fixed with numeric lane-band comparisons before the passing run.

## Release state and limits

No Peloton installation, signing/version bump or physical ride was performed for revision 25. Build 32 remains on the device. A completed recording must exist in its saved data, and **Best-ride ghost** must be On. No code change can reconstruct a deleted or never-completed ride. Changing point units, lane bands or Kid cadence mode intentionally keeps incompatible benchmarks separate.
