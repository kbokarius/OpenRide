# Revision 22 — half-cadence Kid mode

November 16, 2026. Requested change: halve Kid cadence requirements and install a new signed build. Package version is `1.2.0-lane-smash.22`, Android code **30**. Course 12 / generator 9 / scoring 11 / envelope 1 remain unchanged.

## Targets and scope

| Pedal Speed section | Adult target | New Kid target |
| --- | --- | --- |
| Warm-up | 75–95 rpm | **38–48 rpm** |
| Work lanes 1–2 | 85–105 rpm | **43–53 rpm** |
| Work lanes 3–4 | 70–90 rpm | **35–45 rpm** |
| Work lanes 5–6 | 55–75 rpm | **28–38 rpm** |

Both endpoints are multiplied by 0.5 and rounded to the nearest integer for the existing whole-rpm UI. The sweet spot stays midpoint ±3 rpm. Resistance bands, measured inputs, speed mapping, road geometry, section distances, Power Burst formula and Incoming Fire recommendations are unchanged. Lower cadence therefore means longer section/approach traversal; the chosen total ride duration remains fixed.

## Shared data and records

`NeonCourse.for_difficulty` copies a new Kid course, stores its adjusted hold endpoints and `kidCadencePercent: 50`, and is idempotent. The menu course, last/best lookup and `NeonVector` preparation all use it. Scoring, status, cadence gauge and gunfire then consume the same event data. A display-only change was rejected because it would disagree with scoring and damage. Named and seeded random courses use this same path.

Replays load their stored snapshot without adjustment. New Kid comparisons differ from old Kid comparisons; all adult and historical hashes stay unchanged. New Kid fingerprints canonicalize their JSON numeric representation, preventing an integer-to-float JSON round trip from changing a replay key. No Room or Drizzle migration is involved.

## Validation

- **52 Godot tests across seven suites passed**, zero failures/errors or test orphans. New assertions cover all 100 named tracks and 16 random seeds, exact bands, immutable adult input, no repeated halving, adult comparison stability, Kid JSON replay identity, scoring, gunfire, local gauge, top prompt and menu record keys.
- Native Compatibility-renderer capture exercises the lowered warm-up cadence with the actual meter and gunner. Capture data/history/preferences are isolated.
- The complete-ride audit now prepares Kid snapshots exactly like production. Its pace assertions allow twice the adult traversal time for half cadence; adult limits remain 60 seconds per lane visit and 22 seconds per approach. Spatial minimum lengths, lane-jump limits, section completeness, meter/gunner checks and empty-lane-visit checks remain unchanged. Warm-up classification follows the authored warm-up event IDs as well as distance, because an attack can shift the runtime approach. **Final audit: 116 complete rides / 36.25 simulated hours plus four speed traces; 2,726 lane changes and 837,230 active cadence checks; zero failures.** The half-cadence Kid Nightfall trace had a 38.15-second longest approach; adult Nightfall traces remained at 19.4 seconds.

## Build and installation

Signed build verified: `assembleNeonReal`, `lintNeonReal` and the 17 real-build settings/history tests passed. Lint reports zero errors and 79 existing warnings. The real-sensor ARM64 package remains `dev.digitalducktape.openride.neon`, non-debuggable, minimum Android 10. Auto graphics and the established signing identity are retained.

- Artifact: `openride-neon-30.apk`, **204,206,793 bytes**.
- SHA-256: `3f71ed99e04f1595021e9dd21791675b00ced16b3dff367ff1baba762be78779`.
- Signing certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`.
- Exported and embedded game packs match byte-for-byte. Loading the embedded pack independently verifies Kid warm-up 38–48 rpm, adult warm-up 75–95 rpm, stable new Kid JSON replay identity, course 12 / generator 9 / scoring 11, Auto graphics, original Kid resistance endpoints and the wider rear tyre.

The connected Bike was running code 29. With explicit owner approval, the open Solar Array Kid ride was ended using End Ride → End session; the result screen confirmed **Partial ride saved** before installation.

The in-place Wi-Fi `adb install -r` returned **Success**. Android reports code **30** / `1.2.0-lane-smash.22`; the package user ID and original first-install timestamp are unchanged. Cold launch returned **Status: ok**. No uninstall, data clear or launcher change was performed.

The updated selector rendered successfully and showed **Bike connected · ready**. Kid was selected for the next ride; no new ride was started. The inspected startup log had no fatal exception or script error. Existing vendor/engine startup warnings remain. This verifies installation, menu rendering and sensor connectivity, not sustained physical riding performance.
