# Lane Smash — living technical reference

Current source: revision 25, showing previous-best targets in the pre-ride preview and retaining compatible best-ride ghosts across updates. Course 13 / generator 10 / scoring 12 are unchanged. Updated November 20, 2026. **Signed build 33 / revision 25 is installed on the Peloton.**

Latest signed APK and verified Peloton installation: code **33** (`1.2.0-lane-smash.25`), installed in place over Wi-Fi on November 20, 2026. See [Parameters](PARAMETERS.md#units-and-release-state) and the [revision-25 build and installation record](../specs/lane-smash-v25.md#build-and-installation).

This directory describes the current game. Versioned files under `docs/specs/` preserve past decisions and validation; they are historical when they disagree with this reference.

| Document | Purpose |
| --- | --- |
| [Architecture](ARCHITECTURE.md) | Components, data ownership, lifecycle, persistence and compatibility |
| [Parameters](PARAMETERS.md) | Exact timings, distances, cadence/resistance bands, bomb spacing, score animation and motorcycle geometry |
| [Rules and courses](RULES.md) | Steering, speed, course generation, points, bombs and stars |
| [Presentation and audio](PRESENTATION.md) | Visual contacts, score animation, sound mapping and shared settings |
| [Player and installation guide](../LANE_SMASH.md) | Visible controls and installation |
| [Revision 25](../specs/lane-smash-v25.md) | Pre-ride score target, cross-version personal benchmarks, ghost visibility and validation; signed build 33 and verified Wi-Fi installation |
| [Revision 24](../specs/lane-smash-v24.md) | Between-section mines, lane-change allowance, compatibility and validation; signed build 32 and verified Wi-Fi installation |
| [Revision 23](../specs/lane-smash-v23.md) | Resistance latency audit, faster reporting request, live steering feedback and brighter edge warning; signed build 31 and verified Wi-Fi installation |
| [Revision 22](../specs/lane-smash-v22.md) | Half-cadence Kid targets, unchanged adult records, signed build 30 and Wi-Fi installation |
| [Revision 21](../specs/lane-smash-v21.md) | Handoff/cadence audit, beside-bike bomb meter, edge warning and speed-weighted burst scoring |
| [Revision 21 installation](../specs/lane-smash-v21-installation.md) | Signed build 29, Wi-Fi update and verified sensor-ready selector |
| [Revision 20](../specs/lane-smash-v20.md) | Signed build 28, Kid/rear-tyre packaging, Wi-Fi installation and physical startup checks |
| [Kid difficulty](../specs/lane-smash-kid-mode.md) | Zero-based resistance, half-size lane steps, shared steering/bomb mapping and six-button selector |
| [Revision 19](../specs/lane-smash-v19.md) | Immediate pass rewards, smooth counters, sustained sections, continuous lane guidance and dense off-lane mines |
| [Revision 18](../specs/lane-smash-v18.md) | Auto graphics restored by default and on the Peloton |
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
