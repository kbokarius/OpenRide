# Revision 14 validation

November 13, 2026. Godot 4.7.2, GL Compatibility, macOS desktop.

## Automated

46 cases passed, 0 errors/failures/skips/orphans, in these five suites:

- `lane_smash_steering_test`: all five difficulty bands, within-lane clearance/contact range, 30/60/120 fps threshold shifts, reversal, skipped bands, invalid input, highlight fades and direction cues.
- `neon_vector_space_test`: anchored arrows, scenery lifetime, distance scale, music seam pulses and colour easing.
- `lane_smash_sweet_spot_test`: cadence bonus and frame-rate independence, gauge layout including edge clearance, burst celebration, graphics governor and tier setup.
- `lane_smash_path_test`: reproducible fixed paths, continuous width/orientation and full/reduced motion.
- `lane_smash_catalog_test`: course layouts, resistance ranges, power zones, final-item contact and adjacent-section separation.

First visual review caught outside-lane clipping and a direction cue overlapping the cadence gauge. Camera setback and gauge clearance were adjusted; the cue now has a fixed position beneath the main instruction. The longer camera setback also required keeping scenery behind the rider longer; the existing scenery lifetime test caught this and now passes. Power-zone intensity retains the established visual contact condition, including every within-lane steering position.

`tests/play_neon_vector.gd --hidden` also passed **54 lifecycle checks** with the real renderer: menu layout, track selection, intro, live simulated input, matching best-ride ghost, scoring, audio switches, rejection of manual pause, sensor interruption/recovery, ending and returning to setup. Logs contained no script or shader compilation errors. `git diff --check` passed.

## Visual checks

Real-renderer captures reviewed on High, Balanced and Performance. Checked the bright uncharged floor, filled charge strands, side rims, direction prompts and target-lane wash. The power floor stays violet and visibly bounded with bloom off. Outside-lane framing and the cadence gauge were inspected separately. PNG capture is synchronous and expensive; its logged FPS is not a gameplay performance measurement.

## Android and delivery

`./gradlew :app:assembleNeonReal :app:lintNeonReal` passed. Lint reports 0 errors and the same 79 warnings as revision 13. APK signature verification passed (v2), using the existing fork signing certificate. Generated BuildConfig confirms `DEBUG=false`, real Bike sensors enabled, code 22 and version `1.2.0-lane-smash.14`. Package remains `dev.digitalducktape.openride.neon`; native libraries are ARM64 only and minimum Android API remains 29.

Artifact: `openride-neon-22.apk`, 204,187,505 bytes. SHA-256: `f165a8cacbf94655eb6012e90e7080536bb86648254c6b1f5f35f6e3c9284703`.

Preview: `Lane-Smash-revision-14-preview.mp4`, 25 seconds, 1280×784, H.264, silent simulated input. First clip demonstrates resistance movement and correction cues; second shows the brighter power floor filling and its section completion. Separate Balanced captures checked both outermost resistance positions, including later curved road.

Peloton was absent from `adb devices -l` during this update; this revision has not been installed or ridden on the physical tablet. Previous installed release was revision 13 / code 21. Desktop checks cannot establish tablet frame rate or guarantee the absence of future crashes.
