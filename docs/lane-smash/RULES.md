# Rules, courses and scoring

## Course selection

Each 10/15/20/30-minute duration has the same 25 names with duration-specific seeded courses. Random generation chooses its layout, theme, environment and fixed 3D route from a stored seed. Saved replays load the snapshot, not a newly generated replacement.

Names: Nightfall, Vector Run, Cold Circuit, Apex Protocol, Iron Horizon, Deep Current, Solar Array, Black Meridian, Velocity, Carbon Ridge, Arc Reactor, Zero Gravity, Afterburn, Steel Pulse, Blue Shift, Outer Ring, Ion Storm, Altitude, Dark Matter, Redline, Titan, Slipstream, Overdrive, Summit Relay, Event Horizon.

Only one lane has scoring targets at a time. Courses begin low, build, ease back, recover and repeat with varied lane ordering. A four-minute spatial pattern uses low lanes, high lanes, an easing phase and recovery; each minute has three 20-road-second lane blocks. Tracks share authored resistance exposure and section-time budgets while varying ordering/placement. Actual joules and points vary with sensor input.

Ordinary target lanes change every 20–47 seconds at 60–140 rpm; cadence zones span six road-seconds, about 6–14 actual seconds at those cadences. A 35-second Incoming Fire section temporarily replaces lane targets. The full audit enforces a 60-second maximum for ordinary target-lane changes, resetting that check during attacks.

## Steering and speed

| Difficulty | Lowest–highest resistance |
| --- | --- |
| Light | 15–56 |
| Moderate | 20–61 |
| Hard | 25–66 |
| Challenging, default | 30–71 |
| Extreme | 35–76 |

Each range has six equal seven-value lanes. Lane `n` (1–6) starts at `difficulty minimum + 7 × (n−1)` and ends six values later. The displayed endpoints are inclusive. Out-of-range, fractional or invalid resistance does not select a scoring lane. A new lane must settle for 150 ms. Difficulty does not alter the course, visual grade or physical knob automatically.

Game speed = `clamp(cadence / 140, 0, 1) × 60 km/h`, displayed in mph. Maximum is 37.3 mph. Position advances from that speed; faster riders encounter more sections during the same active duration. Roads are `minutes × 1,000 + 300` metres long, exceeding the maximum reachable distance. Higher cadence cannot overrun the road. This is a game-speed scale, not an estimate of physical road cycling speed.

## Current point scale

Scoring version 6 multiplies the previous base scoring by **18**. The calibration target is a typical **20-minute ride** around 150,000 points, not a fixed score for every duration or rider. The measured 25-track Challenging trace averaged **147,760.88** (137,462–156,977). It uses 90 rpm cruise, cadence-band midpoint, 110 rpm bursts, resistance-dependent simulated watts, modest misses and gradual attack responses. Real sensor power and performance determine actual scores. Longer/shorter rides scale naturally.

| Section | Conditions | Points |
| --- | --- | --- |
| Gold bars / Collect | Settled in the marked lane; cadence at least 20 rpm | 180 points per valid road-second, proportional to distance traversed (10.8 points/metre) |
| Mint arrows / Pedal speed | Same lane/cadence floor, plus inclusive minimum–maximum rpm band | Same distance rate as Collect, only while inside the band |
| Violet Power Burst | Same target lane; cadence at least 20 rpm; measured power | **18 points per five joules**, without a power-score ceiling; ten valid seconds at 150 W earns 5,400 |
| Red road bomb | Front-wheel position crosses bomb in its lane, outside Incoming Fire | Lose up to **1,800**; zero floor; avoiding a static road bomb has no bonus |
| Incoming blast: hit | At impact the rider overlaps its fixed full-width blast footprint | Lose up to **1,800**; zero floor |
| Incoming blast: passed | At impact the rider is safely beyond the blast | **+1,800** |
| Incoming blast: held back | At impact the rider is safely behind the blast | **0**; no penalty |

The final target shows the section's earned total where that section ends. This popup is a recap, not a second bonus. Fractional points are retained internally (`100,000` subpoints per point), while display/results use whole points. Visual shattering itself does not bypass eligibility.

Distance-credit multiplication uses double precision before flooring for new scoring, preventing int64 overflow on long sections after the scale increase. Results remain deterministic across render rates. Old scoring retains its original arithmetic/scale. Gross earnings and accumulated penalties remain monotonic even when the net total falls.

## Incoming Fire

Attacks begin around 75 seconds and recur about every three minutes, leaving the final minute clear. Each lasts 35 seconds. Use lane 1 and respond to Pedal Faster/Pedal Slower; changing lanes cannot evade a full-width blast. Ordinary scoring objects and static road bombs are suppressed during the attack.

Each section has two shots: lock at +6/+21 seconds, charge two seconds, fly nine seconds, impact eleven seconds after lock. The target projects forward from the previous two seconds of cadence and then stays fixed. Recommendations use a substantial cadence change, normally about 35–40 rpm, bounded to 45–120 rpm. The prediction gauge estimates whether holding current pace will escape. Passing or staying behind must clear the 20 m half-length plus 1.5 m rider radius. The shot never homes after locking.

The label changes to Keep This Pace once the projected escape is safe. Sensor interruptions freeze the clock, trajectory and collision evaluation. Per-shot records retain target, input context, outcome, actual points and impact position. Scoring v5 snapshots retain +100 for either dodge; v6 uses the pass-only bonus above.

## Stars

Finish the full selected duration to receive stars: **25% = one, 60% = two, 90% = three**. Ended/interrupted attempts receive zero stars.

The percentage is earned base target credit divided by available target credit for the sections actually encountered. Gold and cadence credit reflect valid distance; a burst's star credit is capped at the internal 150 W reference over eligible time. Extra burst output raises points but cannot compensate for missed target credit elsewhere.

Every incoming shot adds 1,800 available target-credit points. Either safe dodge earns that credit, including a zero-point held-back dodge; a hit earns none. Following Pedal Slower therefore does not damage the star rating. Static road-bomb penalties reduce net points without directly subtracting star credit. Scaling both sides by 18 does not change thresholds.

Stars measure target completion, not medical fitness, FTP or comparison with other riders.
