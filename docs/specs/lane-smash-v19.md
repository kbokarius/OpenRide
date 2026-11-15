# Lane Smash revision 19 — continuous ride flow and scoring

November 15, 2026. Version `1.2.0-lane-smash.19`, APK code 27. Course 11 / generator 8 / scoring 10.

**Later release:** these changes, the wider rear tyre and Kid difficulty shipped together in signed [revision 20 / APK 28](lane-smash-v20.md), installed over Wi-Fi on the Bike on November 15, 2026. The build-27 validation below remains a historical record.

## Requested behavior

- Award a successful incoming-bomb pass at the end of the marked blast area, without waiting for impact.
- Let score counters flow continuously rather than update in once-per-second bursts.
- Remove long early dead periods in Nightfall; give Collect and Pedal speed sections at least ten seconds at maximum speed. Vary the existing short Power Bursts slightly.
- Always identify the target lane, even during approaches.
- Lower cadence bands in higher lanes, informed by Lanebreak footage, without changing difficulty resistance bands.
- Put frequent mines in all non-target lanes during sections; leave all lane-change gaps clear.

## Implementation and compatibility

The existing 10 ms rules tick owns pass resolution. A successful crossing beyond the blast half-length plus the full rider margin resolves once and grants 1,800 points. A separate impact timestamp keeps the bomb's flight and explosion intact. The popup and pass sound occur at clearance; physical impact effects occur at impact. Slowing behind gives zero, and wrong-lane rapid drops still penalize.

Counters use one analytic critically damped follower, keeping velocity across new targets. Repeatedly restarting cubic tweens was rejected because it changes the slope at every update and produces stop/start motion. The total and burst counter take targets every render frame; metrics, instructions and best-ride text retain their slower refresh. Presentation never controls authoritative points.

Generator 8 uses full ten-road-second Collect and Pedal speed sections and a deterministic 5/6/7-second burst cycle. Work blocks have nine road-seconds to change resistance and two between same-lane sections, preserving equal authored budgets across lane orders. Warm-up uses lanes 1–2, work uses 3–6, and jumps remain at most three lanes. The final minute still switches to a mine-free, low-lane cooldown with ten-road-second Collect sections. The timed cooldown and ride finish can close the currently active section; ordinary authored sections and post-bomb returns are never tiny fragments.

Incoming Fire waits for an active section's final marker before preparation. It postpones the pre-attack fade too, keeping the current section fully visible, then gives the final contact 700 ms before preparation starts. An attack that would overrun the final-minute cooldown is omitted. After the last impact fades, normal play returns immediately, removing the former eight-second idle tail. Runtime events and mines reflow together to a full next section after the lane-change allowance. Stored snapshots and route geometry remain unchanged.

Work cadence bands: lanes 1–2 **85–105**, lanes 3–4 **70–90**, lanes 5–6 **55–75 rpm**. Warm-up **75–95**. [Video research and limitations](../research/lanebreak/09-cadence-and-section-flow.md) distinguish observed Peloton examples from our chosen paired bands. Resistance ranges remain Light 15–56, Moderate 20–61, Hard 25–66, Challenging 30–71, Extreme 35–76.

Mines form five-wide rows outside the scoring lane: first row 1.8 road-seconds into a section, then every three, with a 1.8-second margin before the end. Avoiding one has no bonus; hitting one costs up to 1,800 with the existing negative popup, sound and explosion. Mines stay fixed to the route and never chase a rider. The pool is bounded to forty visible mines; authored schedules are bounded to 4,096. No mines in transition gaps, Incoming Fire or cooldown.

Course/scoring versions preserve older replay behavior and comparison keys. Generator 7 is retained only as a test fixture to exercise old snapshots. Updated tracks have new comparison identities; older history remains intact. Android accepts scoring versions 1–10. No database schema change. Graphics remains **Auto** by default.

## Verification

- 127 focused Godot tests passed (the 126-test sweep plus the final handoff/fade regression), including exact clearance timing, one award, separate explosion timing, zero-point held-back dodges, legacy scoring, continuous counter retargeting, all five mine-hit lanes and the safe target lane, full section lengths, generator coverage, lane reachability, records, audio persistence and HUD layout.
- Native 1280×720 Balanced captures show off-lane mine rows, continuous target guidance and an early `PASSED +1,800` popup with the score easing to its new total. The ten-second pass capture starts at active time 68 seconds; the popup is observed at frame 245, before the 77-second impact. The preview joins this with ten seconds of Collect/mine gameplay and has no audio track.
- Full-track audit passed: 116 tracks, 36.25 simulated hours, four additional speed traces and all five difficulties. No ordinary target-following gap exceeded 22 seconds; Nightfall's longest measured gap was 19.4 seconds for every duration. Guidance remained present and lane changes stayed within three lanes.
- Android: all 13 record tests passed; lint reported zero errors and 79 existing warnings. Signed ARM64 package `dev.digitalducktape.openride.neon`, code 27, uses real bike sensors with debugging disabled. The embedded game pack matches the final export and independently verifies course 11 / generator 8 / scoring 10, Auto graphics and the 40-mine pool.
- APK signature verified against the existing certificate SHA-256 `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`. APK size: 204,197,285 bytes. APK SHA-256: `5c9f3d13e3055bf374927a9f5232e94283295a7f7123716fd6cf564939bc1e16`. Prepared, not installed.

## Scope of validation

Headless rules simulation and native desktop captures do not establish sustained performance on the Peloton. PNG capture frame rates include readback and image encoding. This revision is prepared for installation; physical installation and pedalling are not part of this update request. Existing device data is untouched.

## Subsequent visual follow-up: superbike rear tyre

Implemented in `7b56a12` after APK 27 was built. The rear rubber is 0.64 design units wide instead of 0.16, with a fuller rounded profile, 0.485-radius / 0.40-wide rim, 0.76-wide axle and wider swingarm mounts. The 1.3 model scale makes the tyre 0.832 world units wide. Front-wheel contact geometry, rolling radius, scoring and course identity are unchanged. Rider and ghost share the separately cached rear mesh. See [the full geometry parameters](../lane-smash/PARAMETERS.md#superbike-rear-tyre).

Native Godot riding-camera and rear three-quarter close-up renders were inspected without script errors. This visual follow-up is committed source; it is **not included in the APK/checksum verified above**, and no subsequent device installation has occurred as part of this work.
