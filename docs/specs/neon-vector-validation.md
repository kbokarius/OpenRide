# NEON VECTOR — local validation

Date: 2026-11-13. Branch: `feat/neon-vector`. Parent: `ea7e494`.

## Scope and conclusion

Implemented the approved silent six-lane game plus enhancements 1–4: matched personal-best ghosts, completion-based cosmetic worlds/trails, reproducible offline daily courses and saved-course replay, and mutually exclusive Flow/Surge branches. Ten authored courses cover practice and 10/20/30-minute workouts. Four resistance difficulties change the lane envelope independently of reference power. No targeted missed-section practice mode was included.

The implementation has passed the local checks below and produces a signed ARM64 Android APK. This is not a claim that every possible defect has been eliminated. Real Bike sensors, exact firmware compatibility and sustained tablet performance remain unverified.

## Automated evidence

| Check | Result | Evidence |
|---|---|---|
| Android unit/integration suite, including Room and migration tests | 985 tests in 114 suites; zero failures/errors/skips | `:app:testDebugUnitTest`; XML under `app/build/test-results/testDebugUnitTest` |
| Full Godot regression | 1,118 cases in 95 suites; zero test failures/errors/skips/orphans | GdUnit report 10; test runner subsequently crashes during disposal, see below |
| Final focused Godot regression after Android method lookup and fixed-length label changes | 47 cases; zero failures/errors | GdUnit report 11; process exit 0 |
| Complete authored and daily course simulation | 156 full rides, 49 simulated hours; all complete with reachable maximum and three stars | `tests/sim_neon_vector.gd`; four tiers × 30/60/120 fps × 13 courses |
| Actual desktop play lifecycle | 21 checks passed | `tests/play_neon_vector.gd`; real hub, setup, intro, live game, ghost, pause/resume, sensor loss and saved partial result |
| Android packages | Mock debug and signed real-sensor fork both build | `:app:assembleDebug :app:assembleNeonReal` |
| Patch whitespace | Clean | `git diff --check` |

The simulation uses the ten authored courses plus daily courses for 2026-11-13, 2026-12-31 and 2027-01-01. It supplies timestamped 20 Hz sensor samples independently of the simulated render rate. Scores are identical across all render rates and resistance difficulties. A separate course test validates a year of daily generation, deterministic reproduction, varied work patterns and preserved recovery structure.

### Covered rule and storage cases

- Every resistance edge, out-of-envelope readings, lane settling and changing lanes during events.
- One-time pickup windows; cadence hold boundaries; charge thresholds, averaging, overfill and the high-cadence cutoff.
- Exclusive branch choice, no double collection, and a maximum that counts the better route once.
- Fixed-tick fractional scoring, stale/invalid input, long render gaps, sample-buffer overflow, duplicate samples and constant-value fresh deliveries.
- Paused time and countdowns do not score; stale input blocks Resume; one fresh sample cannot bypass the recovery gate.
- Course/version/hash/difficulty/reference-power identity; rider isolation; ghost selection; malformed traces; unlock boundaries; partial attempts never award completion credit.
- Atomic/idempotent finalization; late checkpoints cannot overwrite a completed record; monotonic checkpoints; process-death recovery; native plan interruption; old backup compatibility; course/ghost backup restoration.
- Room migrations through schema 9 and filtering incomplete attempts out of personal-best/leaderboard queries.
- Setup/modal touch targets, course locks, optional power settings, history/cosmetics layout, and exclusion from the generic circuit builder.

## Packaged Android checks

Local device: dedicated AOSP Android 11/API 30 ARM64 emulator, 1920×1080 at 160 dpi, host GPU, 4 GB RAM. Its synthetic rider is `NEON_QA`; no personal Bike data was used.

The packaged app loads the NEON card and all course JSON from the exported pack. Actual Kotlin–Godot calls load history, create a pending attempt, deliver timestamped sensor samples, advance course time and score pickups/holds. The real Android pause path freezes the course when Home is pressed; returning directly through Recents shows the shared pause overlay and requires an explicit three-second Resume countdown.

The emulator exposed a method-discovery defect: `Object.has_method` does not query the Java methods on `JNISingleton`. The native checks now use `has_java_method`, matching [Godot's documented API](https://docs.godotengine.org/en/stable/classes/class_jnisingleton.html). It also exposed an interruption path through OpenRide's main Home screen; native plan completion now marks pending history interrupted immediately.

Final completion, persisted-record inspection and signed real-sensor launch evidence are recorded below after the smoke run finishes.

## Visual and performance review

Inspected the actual gameplay, setup, reference-power panel, cosmetic/history panel, pause, stale-sensor state and summary at 1920×1080 and 1920×1008. The native Android card/setup/gameplay were also inspected at full resolution. Uses the host font, controls and pause layout, with original track artwork and four procedural environments: Midnight Circuit, Orbital Drift, Deep Signal and Solar Frontier.

Rendered fixture sampling on an Apple M4 Max at 1920×1080 recorded median frame intervals of 16.67 ms and p95 intervals of 17.85–18.26 ms across the four worlds. Each sample contains 180 measured frames after 60 warm-up frames, with a 60 fps cap. These short desktop samples ran alongside other local checks; they are not a sustained benchmark or a prediction of Bike performance. The capture fixture includes a demonstrative ghost; the play-lifecycle test separately verifies a ghost loaded from an actual completed stored attempt.

## Known test-tool limitation

Godot 4.7.2's full headless GdUnit run reports all tests passed, then receives SIGSEGV while disposing resources and exits 134. Reproduced in a separate clean worktree at the unchanged parent commit: 1,095 cases, zero failures, then the same disposal crash. It is therefore an upstream/baseline runner-cleanup issue, not a new failing game test. The focused 47-case run exits 0 but reports 30 ObjectDB instances and three resources still present at shutdown; the standalone play script reports three ObjectDB instances at exit. These warnings are retained as limitations rather than hidden.

No such native crash has been observed during the packaged Android smoke run. The engine prints an existing `xr/shaders/enabled` project-setting warning at Android startup; NEON does not use XR.

## Reproducing the checks

From the repository root, with Godot 4.7.2 in `GODOT_BIN`, a Java 17+ JDK in `JAVA_HOME`, and the Android SDK in `ANDROID_HOME`:

```sh
./gradlew :app:testDebugUnitTest :app:assembleDebug :app:assembleNeonReal
"$GODOT_BIN" --headless --path games --editor --import
"$GODOT_BIN" --headless -d --ignore-error-breaks --path games \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit --ignoreHeadlessMode
"$GODOT_BIN" --headless --path games -s res://tests/sim_neon_vector.gd
"$GODOT_BIN" --path games -s res://tests/play_neon_vector.gd \
  -- --out=/absolute/path/to/play-captures
"$GODOT_BIN" --path games -s res://tests/capture_neon_vector.gd \
  -- --out=/absolute/path/to/world-captures --course=intervals_20 \
  --time=195 --size=1920x1080 --measure
```

Do not import or modify Godot source files while a test run is executing. `assembleNeonReal` requires `NEON_SIGNING_PROPERTIES` for a signed result; see [the installation/build guide](../NEON_VECTOR.md).

## Before daily use on the Original Bike

1. Confirm its exact tablet model, Android version (10+) and ARM64 compatibility.
2. Install the signed fork beside existing apps using the local-APK path in the guide.
3. Verify cadence, power and resistance track pedalling/knob movement and remain fresh even at steady effort.
4. Complete First Contact, then a 30-minute ride; inspect responsiveness, temperature and frame stability.
5. Exercise pause/resume, sensor interruption, exit/reopen, history and a same-key APK update. Export a backup off the tablet.

The build does not operate the physical resistance motor, install a replacement operating system or require a Peloton account for its gameplay.
