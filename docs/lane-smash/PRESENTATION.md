# Presentation, controls and audio

Revision 11 rebuilt the look. Nothing here can change a score: renderers read the rules and never award or remove points.

## Art direction

A neon highway through a psychedelic tunnel, ridden on a motorcycle. Dark alloy surfaces, lit seams and a single accent colour per track; bloom carries the light. Four colours keep one meaning everywhere and are never used for scenery:

| Colour | Meaning |
| --- | --- |
| Gold | collect bars |
| Mint | cadence arrows and their bed |
| Violet | power sections |
| Red | road mines, penalties and loss numbers |
| Plasma orange | hostile energy: attackers' lamps, shots, blast zones, machine-gun fire |

Each track's saved palette (Arctic, Cobalt, Copper, Titanium, Petrol, Amber, Ember, Glacier) is lifted into a saturated accent pair at render time (`LaneSmashLook`); the saved course data is unchanged. Four skies remain: Prismatic flow, Kaleidoscope, Liquid aurora, Vortex.

## Interface

One theme (`LaneSmashMenuTheme`) styles the selector, settings, ride HUD, intro card, end-ride and recovery cards and results: dark glass panels with cut corners, one cyan accent, Rajdhani throughout.

- **Spacing:** an 8 px grid on the 1920×1080 stage (`S1`–`S6` = 8/16/24/32/48/64). Menus use a 56 px screen margin, the ride HUD 40 px. Panels pad their content 24–32 px.
- **Type:** wordmark 92, screen title 56, headings 44, body 36, labels 34. Menu text is never under 34 px. The ride HUD's small capitals (track chip, progress caption) are 26–28 px.
- **Touch targets (menus):** at least 120 px tall and 24 px apart; track cards 188 px. In the ride, Audio and End Ride keep the shared HUD's sizes.
- No visible scrollbars; the track library and history scroll. No Pause, reference-power/FTP setting or cosmetic unlocks.

**Selector.** Header: Exit, the LANE SMASH wordmark, what the jukebox is playing, Settings & history. Left: the track library (random-track button, then 25 cards). Right: one setup panel with Duration, Resistance (and its range), the selected track, sensor status and Start. The backdrop is the selected track's own sky, far back and dark. Track cards preview their palette and sky beneath a dark scrim; Reduced motion freezes the previews and the backdrop.

**Settings & history.** Audio: Music On/Off, the track picker and seek slider, Sound effects On/Off. Ride: Best-ride ghost, Background motion, Graphics. Then the latest 50 rides.

**Ride HUD.** Top left: rpm / W / resistance, with a chip under it for the track's name, speed and distance. Top centre: the current instruction on a glass backing. Top right: time left and score, then Audio and End Ride. Bottom: the six-lane dock (lane number and resistance range; the rider's lane filled, the section's target lane marked along its top in that section's colour), and under it the ride-progress line with the best-ride gap or a hint. Loss and award numbers float from where they happened and are kept inside the play area.

Riding: **Audio → Music / track / seek / Sound effects**, then **Done** or tap outside. The timer continues while this panel is open. Both locations use the same persistent device choices.

## Point counters

The HUD total and Power Burst's in-section counter sample new targets once per second, then animate at render rate. `PointRollup` uses a cubic ease-out: quick movement initially, gradual deceleration and an exact final value after **0.72 seconds**. Decreases finish in **0.30 seconds**. A newer target replaces the previous destination from the current displayed value; it never queues stale animations or overshoots. New rides and new burst sections reset their counters.

Labels and panels do not scale or bounce. Total-score digits reserve fixed width and use tabular figures. The power count is a separate fixed-width label so Pedal Faster and the points caption remain still. Metric/ghost/speed values keep their one-second snapshots. Exact award/penalty popups and saved results are not interpolated.

## Road, rider and scenery

The slightly transparent road is a fixed seeded path through space. Camera and rider move along it; the road is never reshaped. Full motion includes curves, loops and rolls; Reduced uses gentler curves without inversions.

- **Deck:** one ribbon per chunk. Its shader draws lit lane seams, ruler ticks every three metres and packets of light that run ahead along the seams, all from course distance and lateral position, so nothing slides on the surface.
- **Rails:** an alloy section along each edge with segmented running lights and a low curtain of light.
- **Gantries:** alloy arches over the road every 48 m, and streaks of light in the space around it. Both are fixed at course distances, so they pass at exactly the rider's speed and stop when the rider stops. They dim while attackers hold the stage.
- **Rider:** a long, low motorcycle with a faceted hull, glowing hub rings and tread lights, twin drive rotors and thrusters, and an armoured pilot. The rotors turn once per measured pedal revolution, the wheels roll at game speed, the thrusters lengthen with effort, and the bike leans into lane changes. A short ribbon of light trails the tail lamp along the route actually taken. The front tyre is the contact surface for every marker.
- **Best-ride ghost:** the same machine as a see-through projection of light, never hiding the road or a target.
- **Sky:** flows past at road-distance speed and shifts colour with resistance, with a sparse star field behind it.

Raised gold bars and mint arrows sit on the surface over a pool of their own light and shatter on front-wheel contact into shards, sparks, a shockwave and a flash. Cadence beds are anchored to their section. The power floor's charge front, strands of current and finish gate build with valid output. A section's finish sends up a beam of light and shows the earned total there.

Road mines are dark spiked cores with red lamps over a red ring on the deck; a hit is an energy blast, sparks, a camera knock and a red number. Incoming Fire's attackers are armoured raiders on hover sleds who charge and lob a plasma shot along a marked arc onto a marked zone. Cadence sections are strafed by a machine gunner on a sled: tracers, two fire lines on the road and, when a round lands, sparks and a red number.

Attackers only ever fade. A raider appears where it stands, over a little more than a second with scan lines that are strongest mid-fade, and leaves the same way over one to one and a half seconds; it never flies in or out and never pops. The machine gunner starts firing only once it is nearly solid, and its fire lines and the shot's marked arc fade with it.

**Comfort.** A hit knocks the camera briefly and pulses the screen's edge red; there is no full-screen flash, and a blast right in front of the camera fades instead of filling the view. Reduced motion removes the camera knock, the edge pulse, the light trail and beat-driven effects.

## Music-reactive scenery

The jukebox analyses the track that is playing (eight log-spaced bands from a 1024-point FFT, each normalised to its own running range, plus a bass-onset beat detector) and the sky reads it:

| Music | Picture |
| --- | --- |
| Bass | the tunnel walls breathe in and the filaments thicken; colours warm slightly |
| Mids | the cross-section bends and the ribbons widen |
| Treble | fine sparkle on the filaments and brighter stars |
| Kick | soft rings of light run down the tunnel, the field lifts slightly, road seams, rails, gantries and markers pulse |
| The track's energy over time | slowly turns the field and cycles its colours |

Every response is eased. The scenery reads the jukebox's calm values (`calm_bass`, `calm_mid`, `calm_treble`, `pulse`), which take about half a second to rise and a second to fall; a kick arrives as a soft swell at half depth, never as a flash, and the phase that turns the field advances at a slowly varying rate. The gains in the shader are deliberately modest (the walls breathe by 3.5%), because large, fast changes across the whole screen are tiring to ride into.

Forward motion is still only the rider's real distance: the music reshapes the field and never moves it. With Music Off, or silence, the field is exactly the calm one. Values are delayed by the device's audio output latency so picture and sound line up. Reduced motion passes 30% of the response and no beats. The selector's backdrop and track cards react the same way.

## Graphics tiers

The bike's tablet is fill-rate bound and has no headroom for MSAA (docs/GAMES.md, "On the tablet"), so the 3D view has three tiers; the HUD is always full resolution.

| Tier | 3D view | Extras |
| --- | --- | --- |
| High | 0.83 of the screen, MSAA 2× (desktop only), bloom | everything, plus slight colour fringing at speed |
| Balanced | 0.72, no MSAA, bloom | everything |
| Performance | 0.62, no MSAA, no bloom | no light streaks, pools of light, rail curtains, trail or stars |

**Settings → Graphics**: **Auto** (default), **High** or **Performance**. Auto starts on High (Balanced on the tablet); if a four-second window of riding averages under 50 fps it steps down one tier, remembers that for the next ride, and never steps back up mid-ride. Every surface is unshaded and lit in its own shader; there are no engine lights or fog. Each material is drawn once behind the intro so shaders compile before scored riding.

## Soundtrack

`Jukebox` (an autoload) plays one long track at a time on its own bus, which feeds the Music bus, so the Music switch, host volume and cue ducking keep working.

- At launch it starts a random track at a random position (at least 60 s before its end) and keeps playing across the selector, rides and results. When a track ends, a different random one starts from the beginning.
- The Audio panel and Settings show the track's name, one button per track and a seek slider with elapsed / total time. The slider previews while dragged and seeks once on release. Neither ever pauses a ride.
- Music Off, the rider's own music app or a host mute stop decoding and hold the position; On resumes there.
- Tracks load on a background thread; only the current one is held in memory.

The three tracks live in `games/games/neon_vector/audio/tracks/` (see that folder's README): Discovery Project (Electric Forest), DNS Mix and Dystopian Euphoria, all by Devloe, supplied by the fork's owner. The jukebox plays whichever of them exist; with none it loops the original **Night Drive** track (128 BPM) and hides the track picker.

## Sound map

| Event | Cue |
| --- | --- |
| Gold bar contact | Short rounded note; consecutive bars climb a pentatonic scale and reset after a 1.8 s gap |
| Mint arrow contact | Slightly higher, soft paired note |
| Positive ordinary section completion | Brief chord |
| Valid power accumulation | Quiet continuous harmonic bed; gain follows watts, pitch follows cadence |
| Power section completion | Fuller resolving chord and soft shimmer |
| Lane change | Very short soft tick (not in the first second) |
| Riding | Engine bed, −22 to −14 dB, pitch following cadence; silent below 5 rpm |
| Incoming target lock | Soft warning pulse, then a two-second weapon charge |
| Shot launch | Short rising sweep |
| Road mine hit | Thump, crack and debris |
| Incoming blast | The larger blast; heard quietly under a pass or avoid cue |
| Passing a blast | Positive short chord |
| Holding back safely | Gentle whoosh, no reward fanfare |
| Machine-gun fire | Looped fire while a cadence section is strafed: quieter during the warning, slightly higher when the rider is exposed |
| Machine-gun round lands | Short armour crack |
| Menu | Tap and confirm |

Every logical contact/completion/shot event plays when effects are enabled. There is **no repeat cooldown, random suppression or per-second sound quota**. Overlapping one-shots use the existing eight effect voices; the power, engine, charge and gun beds have their own players. Muting stops active sounds immediately and does not queue them for later. No sound is required to understand a gameplay prompt.

Effects are original deterministic PCM generated by `games/tools/render_lane_smash_sfx.py` (mono, 44.1 kHz, 16-bit); no downloaded or licensed third-party effects are used. One-shots run 0.085–0.59 seconds with attack and tail fades; loops are seamless.
