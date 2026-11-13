# Lane Smash — revision 3 specification

Date: November 13, 2026. Supersedes the NEON VECTOR presentation and new-ride catalog. Historical course snapshots and comparison identities remain readable.

## 1. Product scope

A subscription-free resistance-controlled cycling game inside the OpenRide fork for an Original Peloton Bike. Touchscreen setup; physical resistance knob selects the lane. No music synchronization, instructor content, cosmetic unlocks, head tracking or automatic resistance control. Display name **Lane Smash**, with a space; internal ID `neon_vector` and installed package remain stable.

## 2. Ride selection

- Duration: 10, 15, 20 or 30 minutes.
- Twenty-five named tracks per duration, 100 total; deterministic seeded random generator.
- Five difficulties: Light 15–56, Moderate 20–61, Hard 25–66, Challenging 30–71, Extreme 35–76. Default Challenging, per rider preference.
- Six lanes, seven inclusive integer resistance values per lane. Exact table and evidence: [difficulty research](../research/lanebreak/06-difficulty-ranges.md).
- Track layout stays identical across difficulty choices. Difficulty changes resistance, not the course seed.
- Track rows show last attempt and completed best for the exact comparison identity. Partial last attempts are marked. Statistics include records beyond the latest-50 history list.
- Track selector scrolls, with no visible scrollbar. Duration/difficulty/start controls remain fixed.
- No user-facing reference power control. New tracks use 150 W internally only as a rating reference; actual burst points remain uncapped energy-based rewards.

## 3. Distance, duration and track coverage

The 10 ms rules loop integrates game distance from delivered cadence. 140 rpm reaches 60 km/h (37.28 mph); higher cadence does not exceed this speed. Render frame rate cannot change distance or score. Fractional micrometres carry across ticks.

Duration remains fixed active time. Every track has `minutes * 1000 + 300` metres of road, enough for maximum speed throughout plus a buffer. Speed/distance display uses mph and miles; ghost gap uses feet. These are game-travel units, not an estimate of outdoor cycling physics. OpenRide exposes mph but no Peloton system unit preference.

CourseVersion/scoringVersion 3 timestamps encode spatial positions normalized to maximum speed. Cadence changes the portions encountered by a given time. Higher target lanes progressively steepen the road; curves, banking and grade are smoothed. Reduced motion softens this geometry.

## 4. Scoring

Only one target lane exists at each course position. Settling requires 150 ms in a valid lane. Cadence under 20 rpm earns no points.

| Road objects | Requirement | Reward |
| --- | --- | --- |
| Gold bars | Pedal in target lane | Continuous valid distance through the section |
| Mint arrows | Target lane and inclusive minimum/maximum rpm | Continuous valid distance within the speed band |
| Violet power crystals | Pedal in target lane; measured positive output | One point per five joules, without an upper score ceiling |

Stars use only encountered target portions and require completing the selected duration. Thresholds: 25%, 60%, 90%. Excess burst output cannot compensate for other missed targets. Pure rules own awards; rendering cannot change the score.

Events recur throughout the road. Ordinary bars occur every 600 normalized milliseconds, arrows at the same spacing, crystals every 850 milliseconds. Section gaps are at most three normalized seconds. At low cadence the physical gap takes longer to traverse.

## 5. Rider and impacts

The rider uses a procedural articulated human on a fighter-inspired bicycle: angular fairings, aero wheels, swept fork, rear fins, twin light pods. One crank revolution matches one measured cadence revolution. Ghost uses the same silhouette with transparency.

All three marker types disappear on contact at the front tire, using the wheel reach and marker's longitudinal extents. Lateral overlap is required; a swept interval prevents skipped hits between frames. Side entry while the front wheel overlaps an object also counts. Each marker explodes at most once. The pool holds at most 192 world-space fragments fading over 0.65 seconds.

Visual shattering is independent of score eligibility: touching an arrow at the wrong cadence still shatters the object, but earns no points for that interval. The renderer cannot award a bonus for collisions. Missed objects in other lanes stay intact. No cyan cross-line or rider trail.

## 6. Background and audio

Eight palettes: Arctic, Cobalt, Copper, Titanium, Petrol, Amber, Ember, Glacier. Four psychedelic shader modes: Prismatic flow, Kaleidoscope, Liquid aurora, Vortex. Named tracks retain their authored combination; random tracks vary palette and background independently, with all 32 combinations reachable. Saved seeds preserve the combination.

Cadence smoothly controls flow speed; normalized resistance changes twist and hue. Effects remain behind the road and HUD. No flying scenery meshes. Reduced motion uses 22% flow speed, reduced brightness and softened road movement. A single sky shader with a low-cost lighting pass replaces floating structures.

**Night Drive** is an original 128 BPM, 64-bar, 120-second electronic loop. Deep bass, restrained acid pulses, minor pads and industrial percussion; no third-party samples. AudioDirector controls playback/muting/looping, independent of scoring.

## 7. Best-ride ghost

Save completed ghosts at 10 Hz as `[activeMs, lane, scoreUnits, distanceMm]`. Interpolate at the current ride's active time. Best means highest score among completed matching course/difficulty/scoring identities, not most recent attempt.

Show the bike at actual course distance, with fades near overlap and at the visibility edges. Visible range is approximately five metres behind to 85 metres ahead. The HUD keeps gap and score difference when the bike is too far away. Simulation/demo records are isolated from real rider history.

## 8. Clear and stable interface

Rajdhani SemiBold, dark panels, restrained outlines. No visible scrollbars. Six lane numbers and resistance ranges remain in the lower dock. Remove duplicate lane/range text above the road.

| Previous prompt | Replacement |
| --- | --- |
| PEDAL UP | PEDAL FASTER |
| EASE CADENCE | PEDAL SLOWER |
| ON TARGET | KEEP THIS SPEED |
| TURN RIGHT | INCREASE RESISTANCE |
| TURN LEFT | LOWER RESISTANCE |
| HOLD | STAY IN THIS LANE |
| CADENCE section heading | PEDAL SPEED |
| BUILD POWER | PEDAL FASTER, with section points |

Live score, speed, distance, ghost gap and ride metrics update once per second. Section transitions update instructions immediately. No repeated text fade on every scoring tick. Road, cyclist, ghost and fragments remain full-frame animations.

## 9. No manual pause

After starting, finish the duration or choose **End Ride** and confirm. The timer runs during confirmation and while coasting. P cannot pause; Android Back opens End confirmation. Music-panel interaction does not pause Lane Smash. Native freewheel pause is disabled only for the active Lane Smash plan and restored afterwards.

Sensor silence beyond 1.5 seconds, invalid input, lost sample history or a display stall beyond 250 ms freezes scoring. After one second of healthy data, recover automatically with a three-second unscored countdown. No manual Resume option. Storage failures can show **Retry save** or ending. Technical recovery does not grant points for missing data.

## 10. Persistence and delivery

Persist before play, every five seconds and at interruption/end. Partial/interrupted attempts cannot become best rides. Kotlin reads/writes on a serial IO mailbox, never the render thread. Native and desktop validation bound ghost size, speed and monotonic data. Room schema remains version 9; no database migration in this revision.

Android build: package `dev.digitalducktape.openride.neon`, code 11, version `1.2.0-lane-smash.3`, label Lane Smash, real sensor flavor, ARM64, API 29 minimum. Install in place using the same signing key; backup first. Physical Bike sensor compatibility and a sustained ride remain unverified. [Installation guide](../LANE_SMASH.md#installing-the-fork-on-the-bike).
