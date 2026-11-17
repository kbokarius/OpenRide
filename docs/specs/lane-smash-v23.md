# Revision 23 — resistance response and clearer lane-edge warning

November 17, 2026. Source changes validated locally, then packaged and installed at the owner’s request as **build 31 / 1.2.0-lane-smash.23**. Course 12 / generator 9 / scoring 11 / envelope 1 and all Kid/adult mappings stay unchanged.

## Audit findings

| Stage | Previous build 30 | Installed build 31 / revision 23 |
| --- | --- | --- |
| Original Bike V1 callback request | 200 ms / 5 Hz requested | 100 ms / 10 Hz requested; log firmware return value |
| Input bridge | Reads buffered deliveries each rendered frame | Unchanged |
| Rules | Ordered samples, 10 ms ticks, raw resistance | Unchanged |
| Within-lane visual easing | 11/s; 90% step response about 209 ms | 24/s; about 96 ms |
| Crossing visual easing | 28/s; 90% response about 82 ms | 40/s; about 58 ms |
| Resistance number | Included in the one-second readout timer | Each delivered change on the next frame; cached label prevents redundant updates |
| Steering text | One-second cache; uses settled lane | Changed resistance invalidates cache; uses actual band membership |
| Scoring eligibility | 150 ms settled in a new lane | Unchanged; does not delay the bike or guidance |

The previous direction expression could say LOWER RESISTANCE while already in the correct band because `settled_lane` was still −1. The one-second cache could preserve that incorrect instruction. A regression now traverses correct lane → above band → correct lane → out of course in 40 ms and verifies immediate correct copy throughout, before any scoring settlement.

Sensor callbacks, sensor measurements and rendered frames are distinct rates. Requesting 100 ms is not proof of 100 ms delivery or end-to-end knob response. Firmware may cap/ignore the request; cadence itself can remain unchanged over several pushed frames. The faster request is best-effort and reapplied after a reconnect; an unsupported rate-control call leaves the callback feed working. No busy polling, synthetic input, resistance recalculation, predicted lane crossing or threshold change was introduced. The other binder and its fallback poll are unchanged.

The implementation reuses the callback buffer, cached HUD labels and exponential steering. Rendering predicted knob movement was rejected because it could place the motorcycle in a lane the hardware never reported. Score/history text and RPM/watt/heart-rate numbers keep their existing refresh behavior.

## Edge warning

The existing road shader changes only its warning RGB from `(0.66, 0.25, 0.29)` to **`(0.95, 0.34, 0.38)`**. It retains the maximum 92% blend, 0.3-second fade, five interior seams, outer-quarter trigger, and local road window −18 to +65 metres (fully visible −4 to +18). It is brighter without flashing or adding geometry.

## Validation

- **39 Godot tests across five suites passed**, zero failures/errors/orphans. Coverage includes frame-rate-independent 90% visual response within 100 ms, non-overshoot/reversals, raw-resistance readout updates while other numbers stay throttled, same-second direction correction before lane settling, Kid/adult steering, edge eligibility and rules regressions.
- **30 Android tests passed** across the V1 source, source arbitration, sample buffer and monotonic timeline. New coverage verifies the 100 ms request, every raw resistance delivery (including duplicate values), reconnect reapplication and continued sensor delivery when firmware rejects rate control.
- Native Compatibility-renderer capture checks the brighter warning near lane 6 with the existing cadence gauge, active gunner and road. No script/shader errors; capture state is isolated from personal ride history.
- No database schema changes, scoring changes or new comparison keys. No full-course rerun was needed because event generation, timing and scoring code are untouched.

The response times above are calculated easing behavior, verified with simulated inputs at 30/60/120 fps. They are not measured physical knob-to-screen latency. Physical callback frequency and sustained tablet performance remain unmeasured; the installation check below confirms startup and sensor connectivity.


## Build and installation

Signed November 17, 2026 using the existing `neonReal` Gradle pipeline and signing identity. This packages source `fae81fb` with only the Android version bump: code **31**, version **1.2.0-lane-smash.23**. Package `dev.digitalducktape.openride.neon` remains ARM64, non-debuggable, real-sensor enabled, minimum Android 10 / target API 34. Auto remains the graphics default.

- `assembleNeonReal`, `lintNeonReal` and **47 real-build tests** passed. These cover the sensor source/arbitration/buffer, timeline, settings and records. Lint: zero errors and 79 existing warnings.
- APK signature verifies with v2. Certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`, matching earlier installed builds.
- Artifact: `openride-neon-31.apk`, **204,206,773 bytes**. SHA-256: `b8b6f8786075bfe173ebebd60b1705ec9f87e86ace84b1712355a5c3ddfe4aac`.
- Embedded `assets/games.pck` is uncompressed and matches the exported pack byte-for-byte. Independently loading it confirms steering rates 24/s and 40/s, half-cadence Kid targets, course 12 / generator 9 / scoring 11, Auto graphics and existing tyre/mine parameters.

The verified Original Bike was on the track selector with no active ride immediately before updating. Wi-Fi `adb install -r` returned **Success**. Android reports code **31** / `1.2.0-lane-smash.23`; the package user ID and original first-install timestamp are unchanged. No uninstall, data clear or launcher change was performed.

Cold launch returned **Status: ok**. After loading, the animated selector displayed **Bike connected · ready**, Nightfall, 20 minutes and Challenging. No ride was started. The inspected process startup log contains no fatal exception or script error; existing vendor/engine warnings remain. The informational sensor-rate return message was not present in the captured log, so actual firmware acceptance/delivery rate is not established by this check.

This verifies installation, menu rendering and sensor connectivity. It does not measure physical knob-to-screen latency or sustained riding performance. Existing app storage is preserved by the in-place update; the full history list and every saved preference were not separately re-inspected.
