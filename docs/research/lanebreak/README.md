# Lanebreak alternative: research report

Research date: **November 13, 2026 (America/Los_Angeles)**. Status: **research only; no implementation or bike installation**.

## Recommendation

Build an original, silent, lane-based cycling game inside OpenRide, after a compatibility trial on the intended bike. OpenRide supplies much of the difficult device integration, but it does **not** currently contain a direct Lanebreak replacement. Its existing games could satisfy someone seeking general cycling games; they do not reproduce the resistance-controlled, multi-lane experience requested here.

The target is the **original Peloton Bike with a non-rotating screen**. That identifies the bike family, not the tablet generation or firmware. Verify those before installation. The repository documents working sensor integration on the Gen 2 tablet; it does not establish support for every original Bike.

## What exists already

- Twelve user-facing games, plus a development demo. Closest matches: Watt Lane (follow a power band), Cadence Karaoke (hold target cadence), and Safe Cracker (turn the resistance knob to targets).
- Scores, stars, personal bests, Easy/Standard/Hard settings, timed sessions, and preset/custom workout circuits.
- Live cadence, resistance and power; profiles; saved ride history; export and backup.
- A Godot game engine embedded in the Android app, with sensor and recording infrastructure already connected.
- Game music can be switched off; sound effects have a separate volume. A new game can operate entirely from visual cues while the rider listens to podcasts elsewhere.

The missing combination is a continuous forward-moving track, resistance-to-lane control, lane pickups, cadence windows, output challenges, and a repeatable library of authored rides. [Code analysis](01-repository.md) and [mechanics comparison](02-lanebreak.md) contain the evidence.

## Stability assessment

**Promising foundation, not yet a proven daily Lanebreak replacement.** Version 1.2.0 was published November 12, 2026, adding seven games. The maintainer explicitly labels games beta and says real-bike testing and difficulty tuning are limited.

The snapshot contains 65 issues: 6 open and 59 closed; pull requests are counted separately. Many closed issues are implementation tasks, and some were closed without implementation, so the close rate is not a reliability measure. Relevant risks include unresolved game tuning, sensor/knob latency, camera sensitivity, and firmware-dependent launcher behavior. There is substantial test source, but no checked-in GitHub Actions workflow or returned Actions run history. Tests were inspected, not executed in this research pass.

The next useful proof is several full-length rides on the actual tablet, including a reboot, pause/resume, saving results, and an offline ride. [Issue analysis and inventory](03-stability.md).

## How it would reach the bike

OpenRide is an Android app installed on the existing tablet through OpenPelo; it is not a replacement operating system. The normal path is a computer, a USB data connection, the bike's developer settings, then OpenPelo's app catalog. A future custom build would instead use **Install local APK**; an APK is the Android app installation file.

Upstream's built-in updater is hardcoded to the upstream repository. Forking GitHub does not redirect it. A custom version needs a deliberate app identity, durable signing key, and update endpoint. Installing a differently signed APK over upstream's package will fail. A distinct package is the preferred initial trial so upstream can remain available.

Some OpenPelo setup paths involve a firmware reset or disabling Peloton components. We have not verified that the target bike needs either. Confirm the tablet and current software before following those steps. [Installation, updates and rollback](04-installation.md).

## Proposed first version

One original game in the existing Games hub, with no camera or audio dependency. Start with a short tutorial and a small set of repeatable 10-, 20- and 30-minute rides covering steady riding, intervals and climbs, each with difficulty choices. Reuse profiles and recording; add course-specific scoring and personal bests. Keep artwork, naming, levels and scoring original.

The first implementation milestone should prove resistance-based lane control and scoring on the actual Bike. Only then expand the ride library. [Proposed scope and acceptance criteria](05-proposal.md).

## Repository record

- Upstream: [digitalducktape/OpenRide](https://github.com/digitalducktape/OpenRide).
- Fork: [kbokarius/OpenRide](https://github.com/kbokarius/OpenRide), created through Firefox after verifying the signed-in account.
- Reviewed baseline: [`bb8a764012972611761c3fc5839436dd1cf4acfc`](https://github.com/digitalducktape/OpenRide/tree/bb8a764012972611761c3fc5839436dd1cf4acfc), `main`, version 1.2.0 / versionCode 9.
- Changes in this research pass: these Markdown notes only. No app code, schema, APK, release, device settings or subscription changes.
- Source links are included in each note. Upstream issue states and release counts are a dated snapshot, not a continuing monitor.
