# Rules, courses and scoring

## Course selection

Each 10/15/20/30-minute duration has the same 25 names with duration-specific seeded courses. Random generation chooses its layout, theme, environment and fixed 3D route from a stored seed. Saved replays load the snapshot, not a newly generated replacement.

Names: Nightfall, Vector Run, Cold Circuit, Apex Protocol, Iron Horizon, Deep Current, Solar Array, Black Meridian, Velocity, Carbon Ridge, Arc Reactor, Zero Gravity, Afterburn, Steel Pulse, Blue Shift, Outer Ring, Ion Storm, Altitude, Dark Matter, Redline, Titan, Slipstream, Overdrive, Summit Relay, Event Horizon.

Only one lane has scoring targets at a time. Courses begin low, build, ease back, recover and repeat with varied lane ordering. A four-minute spatial pattern (generators 5 and 6) runs as intervals; each road-minute has three 20-road-second lane blocks:

| Road-minute | Lanes | Role |
| --- | --- | --- |
| 1 of 4 | 1 → 2 → 3 | Build (the very first block of a ride is the warm-up) |
| 2 of 4 | 4, 5 and 6 in a varied order | The hardest minute |
| 3 of 4 | 5, 4 and 3 in a varied order | Ease back |
| 4 of 4 | 2 → 1 → 2 | Recovery |

**Sections are separated (generator 6).** Each block holds two sections with empty road before the first and between the two, so every section has a clear start and end:

| Block | First | Second |
| --- | --- | --- |
| Burst block | Cadence section, 7 road-seconds | Power Burst, 6 road-seconds |
| Any other block | Gold bars, 6 road-seconds, and a cadence section, 7 road-seconds, in either order (chosen by the track's seed) | |

That is 13 road-seconds of sections and 7 of empty road in every block, so every track still carries the same effort whichever lane lands in which block. The 7 seconds are split at random between the gap that opens the block (3 to 5 road-seconds; the lane changes there, so it is never under 3) and the gap between its two sections (4 down to 2). At 95 rpm a road-second is about 1.5 real seconds, so the gaps are about 3 to 7.5 seconds of clear road. Nothing scores in a gap and nothing is lost in one; the instruction panel counts down to the next section.

Bursts come once a road-minute and twice in the hardest minute (its first and last blocks), which puts them 40 road-seconds apart through the work, and never in the recovery minute. (Generator 5 ran three sections a block with no gaps inside it: gold bars, an eight-second cadence section, then more bars or a burst.)

Cadence targets follow the kind of effort, not the lane number. Every band is 20 rpm wide:

| Section | Lane 1 | Lane 2 | Lane 3 | Lane 4 | Lane 5 | Lane 6 |
| --- | --- | --- | --- | --- | --- | --- |
| Work | 95–115 | 90–110 | 85–105 | 80–100 | 70–90 | 65–85 |
| Warm-up and recovery | 75–95 | 75–95 | — | — | — | — |

Light lanes are fast spins and heavy lanes are climbs, so effort still rises with the lane without asking for a sprint cadence against the heaviest resistance. (Generator 4 used `60 + 4 × lane` to `+20`, which was a slow 60–80 in the lightest lane and 80–100 against the heaviest.) Twenty-wide bands and the 65–105 span match the Lanebreak cadence targets reported in [the range research](../research/lanebreak/06-difficulty-ranges.md).

Tracks share authored resistance exposure and section-time budgets while varying ordering/placement. Actual joules and points vary with sensor input.

Ordinary target lanes change every 20–47 seconds at 60–140 rpm (about 29 seconds at 95 rpm); cadence zones span seven road-seconds, about 9–13 actual seconds when ridden inside their band, and every cadence zone is strafed by machine-gun fire (below). A 35-second Incoming Fire section temporarily replaces lane targets. The full audit enforces a 60-second maximum for ordinary target-lane changes, resetting that check during attacks.

## Steering and speed

| Difficulty | Lowest–highest resistance |
| --- | --- |
| Light | 15–56 |
| Moderate | 20–61 |
| Hard | 25–66 |
| Challenging, default | 30–71 |
| Extreme | 35–76 |

Each range has six equal seven-value lanes. Lane `n` (1–6) starts at `difficulty minimum + 7 × (n−1)` and ends six values later. The five ranges are Lanebreak's published Bike levels, and the seven-value lanes agree with every individual Lanebreak lane found (six, five of them read from the game's own display in review footage) (see [the range research](../research/lanebreak/06-difficulty-ranges.md)); `lane_smash_catalog_test.gd` pins the whole table. The displayed endpoints are inclusive. Out-of-range, fractional or invalid resistance does not select a scoring lane. A new lane must settle for 150 ms. Difficulty does not alter the course, visual grade or physical knob automatically.

Rules speed = `clamp(cadence / 140, 0, 1) × 60 km/h`. Position advances from that speed; faster riders encounter more sections during the same active duration. Roads are `minutes × 1,000 + 300` rules-metres long, exceeding the maximum reachable distance. Higher cadence cannot overrun the road.

The picture draws every rules-metre as **three** world metres (`NeonSpace.STRETCH`), so the road, scenery and sky pass three times faster than before for the same pedalling, and the HUD shows the speed and distance the picture has: `cadence × 0.8` mph, about **48 mph at 60 rpm, 77 mph at 96 rpm and 112 mph at 140 rpm**, and zero when stopped. Nothing in the rules changed: sections, scoring, ghosts and saved rides still work in rules-metres. This is a game-speed scale, not an estimate of physical road cycling speed.

## Current point scale

Scoring version 8 (course version 9) keeps the **18×** scale and machine-gun fire and adds the cadence sweet spot (below). Version 7 added machine-gun fire to cadence sections; version 6 multiplied the previous base scoring by 18. The calibration target is a typical **20-minute ride** around 150,000 points, not a fixed score for every duration or rider. The measured 25-track Challenging trace on generator 6 is in the [validation notes](../specs/lane-smash-v13-validation.md); generator 5 measured 173,216.08 and generator 4 147,760.88 with the same simulated rider. The scale has not changed between them: what changes is how much road carries sections, and from scoring 8 the sweet-spot bonus the simulated rider earns by holding the middle of every band. It uses 90 rpm cruise, cadence-band midpoint, 110 rpm bursts, resistance-dependent simulated watts, modest misses and gradual attack responses. Real sensor power and performance determine actual scores. Longer/shorter rides scale naturally.

| Section | Conditions | Points |
| --- | --- | --- |
| Gold bars / Collect | Settled in the marked lane; cadence at least 20 rpm | 180 points per valid road-second, proportional to distance traversed (10.8 points/metre) |
| Mint arrows / Pedal speed | Same lane/cadence floor, plus inclusive minimum–maximum rpm band | Same distance rate as Collect, only while inside the band |
| Violet Power Burst | Same target lane; cadence at least 20 rpm; measured power | **18 points per five joules**, without a power-score ceiling; ten valid seconds at 150 W earns 5,400 |
| Machine-gun fire | During a cadence section, cadence outside the section's inclusive rpm band, in any lane | Lose up to **60** per round that lands; at most 15 rounds a section; zero floor; holding the band has no extra bonus |
| Red road bomb | Front-wheel position crosses bomb in its lane, outside Incoming Fire | Lose up to **1,800**; zero floor; avoiding a static road bomb has no bonus |
| Incoming blast: hit | At impact the rider overlaps its fixed full-width blast footprint | Lose up to **1,800**; zero floor |
| Incoming blast: passed | At impact the rider is safely beyond the blast | **+1,800** |
| Incoming blast: held back | At impact the rider is safely behind the blast | **0**; no penalty |

The final target shows the section's earned total where that section ends. This popup is a recap, not a second bonus. Fractional points are retained internally (`100,000` subpoints per point), while display/results use whole points. Visual shattering itself does not bypass eligibility.

Distance-credit multiplication uses double precision before flooring for new scoring, preventing int64 overflow on long sections after the scale increase. Results remain deterministic across render rates. Old scoring retains its original arithmetic/scale. Gross earnings and accumulated penalties remain monotonic even when the net total falls.

## The cadence sweet spot

From course version 9 / scoring version 8, the middle of a cadence section's range pays a little more. The sweet spot is the middle of the band plus and minus 3 rpm (`NeonRules.SWEET_HALF_RPM`): 82–88 in a 75–95 section, 92–98 in an 85–105 one. Road covered in the target lane with cadence inside it earns the section's ordinary distance credit and a **20% bonus** on that credit (`SWEET_BONUS_PERCENT`); road covered elsewhere in the band earns the ordinary credit only. Both edges of the sweet spot count.

- The bonus is score only. Stars rate base credit, which is the same anywhere in the band, so the sweet spot can never cost a star and is never needed for one.
- It is computed from the same integer distance as the section's credit, so the result is identical at any frame rate.
- A ride saved under scoring 7 or earlier has no sweet spot and replays exactly as it was.
- The result carries `sweetSpot: {bonusUnits}`, the ride's total bonus; each cadence section's state carries `sweetTravelUnits` and `bonusUnits`.

Lanebreak's footage shows the gauge this is built around (a range with a marker for the rider's cadence; see [the range research](../research/lanebreak/06-difficulty-ranges.md)). Whether Lanebreak itself pays more for the middle could not be confirmed from footage or reviews; the bonus here is this game's rule.

## Machine-gun fire (cadence sections)

From course version 8 / scoring version 7, a raider on a hover sled strafes the road for the whole of every cadence ("Pedal speed") section. Two lines of fire rake the road, one ahead of the front wheel and one behind the tail; the gap between them is the section's cadence band made visible. Pedal toward the top of the band and the leading line closes on the bike; toward the bottom and the trailing line does. Outside the band a line reaches the bike and rounds land. Both band endpoints are safe.

| Rule | Value |
| --- | --- |
| Warning at the start of the section | **2.0 s** of active time: the fire lands wide and walks in; nothing can hit |
| First round | after **0.6 s** outside the band |
| Further rounds | one every **0.5 s** while still outside |
| Cost | up to **60 points** a round (whole points; the score never goes below zero) |
| Limit | **15 rounds** per section (900 points), so stopping to rest cannot drain a ride |
| Forgiveness | time back inside the band drains exposure twice as fast as it built; brushing the edge costs nothing |

Lane does not matter: the fire covers the whole road, so only cadence keeps the rider in the gap. The lane and cadence rules for earning the section's own points are unchanged, as is everything below 20 rpm (no section points; the fire still lands). The rules tick decides every round at 10 ms resolution from the same sensor samples as everything else, so 30/60/120 fps give identical outcomes; a sensor interruption freezes it with the rest of the ride. Rounds add to the result's penalties and are also reported separately (`gunfire.hits`, `gunfire.penaltyUnits`). Like road bombs they lower points but do not subtract star credit. There is no gunfire during Incoming Fire, and none in older snapshots.

A rider who holds every band is never hit, so the representative calibration trace (band midpoint) is unchanged.

## Incoming Fire

Attacks begin around 75 seconds and recur about every three minutes, leaving the final minute clear. Each lasts 35 seconds. Use lane 1 and respond to Pedal Faster/Pedal Slower; changing lanes cannot evade a full-width blast. Ordinary scoring objects and static road bombs are suppressed during the attack.

Each section has two shots: lock at +6/+21 seconds, charge two seconds, fly nine seconds, impact eleven seconds after lock. The target projects forward from the previous two seconds of cadence and then stays fixed. Recommendations use a substantial cadence change, normally about 35–40 rpm, bounded to 45–120 rpm. The prediction gauge estimates whether holding current pace will escape. Passing or staying behind must clear the 20 m half-length plus 1.5 m rider radius. The shot never homes after locking.

The label changes to Keep This Pace once the projected escape is safe. Sensor interruptions freeze the clock, trajectory and collision evaluation. Per-shot records retain target, input context, outcome, actual points and impact position. Scoring v5 snapshots retain +100 for either dodge; v6 uses the pass-only bonus above.

## Stars

Finish the full selected duration to receive stars: **25% = one, 60% = two, 90% = three**. Ended/interrupted attempts receive zero stars.

The percentage is earned base target credit divided by available target credit for the sections actually encountered. Gold and cadence credit reflect valid distance; a burst's star credit is capped at the internal 150 W reference over eligible time. Extra burst output raises points but cannot compensate for missed target credit elsewhere.

Every incoming shot adds 1,800 available target-credit points. Either safe dodge earns that credit, including a zero-point held-back dodge; a hit earns none. Following Pedal Slower therefore does not damage the star rating. Static road-bomb penalties reduce net points without directly subtracting star credit. Scaling both sides by 18 does not change thresholds.

Stars measure target completion, not medical fitness, FTP or comparison with other riders.
