# First installation follow-up

Checked November 13, 2026.

## Owner hardware update

On November 13, 2026, the owner confirmed **Android 11, build RQ.260424.A**, on the Original Bike with a non-rotating screen. This meets the Android 10+ minimum. The exact tablet model and ABI have not yet been read from this unit; the signed build requires arm64-v8a.

[OpenRide issue #47](https://github.com/digitalducktape/OpenRide/issues/47) contains an October 23 report of upstream OpenRide installed through OpenPelo on a Gen 2 `PLTN-RB1VQ` tablet running this exact Android/build combination. That is supporting evidence for installation, not confirmation of this owner's model or a Lane Smash sensor/performance test. The issue's failure concerns enabling a HOME alias, not installing the APK.

Next: try the existing Build number seven-tap developer access, then enable USB debugging and authorize the Mac. If the control is absent or blocked, record what the tablet displays before recommending any reset. Once connected, read `ro.product.model` and `ro.product.cpu.abilist` to establish the remaining hardware details. No reset or firmware update is established as necessary.

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
