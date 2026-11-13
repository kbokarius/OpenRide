# First installation follow-up

Checked November 13, 2026.

## Hardware still needed

The owner identified an Original Bike, but its exact tablet model, Android version and build number are still unknown. Requested those values before prescribing any reset or firmware-dependent workaround. The signed build requires Android 10+ and arm64-v8a.

## Verified installer

`outputs/openride-neon-14.apk`, version 1.2.0-lane-smash.6, package `dev.digitalducktape.openride.neon`, launch activity `dev.digitalducktape.openride.MainActivity`. The APK is signed and non-debuggable. Physical installation and live sensor performance are not yet tested.

## Verified installation controls

[OpenPelo's current documentation](https://github.com/doudar/Openpelo#connect-a-device) identifies USB authorization, Refresh Devices and Target Device. Install the fork through Install local APK, then use Tools → Installed App Manager → Launch. The catalog's OpenRide entry is upstream.

The [USB walkthrough](https://github.com/doudar/Openpelo/blob/main/usb_debug_steps.json) says to tap Build Number seven times and enable USB debugging, with a micro USB-B data cable for the original Bike. It also includes a firmware reset. That reset must not be prescribed as universally necessary for the unidentified tablet.

[OpenPelo v1.0.84](https://github.com/doudar/Openpelo/releases/tag/v1.0.84) remains the latest published release checked. It includes its own ADB connection tools.

## Daily launch limitation

Source and packaged manifest confirm that HomeLauncherAlias is disabled. Lane Smash removed the upstream Profile UI containing the enable control. Consequently this build can launch normally but does not currently offer direct automatic HOME startup. Do not tell the user to select Lane Smash as the default launcher or use debug-only run-as commands. OpenPelo can install Lawnchair and choose it as the default launcher; that supplies a home-screen app icon for Lane Smash. Enabling Lane Smash itself as HOME needs an app change or a verified device-specific procedure.

## First ride

The selector shows readiness, not the full live metrics. Check rpm, power and resistance after starting the test ride. Verify a completed score and best-ride ghost before daily use or changing the subscription.
