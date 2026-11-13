# Lane Smash

A resistance-controlled 3D cycling game built inside OpenRide. Original code, graphics, courses and optional electronic music; no Peloton subscription or network connection is needed by the game. This revision replaces the NEON VECTOR name and course picker while preserving the installed package and saved rides.

## Start a ride

1. Open the app’s **Games** tab, tap **Enter Games**, then choose **Lane Smash**.
2. Choose **10, 15, 20 or 30 min**. Each duration has 25 named tracks.
3. Select a track, or tap **Generate random track**. Scroll the library to see more tracks; there are no visible scrollbars.
4. Choose the resistance difficulty. **Last** and **Best** show scores for this exact track and difficulty; incomplete last attempts are marked **partial**.
5. Pedal until **Bike connected · ready** appears, then tap **Start ride**.

Every track has one scoring lane at a time. Turn the physical knob to reach it. Difficulty sets the resistance at both ends of the six-lane road, without changing the selected track layout.

| Difficulty | Lane 1 | Lane 2 | Lane 3 | Lane 4 | Lane 5 | Lane 6 |
| --- | --- | --- | --- | --- | --- | --- |
| Light | 15–21 | 22–28 | 29–35 | 36–42 | 43–49 | 50–56 |
| Moderate | 20–26 | 27–33 | 34–40 | 41–47 | 48–54 | 55–61 |
| Hard | 25–31 | 32–38 | 39–45 | 46–52 | 53–59 | 60–66 |
| Challenging (default) | 30–36 | 37–43 | 44–50 | 51–57 | 58–64 | 65–71 |
| Extreme | 35–41 | 42–48 | 49–55 | 56–62 | 63–69 | 70–76 |

The five overall ranges match the published Lanebreak Bike update; the equal seven-value lane subdivisions are our design. See [range research](research/lanebreak/06-difficulty-ranges.md). Values outside the chosen range do not score. A lane must settle for 150 ms. The app never turns the physical resistance knob for you; hills are visual.

## Points and movement

- **Gold bars:** pedal in the target lane. Points accumulate with distance through the marked section.
- **Mint arrows:** stay in the target lane and between the displayed minimum and maximum rpm. Both endpoints count.
- **Violet power sections:** accumulate output in the target lane. One point is awarded per five joules: ten valid seconds at 150 W earns 300 points. There is no maximum-cadence target or power-score ceiling.
- Gold bars, arrows and power crystals shatter when the front wheel touches them. The visual collision does not award points by itself: the correct lane, cadence and output rules still apply. Objects in other lanes remain intact.
- Stars rate how well you met the targets encountered during your ride. Complete the full selected duration and reach 25%, 60% or 90% for one, two or three stars. Extra burst output cannot replace missed lane/cadence targets.

The rider sits on an angular fighter-inspired bicycle. The cyclist's legs follow measured cadence. Faster pedalling moves farther down the track. Game speed reaches its **37.3 mph maximum at 140 rpm**; higher cadence cannot overrun the course. This is a game-speed scale, not a road-bike speed estimate. The 10/15/20/30-minute roads cover 6.40/9.51/12.61/18.83 miles, including a buffer beyond the maximum reachable distance. Each ride still ends at the selected active time.

The old **Reference power** control is gone. An internal 150 W reference supplies the star target for power sections; it does not alter resistance, measured watts or the points you can earn.

## Ghost, scenery and scores

**Settings & history** offers **Best-ride ghost**, **Music**, **Background motion**, and the latest 50 attempts. Selecting a saved attempt replays its stored course, including generated tracks. Track-level last/best statistics remain available even when an attempt is older than the history list.

The ghost is your highest-scoring completed ride on the same exact course and resistance difficulty. Its translucent cyclist follows the recorded distance and lane at the same elapsed time. It fades when overlapping you or becoming too distant. **BEST RIDE** keeps showing how many feet it is ahead/behind, plus your points difference, even when the bike is out of view. Partial attempts cannot replace that best.

Eight immediately available palettes are assigned to named tracks: **Arctic, Cobalt, Copper, Titanium, Petrol, Amber, Ember and Glacier**. Four flowing psychedelic backgrounds replace the floating scenery: **Prismatic flow, Kaleidoscope, Liquid aurora and Vortex**. Cadence controls flow speed; resistance smoothly changes the pattern and colors. Random generation varies both palette and environment; saved replays retain the exact combination. There are no cosmetic unlocks or rider trails.

The optional original **Night Drive** soundtrack is a 128 BPM dark electronic loop. Switch it off in **Settings & history** before starting. All gameplay instructions remain visual. **Reduced** background motion slows and dims the effect and softens road curves.

## Uninterrupted rides and saved data

There is **no Pause option**. Finish the selected duration or choose **End Ride** and confirm. The timer continues while the end confirmation is open and while you stop pedalling. Below 20 rpm, no points accrue. Sensor loss, invalid samples, a lost input batch or a display stall freeze scoring so missing data cannot award points. One second of healthy input triggers automatic recovery followed by a three-second unscored countdown; there is no manual Resume button.

Live score, speed, ghost gap and ride-metric numbers update once per second. Section instructions change immediately at a section boundary; animation and the scoring engine continue at full rate. Prompts use **Pedal Faster**, **Pedal Slower**, **Keep This Speed**, **Increase Resistance**, **Lower Resistance**, and **Stay in This Lane**. The lane dock already shows resistance ranges, so the duplicate line above the road is removed.

Attempts save before play, every five active seconds, on interruption and before results. Closing the app leaves an **Interrupted** attempt instead of resuming a partial course. Storage failures offer **Retry save** or ending the ride.

After switching away on Android, return directly through the recent-apps view. Opening OpenRide's main Home screen ends the Games visit under the existing host behavior.

Backups include course snapshots, scores and completed ghost traces. Settings such as music are local preferences. Old NEON VECTOR snapshots retain their original scoring and comparison identity; new tracks use revision 3. This revision does not change Room schema 9.

## Installing the fork on the Bike

This is an app installation, not a replacement operating system. The original Bike's non-rotating screen does not identify its tablet generation. This build needs **Android 10 or later** and an ARM64 tablet. Physical compatibility and sustained performance remain to be verified on the user's Bike.

1. On the Bike, check **Settings → Device Settings → About tablet** for the model, Android version and build. Firmware may arrange these labels differently. Do not start a firmware update just to inspect them.
2. On the Mac, open [OpenPelo](https://github.com/doudar/Openpelo/releases). Follow its **Developer Mode Guide** for that tablet, enable **USB debugging**, and connect a USB data cable to the tablet's data port. Leave the Bike's sensor cable connected.
3. Accept **Allow USB debugging** on the tablet. In OpenPelo, choose the Bike under **Target Device**; use **Refresh Devices** if needed.
4. Choose **Install local APK**, then select the signed `openride-neon-11.apk` supplied with this fork. The normal **Compatible applications → OpenRide** catalog entry installs upstream, not this game build.
5. Open **Lane Smash** on the Bike, create/select a rider, then open **Games → Enter Games → Lane Smash**. Pedal and turn the knob to verify live cadence, power and resistance before starting a 10-minute Light ride.
6. Complete a 10-minute ride, then reopen the app to confirm its saved score and ghost. Test End Ride on a separate attempt. Follow with a full ride before relying on it for daily use.

The fork package is `dev.digitalducktape.openride.neon`, with real sensors enabled, a dedicated signing key and a `kbokarius/OpenRide` update channel. It can coexist with upstream OpenRide. This task does not reset the tablet, disable Peloton apps, change the home app, install onto the Bike, or cancel a membership.

For later updates, keep the same package and signing key. Install a newer signed APK using **Install local APK**, or use **Profile → App updates** after a release has been published to the fork. The updater expects assets named `openride-neon-<versionCode>.apk`; this revision uses version code 11. No fork release is automatically published by a local build.

Before replacing or removing an installed app, use **Profile → Backup & restore** to export a backup off the tablet. Do not uninstall upstream to resolve a signature mismatch. The dedicated fork avoids that conflict. More firmware-specific context and sources: [installation research](research/lanebreak/04-installation.md).

## Building and maintaining

- Godot editor: **4.7.2**, matching the Android engine dependency.
- Java: **17+**; the local verification used Android Studio's bundled JBR.
- Set `ANDROID_HOME` to the SDK and `GODOT_BIN` to the Godot executable.
- `./gradlew :app:testDebugUnitTest` runs Android unit tests.
- `./gradlew :app:assembleDebug` builds the simulated-sensor app for local Android testing.
- `./gradlew :app:assembleNeonReal` builds the ARM64 real-sensor fork. Set `NEON_SIGNING_PROPERTIES` to a private properties file containing `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Without it the APK is deliberately unsigned. Never commit signing keys or passwords; back them up securely and reuse them for updates.
- Godot tests, captures and full-course simulation commands are recorded in the validation report and [framework documentation](GAMES.md).
- `LaneSmashCatalog.gd` defines the named/seeded courses. Legacy JSON remains exported for saved replays. Keep the generator version and course hash stable unless deliberately versioning content.
- `godot --path games -s res://tests/demo_lane_smash.gd` opens an automated desktop ride with an isolated completed ghost. It uses simulated sensor values and separate demonstration history.

Lane Smash is a full-ride mode and stays outside the generic circuit builder. The shared Games UI uses clean typography and preserves the existing pause, resume and result controls. See [revision 3 specification](specs/lane-smash-v3.md) and [validation](specs/lane-smash-v3-validation.md).
