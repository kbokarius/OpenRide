# Daily launch: Lane Smash or Peloton

Configured November 13, 2026 on the owner's Original Bike, PLTN-RB1VQ, Android 11 / RQ.260424.A.

## Installed tools

- OpenPelo **1.0.84** installed in the Mac user's `~/Applications/OpenPelo.app` and launched. Its bundled ADB detected the already-authorized USB connection.
- Downloaded from the [official release](https://github.com/doudar/Openpelo/releases/tag/v1.0.84). DMG SHA-256 matched the release asset digest: `ee560876e15fa78a8f254ac8e0c00781fd03c361a1f688ad8194189a5e394f8c`. The copied app passed macOS code-signature verification.
- Installed **Lawnchair 15 Beta 2**, the launcher recommended by OpenPelo's catalog for this tablet, from its [official release](https://github.com/LawnchairLauncher/lawnchair/releases/tag/v15.0.0-beta2).
- Lawnchair package: `app.lawnchair`, version code `15000202`, Android 8+ minimum. APK signature verification passed; installation returned `Success`.
- Lawnchair APK SHA-256: `c591f4433f26e00ed1b0df57ea55c3a0115f57297add84c3bd6b6fc3ea5a249a`.
- Lane Smash remains version **1.2.0-lane-smash.12**, code **20**. No game rebuild was needed.

## Home-screen configuration

OpenPelo → Tools → Set Default Launcher → `app.lawnchair` → Set Default successfully selected `app.lawnchair/.LawnchairLauncher`. Added **Lane Smash** and **Peloton** shortcuts next to each other on its home screen. Peloton's apps and sensor service remain installed and enabled.

This provides a choice between the two apps. It does not enable Lane Smash's disabled HOME alias or automatically start a ride.

## Daily use

1. On the bike's home screen, tap **Lane Smash** or **Peloton**.
2. To leave Lane Smash, tap **Exit** in its upper-left corner, then **Exit** in the confirmation.
3. To return from Peloton, use the tablet's bottom-center Home control (the Peloton-shaped icon). If the navigation controls are hidden, reveal them by swiping up from the bottom edge.

The Mac, USB cable and OpenPelo are only needed to manage/install apps, not to launch an installed app from the bike's home screen. On the Mac, open OpenPelo through Spotlight: Command–Space, type `OpenPelo`, then Return.

## Verification

- Tapping the Peloton shortcut opened the regular Peloton profile chooser.
- Tapping the Lane Smash shortcut opened its track selector and displayed **Bike connected · ready**.
- Lane Smash → Exit → Exit returned to Lawnchair.
- Restarted the tablet and observed `sys.boot_completed=1` with a fresh uptime. Without sending Home or launching an app after the restart, the foreground activity was Lawnchair and the physical-screen capture showed both saved shortcuts. The resolved default HOME remained `app.lawnchair/.LawnchairLauncher`.
- Left the tablet on this home screen and OpenPelo running on the Mac. Waking from ordinary sleep may resume the last app; the restart test verifies a full boot.

No account sign-in, factory reset, firmware change, package disabling or app-data clearing was performed. This setup does not add physical ride/performance validation.

## Restore the original home screen

With the bike connected to OpenPelo: **Tools → Set Default Launcher → `com.peloton.launcher` → Set Default**. Lane Smash remains installed and can still be opened through OpenPelo's Installed App Manager. Switching the default launcher does not delete ride history.

Reference: [OpenPelo launcher tools](https://github.com/doudar/Openpelo#6-configure-the-launcher-and-device-tools).
