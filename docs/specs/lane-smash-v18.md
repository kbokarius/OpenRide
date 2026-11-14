# Lane Smash revision 18 — restore Auto graphics

November 14, 2026. Version `1.2.0-lane-smash.18`, APK code 26. Course 10 / generator 7 / scoring 9 are unchanged.

## Behavior

At the owner's request, restore **Auto** as the Graphics default. The existing governor and rendering presets are unchanged: Auto starts from its remembered device tier, or Balanced on a tablet without one, and can reduce quality during sustained slow rendering. High and Performance remain selectable. Explicit saved choices remain respected; the connected Peloton's active rider is confirmed on Auto during installation.

Implementation pattern: change the existing option declaration and use the existing settings control. No new graphics mode, tier migration or forced rewrite on every launch is needed. Saved rides, difficulty ranges and course identities are unchanged.

## Validation and installation

- All 14 focused Lane Smash menu/graphics tests passed.
- Signed Android build succeeded; lint reported 0 errors and 79 existing warnings.
- Package `dev.digitalducktape.openride.neon`, code 26 / `1.2.0-lane-smash.18`, ARM64. Existing signing certificate verified; embedded game pack matches the final export.
- APK SHA-256: `6a5ac6a3e34c63d8eea6a55ca170ddc18292903144335e2786a8ec93abc696e2` (204,193,605 bytes).
- An open stationary ride was ended through the app before updating; its result screen confirmed the partial ride was saved.
- Installed in place on the connected PLTN-RB1VQ with `adb install -r` returning **Success**; version metadata confirms revision 18/code 26. No uninstall or data clear occurred and the original first-install timestamp was retained.
- The physical settings screen shows **Auto** selected. Recent rides still includes both the prior completed ride and the partial ride saved before this update. No personal ride details or screenshots are committed.
- Auto was verified after the installed app's cold launch. A subsequent cold restart reached the selector with **Bike connected · ready**; USB disconnected before a second settings inspection or post-restart log collection. The last observed screen was the selector, with no new ride started.
