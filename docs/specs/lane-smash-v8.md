# Lane Smash — revision 8

## Bombs and impact effects

Newly generated tracks use course version 5, generator version 3 and scoring version 4. Each red bomb costs **100 points on contact**, capped at the whole points the rider currently has. Scores cannot go below zero. With no points to lose, the popup says **BOMB HIT** instead of −0. A bomb is resolved once, whether hit or avoided.

Bombs are fixed to the course, with their nearest surface aligned to the front-wheel contact distance. The deterministic 10 ms rules tick checks the selected resistance lane when the rider crosses that distance; render frame rate cannot duplicate or change the penalty. The bomb disappears immediately and a red negative-points popup floats from the hit location. A local flash, expanding shockwave and scattered debris fade out around it. Ordinary markers and section completions receive the same effects at smaller intensities.

Placement is reproducible from the track seed. Bombs begin after the first 60 road-seconds, appear within gold-bar sections, and are separated by at least 45 road-seconds in generated content. They occupy an adjacent lane, never the active scoring lane. Following the targets therefore always has a clear route. Track validation rejects hazards that overlap the scoring lane, use unsupported penalties or have malformed timing.

The scene has fixed capacity: 192 debris pieces, 12 shockwaves/flashes, and 12 visible bomb assemblies. Repeated effects recycle those slots; no per-hit scene spawning or unbounded particles are used. Debris expires after 0.65 seconds, shockwaves after 0.6 seconds and the central flash after 0.22 seconds. Effects do not shake the camera or flash the full screen.

## Scores, stars and saved rides

The result stores `earnedScoreUnits`, `penaltyUnits` and the net `scoreUnits`. Net score equals earned minus penalties. Checkpoints require elapsed time, earned points and cumulative penalties to move forward, while allowing the net score to decrease. Completed ghosts can include these legitimate decreases. Ghost rows must consistently use either the legacy three-column format or the distance-based four-column format; mixed traces are rejected before playback.

Bombs reduce points, including the score used to select the best ride. Stars retain their existing meaning: weighted target credit for the road actually reached, with thresholds of 25%, 60% and 90% and completion required. Bomb penalties do not directly reduce that base-credit percentage. Missing targets while riding in a bomb lane still reduces target credit normally.

Old course snapshots remain saved and replayable under their original scoring version. Revision 4 courses retain scoring version 3 and their original comparison identity. New bomb courses have separate last/best comparisons; a previous bomb-free score cannot become a new bomb-course record. No Room schema migration is needed: the new totals live in the existing versioned JSON payload.

## Stability and rendering

The visible road is divided into five reusable 144-metre chunks. A chunk contains 96 steps and shares its exact boundary vertices with its neighbor. Only the newly needed chunk is rebuilt, approximately once every 8.6 seconds at maximum speed, rather than rebuilding the entire visible road every 1.5 metres. Camera motion, road coordinates, transparency, lane lines and scoring placement remain fixed to the original route. Path-span lookup uses binary search without changing interpolation.

The renderer caches the actual immutable course dictionary rather than only the course ID. Loading a saved snapshot with the same ID correctly rebuilds its stored geometry. Course loading rejects invalid geometry lengths, speed limits, flags, seeds and path values before allocating a route. Saved replay settings are validated before entering the game.

History lists load full snapshots one at a time and keep only compact metadata for display. They omit ghost samples, course snapshots and event-state arrays. Exact snapshots and traces remain available for replay and best-ride playback. Starting a ride no longer performs an unnecessary full-history query.

## Track audit contract

Keep 25 named tracks for each 10/15/20/30-minute block, seeded random generation, eight palettes and four backgrounds. All tracks retain one scoring lane, six resistance lanes, short cadence sections and alternating build/ease/recovery blocks. Authored resistance exposure and section budgets are equal across tracks of the same duration; actual rider output varies. Lane changes remain frequent across the normal 60–140 rpm range. The five accepted difficulty ranges and 140 rpm / 60 km/h movement cap are unchanged.

## Build

Version code 16, `1.2.0-lane-smash.8`, package `dev.digitalducktape.openride.neon`, unchanged signing identity. See [validation](lane-smash-v8-validation.md) and the [installation guide](../LANE_SMASH.md). Physical Peloton performance and sensor compatibility still require testing on the user's tablet.
