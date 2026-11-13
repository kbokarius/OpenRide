# NEON VECTOR — revision 2 validation

Date: 2026-11-13. Branch: `feat/neon-vector`. Implementation follows [the revision specification](neon-vector-v2.md). Earlier storage, bridge and migration evidence is in [revision 1 validation](neon-vector-validation.md).

## Result

The current desktop preview and Android package contain the curved 3D road, raised course objects, fades, denser scoring, integrated-energy bursts, original optional music and hidden app-owned scrollbars. Local checks cover the new rules and the existing record/lifecycle behavior. Physical Bike sensor compatibility and sustained tablet performance are still unverified; these results do not establish that every possible defect has been eliminated.

## Automated checks

| Check | Result |
| --- | --- |
| Android unit/integration suite | 985 tests in 114 suites; zero failures, errors or skips |
| Focused Godot rules/course/storage/UI regression | 56 cases passed; process exit 0 |
| Full Godot regression | 1,124 cases: 1,123 passed and one graphics assertion failed under the dummy headless renderer; corrected and rechecked as described below |
| Final layout and 3D checks | 18 cases passed; process exit 0 |
| Full-course simulations | 156 rides, 49 simulated hours; deterministic scores across four tiers and 30/60/120 fps |
| Play lifecycle harness | 21 checks passed with a rendered window; expanded headless run passed 24 checks, including music/mute/unmute |
| Builds | Mock Android and signed real-sensor ARM64 APKs built successfully |
| Patch whitespace | `git diff --check` passed |

The simulation covers all ten authored courses and three daily courses, including a year boundary. Unit checks also validate 365 daily courses, transition reachability, deterministic generation, and preserved recovery lanes. New rule cases check continuous standard points, inclusive cadence endpoints, output-proportional burst scoring, uncapped burst points, capped star credit and old scoring identities. Existing input freshness, pause, save recovery, rider isolation and exclusive-branch cases remain covered.

The full-run failure was a test assumption: Godot's dummy rendering server returns white instead of stored MultiMesh instance colors. The test now checks opacity only with an actual renderer while retaining geometry assertions headlessly. The corrected test passed independently and in the final 18-case run. A separate real OpenGL check confirmed an arrow's opacity decreased from 0.6885 to 0.5 over 100 ms, while its absolute position changed only by its small hover animation as the camera moved 1.8 m. This verifies that arrows pass the rider instead of staying fixed at section entry.

The expanded play harness initially referenced an autoload-dependent helper before autoload initialization; deferring the helper load fixed that test setup error. Its final run passed all 24 assertions.

## Packaged Android verification

Device: dedicated Android 11/API 30 ARM64 emulator, 1920×1080, 160 dpi, host GPU, 4 GB RAM. All records belong to the synthetic `NEON_QA` rider.

- Updated both mock and signed real-sensor packages in place using the same package/signature. Existing history remained visible.
- Swiped through Style & history to the saved ride list with no visible scrollbar. Setup, power, cosmetics, circuit builder and summary overflow behavior also have layout checks.
- Replayed an existing revision-1 completed attempt. The original pickup rules, stored course and ghost remained available after the update.
- Started the new revision-2 practice course through the real Kotlin–Godot bridge, with course time and scoring advancing from synthetic sensor readings.
- Tested a cold shader cache. An initial experiment exposed first-use shader compilation during gameplay, which correctly triggered the protective stall pause. All required material variants are now exercised during the intro. The final cold-start run spent 6.513 seconds compiling during INTRO, then entered PLAYING at approximately 60 fps without that protective pause. This initial wait depends on the GPU and cache state.

Installing the real-sensor APK on an emulator verifies packaging and signature compatibility, not physical sensor operation. The mock app supplies the test sensor stream.

## Visual, audio and performance review

Reviewed the actual desktop game, setup and shared screens, plus native Android setup, history and gameplay. The six lane labels retain padding below the crossing line as the road climbs and banks. Raised gold bars, mint cadence arrows and violet crystals have different silhouettes as well as colors. Objects remain anchored to the course; scenery recycles beyond view with opacity transitions. The shared OpenRide font, buttons, pause controls and summary style remain in use.

All four cosmetic palettes were rendered at 1920×1080. Short samples on an Apple M4 Max recorded median frame intervals of 16.66–16.69 ms and p95 intervals of 23.72–27.12 ms, with 102–103 draw calls and 61.2–61.6 MiB of Godot-reported static memory. Other local checks and an emulator were active; these are neither isolated nor sustained benchmarks, and they do not predict Bike performance. World captures use a demonstrative ghost; the play test separately loads a ghost from a completed record.

The soundtrack is an original 138 bpm composition generated from oscillators/noise, with no third-party samples. The decoded Ogg measures approximately −1.2 dB peak and −15.2 dB mean; no clipping was detected. Music/mute/unmute checks pass through the shared audio director. Every scoring requirement remains visible when muted.

## Known test-runner limitation

The full headless GdUnit process still exits 134 with a resource-disposal SIGSEGV after its report. The same shutdown crash was reproduced on the unchanged parent before NEON implementation (1,095 passing cases); see the revision-1 report. Focused runs exit 0 but retain existing ObjectDB/resource shutdown warnings. No corresponding native crash was observed in packaged gameplay. These limitations are not reported as a clean full-suite process exit.

## Build identity

| Field | Value |
| --- | --- |
| App label | NEON VECTOR |
| Package | `dev.digitalducktape.openride.neon` |
| Version | `1.2.0-neon-vector.2`, version code 10 |
| Requirements | Android 10/API 29 or newer; ARM64 |
| APK | `openride-neon-10.apk` |
| APK SHA-256 | `a9fc0c8d94650dcad320b7aa697aca9aff7ab558e50c4939d4b18ba3ec0ae28e` |
| Signing certificate SHA-256 | `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773` |

`apksigner verify --print-certs` passed. Manifest inspection confirmed the version, ARM64 ABI and minimum SDK. Signing material is stored outside the repository and is not included in deliverables. No release has been published; use the supplied APK for installation.

## Reproduction and remaining hardware checks

Use the build/test commands in [revision 1 validation](neon-vector-validation.md#reproducing-the-checks) with Godot 4.7.2. For current world captures use `--time=202`. The rendered space test is `tests/unit/neon_vector_space_test.gd`; run without `--headless` to exercise GPU instance-color readback. The current play harness adds music toggling to the earlier lifecycle checks.

On the user's original Bike, first confirm tablet model, Android version and ARM64 support. Then verify live resistance/cadence/power, complete practice and a 30-minute ride, test pause/resume and history, and export a backup. See [installation instructions](../NEON_VECTOR.md#installing-the-fork-on-the-bike). The fork has not been installed on the user's physical Bike.
