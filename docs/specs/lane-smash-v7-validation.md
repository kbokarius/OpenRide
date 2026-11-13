# Lane Smash revision 7 — validation

Validated locally on November 13, 2026 with Godot 4.7.2, GL Compatibility, Apple M4 Max. Physical Peloton installation, sensor accuracy and tablet frame rate remain untested.

## Results

- Godot import and script checks passed.
- 21 focused unit tests passed: catalog, fixed paths, and road targets. The background test verifies actual travel at 0, 60, 140 and 200 rpm, speed capping, unchanged travel over extra render frames, Reduced motion, and precision at 30,000 metres.
- The real hub-to-ride integration passed all 50 checks, including all 20 duration/difficulty combinations, score/ghost loading, music switching, manual pause rejection, sensor recovery, early-end results and history.
- Menu capture checked all 100 named cards for text bounds. It verified animated visible cards, inactive offscreen cards, and frozen Reduced-motion previews. Reviewed all four pattern types, all eight theme colors, settings, random selection, and 1280 × 720 / 1440 × 810 / 1920 × 1080 layouts.
- Render review identified and fixed an angular filtering seam. Filtering now differentiates continuous direction components, avoiding the `atan` wrap. Final screenshots show no seam.
- An eight-second menu preview was captured from the real UI. Export: H.264, 1440 × 810, 30 fps.
- The moving-road render probe measured a 20.35 ms median and 25.46 ms 95th-percentile frame interval in a hidden 1280 × 720 desktop window while another app instance was open. This is a desktop observation, not a Peloton performance claim.
- Signed Android release assembled successfully. Package audit confirms Lane Smash is the sole registered game and the 13 other game scene assets are excluded.
- No database or scoring changes; previous scores and ghosts retain their comparison keys.

The existing integration harness can report audio resources still in use during immediate process shutdown. Verbose review identified audio streams/playback objects, rather than the new cards or shaders. The final menu capture exited with the existing four RefCounted cleanup warnings and no resource-in-use error. No runtime script/shader error occurred in the final menu, ride capture or newly launched interactive app.

## Installer

- File: `openride-neon-15.apk`
- Package: `dev.digitalducktape.openride.neon`
- Version: `1.2.0-lane-smash.7` / code 15
- Size: 65,022,437 bytes
- SHA-256: `5e9b78c68b53559c49662272bc5be7d9add04f8ac3bd0527339ee33a55d75c16`
- APK signature verification passed, v2 scheme.
- Signing certificate SHA-256: `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773` (unchanged)

## Reproduction

Run `lane_smash_catalog_test.gd`, `lane_smash_path_test.gd` and `neon_vector_space_test.gd` using the repository's gdUnit4 command runner. Run `tests/play_neon_vector.gd` for lifecycle verification. Run `tests/capture_lane_smash_menu.gd -- --out=<absolute-directory>` for isolated menu review. Capture scripts use separate history/preferences and do not populate the rider's real records.

See the [specification](lane-smash-v7.md) and [installation guide](../LANE_SMASH.md).
