# Lane Smash — revision 6

## Requested result

A fixed roller-coaster course that the cyclist actually travels along, with natural curves, loops and twists. Remove the pinched horizon and the effect of a stationary foreground connected to a moving, reshaping road end. Add slight road transparency. Make the route random in its design, slower in its transitions and reproducible as part of each track's configuration.

## Fixed world geometry

`LaneSmashPath.gd` generates a versioned set of orientation control points at absolute course distances. They are stored in the course snapshot under `presentation.path`, alongside `presentation.roadOpacity`. Each point contains distance, yaw, pitch and roll. The opening 80 metres ease into the course. Later sections span 480–800 metres and combine loops, banked turns, climbs, barrel rolls and twisting transitions. At the 60 km/h game-speed cap, each section lasts roughly 29–48 seconds; slower pedalling takes longer.

`LaneSmashCoaster.gd` integrates the route once, using midpoint integration at two-metre intervals. Orientation interpolates with a quintic curve whose velocity and acceleration vanish at control-point boundaries. Full rotations retain unwrapped angles. Position samples and orientation frames are fixed for the entire ride. The camera follows the rider's position and orientation through this world. All road vertices, bars, arrows, zone floors, finish gates and ghost positions use that same fixed route.

The road shader never moves or scales vertices. All six lanes remain three metres wide, including the distant road. Ordinary perspective and a gradual atmospheric fade provide the horizon. There is no width taper, moving-endpoint deformation or foreground-to-distant-warp join.

## Background and visibility

The psychedelic opening follows the view down the real route. A continuous distance/curvature budget determines how far along that route the road fades into the background. The visible road fades over the final 38% of that look-ahead distance rather than collapsing into a point. The underlying track continues unchanged beyond the visible range.

The background's 3D reference frame aims at that real course point and uses the route's orientation. It responds to the camera travelling through turns and rolls. Its position is not independently randomized or forced through a screen-edge circuit. Depending on the bend and camera orientation, it can approach a display edge; arbitrary corner visits are no longer imposed on the road. The user's final request for a fixed, natural course takes precedence over the earlier free-moving endpoint treatment.

Cadence still controls the background's internal flow; resistance still changes its colors and pattern. Reduced motion uses gentle versions of the saved route without inversions, while slowing and dimming the background. The HUD stays upright.

## Transparency

The road defaults to 74% opacity so the psychedelic scenery remains visible through it. Lane lines use 94% opacity. Rider, scoring objects and completion feedback remain legible. The road writes depth and draws before transparent lane overlays; nearly invisible distant fragments are discarded to avoid an invisible depth barrier.

## Track identity and persistence

Named tracks deterministically regenerate the same route from their existing seeds. Random tracks receive their own seeded route. New ride snapshots save the actual orientation control points, so replay does not depend on future generator changes. Older snapshots without presentation data get a deterministic fallback route.

`NeonCourse.fingerprint` excludes only the new `presentation` field. Removing that field yields exactly the historical course hash, preserving existing scores, last/best statistics and ghost eligibility. Gameplay fields still affect the hash. Course version 4, generator version 2 and scoring version 3 remain unchanged; presentation data has its own version 1. No database schema changes are required.

## Validation targets

- All 100 named tracks and representative random tracks produce distinct, reproducible routes covering maximum-speed ride distances.
- Saved JSON round trips reproduce physical world positions.
- Nearby and distant world anchors remain identical while the camera, cadence and rider distance change.
- Lane widths and orientation frames remain valid and continuous through full inversions.
- Reduced motion has no inversions.
- Historical score and ghost comparison keys remain unchanged; scoring-content edits still change them.
- Invalid presentation paths are rejected by course validation.
- Actual rendering verifies transparency, attached targets and fades; a two-minute isolated demo covers all three section types and a best-ride ghost.

## Build

Version code 14, version name `1.2.0-lane-smash.6`, same package and signing identity. Lane Smash remains the sole app experience. See the [guide](../LANE_SMASH.md) and [revision 6 validation](lane-smash-v6-validation.md). Physical testing on the user's original Peloton Bike remains outstanding.
