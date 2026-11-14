# Lane Smash revision 10 — validation

Validated locally November 13, 2026 using Godot 4.7.2, GL Compatibility and Apple M4 Max. The Original Bike has not been tested physically.

## Results

| Check | Result |
| --- | --- |
| Focused Godot tests | 118 unique tests across 14 suites passed; zero test errors, failures, skips or orphans |
| Android JVM/Robolectric | 993 passed; zero failures, errors or skips |
| Full catalog | 100 named + 16 seeded random tracks completed; 36.25 simulated riding hours, all with three stars and all incoming shots evaded |
| Bounds and difficulty | Four 30-minute speed traces; capped distance, bounded buffers and all five resistance tiers passed |
| Calibration | 25 named 20-minute Challenging tracks: mean 147,760.88, minimum 137,462, maximum 156,977 points |
| Actual application lifecycle | 53 checks passed: menu layouts, start, saved ghost, audio switches without pausing, sensor recovery, end and history |
| Repeated start/end | Ten cycles, exactly 766 nodes after each return to menu; no retained scene growth |
| Counter layout | Captions/panel dimensions stable through 0 / 9,999 / 10,000 / 99,999 / 150,000 / 1,500,000; power label stable through five digits |
| Counter timing | Monotonic ease-out and exact landing at 30/60/120 fps; retargeting and faster decreases passed |
| Exported PCK | Scoring v6, scale 18, two incoming hits; authoritative HUD decrease; new audio/counter resources present; all 13 other game scenes absent |
| Android installer | Signed code 18 build successful; same package/certificate, Android 10+ and ARM64 |
| Preview | 55.000 seconds, 1,650 frames, 1280×720 at 30 fps, H.264/AAC; full stream decoded successfully |

Focused suites: course, rules, input, records, space, catalog, path, barrage, audio, AudioDirector, point rollup, Lane Smash HUD, Effort and EffortMeter. Follow-up runs covered the final notice/visibility changes and shared-score fix. Tests use isolated settings/history.

## Scoring and storage

- Fast passing awards 1,800, safely staying behind awards zero, and hits remove up to 1,800 without going negative. Both safe outcomes earn star credit. Legacy v5 snapshots still award 100 for either safe dodge.
- Existing render-rate tests preserve identical targets, outcomes, scores and traces at 30/60/120 fps. The full catalog still passes lane-frequency, section coverage, duration, stars and distance checks.
- The 18× scale exposed a long-section integer intermediate overflow. New scoring uses a floating ratio before flooring to avoid that overflow; old scoring arithmetic is preserved. The long bomb fixture and entire catalog pass.
- A new regression reproduced an existing shared HUD issue: `Effort` rejected lower authoritative totals, leaving a pre-bomb score displayed. The test failed before the fix and passed afterward. The HUD now mirrors exact nonnegative net totals; animation never changes saved points.
- Record validators on desktop and Android accept scoring versions 1–6. New comparison identity uses course 7/scoring 6; historical scores are retained without rescaling. Room remains schema 9, with no migration.

The calibration is a simulated representative trace, not measured rider data: 90 rpm cruise, midpoint cadence targets, 110 rpm power sections, resistance-dependent simulated watts, 1.8 seconds of missed lane every 45 seconds and gradual attack responses. Different durations, power, cadence and accuracy produce different totals.

## Audio and interface

- Menu and live ride switches persist through reload and are shared across riders. Music and effects remain independent. Host volume refresh does not unmute an Off switch. Existing per-rider music migration preserves other preferences.
- Twenty immediate repeated contact events produced twenty playback events, with no repeat cooldown. Muted events produced none, and re-enabling restored the next sound.
- WAV one-shots are 0.095–0.52 seconds, with restrained peaks and attack/tail envelopes. A separate power loop fades in/out and responds to power/cadence. No runtime synthesis or per-contact player allocation.
- Real-renderer screenshots verified the settings page, in-ride Audio panel, standard HUD and Power Burst counter. Digit boundaries do not move captions/panels. Saving/recovery notices explicitly replace the power counter.
- The preview recorded 27 collect cues, 18 cadence cues, six ordinary completion cues and one power-finish cue. Its power bed is continuous. Final mix mean is −18.1 dBFS and peak −4.6 dBFS; no clipping was detected. Perceived comfort remains subjective.

## Stability and limits

Retained menu memory was 77.94 MiB after cycle two and 78.26 MiB after cycle ten (78.60 MiB maximum among those samples). Nodes remained exactly 766. Audio/counter additions are bounded; no scene accumulation was observed. This does not establish sustained tablet FPS or thermals.

Desktop harnesses still produce process-exit cleanup diagnostics: the main focused run reported 14 ObjectDB instances; the final lifecycle reported four; Movie Maker reported seven instances and one resource. These occurred at immediate shutdown, not as runtime script failures. They remain a limitation; this report does not claim zero warnings or guaranteed crash-free Peloton operation. No runtime script failure occurred in the final rendered preview or lifecycle.

## Code review

### Critical

No unresolved critical issue found in the reviewed change. Fixed the shared-total penalty rejection and new-scale integer overflow, with regression coverage.

### Improvements addressed

Use shared saved audio gates, bounded voices and one reusable power player; avoid repeat suppression. Reuse finite counter states rather than stacking tweens. Reserve number widths and use tabular digits. Reset power-counter visibility for interruption/saving notices. Restore in-memory preferences on save failure. Preserve legacy comparison/scoring identity.

### Positive

Rules remain authoritative and independent of presentation. Audio consumes logical signals; counters cannot affect saved scores or stars. Existing UI controls/styles are reused, and live settings never pause the ride. Reviewed against GodotPrompter code-review, audio, UI, tween and testing guidance.

## Preview

`Lane-Smash-score-and-audio-preview-v10.mp4` uses the actual renderer/HUD with deterministic simulated sensors and a completed simulated ghost. It demonstrates gold collection, cadence arrows, power-floor charging, eased counters and the new original audio. It is not a Peloton recording. The preview ends after the power section; Incoming Fire mechanics are covered by tests and the prior revision's separate demonstration.

| Approximate time | Event |
| --- | --- |
| 0:00–0:05 | Gold bars, total counting upward and section recap |
| 0:05–0:17 | Cadence arrows and contact notes |
| 0:44–0:52 | Power bed, accumulating counter and finish chord/explosion |

## Installer

- File: `openride-neon-18.apk`
- Package: `dev.digitalducktape.openride.neon`
- Version: code 18 / `1.2.0-lane-smash.10`
- Size: 65,153,045 bytes
- SHA-256: `d866dc0e3bfa3b0b3c05893ceaa7d3234ac12095680712b323a4034eb1a99a2f`
- Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`
- Real-sensor ARM64 build, minimum Android 10. Install over the existing fork without uninstalling or clearing data.

No installation on the Bike, database migration or GitHub release publication was performed. Use the [installation guide](../LANE_SMASH.md). The structured [living reference](../lane-smash/README.md) is the current architecture/rules/audio source.

## Reproduction

Run `addons/gdUnit4/bin/GdUnitCmdTool.gd` with `--headless --ignoreHeadlessMode -a res://tests/unit/<suite>.gd`. Use the audit, calibration, lifecycle and soak scripts in `games/tests/`. Android checks: `:app:testDebugUnitTest :app:assembleNeonReal`, with the existing private signing properties.

Movie Maker capture: `--resolution 1280x720 --fixed-fps 30 --write-movie <absolute-path>.avi -s res://tests/capture_lane_smash_sections.gd -- --movie --seconds=55 --out=<absolute-directory>`. Remove the initial 61 warm-up frames and encode H.264/AAC. Check both stream durations, frame count and full decode after export.
