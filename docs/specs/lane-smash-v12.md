# Lane Smash revision 12 — a faster road, music on the track and interface, and a workout pass

Builds on [revision 11](lane-smash-v11.md). APK code 20, `1.2.0-lane-smash.12`. Course version 8, **generator version 5**, scoring version 7.

## Requested result

1. Sound effects a little quieter than the music by default.
2. Colour pulsing on the track, the background and the parts of the interface where it makes sense, in time with the frequency content of the music.
3. The motorcycle should feel like it is flying: much faster in the middle of the cadence range, while really slowing down still shows.
4. The pulses of light that constantly fire forward along the track should follow the music.
5. A pass on the tracks (speeds, resistance, timing) so they make a solid, fast-paced workout.
6. Resistance for every lane and difficulty must line up with Peloton's Lanebreak, researched online.
7. A new demo video.

Standing preferences from revision 11 still apply: anything that fills the screen moves smoothly with the music, never abruptly.

## Design decisions

Reported before building, as `CLAUDE.md` asks. The `godot-prompter` skills were read from disk (`GodotPrompter/skills/`), not invoked, because they are not registered in the session that did this work.

| Area | Pattern | Rejected alternative, and why |
| --- | --- | --- |
| Speed | Draw every rules-metre as three world metres (`NeonSpace.STRETCH`), applied once in the route's integration step; rules, course data and saved rides untouched | Raising the rules' speed (60 km/h at 140 rpm): it would change how many sections a rider reaches, every score and every saved ghost, and need a new scoring version. Moving the camera closer or widening the lens: more apparent speed but a distorted bike and road |
| Speed curve | Keep speed proportional to cadence | A curve that boosts the middle of the range: the rules' distance would stop being proportional to pedalling, or the picture would disagree with the rules about where the bike is |
| Seam pulses | Up to six pulses launched by the jukebox's kick detector, positions kept in script and handed to the road shaders as two small arrays | Deriving them in the shader from a beat phase: a phase cannot follow a tempo change or a breakdown without the pulses jumping |
| Colour from the music | The same eased levels everywhere (`LaneSmashLook.music()`), with one helper for interface colours (`pulsed`) | Reading the fast analysis values directly: they flicker, which revision 11 already had to remove from the sky |
| Interface pulsing | Change accent lines only (panel edges, outlines, rules, the progress line) through existing style objects | Pulsing text or panel sizes: anything the rider has to read must not move or change contrast |
| Workout | Cadence targets by kind of effort; fixed burst spacing; a lighter recovery minute; the generator version bumped | Editing targets per track by hand: 100 named tracks and every seeded one share one generator, and equal effort budgets across tracks are a tested property |
| Lanebreak alignment | Keep the published ranges and the seven-value lanes, add the lane observations as evidence and pin the table in a test | Changing lane widths to anything else: every individual Lanebreak lane found is seven values wide and sits on this grid |

## What changed

**Speed.** `LaneSmashCoaster.stretch` scales the route's integration step, so the same curve is three times longer in the world. Markers, mines, sections, the attackers' fire lines, arches, light streaks, the trail and the sky's travel all convert between rules-metres and world metres at their edges; sizes that are real (the bike, lane width, the tyre's contact reach) stay in world metres. The HUD shows `cadence × 0.8` mph: 48 at 60 rpm, 77 at 96, 112 at 140, zero when stopped. Arches are now 64 world metres apart and fade in at the far end of their window.

**Music on the road.** A pulse of light leaves the front wheel on each detected kick and runs ahead along the seams as a chevron; with no kicks it keeps a soft 0.9 s rhythm. Each seam's glow and colour follow one band of the spectrum, the rails and curtains follow treble, mids and bass, the arches take turns with the three bands, and the sky's colours follow the spectrum as well as its shape. Details and gains: [Presentation](../lane-smash/PRESENTATION.md#music-reactive-scenery).

**Music in the interface.** Panel edges, the track chip, the rider's lane outline and the progress line in the ride; the wordmark, header rule and Start button in the selector; and an eight-bar meter (`LaneSmashSpectrum`) in both.

**Mix.** `GameOptions.SFX_LEVEL` 0.7 → 0.5 against `MUSIC_LEVEL` 0.65: effects go from 0.6 dB above the music to 2.3 dB below it. The two switches and the bike's own volume are unchanged.

**Tracks (generator 5).** See [Rules](../lane-smash/RULES.md#course-selection) for the tables.

| | Generator 4 | Generator 5 |
| --- | --- | --- |
| Cadence target | `60 + 4 × lane`, +20: 60–80 in lane 1 up to 80–100 in lane 6 | By effort: 95–115, 90–110, 85–105, 80–100, 70–90, 65–85; 75–95 warming up and recovering |
| Cadence section | 6 road-seconds | 8 road-seconds (about 11–15 s ridden in range) |
| Power Bursts | One per work minute (3 per 4-minute cycle) | One per minute and two in the hardest minute (4 per cycle), 40 road-seconds apart, each straight after a cadence section |
| Recovery minute | Lanes 2 → 3 → 2 | Lanes 2 → 1 → 2 |
| Lane changes, lane jumps, attack and mine placement rules | — | Unchanged |

The old cadence rule asked for the slowest pedalling in the lightest lane (so the bike crawled exactly where it should fly) and the fastest against the heaviest resistance. At Challenging, lane 6 is resistance 65–71; 80–100 rpm there is a sprint few riders can hold, while 60–80 rpm at resistance 30–36 is barely a warm-up.

**Resistance.** No value changed. The five ranges were already Lanebreak's published Bike levels; the research was repeated and six individual Lanebreak lanes were found, five of them read from the game's own display in review footage, all agreeing with the seven-value subdivision ([research note](../research/lanebreak/06-difficulty-ranges.md)). A test now pins all thirty lane bands and those six lanes.

## Compatibility

- Tracks generated now have a new fingerprint (generator 5), so they start without a previous best or ghost; rides saved earlier replay their own stored course and keep their records. Scoring version, storage schema and the Android side are unchanged apart from the app version.
- The stretch is presentation only. A saved ghost trace is in rules-metres and plays back correctly at the new scale.
- Typical scores rise by about 17% (see validation) because there is more to score, not because the scale changed.

## Acceptance criteria

1. Rules distance for a given cadence trace is identical to revision 11; one rules-metre is three world metres everywhere along the route.
2. Every marker type still shatters at the front tyre's contact, and the last marker at the scoring boundary.
3. Every arch between the camera and most of the pool's reach is standing on the route for a whole ride.
4. One seam pulse per kick; a soft steady rhythm with no kicks and in Reduced motion; a new pulse starts ahead of the wheel and nearly dark.
5. No seam level moves more than a quarter of its range in a frame at 30 fps on a full-scale step.
6. Interface colours are exactly the designed ones in silence, keep their alpha, and lean only toward the companion hue.
7. All thirty lane bands match the table; the six observed Lanebreak lanes fall on it.
8. Cadence targets follow the table above for every track; bursts are never closer than 30 road-seconds and never in a recovery minute; the recovery minute uses only lanes 1 and 2.
9. Effects default between 1.5 and 4 dB under the music.
10. Every named and seeded track still passes the full-duration audit on all five difficulties.
