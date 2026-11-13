# Installing and updating on the original Bike

Date: November 13, 2026. Planning guide only: nothing was installed or changed on the bike.

## Confirm the tablet first

The owner identified an original Bike with a non-rotating screen. OpenRide's documented original-Bike reference is the **Gen 2 tablet, model PLTN-RB1VQ**, Android 11, build `RQ.250113.A`; later issue reports also describe `RQ.260424.A`. The app requires Android 10 or later. A non-rotating screen alone does not establish the tablet generation. An older tablet below Android 10 will not install this build.

On the Bike, open **Settings → Device Settings → About tablet** (under System on the documented Bike interface). Record **Model**, **Android version** and **Build number** wherever exposed; firmware can change the labels. Also inspect the rear tablet label if the model is not shown. Read the information without starting a software update. Source: [Peloton's device-settings guide](https://support.onepeloton.com/s/article/Peloton-Software-How-to-Update-Your-Device?language=en_US) and [OpenRide's device matrix](../../DEVICE.md).

If a computer connection is already available, these read-only developer commands provide the same details:

```sh
adb shell getprop ro.product.model
adb shell getprop ro.product.device
adb shell getprop ro.build.version.release
adb shell getprop ro.build.display.id
```

`adb` means Android Debug Bridge, the computer-to-tablet connection tool. OpenPelo includes it; no separate installation is needed for its normal interface.

## Initial installation of existing OpenRide

This adds an app to the tablet. OpenRide reads an existing on-device sensor service; it does not flash a replacement operating system or require root.

1. On the Mac, download **OpenPelo-macOS.dmg** from [OpenPelo Releases](https://github.com/doudar/Openpelo/releases). The release checked during research was v1.0.84.
2. Open OpenPelo's **Developer Mode Guide** and use the path for the actual tablet/firmware. Enable the bike's **Developer Options**, then **USB debugging**, when those controls are available.
3. Connect the Mac to the tablet's data port with a USB data cable. OpenPelo's original-Bike guide specifies micro USB-B; inspect the tablet connector before choosing a cable. Leave the bike's sensor connection intact.
4. On the tablet, accept **Allow USB debugging** for this computer.
5. In OpenPelo, use **Refresh Devices** if needed, then select the bike under **Target Device**. Confirm the connection is shown.
6. Under **Compatible applications**, open **Fitness** and select **OpenRide**.
7. Click **Install selected** and wait for completion in **ADB activity**.
8. Open OpenRide on the bike. The expected first screen is **Who's riding?**; add a rider and check live cadence, resistance and watts while pedaling.

OpenPelo's current USB walkthrough also includes **Firmware Reset**, **Skip Home Installation**, and force-quitting **Device Management**. Those are not universally established prerequisites for this specific bike. A reset can erase setup/local data; do not begin it merely because a generic checklist mentions it. If developer access is unavailable, verify the exact tablet procedure and export important data before taking that path. Source: [OpenPelo setup](https://github.com/doudar/Openpelo#connect-a-device) and its [USB walkthrough data](https://github.com/doudar/Openpelo/blob/main/usb_debug_steps.json).

OpenPelo's catalog points to **digitalducktape/OpenRide**, not the new fork. That installs upstream for evaluation. The current release at capture is [v1.2.0, openride-real-9.apk](https://github.com/digitalducktape/OpenRide/releases/tag/v1.2.0).

## Home screen and Peloton software updates

After verifying the app works, **Profile → Device → Home screen → Turn on** offers to make OpenRide the home app. Choose it in Android's prompt. **Turn off** reverses that selection. Installation itself does not enable this setting.

There are two independent update systems:

- **OpenRide app updates** replace the app and normally preserve its data when the package and signing identity match.
- **Peloton firmware/OS updates** change the tablet and can remove developer access, alter the sensor service, or restore Peloton UI behavior.

Upstream's [installation guide](../../INSTALL.md) recommends blocking Peloton updates before relying on the setup. Doing that also defers Peloton's fixes and security updates. Record the working build and evaluate the exact firmware controls; this research did not establish one universal switch sequence and did not disable anything.

[Issue #63](https://github.com/digitalducktape/OpenRide/issues/63) documents a newer tablet where the stock Peloton app covers OpenRide despite the home setting. Disabling `com.peloton.activity` is a reported workaround for that unit, not a required step for the original Bike. Do not disable `com.onepeloton.affernetservice`: OpenRide depends on its sensor data.

## Updating the upstream app

Open **Profile → App updates → Check for updates**, then **Download**, then **Install**, and confirm Android's installer. Android may first require permission for OpenRide to **install unknown apps**. The app does not silently install updates. Alternatively reinstall the latest upstream APK through OpenPelo. Source: [upstream update guide](../../INSTALL.md#in-app-updates-t22--22).

## Installing the custom game build

Implementation update: the fork now supplies a separate **Lane Smash** build. Use **Install local APK** in OpenPelo; see the current [game and installation guide](../../LANE_SMASH.md). The implemented distribution design is:

1. A distinct application ID and visible name for the experimental fork, so it can coexist with upstream.
2. A dedicated signing key kept outside Git and backed up securely. Reuse it for every update.
3. A fork-specific update URL and increasing Android versionCode values.
4. A real-sensor build configuration, not ordinary mock debug.
5. A manual local-APK install for the first trial, then optional updates from releases in this fork.

At the original research snapshot, the updater was hardcoded to `https://api.github.com/repos/digitalducktape/openride/releases/latest` in [UpdateRepository](../../../app/src/main/java/dev/digitalducktape/openride/core/update/UpdateRepository.kt). It expects `openride-real-<versionCode>.apk` for the real build. The `neonReal` build now overrides the endpoint to `kbokarius/OpenRide`, selects the `neon` asset, enables real sensors and uses dedicated signing. Upstream build variants retain their own update configuration.

Android normally refuses to update an installed package with a differently signed APK. A local build does not automatically share the maintainer's signing key. Do not uninstall upstream just to work around that error: uninstalling removes its app data. Prefer a separate app, then explicitly transfer a backup if wanted. Sources: [Android app signing](https://developer.android.com/studio/publish/app-signing), [ADB install options](https://developer.android.com/tools/adb).

## Backups and rollback

- Export a backup from **Profile → Backup & restore** and copy it off the tablet before app replacement or any reset.
- Fork backups include profiles, rides, samples, game results and NEON attempts/course snapshots/ghosts. Custom content sources are excluded; app preferences/circuits are not guaranteed by this backup format. See [BackupRepository](../../../app/src/main/java/dev/digitalducktape/openride/core/backup/BackupRepository.kt).
- To return to the prior home app, turn off OpenRide's Home screen setting. Restore any Peloton components or update settings separately if they were changed.
- The fork installed separately can be removed after backing up its own data without overwriting upstream's data.
- No subscription cancellation, firmware update, reset, component disabling, or installation was performed during research.
