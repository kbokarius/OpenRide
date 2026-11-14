# Lane Smash — living technical reference

Current: revision 17, APK code 25, course version 10, generator version 7, scoring version 9. Updated November 14, 2026.

This directory describes the current game. Versioned files under `docs/specs/` preserve past decisions and validation; they are historical when they disagree with this reference.

| Document | Purpose |
| --- | --- |
| [Architecture](ARCHITECTURE.md) | Components, data ownership, lifecycle, persistence and compatibility |
| [Rules and courses](RULES.md) | Steering, speed, course generation, points, bombs and stars |
| [Presentation and audio](PRESENTATION.md) | Visual contacts, score animation, sound mapping and shared settings |
| [Player and installation guide](../LANE_SMASH.md) | Visible controls and installation |
| [Revision 17](../specs/lane-smash-v17.md) | High graphics by default; signed build and physical installation |
| [Revision 16 and validation](../specs/lane-smash-v16.md) | Slimmer motorcycle, visible jets, lane-checked bombs, work-lane progression and timed cooldown |
| [Revision 15 and validation](../specs/lane-smash-v15.md) | Visible bomb shooter, forward launch, signed Peloton build and checks |
| [Revision 14](../specs/lane-smash-v14.md) | Wider lanes, resistance steering, lane guidance and brighter power zones |
| [Revision 14 validation](../specs/lane-smash-v14-validation.md) | Steering update checks and limits |
| [Revision 13](../specs/lane-smash-v13.md) | Cadence gauge, section spacing and tablet rendering work |
| [Revision 12](../specs/lane-smash-v12.md) | The faster road, music on the track and the workout pass |
| [Revision 11](../specs/lane-smash-v11.md) | The visual makeover, soundtrack and machine-gun rule this builds on |

The product name is **Lane Smash**. Internal `neon_vector` names and the package `dev.digitalducktape.openride.neon` remain for compatibility. Only Lane Smash is registered/exported as a selectable game. The internal power reference is 150 W; there is no FTP or reference-power control. No Pause button, cosmetic unlocks or other games are available. The rider's machine is a motorcycle; `LaneSmashBike` replaces the earlier bicycle model.

Original research, including upstream stability and published Lanebreak difficulty ranges, remains under [research/lanebreak](../research/lanebreak/README.md). This fork uses original code, art and sound effects. Its soundtrack is three long-form mixes supplied by the fork's owner, with the original Night Drive loop as the fallback (see [Presentation and audio](PRESENTATION.md)).
