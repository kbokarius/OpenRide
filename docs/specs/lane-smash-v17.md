# Lane Smash revision 17 — High graphics by default

November 14, 2026. Version `1.2.0-lane-smash.17`, APK code 25. Course 10 / generator 7 / scoring 9 remain unchanged.

## Behavior

The existing Graphics option now defaults to **High**, including on Android. High bypasses the automatic quality governor and its previously remembered tier. Existing High rendering settings are unchanged: the tablet renders the main view at 90% linear resolution, its sky at that full view size, engine bloom and all effects; tablet MSAA remains disabled because the existing renderer compatibility setting avoids black output. This is the highest existing tablet preset.

Auto and Performance remain selectable and their behavior is unchanged. Explicit saved per-rider preferences continue to override defaults. The active Peloton rider was confirmed on High during installation and again after an app restart. Scores, course identities, difficulty ranges and saved rides are unaffected.

Implementation pattern: change the existing option declaration and use the existing settings persistence. Merely raising Auto's starting tier would allow it to reduce quality during a ride and would not meet the owner's request. No new rendering system or preference migration is needed.

## Validation and installation

All 14 focused Lane Smash layout/graphics tests passed before export. A broader legacy hub suite also exercised removed games (Safe Cracker, Tug of War and Kart Race) and raised eight fixture/type errors because navigation now opens NeonSetup instead of GameScreen; those unrelated legacy tests are not evidence about this preference change. The signed Android build succeeded; lint reported 0 errors and 79 existing warnings. This default preference change does not establish sustained tablet frame rate.


- Package: `dev.digitalducktape.openride.neon`, code 25 / `1.2.0-lane-smash.17`; ARM64, live sensors enabled, debug disabled.
- APK v2 signature verified with the existing signing certificate. The embedded game pack exactly matches the final export; no development override was present.
- APK SHA-256: `6ed92bc51eab0c600b129c122781f0e7bd5c50478caec60f026f89013eead976` (204,193,605 bytes).
- Installed in place on the connected PLTN-RB1VQ with `adb install -r` returning **Success**. The original first-install timestamp was retained; no data clear or uninstall occurred.
- Physical-device settings showed **High** selected and the owner's existing completed ride in Recent rides. No personal ride details or screenshots are committed to the repository.
- A cold app restart retained **High**. The selector showed **Bike connected · ready**. Inspected startup logs contained no fatal exception, native fatal signal, script/shader error or ANR; existing vendor/XR warnings remain. Left at the selector without starting a ride.
