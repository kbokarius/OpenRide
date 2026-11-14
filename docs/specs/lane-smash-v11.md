# Lane Smash revision 11 — visual makeover, soundtrack, music-reactive scenery and machine-gun fire

## Requested result

1. A complete makeover of the presentation: menus, backgrounds and psychedelic effects, the track and the objects on it, the attackers, mines and explosions, and the sound effects. The bicycle becomes an animated motorcycle. Spacing, formatting and padding are re-evaluated for all text and elements.
2. Three supplied long-form music tracks become the soundtrack: the app starts on a random track at a random point and keeps playing; when a track ends another random one follows; the audio controls choose between the tracks and skip backward or forward with a slider.
3. The psychedelic background moves with the music that is playing: colour, shape, thickness and movement.
4. Cadence sections gain machine-gun fire: holding the cadence range keeps the fire ahead of and behind the rider; dropping behind or running too far forward gets the rider shot and loses points.

## Design decisions

Reported before building, as `CLAUDE.md` asks. The `godot-prompter` skills were read from disk (`GodotPrompter/skills/`), not invoked, because they are not registered in the session that did this work.

| Area | Pattern | Rejected alternative, and why |
| --- | --- | --- |
| Light and grade | Environment glow and tonemapping in the existing 3D SubViewport; one lens shader on the image that shows it (vignette, hit pulse, optional fringing) | Extra full-screen passes that read the screen back: each is another full render on a fill-rate-bound tablet |
| Surfaces | Every surface unshaded and lit in its shader (`ls_light.gdshaderinc`: key, fill, highlight, rim, fixed to the view) | Engine lights and fog: measured upstream at about a third of the tablet's frame (docs/GAMES.md) |
| Effects | Bounded MultiMesh pools driven from the ride loop | GPU particle trails and sub-emitters: not drawn by the Compatibility renderer |
| Models | Built in code with `MeshKit3D`, merged into a few meshes each | Imported models/textures: the repository only takes original or CC0 assets with a recorded source |
| Interface | One theme with a spacing and type scale, laid out in containers | Hand-placed label coordinates, the source of the previous misalignment |
| Music | An autoload with one streaming player on its own bus and a spectrum analyser | AudioDirector's stem decks: built for short looped stems, they load on the main thread and clear the Music bus's effects every segment |
| Graphics cost | Three tiers and a frame-rate governor | A fixed 1600×900 view with MSAA 2×: MSAA halved the frame rate on the tablet upstream and rendered black in a SubViewport there |
| Machine-gun rule | A rules-tick mechanic keyed to cadence only, versioned as scoring 7 | A kinematic "pocket" that integrates position: a rider inside the band but slightly off its centre would drift out and be shot while doing what the prompt says |

## What changed

**Look.** New road (lit seams, ticks, travelling packets, alloy rails, light curtains), gantries and light streaks fixed along the route, a motorcycle and pilot, a hologram ghost, self-lit markers over pools of light, shards/sparks/shockwaves/flashes/beams/energy blasts, redesigned mines and attackers (now on hover sleds, in hostile colours distinct from every reward colour), star field, bloom. See [Presentation](../lane-smash/PRESENTATION.md).

**Interface.** `LaneSmashMenuTheme` for every screen; rebuilt selector, settings, track cards, lane dock, track chip, status backing, progress line and floating numbers. Fixed along the way: the dock's scrim stopped short of the window's edges on the bike's wider screen; the 3D image was a fixed 16:9 size stretched to that wider screen; the duration row and header could overlap their neighbours; floating numbers could leave the screen.

**Soundtrack and analysis.** `Jukebox`, `LaneSmashMusicPanel`, the Audio panel and Settings. The three supplied tracks are in the repository at the owner's request; Night Drive is the fallback when they are absent.

**Music-reactive scenery.** The shared tunnel field takes bass, mids, treble, beat and a music-advanced phase. Forward travel is still only road distance.

**Sound.** All cues regenerated; new: road-mine explosion, lane tick, engine bed, weapon charge, machine-gun loop and hit, menu tap and confirm.

**Machine-gun fire.** See [Rules](../lane-smash/RULES.md#machine-gun-fire-cadence-sections). Two seconds of warning, first round after 0.6 s outside the band, then one every 0.5 s, 60 points each, at most 15 a section, band edges safe, lane irrelevant.

**Graphics tiers.** High / Balanced / Performance, with Auto stepping down on a four-second average under 50 fps and remembering the tier.

## Acceptance criteria

1. Existing render contracts hold: fixed world anchors, shared chunk boundary vertices, bounded pools, front-wheel contact at the scoring boundary, road tip inside the tunnel, sky travel equal to road distance.
2. The machine-gun rule: band edges safe; no round in the first two seconds; first round at 0.6 s, then every 0.5 s; exactly 60 points each; 15 at most per section; never below zero; a brief slip forgiven; identical outcomes when the rules are advanced every 10, 30, 50 or 100 ms; no gunfire in course 7 or older snapshots.
3. Records: scoring 7 accepted and 8 rejected on desktop and Android; older versions unchanged.
4. Soundtrack: random start inside the track with the end margin; auto-advance to a different track; select/seek clamp; fallback playlist; Music Off holds the position; analysis falls to zero when nothing is audible; nothing starts by itself in headless runs.
5. Menus: every touch target at least 120 px and 24 px apart, on screen; no text under 34 px; ride controls inside their panel; header elements never overlap.
6. The whole application lifecycle passes: selector, start, saved ghost, audio switches without pausing, sensor loss and automatic recovery, end and results.
7. Reduced motion removes the camera knock, edge pulse, trail and beat-driven effects; the Performance tier removes bloom and the optional set dressing without touching gameplay objects.
8. The structured reference under [docs/lane-smash](../lane-smash/README.md) describes the result.

## Compatibility

APK code 19 / `1.2.0-lane-smash.11`, same package and signing identity. Course 8 / generator 4 / scoring 7. Course 7 snapshots replay under scoring 6 without gunfire; every earlier version is unchanged. New tracks have new fingerprints, so their last/best records start fresh. Room stays at schema 9. `GameOptions` gains one per-rider choice (`graphics`) and one per-device value (`shared/lane_smash_graphics/auto_tier`).

The repository and the exported pack grow by about 133 MB for the three tracks; only the track that is playing is held in memory (about 28–78 MB of compressed audio).

See [validation](lane-smash-v11-validation.md) for what was executed and what remains unverified.
