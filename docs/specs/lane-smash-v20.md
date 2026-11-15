# Lane Smash revision 20 — Kid difficulty and superbike tyre release

November 15, 2026. Signed version `1.2.0-lane-smash.20`, APK code **28**. Course 11 / generator 8 / scoring 10 / envelope 1 are unchanged.

## Included source

- Revision-19 full-length sections, shorter attack handoffs, constant target-lane guidance, paired cadence bands, immediate bomb-pass rewards, continuous score counters and dense off-lane mines.
- The wider rear tyre from `7b56a12`: four times the rubber width, fuller sidewalls, matching rim/axle and swingarm clearance, shared by rider and ghost.
- Kid difficulty and selector fix from `a13bcde`: resistance 0–20, a 3.5-point lane step, six correctly spaced difficulty buttons, shared mapping for steering/scoring/bombs, separate Kid records and ghosts.
- Updated structured architecture, rules, presentation, player guide and [parameter reference](../lane-smash/PARAMETERS.md).

Adult resistance ranges, the internal 150 W reference, stored ride data and package/signing identity are unchanged. Graphics remains **Auto** by default. This release packages the reviewed source; it introduces no further gameplay changes.

## Build and verification

The existing Gradle `neonReal` pipeline exports the Godot pack and signs an ARM64, non-debuggable APK with the established private release key. An in-place update preserves app storage; replacing the package or uninstalling is unnecessary.

- Godot 4.7.2 with matching embedded engine; Android minimum SDK 29, target 34.
- Package: `dev.digitalducktape.openride.neon`; code 28 / `1.2.0-lane-smash.20`; real bike sensors enabled.
- All **17 Android settings/record tests** passed; lint: **0 errors, 79 existing warnings**.
- The prior source validation remains applicable: **84 Godot tests** and **116 full tracks / 36.25 simulated hours**, four speed traces and all six difficulty mappings. See [Kid validation](lane-smash-kid-mode.md).
- APK signature verified. Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`, matching prior installed releases.
- Embedded `assets/games.pck` matches the final exported pack. Loading that pack independently confirms course 11, generator 8, scoring 10, Auto graphics, 40-mine pool, Kid endpoints 0–3 / 18–20, and rear rubber width 0.64 design units.
- Artifact: `openride-neon-28.apk`, **204,198,345 bytes**. SHA-256: `40755b692283d5519e1eb244da3344d79b240cb7ba8436e6a426dab37d1711d1`.

## Wi-Fi installation

The owner enabled wireless debugging and requested installation from the laptop. Network discovery found the tablet; the laptop's existing authorization connected without a new pairing code or USB cable. The active ADB transport was Wi-Fi. The target identified as **PLTN-RB1VQ / Android 11** with revision 18/code 26 installed.

Before updating, the tablet was on its launcher; opening the existing app showed the selector and “Nothing to save,” with no active ride to interrupt. Update uses `adb -s <verified-wireless-device> install -r <signed-apk>`, preserving package data. Network addresses and pairing credentials are not stored in the repository.

The streamed Wi-Fi installation returned **Success**. Android reports code **28** / `1.2.0-lane-smash.20`; the package user ID and original first-install timestamp are unchanged, confirming an in-place update. No uninstall or data clear was performed.

Cold launch returned **Status: ok**. The physical tablet displayed all six difficulty buttons, including Kid, with Challenging selected and **Bike connected · ready**. The settings screen retained enabled music, sound effects and best-ride ghost, plus the selected soundtrack and playback position. A Nightfall ride subsequently opened during verification; further screen interaction was stopped. Its 3D road, wider rear tyre, target-lane guidance and live resistance value rendered successfully. No automated ride was intentionally started or ended.

The post-launch/ride log contained no `FATAL EXCEPTION`, `SCRIPT ERROR` or `ERROR:` entries. Startup still reports platform/engine warnings (including the absent XR setting, Vulkan capability check before OpenGL ES, and resource/profile warnings); this is not a warning-free log. Auto is verified as the packaged graphics default; the current saved graphics selection and full history list were not re-inspected after the ride opened. Existing history is preserved by the in-place update, while the changed course/scoring identity intentionally separates new last/best comparisons from older rides.

This confirms Wi-Fi installation, startup and initial rendering/sensor connectivity, not a completed ride or sustained thermal/performance test.

## Repeating a Wi-Fi update

1. Keep the laptop and Bike on the same local network, with wireless debugging enabled on the Bike.
2. Use `adb mdns services` and `adb devices -l` to find the advertised endpoint and confirm the authorized device. If needed, use `adb connect <ip:connection-port>`. A first-time Android 11 pairing instead uses `adb pair <ip:pairing-port>` with the code on the tablet, followed by the separate connection endpoint.
3. Verify the selected target's model and installed package before proceeding. Wait until no ride is active.
4. Build with the existing package/signing identity, then use `adb -s <verified-wireless-device> install -r <signed-apk>` and wait for **Success**.
5. Verify the installed version with `adb -s <verified-wireless-device> shell dumpsys package dev.digitalducktape.openride.neon`, then launch with `adb -s <verified-wireless-device> shell am start -W -n dev.digitalducktape.openride.neon/dev.digitalducktape.openride.MainActivity`.

OpenPelo's **Install local APK** is the GUI alternative once its target device is connected over Wi-Fi. Discovery/connection ports can change; use the currently advertised endpoint rather than saving a private address in these instructions. This installation reused existing authorization and required no new pairing code.
