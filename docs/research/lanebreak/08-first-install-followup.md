# First installation follow-up

Checked November 13, 2026.

## Owner hardware update

On November 13, 2026, the owner confirmed **Android 11, build RQ.260424.A**, on the Original Bike with a non-rotating screen. This meets the Android 10+ minimum. The exact tablet model and ABI have not yet been read from this unit; the signed build requires arm64-v8a.

[OpenRide issue #47](https://github.com/digitalducktape/OpenRide/issues/47) contains an October 23 report of upstream OpenRide installed through OpenPelo on a Gen 2 `PLTN-RB1VQ` tablet running this exact Android/build combination. That is supporting evidence for installation, not confirmation of this owner's model or a Lane Smash sensor/performance test. The issue's failure concerns enabling a HOME alias, not installing the APK.

The subsequent USB connection confirmed **PLTN-RB1VQ / RB1VQ**, Android 11, `RQ.260424.A`, and **arm64-v8a** directly from the tablet. USB debugging was already authorized. No reset or firmware update was needed.

## First physical installation — November 13, 2026

- Built current revision 12 from commit `561183e9ecc893062f2be5b65816ceef987054b7` using the existing signed `neonReal` configuration. Gradle build/lint completed successfully; verified ARM64, package/version, signing certificate and the APK's embedded game pack.
- Installer: `openride-neon-20.apk`, code **20**, version **1.2.0-lane-smash.12**, package `dev.digitalducktape.openride.neon`; 204,153,545 bytes.
- APK SHA-256: `b9f2e1d79babecdda2f886a3d4910868b5952a11778bc160428dd5adc785d5df`.
- Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773` (unchanged).
- No prior fork package was present. `adb install -r` returned **Success**. Starting MainActivity returned **Status: ok** and opened the persistent GameHostActivity.
- A physical-tablet screenshot showed the Lane Smash track selector, animated track previews and **Bike connected · ready**. This indicates fresh decoded sensor data, not just a successful service bind. Physical display: 1920×1080, density 240.
- The app remained running through the initial inspection. OpenGL ES 3.0 context initialized. The unused Bike+ binder returned null, which is expected on this model; readiness came through the original Bike sensor path. Startup logs also contained vendor/linker warnings and a Godot `xr/shaders/enabled` warning. No fatal exception was observed in the inspected application log.
- Live nonzero cadence/power, knob changes, 3D riding performance, completed-score persistence and sustained thermal stability are **not yet verified on this bike**. No ride was started as part of installation.
- No factory reset, firmware change, Peloton-package disabling, default-launcher change or app-data clearing was performed. The app was left open at its selector.

The user-facing installer and first-launch screenshot were saved in the task's outputs directory. Serial numbers and account data are intentionally absent from these public notes.

## Historical installer at the time of the initial follow-up

`outputs/openride-neon-14.apk`, version 1.2.0-lane-smash.6, package `dev.digitalducktape.openride.neon`, launch activity `dev.digitalducktape.openride.MainActivity`. The APK is signed and non-debuggable. Physical installation and live sensor performance are not yet tested.

## Verified installation controls

[OpenPelo's current documentation](https://github.com/doudar/Openpelo#connect-a-device) identifies USB authorization, Refresh Devices and Target Device. Install the fork through Install local APK, then use Tools → Installed App Manager → Launch. The catalog's OpenRide entry is upstream.

The [USB walkthrough](https://github.com/doudar/Openpelo/blob/main/usb_debug_steps.json) says to tap Build Number seven times and enable USB debugging, with a micro USB-B data cable for the original Bike. It also includes a firmware reset. That reset must not be prescribed as universally necessary for the unidentified tablet.

[OpenPelo v1.0.84](https://github.com/doudar/Openpelo/releases/tag/v1.0.84) remains the latest published release checked. It includes its own ADB connection tools.

## Daily launch limitation

Source and packaged manifest confirm that HomeLauncherAlias is disabled. Lane Smash removed the upstream Profile UI containing the enable control. Consequently this build can launch normally but does not currently offer direct automatic HOME startup. Do not tell the user to select Lane Smash as the default launcher or use debug-only run-as commands. OpenPelo can install Lawnchair and choose it as the default launcher; that supplies a home-screen app icon for Lane Smash. Enabling Lane Smash itself as HOME needs an app change or a verified device-specific procedure.

## First ride

The selector shows readiness, not the full live metrics. Check rpm, power and resistance after starting the test ride. Verify a completed score and best-ride ghost before daily use or changing the subscription.
