# Lanebreak mechanics and the requested alternative

Date: 2026-11-13. This note separates documented behavior from our proposed design.

## Documented reference behavior

Peloton describes a six-lane track controlled by the resistance knob, with lane resistance ranges changing by difficulty. Its three main challenge types are:

- **Beats:** enter the required lane to collect points.
- **Streams:** keep cadence in the specified range.
- **Breakers:** produce power during an effort section for points and bonuses.

Rides have different workout types, durations and difficulty levels. Results include points, up to three stars, and comparison with riders on the same difficulty. Sources: [Peloton's mechanics overview](https://www.onepeloton.com/bike/lanebreak), [launch explanation](https://www.onepeloton.com/blog/lanebreak), and [original product announcement](https://www.onepeloton.com/de-DE/press/articles/peloton-lanebreak).

Those sources explain the experience, not a full scoring specification. Exact point formulas, threshold tables, current ride inventory and all current challenge variants remain unverified. The support article attempted during research returned a loading/CSS error. No access to proprietary source or ride files was used.

## Requirements for this fork

The requested experience is visual cycling with points and varied rides/difficulties, without music. A game should remain understandable with every audio channel muted. Podcast playback on a separate device is sufficient; integrating podcast accounts, feeds or streaming is not required.

| Requirement | OpenRide baseline | Remaining work |
| --- | --- | --- |
| Resistance knob chooses a track lane | Resistance is available; Safe Cracker uses it | Continuous multi-lane navigation |
| Cadence affects scoring | Cadence Karaoke already scores cadence windows | Integrate into the same course |
| Output challenges | Several power-based games | Schedule and score pushes within the course |
| Points, stars, personal bests | Existing framework and storage | Course-specific scoring and comparable records |
| Different rides | Game circuits and standalone games | Repeatable authored lane-game courses |
| Different difficulties | Easy/Standard/Hard and FTP scaling | Tune lane ranges, cadence targets and output goals |
| Silent use | Music switch and effects volume | Make every cue visual; no audio clock dependency |
| No subscription/backend for play | Local sensors, games and saved data | Keep courses bundled and fully playable offline |

## Proposed adaptation, not an implemented feature

- A forward-scrolling track with six visible lanes and an original rider marker.
- Resistance determines position; cadence and watts determine challenge success.
- Three original challenge presentations: collect lane markers, hold cadence windows, and fill bounded effort targets.
- Preview upcoming turns and target changes in time to respond to physical knob lag.
- Show score, progress, time remaining, live metrics and a clear end-of-ride result.
- Use elapsed workout time rather than songs or beats to schedule the course. Audio can remain completely absent.
- A fixed course/difficulty/version should present the same challenge sequence so repeat attempts are comparable.

No Peloton music, artwork, logo, proprietary levels or branding is needed. Exact Lanebreak scoring parity is not a requirement and should not be claimed. Use original product/game naming when implementation starts.

## Why the existing games are not enough

Watt Lane moves a cursor up/down based on watts. Cadence Karaoke asks for a steady cadence in a tunnel. Neither asks the rider to navigate six resistance-selected lanes while alternating several challenge types through a curated ride. Combining them in a circuit changes games and shows transition cards; it does not create that continuous experience.

The finding is limited to the reviewed OpenRide baseline and its issue/PR inventory. A broader search did not establish another ready-to-use project, but this is not an exhaustive claim that no alternative exists anywhere.
