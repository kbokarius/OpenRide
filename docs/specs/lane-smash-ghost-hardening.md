# Ghost playback hardening

Date: November 20, 2026. Follow-up to revision 25, requested after the [finish assessment](../lane-smash/GHOST_FINISH_ASSESSMENT.md). No APK or Peloton installation is included in this change.

## Problem and behavior

An incomplete saved ghost previously stayed at its last distance indefinitely, with its last animated cadence still active. This could look like a rider stopping. The reported physical ride was a valid recorded stop, but the separate endpoint weakness needed fixing.

Playback now identifies contiguous recorded spans. A span ending early fades out over its final half-second while following its actual samples; it is hidden at the endpoint and stays hidden through missing time. A delayed start or resumed span fades in over half a second. No movement is extrapolated across gaps. Full recordings retain their real stops, including stationary cooldowns, and their final measured cadence is derived explicitly rather than inherited from the previous rendered frame.

## Design and compatibility

- Use a small `RefCounted` playback object with a cached span list and advancing cursors. This keeps IO and coverage scans outside the render loop and makes replay behavior testable without a 3D scene.
- Keep replay coverage separate from record validity. Rejecting an entire completed ride for an incomplete ghost would discard a valid score target. Score/history data, snapshots and comparison keys are unchanged.
- Continue reading three-column legacy samples and their existing relative-distance presentation. Modern four-column traces use recorded distance.
- Source constants: 100 ms sample cadence and 500 ms smoothstep fades. Completeness requires a first sample no later than 100 ms, no larger intervening interval, and coverage through the final expected 100 ms tick of the ride.
- Empty traces retain the existing no-recording preview. Nonempty partial traces show **Ghost recording is incomplete**. Ghost Off continues to suppress replay notices.
- During missing time, the HUD says **GHOST RECORDING UNAVAILABLE**; after an early endpoint, **GHOST RECORDING ENDED**. Stale distance/points/cadence are cleared. Text keeps its existing one-second refresh to avoid flicker.
- Opacity multiplies the existing overlap, distance and portal fades. No new shader, mesh, database field, scoring version, course version or bridge operation is introduced.

## Validation

The regression test first reproduced both original failures: the ghost stayed visible after an early endpoint and retained 67.2 RPM from its last moving interval. The complete stationary-tail regression preserves a full synthetic 15-minute recording that stops with 27.8 seconds remaining.

Focused validation covers early endpoints, opacity progression, moving finishes, stationary finishes, missing middle/start intervals, replay rewind, legacy rows, empty data, Ghost Off, score preservation, preview messages and all four supported durations. Existing benchmark, record and intro-layout suites also run. The native capture uses isolated synthetic history/settings and exercises normal visibility, an incomplete preview, a half-faded motorcycle and the ended-recording HUD.

Verified results:

- **26 focused test cases passed:** 9 ghost-playback cases, 6 benchmark cases, 10 saved-record cases and 1 registered-game intro-layout case. Zero test errors, failures, skips or orphan nodes. The initial run passed 25 cases; the additional all-duration case and the other eight playback cases then passed in the final focused rerun.
- Godot editor import completed without parse/script errors. `git diff --check` passed.
- Native GL Compatibility capture passed normal and incomplete replay assertions. Screenshots at 1280 × 720 were inspected: the partial ghost fades, the exhausted ghost disappears, and the preview/HUD messages fit the established layout.
- The first capture assertion assumed no preexisting portal fade. It was corrected to verify that the new 50% opacity multiplies the renderer's existing opacity; the final capture passed. This was a harness correction, not a gameplay change.
- Native capture exits successfully with the same four ObjectDB/two resource shutdown diagnostics documented for the previous revision-25 capture. No in-session script error occurred in the final run. This is not a new physical-device or endurance validation.

No personal backup or real ride trace is checked into the repository. Build 33 remains installed; the hardening source is ready for a subsequent signed build.
