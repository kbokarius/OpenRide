# NEON VECTOR

A silent, resistance-controlled cycling game for the original Peloton Bike, built inside OpenRide. It uses original code, graphics and courses. No Peloton subscription, music track, camera, cloud account or network connection is used by the game itself.

## Choose a ride

Open **Games → NEON VECTOR**. Choose a course family, length, resistance difficulty and reference power, then tap **Enter the circuit**. Start requires fresh bike readings.

| Course | Lengths | Purpose |
|---|---|---|
| First Contact | 5 minutes | Guided practice; its records are separate and it does not unlock cosmetics. |
| Steady Flow | 10 / 20 / 30 minutes | Longer cadence holds and smooth changes. |
| Intervals | 10 / 20 / 30 minutes | Short power charges with recovery. |
| Rolling Climb | 10 / 20 / 30 minutes | Gradual movement toward higher resistance. |
| Daily Signal | 20 minutes | Reproducible offline course for the selected local date. |

Difficulty changes the resistance at the outer edges of the six lanes. It does not change the course schedule, duration or available points.

| Difficulty | Lane 1 | Lane 2 | Lane 3 | Lane 4 | Lane 5 | Lane 6 |
|---|---|---|---|---|---|---|
| Beginner | 20–26 | 27–33 | 34–40 | 41–47 | 48–54 | 55–61 |
| Intermediate | 24–30 | 31–37 | 38–44 | 45–51 | 52–58 | 59–65 |
| Advanced | 30–36 | 37–43 | 44–50 | 51–57 | 58–64 | 65–71 |
| Expert | 34–40 | 41–47 | 48–54 | 55–61 | 62–68 | 69–75 |

Turn the physical resistance knob to move between lanes. Values outside the chosen range do not score. A lane must settle for 150 ms; changing lanes cannot score in both at once. The app never changes the Bike's resistance automatically.

## Points, targets and stars

- **Gold diamonds:** be in the indicated lane at the hit line, within ±250 ms. Each scores once: 100 points in lane 1, increasing by 20 per lane.
- **Green ribbons:** remain in the lane and within the displayed cadence band. Valid time earns 10 points per second before any branch bonus.
- **Violet charges:** remain in the lane and build the meter with power. A one-second trailing power average is used. The reference power setting is independent of resistance difficulty: 60% of it fills at the 100% rate; the full reference fills at the 200% rate. The extra half of the meter adds up to a 50% point bonus. Cadence above 120 rpm adds no charge but does not erase previously earned points.
- **Split routes:** choose the lower Flow lane or the higher Surge lane. Surge offers 25% more points. The first settled eligible lane locks the choice; switching afterward cannot collect both. The maximum counts the better route once.
- **Stars:** finish the whole course and achieve 25%, 60% or 90% of its reachable base points for one, two or three stars. Charge overfill does not inflate star completion. Partial attempts earn no stars and cannot replace personal bests.

Pedalling below 20 rpm earns nothing. Three seconds below that threshold pauses the course. Eight seconds of upcoming track are visible. All cues are visual; the game registers no music or sound effects.

## Ghost, worlds and daily courses

**Style & history** contains the ghost and motion options, cosmetic choices and the latest 50 attempts. Tap a saved attempt to replay its exact saved course; the date changing or a later generator revision does not replace that content.

The optional ghost uses your highest completed score for the same rider, exact course hash, difficulty, scoring/envelope versions and reference power. Its translucent rider shows the previous lane and the live points difference. Cosmetics are excluded from that identity.

| Cosmetic | Completed non-practice rides required |
|---|---:|
| Midnight Circuit / Ion trail | 0 |
| Orbital Drift | 3 |
| Prism trail | 5 |
| Deep Signal | 7 |
| Comet trail | 10 |
| Solar Frontier | 12 |

Unlocks have no scoring or resistance advantage. **Reduced** background motion keeps moving targets readable while reducing decorative animation.

Daily Signal uses an explicitly versioned deterministic generator and stored seed. It varies validated work blocks, preserves warm-up/recovery/cooldown targets, and keeps the bonus branch on the higher-resistance side. There is no online daily leaderboard or server clock.

## Pauses, saved data and backups

A display stall over 250 ms, lost sample history, invalid sensor input or readings older than 1.5 seconds pauses scoring. Backgrounding the Android app pauses the session. Manual Resume requires one second of fresh readings, followed by a three-second unscored countdown. Old samples and power smoothing are cleared before the course resumes.

After switching away, use Android's recent-apps view to return directly to the **Games** screen and tap **Resume**. Opening OpenRide's main Home screen ends the current Games visit, following OpenRide's existing behavior; the partial NEON attempt is retained as **Interrupted**. Use the in-game Pause button for ordinary breaks.

Every attempt is written before its clock starts, checkpointed every five course seconds and on pause, and finalized before the normal result screen. Android uses Room transactions; desktop testing uses versioned JSON files written by rename. Duplicate finish requests cannot create extra completions. After process death, a pending attempt becomes **Interrupted** history, with no mid-course scoring resume. Storage failures pause the ride and offer an explicit retry through Resume.

Schema 9 adds durable `neon_attempts` and `game_results.recordEligible`. Existing game records keep their previous behavior. Backups include course snapshots, result breakdowns and completed ghost traces; pending attempts restore as interrupted. Cosmetic selections and other game preferences are local settings, so a restored device may need those choices selected again. Unlock counts come from restored completed attempts.

## Installing the fork on the Bike

This is an app installation, not a replacement operating system. The original Bike's non-rotating screen does not identify its tablet generation. This build needs **Android 10 or later** and an ARM64 tablet. Physical compatibility and sustained performance remain to be verified on the user's Bike.

1. On the Bike, check **Settings → Device Settings → About tablet** for the model, Android version and build. Firmware may arrange these labels differently. Do not start a firmware update just to inspect them.
2. On the Mac, open [OpenPelo](https://github.com/doudar/Openpelo/releases). Follow its **Developer Mode Guide** for that tablet, enable **USB debugging**, and connect a USB data cable to the tablet's data port. Leave the Bike's sensor cable connected.
3. Accept **Allow USB debugging** on the tablet. In OpenPelo, choose the Bike under **Target Device**; use **Refresh Devices** if needed.
4. Choose **Install local APK**, then select the signed `openride-neon-9.apk` supplied with this fork. The normal **Compatible applications → OpenRide** catalog entry installs upstream, not this game build.
5. Open **NEON VECTOR** on the Bike, create/select a rider, then open **Games → NEON VECTOR**. Pedal and turn the knob to verify live cadence, power and resistance before starting First Contact.
6. Complete the practice ride, pause/resume, then end and reopen the app to confirm history. Follow with a full ride before relying on it for daily use.

The fork package is `dev.digitalducktape.openride.neon`, with real sensors enabled, a dedicated signing key and a `kbokarius/OpenRide` update channel. It can coexist with upstream OpenRide. This task does not reset the tablet, disable Peloton apps, change the home app, install onto the Bike, or cancel a membership.

For later updates, keep the same package and signing key. Install a newer signed APK using **Install local APK**, or use **Profile → App updates** after a release has been published to the fork. The updater expects assets named `openride-neon-<versionCode>.apk`; the first build uses version code 9. No fork release is automatically published by a local build.

Before replacing or removing an installed app, use **Profile → Backup & restore** to export a backup off the tablet. Do not uninstall upstream to resolve a signature mismatch. The dedicated fork avoids that conflict. More firmware-specific context and sources: [installation research](research/lanebreak/04-installation.md).

## Building and maintaining

- Godot editor: **4.7.2**, matching the Android engine dependency.
- Java: **17+**; the local verification used Android Studio's bundled JBR.
- Set `ANDROID_HOME` to the SDK and `GODOT_BIN` to the Godot executable.
- `./gradlew :app:testDebugUnitTest` runs Android unit tests.
- `./gradlew :app:assembleDebug` builds the simulated-sensor app for local Android testing.
- `./gradlew :app:assembleNeonReal` builds the ARM64 real-sensor fork. Set `NEON_SIGNING_PROPERTIES` to a private properties file containing `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Without it the APK is deliberately unsigned. Never commit signing keys or passwords; back them up securely and reuse them for updates.
- Godot tests, captures and full-course simulation commands are recorded in the validation report and [framework documentation](GAMES.md).
- Course JSON files are explicitly included in the exported pack. Regenerate authored files with `python3 games/tools/generate_neon_courses.py` and run validators before committing content changes.

NEON VECTOR is a complete-course mode and is excluded from the generic circuit builder, which would otherwise shorten a course or omit its locked settings. This fork preserves OpenRide's existing game controls, font, pause overlay and summary layout.
