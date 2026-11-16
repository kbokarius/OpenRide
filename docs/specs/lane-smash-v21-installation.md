# Revision 21 — signed build 29 and Peloton installation

November 16, 2026. This release packages gameplay source `6a5572c` with version `1.2.0-lane-smash.21`, Android code **29**. The owner requested installation after the source-only revision-21 review. The proposed player-shooting/enemy sections were canceled and are not included.

## Included changes

- Beside-bike bomb meter: green pass zone, red blast zone and dark slate no-points zone.
- Committed lane approaches, complete sections before attack/cooldown handoffs, and synchronized cadence cues, gauge and gunner.
- Muted warning on nearby interior lane boundaries.
- Speed-weighted Power Burst rewards: a complete section at twice the cadence earns approximately twice the points at equal measured watts.
- Course 12 / generator 9 / scoring 11; earlier history remains readable, with separate new-layout best/ghost comparisons. See the [implementation and validation record](lane-smash-v21.md).

## Build verification

The existing Gradle `neonReal` pipeline exports the Godot pack and signs an ARM64 APK with the established private release key. Package `dev.digitalducktape.openride.neon`, real bike sensors enabled, non-debuggable, minimum Android API 29 / target 34. Godot editor and embedded engine are both 4.7.2. Auto remains the graphics default; resistance mappings and stored settings are unchanged.

- `assembleNeonReal`, `lintNeonReal`, and the real-build record/settings tests passed: **17 tests, zero failures; lint zero errors and 79 existing warnings**.
- Prior source validation: **118 Godot tests and 144 complete simulated rides / 45 hours**, plus four speed traces. No gameplay code changed for packaging.
- APK signature verified using v2. Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`, matching previous installed releases.
- The uncompressed `assets/games.pck` matches the exported pack by SHA-256. Independently loading the embedded pack confirms course 12, generator 9, scoring 11, the 1,200 ms cadence preview, speed-weighted burst ticks, Auto graphics, Kid endpoints, and the wider rear tyre. The tick-ratio check allows the documented integer rounding.
- Artifact: `openride-neon-29.apk`, **204,206,169 bytes**.
- APK SHA-256: `83f0d625cd115e41d2a9e2eecdc61246d7d94c79a344716a669a4b74f209f4c6`.

## Device verification

The connected target was verified as the owner's Original Bike tablet, PLTN-RB1VQ / Android 11, with build 28 installed. Before installation its screen showed a saved, ended ride; no active ride was interrupted. Network addresses and signing credentials are not stored in this record.

`adb install -r` over the existing Wi-Fi connection returned **Success**. Android now reports code **29** / `1.2.0-lane-smash.21`; the package user ID and original first-install timestamp are unchanged. No uninstall or data clear was performed.

Cold launch returned **Status: ok**. After initial loading, GameHostActivity displayed the animated track selector with **Bike connected · ready**, Nightfall, 20 minutes and Challenging selected. The existing soundtrack was playing. No ride was started for this installation. Lawnchair remains the default HOME app, preserving the Lane Smash/Peloton choice.

The inspected startup log contains no fatal exception or script error. Existing platform/engine warnings remain, including an initial null legacy sensor binding, the XR setting warning and Vulkan capability check before OpenGL ES 3.0; the final screen confirms that the sensor fallback connected. This verifies installation, menu rendering and sensor connectivity, not sustained riding performance or thermals.

Use the [Wi-Fi update workflow](lane-smash-v20.md#repeating-a-wi-fi-update) for subsequent releases, with the current endpoint and newer signed APK.
