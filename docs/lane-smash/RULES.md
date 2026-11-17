# Rules, courses and scoring

For exact constants, source locations and the distinction between active time and road time, see [Parameters](PARAMETERS.md).

## Course selection

Each 10/15/20/30-minute duration has the same 25 names with duration-specific seeded courses. Random generation chooses its layout, theme, environment and fixed 3D route from a stored seed. Saved replays load the snapshot, not a newly generated replacement.

Names: Nightfall, Vector Run, Cold Circuit, Apex Protocol, Iron Horizon, Deep Current, Solar Array, Black Meridian, Velocity, Carbon Ridge, Arc Reactor, Zero Gravity, Afterburn, Steel Pulse, Blue Shift, Outer Ring, Ion Storm, Altitude, Dark Matter, Redline, Titan, Slipstream, Overdrive, Summit Relay, Event Horizon.

Only one lane has scoring targets at a time. Generator 9 opens with ten road-seconds of Collect in lane 1, then ten road-seconds of Pedal speed in lane 2. The first approach is three road-seconds; the lane-2 approach is six. Work then stays in lanes 3–6, visiting each work lane once per complete four-block wave in seeded order. No required jump exceeds three lanes, including attacks, returns and cooldown.

Collect and Pedal speed sections each span **ten road-seconds minimum**, measured at the 140-rpm speed cap; a slower rider takes longer. Power Bursts rotate through **five, six and seven road-seconds**. Ordinary work blocks pair a cadence section with Collect or a burst, with a nine-road-second lane-change approach and a two-road-second gap within the same lane, keeping the same block budget regardless of lane order. Shorter bursts shorten the block rather than leaving extra empty road. Partial final blocks never author a shortened section.

| Lane change | Empty approach at maximum speed | Gap within the same-lane block |
| --- | --- | --- |
| One lane | 9 s authored / 6 s after an attack | 2 s |
| Two lanes | 9 s authored / 7.5 s after an attack | 2 s |
| Three lanes | 9 s | 2 s |

Guidance always highlights the current or next target, including approaches and interruptions. Incoming Fire honors the next section as soon as its lane is announced, including the approach, and waits for its final marker before starting preparation. The finished lane stays highlighted during the 700 ms recap/fade; a later ordinary lane is never flashed in between. After the final explosion fades (1.2 seconds), ordinary play returns without the old eight-second idle tail. The next full, unplayed section starts after its resistance-change approach; its successors and off-lane mines are rebased together in runtime copies. A short fragment is never presented as a new section. The fixed route geometry itself is unchanged.

Work cadence steps down every two lanes:

| Section | Lanes 1–2 | Lanes 3–4 | Lanes 5–6 |
| --- | --- | --- | --- |
| Work | 85–105 rpm | 70–90 rpm | 55–75 rpm |
| Warm-up | 75–95 rpm | — | — |

These are Lane Smash's chosen bands, informed by Lanebreak footage rather than a claimed universal Peloton table. See [cadence research](../research/lanebreak/09-cadence-and-section-flow.md). Difficulty resistance ranges are unchanged.

**Cooldown follows active time without cutting sections short.** At one minute remaining, finish any section already underway before entering the runtime-only Collect tail. If an approach has already asked for another lane, deliver a full ten-road-second Collect there before stepping left by at most three lanes, then down toward lane 1. The remaining approach is preserved. No bursts, gunfire or road mines occur in the tail. The ride still ends at its selected duration, so a slow/stopped rider can have less time to descend. Saved course-11 snapshots retain the exact-minute cutover; the original course snapshot is never rewritten.

Named and random tracks use the same rules. Authored time, lane-exposure and cadence budgets stay within 4% across each duration's tested layouts; actual joules and points depend on inputs, attack timing and distance covered. Older snapshots retain their authored four-minute waves and old cooldown behavior.

## Steering and speed

| Difficulty | Lowest–highest resistance |
| --- | --- |
| Kid | 0–20 |
| Light | 15–56 |
| Moderate | 20–61 |
| Hard | 25–66 |
| Challenging, default | 30–71 |
| Extreme | 35–76 |

The five adult ranges have six equal seven-value lanes. Lane `n` (1–6) starts at `difficulty minimum + 7 × (n−1)` and ends six values later. The five adult ranges are Lanebreak's published Bike levels, and the seven-value lanes agree with every individual Lanebreak lane found (six, five of them read from the game's own display in review footage) (see [the range research](../research/lanebreak/06-difficulty-ranges.md)); `lane_smash_catalog_test.gd` pins the whole table. The displayed endpoints are inclusive. Out-of-range, fractional or invalid resistance does not select a scoring lane. A new lane must settle for 150 ms. Difficulty does not alter the course, visual grade or physical knob automatically.

**Kid** is a custom low-resistance difficulty starting at sensor value 0, with a **3.5-point lane step**, half the ordinary 7. Because readings are integers, lanes alternate four and three values: **0–3, 4–6, 7–10, 11–13, 14–17, 18–20**. The upper bound is exclusive at 21; out-of-range and fractional values do not score. The same mapping drives the lane dock, smooth steering, target prompts, mine contacts, rapid-bomb placement and scenery response. Existing adult/historical ranges stay exact. Kid keeps the same course, cadence, power, scoring and cooldown rules, and gets separate last/best/ghost comparisons through its `kid` difficulty key. Challenging remains the default. See [Kid specification](../specs/lane-smash-kid-mode.md).

Rules speed = `clamp(cadence / 140, 0, 1) × 60 km/h`. Position advances from that speed; faster riders encounter more sections during the same active duration. Roads are `minutes × 1,000 + 300` rules-metres long, exceeding the maximum reachable distance. Higher cadence cannot overrun the road.

The picture draws every rules-metre as **three** world metres (`NeonSpace.STRETCH`), so the road, scenery and sky pass three times faster than before for the same pedalling, and the HUD shows the speed and distance the picture has: `cadence × 0.8` mph, about **48 mph at 60 rpm, 77 mph at 96 rpm and 112 mph at 140 rpm**, and zero when stopped. Nothing in the rules changed: sections, scoring, ghosts and saved rides still work in rules-metres. This is a game-speed scale, not an estimate of physical road cycling speed.

## Current point scale

Scoring version 11 (course 12 / generator 9) adds committed lane handoffs and speed-weighted burst rewards. Scoring version 10 (course version 11) added immediate pass rewards, full-section handoffs and dense off-lane mines. It preserves the scoring-8 cadence sweet spot, **18×** point scale and machine-gun fire. Scoring 9 added lane-checked rapid bomb drops and the timed cooldown. Version 7 added machine-gun fire to cadence sections; version 6 multiplied the previous base scoring by 18. The calibration target is a typical **20-minute ride** around 150,000 points, not a fixed score for every duration or rider. The measured 25-track Challenging trace on generator 6 is in the [validation notes](../specs/lane-smash-v13-validation.md); generator 5 measured 173,216.08 and generator 4 147,760.88 with the same simulated rider. The scale has not changed between them: what changes is how much road carries sections, and from scoring 8 the sweet-spot bonus the simulated rider earns by holding the middle of every band. It uses 90 rpm cruise, cadence-band midpoint, 110 rpm bursts, resistance-dependent simulated watts, modest misses and gradual attack responses. Real sensor power and performance determine actual scores. Longer/shorter rides scale naturally.

| Section | Conditions | Points |
| --- | --- | --- |
| Gold bars / Collect | Settled in the marked lane; cadence at least 20 rpm | 180 points per valid road-second, proportional to distance traversed (10.8 points/metre) |
| Mint arrows / Pedal speed | Same lane/cadence floor, plus inclusive minimum–maximum rpm band | Same distance rate as Collect, only while inside the band |
| Violet Power Burst | Same target lane; cadence at least 20 rpm; measured power and speed | **18 points per five speed-weighted joules**: integrate W × (rpm / 90)²; rpm capped at 140. At equal W, a full burst at twice the cadence earns twice the points despite taking half as long |
| Machine-gun fire | During a cadence section, cadence outside the section's inclusive rpm band, in any lane | Lose up to **60** per round that lands; at most 15 rounds a section; zero floor; holding the band has no extra bonus |
| Red road bomb | Front-wheel position crosses bomb in its lane, outside Incoming Fire | Lose up to **1,800**; zero floor; avoiding a static road bomb has no bonus |
| Incoming blast: hit | At impact the rider overlaps its fixed full-width blast footprint | Lose up to **1,800**; zero floor |
| Incoming blast: passed | As soon as the whole rider clears the far edge of the marked blast after launch | **+1,800** |
| Incoming blast: held back | At impact the rider is safely behind the blast | **0**; no penalty |

At 150 W over a six-road-second burst, ideal complete-pass totals are about 2,520 points at 45 rpm, 3,360 at 60 rpm, 5,040 at 90 rpm, 6,720 at 120 rpm and 7,840 at 140 rpm. Tick/contact boundaries can change the displayed total slightly. Zero power, wrong-lane riding and cadence below 20 earn no burst points. At 90 rpm the old energy reward is unchanged; older scoring retains its unweighted energy formula. The current 25-track 20-minute Challenging calibration averages 156,973.6 points.

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

## Off-lane mines

Each Collect, Pedal speed and Power Burst section has rows of five mines: one in every lane except its authored target. The first row sits 1.8 road-seconds after the start; rows repeat every three road-seconds, with at least 1.8 road-seconds clear before the end. All six lanes are free of mines during approaches and lane changes. The target lane stays clear even if the rider is in the wrong lane; mines do not chase the bike. Incoming Fire and cooldown suppress road mines.

Each crossed mine uses the existing up-to-1,800-point penalty, zero floor, negative popup, explosion and sound. Avoidance earns no extra points. Simultaneous mines in different lanes never multiply a single contact penalty. Authoring is bounded to 4,096 hazards; only forty pooled mines can be rendered at once. Mine schedules and section reflow are deterministic and saved-course fingerprints remain immutable.

## Incoming Fire

Attacks begin around 75 seconds and recur about every three minutes, leaving the final minute clear. A nine-second preparation window precedes each attack. Its authored window is up to 35 seconds; current play returns after the second impact fades. A section already underway is completed before preparation begins; an attack that would intrude on the final-minute cooldown is omitted. The highlighted target varies through lanes 3–6; repeated consecutive authored attack lanes are avoided. A slow warm-up's first attack is clamped to a reachable work lane. Ordinary targets and road mines are suppressed during preparation and attack.

The first shot charges during the final two preparation seconds and fires at zone entry; the second charges at +16 seconds and fires at +18. Correct-lane shots retain nine seconds of flight, the fixed cadence-projected target, and the Pedal Faster/Pedal Slower escape challenge. Normal targets use the previous two seconds of cadence. Recommendations retain their existing 45–120 rpm bounds and substantial cadence change. Changing lanes alone does not evade a normal full-width blast.

**Wrong lane:** at either firing boundary, or when crossing into a pending blast's marked footprint, being outside the highlighted lane triggers a drop within 450 ms, without postponing an earlier scheduled impact. It locks one short strike at the rider's projected position and lane, smoothly redirects the existing projectile, and incurs one ordinary bomb penalty (up to 1,800 points). Steering afterward does not cancel that already-triggered strike. The highlight and left/right cues remain visible for the next shot. The close-range effect uses a compact lane-sized blast rather than three overlapping full-road explosions.

A normal safe pass earns 1,800 points immediately on crossing `targetMeters + 20 m blast half-length + 1.5 m rider margin`, without waiting for impact. Its popup and pass sound happen then; the projectile and distant explosion keep their scheduled impact time. Resolution is locked, so neither the later explosion nor a slowdown can award again. Course 10 and earlier retain impact-time settlement. Holding behind earns zero points; either earns avoidance star credit. Rapid strikes count as hits. Sensor interruptions freeze the preparation, flight and drop timers. Per-shot records include the rapid trigger and original target where applicable. Old course snapshots retain the lane-1, two-second-charge/nine-second-flight behavior, and old dodge scoring remains versioned.

## Stars

Finish the full selected duration to receive stars: **25% = one, 60% = two, 90% = three**. Ended/interrupted attempts receive zero stars.

The percentage is earned base target credit divided by available target credit for the sections actually encountered. Gold and cadence credit reflect valid distance; a burst's star credit is capped at the internal 150 W reference over eligible speed-weighted time. Available burst credit uses the same speed factor, so the speed reward does not change the power requirement for full star credit. Extra burst output raises points but cannot compensate for missed target credit elsewhere.

Every incoming shot adds 1,800 available target-credit points. Either safe dodge earns that credit, including a zero-point held-back dodge; a hit earns none. Following Pedal Slower therefore does not damage the star rating. Static road-bomb penalties reduce net points without directly subtracting star credit. Scaling both sides by 18 does not change thresholds.

Stars measure target completion, not medical fitness, FTP or comparison with other riders.

## Kid cadence targets (revision 22)

New Kid rides use 50% of each authored Pedal Speed minimum and maximum, rounded to the nearest whole rpm: warm-up 38–48, work lanes 1–2 43–53, lanes 3–4 35–45 and lanes 5–6 28–38. Scoring, the top prompt, local meter and gunfire all read these same saved endpoints. The sweet spot remains midpoint ±3 rpm. Named and random tracks use the same adjustment. Adult difficulties and old saved replays keep their original values.

This changes cadence eligibility, not measured sensors, road speed, spatial lengths, burst rewards or bomb escape recommendations. Riding at the lower targets naturally increases section and approach traversal time; the ride clock still ends at the selected duration. New Kid comparisons are separate from the former faster-target Kid rides.
