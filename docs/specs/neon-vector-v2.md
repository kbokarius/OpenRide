# NEON VECTOR — revision 2

Requested 2026-11-13 after hands-on preview. Supersedes the v1 presentation, sparse pickup layout and silence-only choice. Existing saved v1 courses retain their original scoring when replayed.

## Presentation

- A real 3D, banked six-lane road curves and climbs through space. The camera follows the road. Reduced motion flattens the curves.
- Scoring bars, beveled arrows and rotating power crystals are raised meshes anchored to absolute course positions. They continue passing the rider after section entry. Near/far opacity transitions prevent popping.
- Gold bars identify standard points; mint arrows identify cadence bands; violet crystals identify power bursts. The HUD states the relevant target as text.
- Lane numbers and resistance bands occupy a padded bottom dock. Metric units stay close to their values and align across columns.
- No app-owned scrollbar is visible. Swipe, wheel and keyboard navigation still reach overflow content; primary actions remain fixed in view.

## Scoring version 2

| Section | Requirement | Award |
| --- | --- | --- |
| Cruise | Stay in the target lane and pedal at least 20 rpm | 10 points per second |
| Cadence | Stay in the lane and between the inclusive minimum and maximum rpm | 10 points per valid second |
| Power burst | Stay in the lane and keep pedalling | Total measured energy / 5 joules per point |

Power is integrated on 10 ms ticks from timestamped sensor readings. A 10-second burst at 150 W gives 300 points; 300 W gives 600. There is no score cap or upper cadence target in a burst. Reference power establishes the burst's star target, not a ceiling on points. Star credit for a burst is capped at its target, so excess output cannot replace missed cadence/lane targets. Invalid or stale samples, pause and unsettled lane changes earn nothing. Flow/Surge remains a single locked choice with 100%/125% rewards.

Each minute has five sections: cruise at 3–16 seconds, cadence or burst at 16–30, cruise at 30–36, cadence at 39–51, and cruise at 54–60. Three-second lane transitions preserve reachability, leaving scoring available for 85% of the course. Bursts occur only in work phases, last 14 seconds and have at least 30 seconds recovery. Daily generator g2 shifts whole minute blocks while preserving every transition and gentle recovery lanes.

## Audio

Original instrumental electronic music at 138 bpm, rendered to a looping Ogg asset. Reuse the shared audio mixer, pause handling and external-audio policy. A Music on/off option is available in Style & history and Pause. Scoring never depends on audio timing.

## Compatibility and validation

Course schema stays additive at 1; new authored content is courseVersion 2 and scoringVersion 2. CourseVersion 1 snapshots keep scoringVersion 1 and old comparison keys. Daily g1 snapshots remain replayable. Verify deterministic energy scoring, cadence endpoints, dense-course reachability, old replay identity, hidden scrollbars with reachable overflow, 3D travel and fades, music/mute, pause/resume, signed APK updates and preserved history. Desktop/emulator evidence does not establish original Bike GPU performance or sensor compatibility.
