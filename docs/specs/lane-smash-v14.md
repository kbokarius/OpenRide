# Lane Smash revision 14 — resistance steering and readable effort zones

Updated November 13, 2026. Builds on Claude's completed revision 13 (`e762a2f`), preserving its motorcycle, cadence gauge, soundtrack, attacks, graphics tiers and scoring. Android version `1.2.0-lane-smash.14`, APK code 22.

## Request

- Make power bursts brighter, with unmistakable starts, lengths and ends.
- Widen lanes; show smooth resistance-driven travel inside each lane and a quick shift across its resistance threshold.
- Fade a distinct highlight onto the lane the rider needs, and show left/right correction arrows.
- Learn from Peloton Lanebreak footage without importing its assets.

## Reference and interpretation

Reviewed the official launch footage embedded in [ustwo's Peloton case study](https://ustwo.com/work/peloton/), including the resistance/lane-change sequence and the cadence and breaker floor treatments. The [embedded launch film](https://videos.ctfassets.net/ve81k805bx04/qBJxB7GXF4LXLo83VXUJn/a00994be80484b7a5e93eeaec47659e9/LaneBreak-Feature-Launch-16x9-H264.mp4) was inspected at multiple times. It shows a resistance-steered rider, bright bounded effort lanes and charging feedback. The exact dimensions, timing, violet treatment and text below are Lane Smash design decisions, not claims about Peloton's implementation. The previously supplied YouTube URL was unavailable through the current page fetch; the official film supplied the visual reference instead.

## Steering

`LaneSmashSteering` owns presentation state only; it does not change sensor input, lane eligibility or points.

| Property | Behavior |
| --- | --- |
| Lane width | 4.2 world metres, up from 3.0 (40% wider) |
| Resistance bands | Existing five difficulties, six lanes, seven integer resistance values per lane |
| Travel inside a band | Band minimum maps to lane centre −0.28 lane widths; midpoint to centre; maximum to centre +0.28 |
| Motion | Exponential easing, rate 11/s within a lane; rate 28/s for 0.18 seconds after crossing a threshold |
| Threshold | First resistance value in the next band changes the destination immediately; the camera never reshapes the route |
| Outside course range | Clamp the rendered motorcycle to the outermost in-lane position; existing rules still award no lane credit |
| Non-finite input | Hold the last visual position; suppress the direction cue |
| Ghost | Existing traces store a lane, not within-band resistance, so the best-ride ghost remains centred in that lane |

The wider road carries wider bars, cadence arrows, beds and finish gates. Gantries and surrounding motes move outward. Camera setback is 17.5 m and height 7.4 m so the outer-lane motorcycle remains in view; scenery stays alive at least 40 m behind the rider. The cadence gauge moves inward when the outer edge lacks room, with hysteresis, and leaves 132 stage pixels between its edge and the motorcycle anchor.

## Lane guidance

The current section is the target, or the next section once its start is within four road-seconds. During Incoming Fire the existing escape lane remains lane 1. No direction cue appears without a target or during an input interruption.

Six scalar weights crossfade over 0.32 seconds. The road shader uses those weights to draw an ice-blue wash and inset edge lines directly on the existing deck; there is no floating overlay or extra road mesh. Between targets the old wash fades out while the new one fades in.

The small prompt below the main ride instruction uses the shared menu shape and font:

- Too much resistance: **MOVE LEFT / LESS RESISTANCE**, with animated left chevrons.
- Too little resistance: **MOVE RIGHT / MORE RESISTANCE**, with animated right chevrons.
- Anywhere within the target band's minimum and maximum: fade the prompt away.

Direction reversal fades out before fading in with the other arrow. Reduced Motion removes the pop/chevron motion but keeps fades and readable guidance. The prompt stays in one place instead of following the rider across the cadence gauge.

## Power burst treatment

- Saturated violet bed with baseline opacity 0.76; visible at zero charge, on every track palette and without bloom.
- Pale violet/white side rims, a dark outer hairline, and fixed-width white start/end caps.
- Diagonal etching fixed to world distance; it passes under the rider rather than following the camera.
- Existing valid-output charge front, strands and energy waves brighten the bed as the section fills.
- The outer triangular finish gate remains full size from approach; the inner rings grow with accumulated charge.
- The existing final-contact explosion, earned-point celebration and exact section boundary are retained.

Cadence floors remain mint, ordinary bars remain gold, and burst zones remain violet. Course version 9, generator 6, scoring 8, difficulty ranges, saved records and comparison fingerprints do not change.

## Implementation and cost

Reuses the road shader, section meshes, material instances and marker pools. No new viewports, lights, audio players, physics bodies or per-frame road rebuilds. Adds six interpolated lane weights, one uniform lookup per deck fragment and a small drawn HUD cue. Power caps and etching use derivatives for distance filtering. The wider geometry has the same vertex/instance count; the existing quality tiers still apply.

## Validation

See [revision 14 validation](lane-smash-v14-validation.md) for executed checks, artifacts and device limits.
