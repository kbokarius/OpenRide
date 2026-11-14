# Lane Smash revision 15 — visible bomb shooter and clean launch

November 14, 2026. Version `1.2.0-lane-smash.15`, APK code 23. Builds on revision 14 while preserving Claude's revision 13 rework.

## Request and diagnosis

The bomb shooter was sometimes unseen. The user also reported that a newly fired bomb appeared to fall behind him.

The old bomb-shooter fade used time since **firing**: it began fading 0.4 seconds after launch and was completely hidden by +2 seconds, although the bomb remains in flight for nine seconds. This was reproduced in a real-renderer capture at 80 seconds on Nightfall and in a regression test covering both shots. Separately, turning the entire model toward a distant curved target could make it lean or turn edge-on; projected model bounds also exposed edge clipping in some slots and aspect ratios.

## Presentation changes

| Element | Revised behavior |
| --- | --- |
| Shooter presence | Fade in over the existing 1.4-second interval during charge; fully visible throughout flight and through impact +0.3 seconds; fade out by impact +1.2 seconds |
| Placement | Same 3D attacker, projected at an 8 m foreground depth so loops and gantries cannot cover it; retains normal self-depth testing and shading |
| Pose | Stable three-quarter stance facing the rider, with six display positions clear of the HUD; camera projection uses the actual viewport aspect ratio |
| Bomb and tail | Render at a maximum 4 m foreground depth, ahead of the shooter, with position and scale transformed together to preserve the world arc's image and apparent size |
| Launch | Arc progress `t + 1.2*t*(1-t)^2`: immediate departure from the muzzle, smoothly varying speed, strictly positive derivative (minimum 0.6), unchanged endpoints and nine-second impact time |
| Landing zone | Covers the full six-lane width (25.2 m), matching the already lane-independent blast rules |

`LaneSmashBarrageSpace` owns these changes. The visible actor and ball are foreground presentations of world-space geometry; the launch muzzle is reconstructed from the saved fire-distance snapshot, and the world target and flight arc stay fixed. Bringing the ball and tail forward prevents the shooter's foreground torso from hiding them at release. No new viewports, shaders, lights, effects pools or physics objects are added. The machine gunner retains its existing rendering and timing.

Course version 9, generator 6, scoring 8, the 11-second warning, two-second charge, nine-second flight, dodge outcomes, points, stored records and comparison fingerprints are unchanged.

## Validation

- Original failure reproduced with a captured missing shooter and a failing test that checked both shots through impact.
- 45 targeted cases across the barrage, gunfire and course-catalog suites passed after the fix.
- New tests cover opacity through both flights/impacts, fade-out afterward, all six complete model bounds across six route positions and three screen shapes (16:9, 16:10, 4:3), muzzle projection consistency, bomb/tail foreground depth at 45/80/140 rpm, fixed arc endpoints and monotonic launch progression.
- Real-renderer Balanced captures reviewed for all six spawn positions after the point where the old shooter disappeared. Launch/flight/impact captures reviewed separately with the normal ride HUD.
- `git diff --check` passed. Existing rules and rendering components were reviewed for ownership, bounded allocation and compatibility.

## Signed Android build

- `:app:assembleNeonReal :app:lintNeonReal` completed successfully. Lint reported zero errors and 79 existing warnings.
- APK: `openride-neon-23.apk`, 204,188,341 bytes; version `1.2.0-lane-smash.15`, code 23, package `dev.digitalducktape.openride.neon`.
- Real bike sensors enabled; debugging disabled; ARM64 only; minimum Android API 29.
- APK signature verified with the existing update certificate: SHA-256 `45820456eab35d1a56adbc29d2ef7f09369b94d41f101868f5bb354ac3903773`.
- APK SHA-256: `2fe59873c1db6217457590a79051a519a864a98419a5e8c56a381466dae9f2b2`.
- Embedded `assets/games.pck` matches the newly exported game pack byte for byte: SHA-256 `fcebf6968c4d2cc4f366c5538b653914553ef31bc9898d128cfcc21b9eb701c6`. No capture override is included.
- An 11-second silent simulated-ride preview, `Lane-Smash-revision-15-bomb-preview.mp4`, shows charging, launch, flight and impact in the real desktop renderer.

This request prepares an installer; it does not install or launch it on the Peloton. Desktop rendering checks do not establish the tablet's frame rate.
