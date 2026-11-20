# Ghost stopping before the finish — assessment

Date: November 20, 2026. Source and installed build: revision 25 / code 33 (`8cd1227`). Assessment only; no gameplay changes or installation.

## Report and conclusion

The rider saw the previous-best motorcycle stop roughly 30 seconds before the end, then passed it. The saved recordings explain this observation: the previous ride's distance stops increasing with **27.8 seconds remaining**, while the current ride continues moving until time expires. Comparing their distance samples places the overtake at **26.3 seconds remaining**.

This is a replay of recorded movement, not a prematurely exhausted ghost trace. A ghost races at the same **active elapsed time** as the current rider; it does not finish early merely because it travels farther. Both rides have the same comparison key and duration.

## Evidence and scope

- Read the app's existing automatic backup from shared Downloads storage over ADB. No ride, UI, private database, launcher, or app state was changed.
- The two relevant completed 15-minute rides each contain all **9,000** expected samples: 100 ms through 900,000 ms, with no missing intervals.
- The prior ride continues recording through the finish even though its final 27.8 seconds have unchanged distance. The current ride's final sample still advances.
- All seven completed rides in that backup have full 10 Hz coverage, and their final distance and score match the saved results.
- The route has 15,300 rules-metres available for a 15-minute ride, exceeding its theoretical 15,000-metre maximum. These recordings end well before the route limit, ruling out the path's endpoint clamp in this case.
- The ghost stores integrated distance rather than raw cadence. This proves what was recorded and replayed; it does not independently prove whether the rider physically stopped or the sensor reported zero cadence.

Raw backups, rider identifiers, scores and full ride traces remain outside the repository. The diagnostic comparison used existing records and did not write to them.

## Code path reviewed

| Component | Behavior |
| --- | --- |
| `NeonRules.advance()` | Runs fixed 10 ms steps and appends a ghost row every 100 ms, including the final tick of normal ride durations. |
| `NeonRules._tick()` | Integrates forward distance from reported cadence. Zero cadence stops distance but does not stop a distance-based ride's timer while fresh input continues. Cooldown changes sections, not this speed integration. |
| `NeonVector._record()` / `_complete()` | Saves the full trace for a completed ride; partial/pending records do not become best-ride ghosts. |
| `NeonBenchmark.select()` | Chooses the highest completed compatible score, with matching rider, course, duration and resistance settings. |
| `NeonVector._update_ghost()` | Interpolates recorded distance and lane using current active elapsed time. Constant recorded distance produces a stationary ghost and zero animation cadence between those samples. |
| `NeonSpace.update_view()` / `LaneSmashCoaster.at()` | Places the model at that recorded route distance, with proximity/portal fades. The available route length is sufficient here. |

## Separate hardening opportunities

These are code-review findings, not the cause established by the complete recordings above. They were unimplemented at assessment time; the subsequent [hardening follow-up](../specs/lane-smash-ghost-hardening.md) addresses them without changing the interpretation of those recordings.

1. **Incomplete traces can look like a stopped rider.** Both `NeonRecords.valid_record()` and Android `NeonRecords.decode()` require increasing timestamps within the result duration, but do not require a nonempty trace to reach the finish. If such a record is loaded, `_update_ghost()` holds its final position after the last sample indefinitely. Preserve the score/history, validate replay coverage separately, and explicitly mark/fade an unavailable tail rather than displaying it as a real stop. Do not invent extra movement.
2. **Animation cadence can remain stale at an exhausted trace.** `_update_ghost()` only updates cadence when a following sample exists. The endpoint path needs an explicit cadence/visibility state. Ordinary full recordings end with the current ride, so this matters chiefly for incomplete recordings.
3. **Coverage gap in tests.** Existing benchmark tests cover selection, loading and visibility but do not exercise an early trace endpoint. Add regression cases for a complete moving finish, a valid stationary final interval, and a truncated trace when implementing endpoint handling.

## Validation performed

Read-only Python checks on the copied backup verified full timestamp coverage, matching comparison keys, final result/trace agreement, the stationary interval, and the overtake time. Code inspection traced recording, completion, selection, playback, cooldown and route bounds. No new executable tests, game build, or device endurance run were performed for this assessment.
