# Lane Smash revision 10 — audio, score scale and animated counters

## Result

Music and Sound effects now have independent On/Off controls in Settings & history and the live Audio panel. Choices persist across screens, riders and restarts. Every gameplay effect has a short original cue, with no repeat cooldown. The live panel never pauses the ride.

Passing an incoming blast earns points; staying behind safely earns zero. A new 18× point scale targets about 150,000 points for a typical 20-minute ride. Hits remove up to 1,800, passes award 1,800, and both safe outcomes earn star target credit. Previous snapshots keep their original rules. Course 7 / generator 4 / scoring 6 separates new comparisons.

Total and power counters roll quickly toward the latest target and ease to an exact stop. Gains take 0.72 seconds, losses 0.30; captions and panels remain fixed. The shared total mirror now accepts authoritative penalties as well as gains. Animation never affects scoring or storage.

## Acceptance criteria

1. Menu and ride switches share saved values; music and effects mute independently; host refresh cannot undo Off.
2. Every repeated contact emits its sound when enabled, without cooldown; muted events are not replayed later.
3. Passed, held-back and hit outcomes award +1,800 / 0 / up to −1,800. Old v5 snapshots retain their previous 100-point dodge behavior.
4. Representative 25-track, 20-minute calibration is near 150k, with a documented trace rather than a claim about every rider.
5. Counter gains decelerate, penalties count down, retargeting does not jump/overshoot, and digit changes do not move captions or panels. Saved values stay exact.
6. Full catalog/rules/audio tests, lifecycle and repeated start/end checks pass; APK builds and retains signing/package identity.
7. Current architecture, rules, stars, courses, effects and settings are maintained as structured Markdown under [docs/lane-smash](../lane-smash/README.md).

## Implementation choices

Reuse AudioDirector buses/player pools and GameOptions persistence; do not add an unrelated audio system or duplicate settings. Render short original WAVs offline and reuse a single power-bed player. Use one bounded interpolation state per counter instead of stacking newly allocated tweens. Freeze layout widths/tabular digits instead of scaling/bouncing the score panel. Version scoring rather than rewriting historical scores.

## Compatibility

APK code 18 / `1.2.0-lane-smash.10`, same package and signing certificate. Room remains schema 9. Course layout/generator 4 and saved presentation paths are unchanged. Old completed ghosts remain eligible within their original comparison identity. New courses get separate last/best records. See [validation](lane-smash-v10-validation.md) for measurements and outstanding physical-device limits.
