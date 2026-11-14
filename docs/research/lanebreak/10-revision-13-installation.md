# Revision 13 installed on the Original Bike

Verified November 13, 2026. This is an installation follow-up to the revision 13 implementation and desktop validation, not a physical ride test.

## Build provenance

- Built the latest local revision 13 source, including uncommitted changes above `e4c07da`, in a separate filesystem snapshot so concurrent validation could not change the build's inputs. No production-source drift was found before or after installation; only the separate soak test changed afterwards.
- Built signed `neonReal`: package `dev.digitalducktape.openride.neon`, version **1.2.0-lane-smash.13**, code **21**, ARM64 only, real bike sensors enabled, non-debuggable, minimum Android 10.
- Exported a fresh Godot game pack with Godot 4.7.2. Verified that its SHA-256 matched the pack embedded in the APK.
- Installer: `openride-neon-21.apk`, **204,181,153 bytes**.
- APK SHA-256: `0c80599890b6b50909aee4d88146f0fb042808b35b5e916f0a01b08587e5ce94`.
- Signing-certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`, unchanged from the installed version.
- A local source-input manifest was retained with the build snapshot. Its SHA-256 is `fdf674197f914eb58bf9ac0b4b710d805c09bcbbecc5da1b341647094fc38d1b`.

## Build checks and one fix

The initial full release lint check failed on a literal invisible byte-order-mark character inside `WorkoutHistoryCsv.parse`. Replaced it with the equivalent Kotlin `\uFEFF` escape in both the source repository and build snapshot; runtime behavior is unchanged. The final `assembleNeonReal`, `lintNeonReal` and the ten existing `WorkoutHistoryCsvTest` cases passed. Lint still reports 79 warnings.

Reviewed existing revision 13 validation output: 180 relevant Godot tests across 19 suites, 995 Android tests, 54 lifecycle checks, and 116 tracks / 36.25 simulated hours passed. The ten-cycle soak reported no failures and 804 nodes at its end. The lifecycle and soak processes reported resource cleanup warnings at shutdown. Two legacy hub suites still target the removed OpenRide HomeScreen and fail; these are not evidence that all repository tests passed.

## Physical update and launch

- Original Bike tablet: PLTN-RB1VQ, Android 11 / RQ.260424.A.
- Updated the existing app using `adb install -r`; result **Success**. No uninstall or data clear. The package retained its original first-install timestamp, and now reports code 21 / revision 13.
- Cold-started MainActivity successfully, then observed the persistent GameHostActivity in the foreground.
- The physical screenshot showed the revision 13 selector and **Bike connected · ready**. The app process remained alive during subsequent inspection.
- OpenGL ES 3.0 initialized. The inspected app log had no fatal exception; it retained the previously observed vendor/linker and `xr/shaders/enabled` startup warnings.
- The default HOME remained `app.lawnchair/.LawnchairLauncher`, preserving the Lane Smash/Peloton choice configured earlier. No launcher changes or reboot were needed for this update.
- Left the game on its selector. No ride was started for this installation.

## Data and remaining checks

Updating in place preserves app data. Revision 13 changes course/generator/scoring versions, so newly generated tracks have new personal-best/ghost identities; earlier saved rides remain under their original course rules.

Frame rate, the new cadence gauge and effects during a physical ride, long-frame recovery, and thermal stability remain unverified on this tablet. The successful launch and sensor-ready state do not establish those results.
