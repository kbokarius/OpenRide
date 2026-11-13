# Proposed implementation after review

Status: proposal only. No implementation has begun.

## Product scope

Create one original game inside OpenRide's Games hub that delivers resistance-controlled lane riding, visible challenges, points and repeatable workouts. No subscription, music service, camera, trainer video or online leaderboard is needed for the requested first version.

Use six lanes for familiar spatial progression, with independent cadence and output challenges. Turning the knob should visibly change lanes. More watts alone should not move the player to a different lane.

## First playable slice

- One five-minute tutorial with a complete start → ride → results flow.
- A forward-scrolling track and readable rider marker, designed for the actual Bike window.
- Three challenge types: lane pickups, cadence holds and bounded output pushes.
- Time/progress, current lane, cadence, resistance, watts and score visible from the saddle.
- Manual pause/end and correct resume behavior. Visual feedback for every event, working with all audio muted.
- Persist a result and personal best tied to the exact tutorial version and difficulty.

This slice should be ridden on the original Bike before expanding the art or content library. Measure how long resistance takes to reach the game after turning the physical knob. That measurement determines lane transition tolerance and preview time.

## Suggested initial ride library

These are proposed content targets, not existing features or fitness prescriptions:

| Course | Duration | Structure |
| --- | --- | --- |
| Getting started | 5 min | Tutorial and gentle lane/cadence practice |
| Steady flow | 10 / 20 / 30 min | Longer holds, predictable lane changes |
| Interval circuit | 10 / 20 / 30 min | Alternating work and recovery sections |
| Rolling climb | 20 / 30 min | Gradual resistance changes and controlled cadence |

Reuse Easy/Standard/Hard initially, tune against real rides, and decide whether an additional Expert tier is useful. Each ride should include appropriate opening/closing easier sections. Content must be curated so increasing duration is more thoughtful than repeatedly generating random targets.

## Game and data design

| Component | Proposed responsibility |
| --- | --- |
| Course data | Stable ID/version, duration, difficulty settings and timestamped challenges |
| Lane resolver | Map resistance to lane using configured bands, boundary tolerance and measured sensor response |
| Course clock | Pause-aware monotonic elapsed time; no dependency on music or frame count |
| Scoring logic | Deterministic event scoring and cadence/power integration, independent of rendering frame rate |
| Renderer | Original track, rider, previews, targets and feedback; reuse common HUD/pause controls |
| Integration | Registry/catalog entry, `InputBus` inputs, `Session` lifecycle and existing recording |
| Results | Score, stars, completion, challenge accuracy, course/scoring version and target basis |

Use bounded output rewards rather than an uncapped incentive to pedal faster or turn resistance up indefinitely. Explicitly define what counts when the rider stops, data is stale, a lane boundary jitters, the app pauses, or a frame arrives late. Course timing and scoring must agree after resume.

Compare personal bests only for compatible course versions/difficulties and target settings. If random variety is offered, store a repeatable seed; keep fixed authored rides available. Existing session code sends random seeds, and current personal-best queries do not independently key by course revision, so this needs explicit integration.

For the first course, assess whether `planId`, `variant` and `statsJson` can represent these fields without a schema change. If schema changes become necessary, add and test Room migrations, update backup compatibility, and verify historical records remain readable. This repository has no Drizzle migration journal; the user-provided Drizzle rule would apply only if a Drizzle-backed component were introduced.

## Visual consistency

Keep the existing Home/Games navigation, game card entry, difficulty controls, live status, Pause/End controls and summary behavior. Match the shared framework's typography and touch sizes. Give the lane course its own original visual identity without adding a separate app navigation system. Recheck Home, hub, several game screens and summary screens when implementing UI.

The old original-Bike GPU is a real constraint. Prefer a lightweight 2D/perspective track and restrained effects. Treat 60 fps as a target to measure on hardware, not an assumption from a desktop preview.

## Delivery stages

1. **Compatibility trial:** identify the tablet/firmware, confirm upstream sensors, recording and a full silent ride.
2. **Original playable slice:** tutorial and scoring, plus desktop simulations of known sensor traces.
3. **Bike tuning:** resistance lag, responsiveness, readable cues, frame rate, pause/dropout behavior.
4. **Ride library:** authored course families and difficulty calibration; stable personal-best comparisons.
5. **Distribution:** separate app identity, stable signing, fork update endpoint, backup/rollback check and install instructions.

## Acceptance before using it daily

- A completed course has the same result across different rendering frame rates for the same input trace.
- Pause, sensor loss and resume do not grant free points or skip/duplicate challenges.
- Stopping pedaling does not continue collecting valid points indefinitely.
- Resistance boundaries do not flicker lanes while the rider holds the knob steady.
- Repeating a fixed course preserves challenge order and comparable scoring.
- A full 30-minute ride runs acceptably on the actual tablet and survives ordinary interruptions.
- Saved rides, course metadata and bests remain correct after relaunch and an app update.
- A backup can be restored in an isolated test installation before relying on it for migration.
- The whole experience is usable offline with music and effects muted.

The remaining hardware information is the tablet model, Android version and firmware build. The design should also be tuned against the rider's usual Lanebreak duration and difficulty when implementation begins. No estimate of exact effort or delivery date is warranted before the hardware/interaction slice.
