# Lane Smash audio

## Soundtrack: the jukebox

`LaneSmashJukebox.gd` (autoload `Jukebox`) plays one long track at a time on its own bus,
`LaneSmashMusic`, which feeds AudioDirector's `Music` bus. The app starts on a random track at a
random position and keeps playing across the menu, rides and results. A track that ends hands
over to another random one. The rider picks a track and seeks with `LaneSmashMusicPanel`
(the in-ride **Audio** menu and **Settings & history**). Music Off, the rider's own music app or
a host mute stop decoding and hold the position.

The three long-form tracks live in [`tracks/`](tracks/README.md): Discovery Project (Electric Forest), DNS Mix and Dystopian Euphoria by Devloe, supplied by the fork's owner. A build without them plays Night Drive and hides the track picker.

The jukebox also publishes a live analysis of what is playing (`level`, `bass`, `mid`, `treble`,
`beat`, `beat_count`, `flow`, eight `bands`) for the visuals. It is presentation only.

### Night Drive

Original 128 BPM dark electronic instrumental: 64 bars, 120 seconds, stereo Ogg Vorbis. Deep
syncopated bass, restrained acid pulses, industrial percussion and suspended minor pads.
Synthesized from oscillators and deterministic noise, without third-party recordings or samples.
Licensed under the repository's Apache-2.0 license. Reproduce from the repository root with
`python3 games/tools/generate_neon_music.py ../lane-smash-audio` (NumPy, SciPy and ffmpeg). The
master peaks at -1.5 dBFS with approximately -14.32 dBFS RMS.

## Sound effects

Every file under `sfx/` is original, rendered by `python3 games/tools/render_lane_smash_sfx.py`
(NumPy and SciPy) from layered FM and sine partials, seeded noise, pitch envelopes, a few early
reflections and soft saturation: mono, 44.1 kHz, 16-bit PCM, imported uncompressed
(`compress/mode=0`). Re-running the script reproduces the files bit for bit.

| File | Used for |
| --- | --- |
| `collect`, `cadence` | Gold-bar and cadence-arrow contacts (consecutive gold bars climb a pentatonic scale) |
| `section`, `power_finish` | A scored section's end; a power section's end |
| `lane` | A settled change to another lane |
| `warning`, `charge`, `launch` | Incoming Fire: target lock, the weapon charging for two seconds, the shot |
| `impact`, `pass`, `avoid` | The blast (quieter and lower under a dodge); passing it; holding back |
| `bomb` | A road bomb |
| `gun_loop`, `gun_hit` | Machine-gun fire over a cadence section; a round striking the rider |
| `power_loop`, `engine_loop` | Beds: the power-section charge; the motorcycle's engine |
| `ui_tap`, `ui_confirm` | Menu and audio-panel buttons |

One-shots in `LaneSmashSound.FILES` stay between 0.07 and 0.6 seconds. The loops repeat exactly:
every component completes whole cycles (or is folded around the loop point) within the file.
