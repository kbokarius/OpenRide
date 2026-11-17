# Lane Smash — Kid difficulty

November 15, 2026. Source follow-up after revision 19 and the superbike rear tyre. Not included in the previously prepared APK 27; no new installation is part of this change.

**Later release:** shipped in signed [revision 20 / APK 28](lane-smash-v20.md), installed over Wi-Fi on the Bike on November 15, 2026.

**Cadence follow-up:** [revision 22](lane-smash-v22.md) halves Pedal Speed requirements for new Kid rides. The resistance-only scope below describes the original implementation.

## Requested behavior and exact ranges

Add a very easy resistance option starting at the beginning of the sensor scale, with each lane increasing by half the ordinary amount. The native bridge passes Peloton's integer resistance on a 0–100 scale, so Kid starts at **0**. It uses a **3.5-point step**, half the existing seven-point step.

| Lane | Inclusive resistance values |
| --- | --- |
| 1 | 0–3 |
| 2 | 4–6 |
| 3 | 7–10 |
| 4 | 11–13 |
| 5 | 14–17 |
| 6 | 18–20 |

Whole-number readings yield alternating four- and three-value bands; nothing is skipped or counted twice. For player-facing lane `n`, the lower limit is `ceil((n−1) × 3.5)` and the upper is `ceil(n × 3.5) − 1`. Fractional/nonfinite readings and values outside 0–20 cannot earn lane points. New lanes still settle for 150 ms.

Kid is a Lane Smash addition, not a claimed sixth Peloton difficulty. Light, Moderate, Hard, Challenging, Extreme and all historical replay mappings remain unchanged. Challenging stays the default.

## Scope and UI

Kid changes the resistance bands only. It retains the selected course, lane progression, cadence ranges, power targets, bombs, score scale, star calculation and timed cooldown. The app reads resistance and never turns the physical knob. Kid scores and ghosts compare only with Kid rides on the same course and other existing comparison-key fields.

The existing Resistance selector has two rows of three buttons: **Kid / Light / Moderate**, then **Hard / Challenging / Extreme**. Selecting Kid displays **0–20 ACROSS SIX LANES**; the ride dock shows each range above. Buttons retain the same style, 34 px font, 120 px minimum height and 24 px spacing. Restyling now preserves explicit font-size overrides: briefly growing the Challenging label to the generic button font had forced its control wider than the row allocation even after restoring the smaller font.

## Implementation

The existing difficulty model is extended with the `kid` key. A separate game mode or duplicated rules engine would make steering and penalties disagree, so all consumers share `NeonRules.lane_step`, `band`, `lane_for` and `clamped_lane_for`.

- `lane_for` validates scoring eligibility; `clamped_lane_for` places visuals and rapid strikes at the nearest road lane even when resistance is out of range.
- The steering fraction uses each actual band's endpoints, so the motorcycle moves across the full interior of even a three-value band before its eased threshold shift.
- Setup range labels, ride title, out-of-range instructions and scenery normalization use those endpoints instead of the old fixed 41-point span.
- Wrong-lane incoming bombs use the same mapping. A Kid reading of 18 belongs to lane 6, not lane 3 as the former divide-by-seven expression would have placed it.
- `band_center` gives demonstrations/audits a valid integer reading; adding three to a narrower band's minimum could accidentally select its neighbor.
- Native `NeonSettings` accepts and round-trips `kid` through the Android request bridge. Existing storage saves the difficulty field and comparison key unchanged; no Room/Drizzle migration is needed.
- Course 11 / generator 8 / scoring 10 / envelope 1 remain unchanged. Existing adult scores and ghosts do not reset because their content, difficulty keys and rules did not change.

## Verification

Focused checks cover every Kid integer boundary and invalid readings, zero resistance, lane settling, steering at 30/60/120 fps, mines in each wrong lane, clear target-lane scoring, normal versus rapid incoming shots, out-of-range copy, native request parsing and isolated saved history/ghosts. Adult and historical bands are checked alongside Kid.

The complete track audit passed: **116 tracks, 36.25 simulated hours, four additional speed traces and all six difficulty mappings**. It includes full Kid rides, all section types, target guidance, lane-change limits, cooldown, scoring and ghost bounds. Existing menu, settings, audio and ride-HUD layout checks are also included. Final verification: **84 Godot test cases across nine suites**, with zero assertion failures/errors or reported test orphans; **17 Android tests** (four settings/bridge tests and thirteen record tests), all passed. The combined Godot run reported retained ObjectDB/resources during process shutdown after the successful test summary; no script errors occurred during the Kid riding capture. This desktop check does not establish sustained tablet performance.

The native menu capture shows Kid selected, 0–20 across six lanes, and six buttons with correct spacing. The riding capture shows resistance 1 in lane 1, all six Kid ranges in the dock, the target lane clear of mines, and the widened rear tyre. The existing settings/audio/HUD layouts were checked alongside the selector. The source documentation's relative file and section links were verified.

See [current parameters](../lane-smash/PARAMETERS.md) for the complete accumulated tuning reference and [revision 19](lane-smash-v19.md) for the preceding ride-flow/bomb changes. This update also reconciles stale player-guide descriptions of cadence bands, bomb target lanes, score-counter animation and version identities. Source, built APK and last verified device installation are tracked separately; the documented APK 27 checksum is not claimed to include these later source changes.

## Repeat the checks

Run from the repository root with Godot 4.7.2 available as `godot`:

```sh
godot --headless --path games -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit/lane_smash_kid_test.gd -a res://tests/unit/lane_smash_steering_test.gd -a res://tests/unit/lane_smash_catalog_test.gd -a res://tests/unit/neon_vector_rules_test.gd -a res://tests/unit/neon_vector_records_test.gd -a res://tests/unit/lane_smash_menu_layout_test.gd -a res://tests/unit/lane_smash_workout_test.gd -a res://tests/unit/lane_smash_hud_test.gd -a res://tests/unit/lane_smash_audio_test.gd
godot --headless --path games -s res://tests/audit_lane_smash_tracks.gd
./gradlew :app:testNeonRealUnitTest --tests 'dev.digitalducktape.openride.games.bridge.NeonSettingsTest' --tests 'dev.digitalducktape.openride.games.bridge.NeonRecordsTest'
```

These checks use isolated test state and simulated sensor traces. No device install, saved-rider-data migration, signing-key change or release publication is performed.
