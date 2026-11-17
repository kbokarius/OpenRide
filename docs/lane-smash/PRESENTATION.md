# Presentation, controls and audio

Revision 11 rebuilt the look; revision 12 made the road three times faster on screen and tied the road, scenery and interface to the music; revision 13 added the cadence gauge and the power-burst celebration, smoothed the picture's edges and made it much cheaper to draw. Nothing here can change a score: renderers read the rules and never award or remove points.

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

**Selector.** Difficulty buttons form two rows of three: Kid / Light / Moderate, then Hard / Challenging / Extreme. Kid displays 0–20 across six lanes. Explicit 34 px button fonts are preserved when selection styles change, preventing a temporary font enlargement from forcing a button over its neighbor. Header: Exit, the LANE SMASH wordmark, what the jukebox is playing with a small eight-bar meter of it (`LaneSmashSpectrum`), Settings & history. Left: the track library (random-track button, then 25 cards). Right: one setup panel with Duration, Resistance (and its range), the selected track, sensor status and Start. The backdrop is the selected track's own sky, far back and dark. Track cards preview their palette and sky beneath a dark scrim; Reduced motion freezes the previews and the backdrop.

**Settings & history.** Audio: Music On/Off, the track picker and seek slider, Sound effects On/Off. Ride: Best-ride ghost, Background motion, Graphics. Then the latest 50 rides.

**Cadence gauge** (`LaneSmashCadenceGauge`). From an estimated 1.2 active seconds before the currently approached cadence section until it ends, a panel floats beside the motorcycle, on the side away from the middle of the road so it never covers the lane ahead: a vertical track from the section's lowest rpm (bottom) to its highest (top) with both numbers, a bright band across the middle for the sweet spot, a marker where the rider's cadence is, the measured rpm in large digits beside the marker, and one word underneath. Mint means in range, white-hot means in the sweet spot, red means out of range.

| State | Word | When |
| --- | --- | --- |
| Ahead | GET READY | the section is coming; the panel is titled NEXT · RPM |
| Sweet spot | SWEET SPOT | within 3 rpm of the middle |
| In range | AIM FOR MIDDLE | in the band, outside the sweet spot |
| Too slow / too fast | FASTER / SLOWER | outside the band: the marker stops just past the end of the track |

The instruction panel's second line gives the sweet spot in numbers ("82–88 rpm pays +20%"). The design follows the gauge Lanebreak draws on its wheel during a cadence section (a range bar with the limits at its ends and a dot for the rider's cadence), with the sweet spot drawn in.

**Bomb gauge** (`LaneSmashBarrageGauge`). A vertical panel beside the bike replaces the top horizontal bar, using the cadence panel’s size and shared bounded anchor. Its scale shows predicted position at impact: green above the blast, red across the middle and dark slate below. A white marker follows smoothly; the countdown, pace instruction and actual outcome/points make prediction distinct from a confirmed dodge. It fades during preparation/exit and suppresses the cadence panel while present.

**Power-burst celebration** (`LaneSmashCelebration`). When a power burst ends with points, the middle of the screen gets a flash, two rings and eighteen rays flying outward, tumbling shards, a word and the points earned in 148 px digits that punch in past full size and settle. It is in within a tenth of a second and gone in 1.3. The word depends on the output against the 150 W reference: POWER BURST, FULL POWER (100%), SUPERCHARGED (140%) or OVERCHARGED (200%). It replaces the small floating number for bursts. Reduced motion keeps the word and number and drops the rest.

**Scrolling.** The track library and the settings list scroll when a finger is dragged anywhere on them, including on a card or a button (`LaneSmashDragScroll`): more than 14 px of travel turns the press into a scroll, the list coasts a little after the finger lifts, and the button it started on is not activated. Before revision 13 only the gaps between cards scrolled, because each card kept the touch for itself.

**Ride HUD.** Top left: rpm / W / resistance, with a chip under it for the track's name (and, while music plays, the same eight-bar meter), speed and distance. Top centre: the current instruction on a glass backing. Top right: time left and score, then Audio and End Ride. Bottom: the six-lane dock (lane number and resistance range; the rider's lane filled, the section's target lane marked along its top in that section's colour), and under it the ride-progress line with the best-ride gap or a hint. Loss and award numbers float from where they happened and are kept inside the play area.

Riding: **Audio → Music / track / seek / Sound effects**, then **Done** or tap outside. The timer continues while this panel is open. Both locations use the same persistent device choices.

## Point counters

Exact tuning values and geometry dimensions are maintained in [Parameters](PARAMETERS.md).

The HUD total and Power Burst counter follow new targets every render frame. `PointRollup` uses an analytic critically damped follower (gain rate 12/s, loss rate 18/s), preserving velocity when a new gain arrives. There is no once-per-second target latch, restarted tween or stop/start gap. Penalties reverse cleanly without overshoot. Only sub-hundredth-point settling is snapped internally, after the visible integer has already reached the result. Saved scores remain authoritative and immediate. New rides and new burst sections reset their counters.

Labels and panels do not scale or bounce. Total-score digits reserve fixed width and use tabular figures. The power count is a separate fixed-width label so Pedal Faster and the points caption remain still. Metric/ghost/speed values keep their one-second snapshots. Exact award/penalty popups and saved results are not interpolated.

## Road, rider and scenery

The slightly transparent road is a fixed seeded path through space. Camera and rider move along it; the road is never reshaped. Full motion includes curves, loops and rolls; Reduced uses gentler curves without inversions.

**Resistance steering (revision 14).** Lanes are 4.2 m wide. Each band's resistance values (seven in adult modes; alternating four/three in Kid) move the motorcycle smoothly from centre −28% of a lane to centre +28%; crossing the next threshold produces a quick eased shift. A pale blue target-lane wash and inset lines crossfade over 0.32 s in the deck shader. The current or next target is always highlighted, including long approaches, interruption screens and the final roll-out. If the rider is outside its resistance range, a small prompt below the main instruction says **MOVE LEFT / LESS RESISTANCE** or **MOVE RIGHT / MORE RESISTANCE**, with direction chevrons; it fades away anywhere within the correct band. Reduced Motion suppresses its pop and chevron movement. The chase camera sits 17.5 m behind and 7.4 m above the rider. The cadence gauge keeps clear of the motorcycle, moving inward when the outer screen edge lacks room. Ghosts remain centred because stored traces contain lanes, not within-lane resistance. See [revision 14](../specs/lane-smash-v14.md).

**Inner lane-edge warning.** When reported resistance is in the outer quarter of a band next to an internal seam, that nearby line fades to brighter coral-red over 0.3 seconds. It fades away toward lane center, and crossing the threshold keeps the same boundary highlighted. Only the five inside lines can warn; the two exterior edges cannot. The existing road shader tints the line near the bike without extra geometry, blinking, sound, steering or scoring changes.

**Speed.** The picture draws every rules-metre as three world metres (`NeonSpace.STRETCH = 3`, applied in `LaneSmashCoaster`'s integration step), so the same pedalling covers three times the ground on screen: about 77 mph at 96 rpm and 112 mph at 140 rpm, against 37 mph before. The route keeps its shape per rules-metre (a loop is three times larger and takes the same riding time). Everything with a real size keeps that size in world metres: the bike, lane width, markers, arches, ticks and the tyre's contact reach, which is why contact distances are divided by the stretch. Course events, scoring, ghost positions and saved rides are untouched and still in rules-metres. The HUD multiplies speed and distance by the stretch so the numbers agree with the picture.

- **Deck:** one ribbon per chunk. Its shader draws lit lane seams and ruler ticks every six metres from course distance and lateral position, so nothing slides on the surface. The one thing that does move is on purpose: pulses of light that run ahead along the seams (below).
- **Rails:** an alloy section along each edge with running lights in eight-metre bars and a low curtain of light. (Ticks and bars repeat over more than twice the 1.6 m the bike covers per frame at top speed at 30 fps, so they never appear to stand still or run backwards.)
- **Gantries:** alloy arches over the road every 64 world metres, and streaks of light in the space around it. Both are fixed at course distances, so they pass at exactly the rider's speed and stop when the rider stops; an arch fades in at the far end of its window and stays until it is behind the camera. They dim while attackers hold the stage.
- **Rider:** a long, low motorcycle with a faceted hull, glowing hub rings and tread lights, twin drive rotors and thrusters, and an armoured pilot. The rotors turn once per measured pedal revolution, the wheels roll at game speed, the thrusters lengthen with effort, and the bike leans into lane changes. A short ribbon of light trails the tail lamp along the route actually taken. The front tyre is the contact surface for every marker. Revision 16 narrows the front cowl and winglets; each booster plume is now rooted at its nozzle, with crossed planes and wider spacing so it stays visible in the middle lanes. The rear tyre now uses a separate cached superbike mesh: 0.64 design units wide (four times its previous 0.16), a fuller rounded sidewall, a wider rim/axle and outward-set swingarms. The front tyre, rolling radius, contact timing and lean animation keep their existing dimensions and behavior. The same rear geometry is shared by the best-ride ghost. Native riding-camera and close-up renders were checked after the change; it adds no per-frame mesh generation or extra wheel draw calls.
- **Best-ride ghost:** the same machine as a see-through projection of light, never hiding the road or a target.
- **Sky:** flows past at road-distance speed and shifts colour with resistance, with a sparse star field behind it.

Raised gold bars and mint arrows sit on the surface over a pool of their own light and shatter on front-wheel contact into shards, sparks, a shockwave and a flash. Cadence beds are anchored to their section. The power floor's charge front, strands of current and finish gate build with valid speed-weighted output; physical joules remain separate in ride statistics. A section's finish sends up a beam of light and shows the earned total there.

Power floors use a bright, saturated violet bed even before charging, with pale rims, a dark outer hairline and white start/end caps of fixed world width. Their diagonal etching stays fixed to the road. Output adds brighter strands and a travelling charge front. The outer finish-gate ring is always full size, while its inner rings grow with the charge. The treatment remains readable on Performance with bloom disabled.

Road mines are dark spiked cores with red lamps over a red ring on the deck; a hit is an energy blast, sparks, a camera knock and a red number. Incoming Fire's attackers are armoured raiders on hover sleds who charge and lob a plasma shot along a marked arc onto a marked zone. Cadence sections are strafed by a machine gunner on a sled: tracers, two fire lines on the road and, when a round lands, sparks and a red number.

Attackers only ever fade. The bomb shooter appears over 1.4 seconds during the two-second charge, stays fully visible for the complete nine-second flight and 0.3 seconds after impact, then fades out by impact +1.2 seconds. Revision 15 fixes the old disappearance two seconds after launch. A camera-relative foreground rig keeps the 3D model ahead of road loops and gantries; six display slots stay below the HUD, and a stable three-quarter pose faces the rider rather than turning edge-on toward a curved landing zone. The machine gunner uses the same 1.2-active-second preview signal as the cadence gauge. Firing begins on the first active frame; a sudden acceleration or resumed render raises its presence to at least 0.9 so fading never delays the firing cue. Damage still has its existing grace period.

The bomb and its tail draw in front of the foreground shooter, retaining the fixed arc's projected position and apparent size. The launch advances quickly out of the muzzle, then eases into its flight; progress is monotonic and still reaches the locked world target at exactly the original impact time. The landing zone spans all six widened lanes. Those presentation-only changes preserve timing, dodge rules, scores and course fingerprints; see [revision 15](../specs/lane-smash-v15.md).

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

Colour follows the spectrum as well as shape (revision 12). In the sky, mids slide the field between its two colours and turn the first hue, treble turns the second and pushes the bright filaments toward a cooler hue, and bass warms the body of the ribbons; the two extra hues are the palette's own channels rotated, so they stay related to the track's colours. On the road and around it:

| Piece | Follows |
| --- | --- |
| Seam pulses | One leaves the bike's front wheel on every detected kick and runs ahead at 190 world m/s plus the bike's own speed, as a chevron with the centre seam leading; its strength follows the bass. It brightens over its first 0.16 s, so it never flashes beside the bike, and fades out by two seconds, past the visible road. Up to six are alive. With no kicks arriving (silence, Music Off, a breakdown, Reduced motion) a soft pulse leaves every 0.9 s, so the road is never dead |
| Lane seams | Each seam's steady glow and colour (accent toward the second colour) follow one part of the spectrum: bass on the centre seam, low mids, high mids, then treble on the outer seams. A faint band of the same colour crosses the deck with each pulse |
| Rails and curtains | Running lights take the treble's colour and level, the cap and the curtain the mids', and the curtain rises with the bass |
| Gantries | Arches take turns down the road with bass, mids and treble: each one's light strip swells and changes colour with its own band |
| Light streaks | Brighten with the treble |

The interface's accent lines breathe the same way (`LaneSmashLook.pulsed`): toward the companion hue with the mids and treble, brighter with the bass and each kick. In the ride that is the edges of the ride, clock and instruction panels, the track chip's edge, the outline of the rider's lane in the dock and the progress line; in the selector it is the wordmark's second word, the header rule and the Start button's edge. Both carry the eight-bar meter. Text never changes colour and no panel changes size, so nothing that has to be read moves.

Every response is eased. The seams ease the live bands themselves (about 0.15 s up, 0.4 s down) and the small meters a little faster; everything large reads the jukebox's calm values. The scenery reads the jukebox's calm values (`calm_bass`, `calm_mid`, `calm_treble`, `pulse`), which take about half a second to rise and a second to fall; a kick arrives as a soft swell at half depth, never as a flash, and the phase that turns the field advances at a slowly varying rate. The gains in the shader are deliberately modest (the walls breathe by 3.5%), because large, fast changes across the whole screen are tiring to ride into.

Forward motion is still only the rider's real distance: the music reshapes the field and never moves it. With Music Off, or silence, the field is exactly the calm one. Values are delayed by the device's audio output latency so picture and sound line up. Reduced motion passes 30% of the response and no beats: the seam pulses keep only their steady rhythm, the seams hold their plain colour and the menu's accent pieces stay still. The selector's backdrop and track cards react the same way.

## Graphics tiers

The bike's tablet has little to spare: upstream's measurements on it (docs/GAMES.md, "On the tablet") show a throttling four-core chip where every rendered view costs CPU time, pixels cost frame rate, MSAA halves the frame rate and draws black, and the engine's FXAA does nothing in this renderer. So the 3D view has three tiers; the HUD is always full resolution.

| Tier | 3D view | Edges | Bloom and grade | Sky | Extras |
| --- | --- | --- | --- | --- | --- |
| High | the full screen (0.9 of it on the bike) | MSAA 2× on a desktop, plus the lens pass's smoothing | the engine's | drawn at full size | everything, plus slight colour fringing at speed |
| Balanced (Auto's initial tablet tier) | 0.80 of the screen (was 0.72) | smoothed in the lens pass | two small passes added in the lens pass | drawn at half size each way | everything |
| Performance | 0.66 (was 0.62) | smoothed in the lens pass | none; graded in the lens pass | half size | no light streaks, pools of light, rail curtains, trail or stars |

Revision 13 moved three things out of the engine's hands to make that affordable:

- **Edge smoothing** lives in the lens pass (`ride_view.gdshader`), the one pass that already touches every screen pixel to scale the 3D view up. It reads the four diagonal neighbours; where they differ enough to be an edge it blends the pixel along that edge (the FXAA method), and leaves everything else sharp.
- **Bloom** on the Balanced tier is two quarter-size passes (`bloom_down.gdshader` keeps what is bright by luminance, so the sky's saturated ribbons stay out of it; `bloom_blur.gdshader` blurs it in one pass) added in the lens pass, in place of the engine's chain of passes over a high-range copy of the picture. In the desktop profile the engine's bloom and grade were about half of the picture's fill cost.
- **The sky's shader**, the heaviest in the picture (about a fifth of the fill cost in the same profile), is drawn into a small off-screen image (`psychedelic_sky_pass.gdshader`) and the sky itself only reads that image. Because the sky's own material no longer changes from frame to frame, the engine also stops re-filtering the sky every frame. The off-screen image is a child of the 3D view, so it is drawn first and is never a frame behind the camera.

The road's pulses went from six to four alive at once (the road, rail and curtain shaders loop over them for every pixel). These are savings by construction and by a desktop profile (`tests/profile_lane_smash_gpu.gd`); the tablet's own frame rate has not been measured.

**Settings → Graphics**: **Auto** (default restored in revision 18), **High** or **Performance**. High holds the highest existing preset throughout the ride and ignores Auto's remembered tier. Explicit saved choices remain respected. Auto starts on High (Balanced on the tablet), or its remembered tier. `LaneSmashGovernor` watches four-second windows of riding; after two in a row under 50 fps it steps down one tier, remembers that for the next ride, and never steps back up mid-ride. A single long frame (over 0.2 s) is left out of the count: before revision 13 one hitch could pull a window under the floor and cost the rest of the ride, and every ride after it, its resolution. The tier an earlier build settled on is forgotten once, since the cost of every tier changed. Every surface is unshaded and lit in its own shader; there are no engine lights or fog. Each material is drawn once behind the intro so shaders compile before scored riding.

## Soundtrack

`Jukebox` (an autoload) plays one long track at a time on its own bus, which feeds the Music bus, so the Music switch, host volume and cue ducking keep working. The default mix (`GameOptions.MUSIC_LEVEL` 0.65, `SFX_LEVEL` 0.5) puts the effects about 2.3 dB under the music; before revision 12 they sat 0.6 dB above it.

- At launch it starts a random track at a random position (at least 60 s before its end) and keeps playing across the selector, rides and results. When a track ends, a different random one starts from the beginning.
- Nothing starts or stops abruptly. Whatever starts fades in over 0.6 s; whatever was playing (the track being replaced, the old position of a seek, the music when it is switched off or held) fades out over 0.4 s on a second player while the new sound comes in, so a change of track or position is a short crossfade.
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

Revision 16 adds a lane-checked drop taking at most 450 ms for wrong-lane entries. It smoothly redirects the bomb, preserves its foreground depth, and uses a compact blast in the offending lane. The existing shooter fades remain tied to the actual impact. The nine-second preparation highlights the required lane and shows a countdown; a rapid strike displays **WRONG LANE · INCOMING BOMB**. See [revision 16](../specs/lane-smash-v16.md) and [the current rules](RULES.md).


### Immediate bomb-pass feedback (revision 19)

Passing the full blast footprint triggers the +1,800 popup and pass cue immediately. The flying bomb remains visible until actual impact, then explodes once with its distant impact cue. View state independently tracks reward feedback and physical impact so neither can be duplicated or appear early. The final impact fades before ordinary play resumes; the former idle eight seconds are removed.

### Resistance feedback (revision 23 source)

The resistance number follows each delivered change immediately using the existing cached label; RPM/watts/heart rate keep their steady one-second cadence. Steering prompts refresh on a changed resistance reading and acknowledge the correct band without waiting for score eligibility. The motorcycle follows a within-lane step at 24/s and a threshold crossing at 40/s, with the same smooth, non-overshooting path. The inner-edge warning uses RGB (0.95, 0.34, 0.38) at the existing 92% maximum blend, 0.3-second fade and bounded road window. No blinking, extra geometry, exterior-edge warning or wider warning region is added.
