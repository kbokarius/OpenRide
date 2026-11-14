# Lane Smash

A resistance-controlled 3D cycling game built inside OpenRide. Original code, graphics, courses and optional electronic music; no Peloton subscription or network connection is needed by the game. Lane Smash is the only available experience. The app opens directly into its track selector while preserving the installed package and saved rides.

## Start a ride

1. Open **Lane Smash**. Its track selector appears directly; no profile, FTP, or game-selection screen is required.
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

The five overall ranges match the published Lanebreak Bike update, and the seven-value lanes match every individual Lanebreak lane we could find, including the lane-edge numbers visible in review footage of the game. See [range research](research/lanebreak/06-difficulty-ranges.md). Values outside the chosen range do not score. A lane must settle for 150 ms. The app never turns the physical resistance knob for you; the roller-coaster route is visual and independent of resistance.

## Points and movement

- **Gold bars:** pedal in the target lane. Points accumulate with distance through the marked section.
- **Mint arrows:** stay in the target lane and between the displayed minimum and maximum rpm. Both endpoints count. A soft mint gradient stays attached to the section beneath the raised arrows.
- **Machine-gun fire:** every mint-arrow section is strafed by a raider on a hover sled. Two lines of fire rake the road, one ahead of you and one behind; hold the displayed rpm range and you ride in the gap. Speed up toward the top of the range and the line ahead closes in; slow toward the bottom and the line behind does. Outside the range the fire reaches you: after a two-second warning at the start of the section, a round lands after 0.6 seconds outside and then every half second, each costing up to **60 points**, at most 15 rounds (900 points) per section. Your lane does not matter for this; only your pedalling speed does.
- **Violet power sections:** accumulate output in the target lane. The floor charges and brightens as energy builds, with faster pulses at higher cadence and a growing triangular finish gate. Eighteen points are awarded per five joules: ten valid seconds at 150 W earns 5,400 points. There is no maximum-cadence target or power-score ceiling.
- Bars and arrows sit on the road without hovering; adjacent sections leave a clear space between the final target and the next section’s first target. Gold bars, arrows and the power section’s finish gate shatter when the front wheel touches them. The visual collision does not award points by itself: the correct lane, cadence and output rules still apply. Objects in other lanes remain intact.
- **Red bombs:** avoid them. A front-wheel hit removes up to **1,800 points**, shows the amount lost in red and triggers a flash, shockwave and debris. Your score cannot fall below zero. Bombs never occupy the active scoring lane.
- **Incoming Fire:** armored attackers fade in above the road and launch arcing shots at a marked, fixed blast zone. Use the lowest resistance lane and change pace substantially when prompted. You get 11 seconds to react and build or reduce speed; the prediction bar shows whether your current pace will pass the blast or stay behind it. Each 35-second section has two shots. A hit costs up to **1,800 points**. Passing the blast earns **1,800**; staying behind it safely earns **zero**, with no penalty. Changing lanes alone does not avoid this full-width blast.
- Stars rate how well you met the targets encountered during your ride. Complete the full selected duration and reach 25%, 60% or 90% for one, two or three stars. Extra burst output cannot replace missed lane/cadence targets. Road bombs lower your points but do not directly change the star percentage. Incoming Fire adds 1,800 available target-credit points per shot; either safe dodge earns that credit. Following Pedal Slower therefore does not hurt your stars even though it earns no score bonus.

A representative simulated 20-minute Challenging ride across all 25 tracks averaged about **173,000 points** (147,761 before the tracks were retuned in revision 12: there is now more to score). Your actual total depends on duration, cadence, measured power and accuracy; it is not normalized to a fixed result. Older saved courses keep their original point values.

Tracks ride as intervals: build through lanes 1–3, a hardest stretch in lanes 4–6, ease back through 5–3, then a real recovery in lanes 1–2, and repeat. Lane targets change every 20–47 seconds at 60–140 rpm (about 29 seconds at 95 rpm). Cadence sections last about 11–15 seconds and ask for a 20-rpm range that suits the lane: **95–115 in lane 1, 90–110, 85–105, 80–100, 70–90, and 65–85 in lane 6**, with an easy 75–95 while warming up and recovering. So light lanes are fast spins and heavy lanes are climbs. A Power Burst comes about once a minute of riding (twice in the hardest stretch, never while recovering), straight after a cadence section. Every track has the same target-effort budget per road minute, with different ordering and target placement. Incoming Fire temporarily replaces the lane targets with a 35-second pace challenge, beginning around 75 seconds and repeating about every three minutes; the last minute stays clear. Actual output depends on the rider. Each section’s final target explodes at its scoring endpoint and shows the earned +points at that spot. The number floats, fades and travels behind you with that point on the road; it does not add a second bonus.

You ride a long, low motorcycle with glowing wheels, twin drive rotors and thrusters. Everything on it follows your pedalling: the rotors turn once per pedal revolution, the wheels roll at game speed, the thrusters lengthen with effort, and the bike leans into lane changes. Faster pedalling moves farther down the track, and the road rushes past to match: the speed shown is your cadence × 0.8 in mph, so about **48 mph at 60 rpm, 77 mph at 96 rpm and 112 mph flat out at 140 rpm**. Ease right off and it slows with you; stop and it stops. Higher cadence cannot overrun the course. This is a game-speed scale, not a road-bike speed estimate. The 10/15/20/30-minute roads are 19.2/28.5/37.8/56.5 miles long on screen, including a buffer beyond the maximum reachable distance. Each ride still ends at the selected active time.

The old **Reference power** control is gone. An internal 150 W reference supplies the star target for power sections; it does not alter resistance, measured watts or the points you can earn.

## Ghost, scenery and scores

**Settings & history** offers **Music** (with the track picker and seek slider), **Sound effects**, **Best-ride ghost**, **Background motion**, **Graphics**, and the latest 50 attempts. Selecting a saved attempt replays its stored course, including generated tracks. Track-level last/best statistics remain available even when an attempt is older than the history list.

The ghost is your highest-scoring completed ride on the same exact course and resistance difficulty. It appears as a see-through projection of your motorcycle, following the recorded distance and lane at the same elapsed time. It fades when overlapping you or becoming too distant. **BEST RIDE** keeps showing how many feet it is ahead/behind, plus your points difference, even when the bike is out of view. Partial attempts cannot replace that best.

Eight immediately available palettes are assigned to named tracks: **Arctic, Cobalt, Copper, Titanium, Petrol, Amber, Ember and Glacier**. Four flowing psychedelic backgrounds replace the floating scenery: **Prismatic flow, Kaleidoscope, Liquid aurora and Vortex**. Cadence controls flow speed; resistance smoothly changes the pattern and colors. Random generation varies both palette and environment; saved replays retain the exact combination. There are no cosmetic unlocks or rider trails.

Music starts when the app opens, on a random track at a random point, and keeps playing through the selector, rides and results; when a track ends another random one begins. Use **Settings & history** in the main menu or **Audio** while riding to pick a track, drag the slider to skip backward or forward, and turn **Music** and **Sound effects** on or off independently. The switches persist until changed from either location, including after restart. The three tracks are Discovery Project (Electric Forest), DNS Mix and Dystopian Euphoria by Devloe; a build without them plays the original **Night Drive** loop (128 BPM). Effects include soft contact notes, section chords, power charging, the engine, lane changes, warnings, launches, machine-gun fire and impacts. By default the effects sit a little under the music (about 2 dB), so cues stay clear without talking over the soundtrack.

The whole picture moves with the music. In the background, bass makes the tunnel breathe, thickens its filaments and warms their colour; mids bend its shape and slide it between its two colours; treble adds sparkle and cools the highlights; each kick sends rings of light down it. On the road, **a pulse of light leaves your bike on every beat** and runs ahead down the lane lines as a chevron, the lane lines themselves take their brightness and colour from the spectrum (bass in the middle of the road, treble at the edges), the rails and their curtains of light follow the treble and mids, and the arches over the road take turns with bass, mids and treble. In the interface, the accent lines breathe the same way: the panel edges, the track chip (which carries a small eight-bar meter of the music), your lane's outline and the progress line in the ride, and the wordmark, header line, Start button and a meter beside **Now playing** in the menu. Text never changes colour. Everything is eased so it swells and settles instead of flickering. Your pedalling still sets how fast you travel. With Music off the picture is calm and the road keeps a soft, steady pulse.

**Graphics** is **Auto** by default: the game lowers the 3D detail by itself if the tablet cannot hold a smooth frame rate, and remembers that. **High** and **Performance** force a setting. Every event plays when enabled, with no repeat cooldown. All gameplay instructions remain visual. **Reduced** background motion dims and softens the effect, uses gentle curves without inversions, and removes the camera knock, the red edge pulse on hits and the beat-driven pulses. Normal motion includes vertical loops, full rolls and twisting climbs, independent of lane resistance. The slightly transparent road is a fixed 3D course: the camera travels along its curves instead of reshaping the road toward a moving endpoint. Lane lines and scoring objects stay clear while the background shows through the surface. Each named track has a repeatable route; generated tracks get their own seeded curves, loops and twists. New ride snapshots save that route. The psychedelic opening follows the view down the real course, with longer, smoother transitions. Its patterns now flow outward and past you using the same distance as the road: pedal faster to move through them faster, and stop to halt forward motion. Track cards preview their own colors and animated patterns behind a dark text gradient; Reduced motion freezes those previews.

## Uninterrupted rides and saved data

There is **no Pause option**. Finish the selected duration or choose **End Ride** and confirm. The timer continues while the end confirmation is open and while you stop pedalling. Below 20 rpm, ordinary road targets award no points; an incoming shot still resolves at its scheduled impact. Sensor loss, invalid samples, a lost input batch or a display stall freeze scoring so missing data cannot award points. One second of healthy input triggers automatic recovery followed by a three-second unscored countdown; there is no manual Resume button.

The total score and power-section points count up quickly, then ease to the exact number over 0.72 seconds; penalties count down in 0.30 seconds. New target values are sampled once per second, while the counter animation stays smooth. Captions and panels stay still. Speed, ghost gap and ride-metric numbers keep their one-second refresh. Section instructions change immediately at a section boundary. Prompts use **Pedal Faster**, **Pedal Slower**, **Keep This Speed**, **Increase Resistance**, **Lower Resistance**, **Stay in This Lane**, **Keep This Pace** and **Get Ready to Change Pace**. The lane dock already shows resistance ranges.

Attempts save before play, every five active seconds, on interruption and before results. Closing the app leaves an **Interrupted** attempt instead of resuming a partial course. Storage failures offer **Retry save** or ending the ride.

Return through recent apps or the **Lane Smash** app icon after switching away. Both lead to the same persistent game activity. **Exit** returns to the tablet launcher.

Backups include course snapshots, scores and completed ghost traces. Settings such as music are local preferences. Old snapshots retain their original scoring and comparison identity; new tracks use course version 8 / generator version 5 / scoring version 7 (machine-gun fire). Older bests remain in history and can be replayed with their original rules, while new tracks use separate score comparisons. Presentation paths have their own version and do not change score or ghost eligibility. This revision does not change Room schema 9.

## Installing the fork on the Bike

This is an app installation, not a replacement operating system. The original Bike's non-rotating screen does not identify its tablet generation. This build needs **Android 10 or later** and an ARM64 tablet. Sustained riding performance must be checked on the actual tablet.

**First installation update, November 13, 2026:** code 20 was installed and launched on the owner's PLTN-RB1VQ, Android 11 / RQ.260424.A, ARM64. The selector displayed **Bike connected · ready**. Live pedalling and sustained ride performance remain untested; see the [device installation record](research/lanebreak/08-first-install-followup.md).

1. On the Bike, check **Settings → Device Settings → About tablet** for the model, Android version and build. Firmware may arrange these labels differently. Do not start a firmware update just to inspect them.
2. On the Mac, open [OpenPelo](https://github.com/doudar/Openpelo/releases). Follow its **Developer Mode Guide** for that tablet, enable **USB debugging**, and connect a USB data cable to the tablet's data port. Leave the Bike's sensor cable connected.
3. Accept **Allow USB debugging** on the tablet. In OpenPelo, choose the Bike under **Target Device**; use **Refresh Devices** if needed.
4. Choose **Install local APK**, then select the signed `openride-neon-<version code>.apk` built from this fork. The normal **Compatible applications → OpenRide** catalog entry installs upstream, not this game build.
5. In OpenPelo, open **Tools → Installed App Manager**, search for **Lane Smash**, and click **Launch**. The Bike should show the track selector. Pedal until it reports ready, start a 10-minute Light ride, and verify that the top-left rpm, W and resistance values respond to pedalling and the knob.
6. Complete a 10-minute ride, then reopen the app to confirm its saved score and ghost. Test End Ride on a separate attempt. Follow with a full ride before relying on it for daily use.

For daily access without the Mac, a tablet launcher such as **Lawnchair** can display the Lane Smash app icon. OpenPelo offers it under **Compatible applications → Launchers**; after installation, use **Tools → Set Default Launcher → Lawnchair → Set Default**. This changes the home screen to the launcher, not directly to Lane Smash. The current signed build has its HOME alias disabled and no accessible control to enable it; the removed upstream Profile setting is not available. Direct automatic startup requires an app change or a separately verified device-specific setup. Do not use the old debug-only `run-as` instructions with this non-debuggable installer.

OpenPelo's generic Developer Mode Guide includes **Firmware Reset**. First confirm the tablet model, Android version and build, and try existing developer access. A reset is not established as necessary for this user's tablet; if USB debugging is missing or blocked, stop before resetting and obtain instructions for that exact firmware. Leave the Bike sensor cable connected.

The fork package is `dev.digitalducktape.openride.neon`, with real sensors enabled, a dedicated signing key and a `kbokarius/OpenRide` update channel. It can coexist with upstream OpenRide. This task does not reset the tablet, disable Peloton apps, change the home app, install onto the Bike, or cancel a membership.

For later updates, keep the same package and signing key. Install a newer signed APK using **Install local APK**. The former Profile and App updates controls are removed. This revision uses version code 20 and keeps the same package/signing identity. No fork release is automatically published by a local build.

Update this fork in place: do not uninstall it or clear its app data, since that can remove locally stored history. Automatic backups remain enabled, but the former manual Profile controls are removed. Do not uninstall upstream to resolve a signature mismatch. The dedicated fork avoids that conflict. More firmware-specific context and sources: [installation research](research/lanebreak/04-installation.md).

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

Lane Smash is the only selectable game; other game assets are excluded from the APK. See the [structured architecture and rules](lane-smash/README.md), [revision 11 specification](specs/lane-smash-v11.md) and [validation](specs/lane-smash-v11-validation.md).
