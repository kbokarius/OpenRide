# Revision 23 — resistance response and clearer lane-edge warning

November 17, 2026. Source changes and local validation only. No APK was signed or installed; the Peloton remains on **build 30 / revision 22**. Course 12 / generator 9 / scoring 11 / envelope 1 and all Kid/adult mappings stay unchanged.

## Audit findings

| Stage | Installed build 30 | Revision-23 source |
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

The response times above are calculated easing behavior, verified with simulated inputs at 30/60/120 fps. They are not measured physical knob-to-screen latency. Physical callback frequency and sustained tablet performance require checking the updated build on the Bike.
