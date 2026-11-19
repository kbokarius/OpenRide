# Revision 24 — bombs between sections

November 18, 2026. Requested change after build 31: discourage easy-lane detours between sections while allowing time to adjust resistance. **Signed build 32 / 1.2.0-lane-smash.24 is installed on the Peloton.**

## Placement and adjustment

All named tracks and seeded random tracks use the same deterministic schedule. The existing section mines are retained. New gap rows follow the track's previous and next target lanes; they never follow the rider into a different lane.

| Parameter | Value |
| --- | --- |
| First gap row | Previous section end +1,000 road-ms |
| Row interval | 3,000 road-ms |
| Last gap row | No later than next section start −500 road-ms |
| Same-lane gap | Five mines in every non-target lane; the ordinary two-second gap has a row at its midpoint |
| One-lane change allowance | 4,000 road-ms |
| Two-lane change allowance | 5,000 road-ms |
| Three-lane change allowance | 6,000 road-ms |
| Clear lanes during allowance | Previous lane, next target, and every lane between them |
| Clear lane after allowance | Next target; the first row at or after the deadline closes the other lanes |
| Initial approach | No mines before the first section |
| Incoming Fire / cooldown | Road mines suppressed as before |
| Penalty / feedback | Existing up-to-1,800-point loss, zero floor, explosion, negative popup and sound; no avoidance reward |

These are minimum real-time allowances at 140 rpm, the speed cap; slower riding takes longer to cover the same distance. Row spacing can provide additional time: in a nine-road-second approach, rows fall at +1/+4/+7; a three-lane corridor remains clear at +1/+4 and closes at +7. The target remains clear throughout. Existing 6/7.5/9-road-second section approach budgets and section lengths are unchanged.

## Implementation and compatibility

`LaneSmashHazards.generate_guarded` wraps the existing section schedule with gap rows. `NeonCourse` enables gap validation only for course 13 and newer; placement in a target lane or protected adjustment corridor is invalid. The existing 4,096-hazard bound and 40-instance mine renderer are unchanged. No new per-frame queries, scene nodes, materials or audio behavior are introduced.

After Incoming Fire, rules already reflow the next full sections. The new schedule uses the actual attack exit lane and road position (rounded upward to the 10-ms grid) as the first gap's starting context. Existing resolved states remain and regenerated IDs include the attack-return index. The same runtime array drives collision and rendering. The original saved course snapshot is never rewritten.

Chosen pattern: deterministic placement from authored lane transitions, reusing the existing mine pool and rules feedback. Rider-following placement was rejected because it could close a legitimate crossing path or make a replay depend on rendering behavior.

New source uses **course 13 / generator 10 / scoring 12 / envelope 1**. Course 12 maps explicitly to scoring 11 and retains mine-free approaches, including after attacks; older versions keep their existing behavior. New hazards change the course fingerprint and best/ghost comparison key. Historical scores and ghosts remain readable. Kotlin and Godot records accept scoring versions 1–12. No database or bridge-envelope migration is required. Resistance, cadence, scoring amounts and burst weighting are unchanged.

## Verification

- **89 Godot cases across ten suites and 17 Android records/settings tests passed.** This includes the focused rerun after correcting a penalty test's starting score so it tests the full penalty rather than the zero-score floor. No implementation change was needed for that test correction.
- Nine new gap-mine cases cover one/two/three-lane allowances, both crossing directions, slower speeds including 35 rpm, same-lane detours, lingering in the old lane, invalid placements, first-approach clearance, attack returns, old-course replay identity and cooldown suppression.
- Gap placement and the 17.5-road-second rendering window fit the existing 40-instance pool for all 100 named tracks and 16 seeded tracks. The section/layout suite also covers 128 additional seeded course generations.
- Full-ride audit: **116 complete rides / 36.25 simulated hours**, four speed traces, all six difficulty mappings, 2,726 guidance changes and 837,230 cadence checks; **zero failures and no target-following road-mine hits**. Existing section completion, lane-jump, cadence/gunfire consistency and ride-end checks remain enabled.
- Native Compatibility-renderer capture of Nightfall's between-section approach confirms an open crossing corridor, visible red mines in unrelated lanes and continuous target highlighting. No script/shader errors. Capture history/settings are isolated from personal rides.
- Android records/settings tests pass, including acceptance of scoring 12, rejection of unknown scoring 13 and older record compatibility.

Local simulated and renderer checks do not establish performance during a physical Peloton ride. The installation checks below confirm startup and sensor connectivity.


## Build and installation

Signed and installed November 18, 2026 at the owner's request. The existing `neonReal` Gradle pipeline packages source `d5e64a8` plus the Android version bump: code **32**, version **1.2.0-lane-smash.24**. Package `dev.digitalducktape.openride.neon` remains ARM64, non-debuggable, real-sensor enabled, minimum Android 10 / target API 34. Auto remains the graphics default.

- `assembleNeonReal`, `lintNeonReal` and **17 real-build records/settings tests** passed; lint has zero errors and 79 existing warnings.
- APK signature verifies with v2. Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`, matching earlier installed builds.
- Artifact: `openride-neon-32.apk`, **204,207,861 bytes**. SHA-256: `1f985deeda7e535946976c2990c4f4c3f0c05759a6b75d47b58ba921016da56d`.
- Embedded `assets/games.pck` is uncompressed and matches the exported pack byte-for-byte. Independent loading verifies course 13 / generator 10 / scoring 12, valid gap hazards, the three-lane 6,000-road-ms allowance, faster steering, half-cadence Kid targets and Auto graphics.

The verified Original Bike was showing a completed ride before installation. Its screen slept during packaging; waking it confirmed the same completed result, so no active ride was interrupted. Wi-Fi `adb install -r` returned **Success**. Android reports code **32** / `1.2.0-lane-smash.24`; the package user ID and first-install timestamp are unchanged. No uninstall, data clear or launcher change was performed.

Cold launch returned **Status: ok**. After loading, the animated selector showed **Bike connected · ready**, with Nightfall, 20 minutes and Challenging selected. No ride was started. The inspected process log after the menu loaded contains no fatal exception or script error; existing vendor/engine warnings remain.

This verifies installation, initial rendering and sensor connectivity, not sustained riding performance. App storage is preserved by the in-place update; historical ride lists and every saved preference were not individually re-inspected. New-layout last/best/ghost comparisons are intentionally separate from previous layouts, as described above.
