# Soundtrack

Lane Smash's long-form music, played by `LaneSmashJukebox` (the `Jukebox` autoload). These
three mixes were supplied by the fork's owner and added to the repository at the owner's
request.

| File | Shown as | Length |
| --- | --- | --- |
| `devloe_discovery_project.ogg` | Discovery Project (Electric Forest) — Devloe | 30:50 |
| `devloe_dns_mix.ogg` | DNS Mix — Devloe | 29:54 |
| `devloe_dystopian_euphoria.ogg` | Dystopian Euphoria — Devloe | 1:22:15 |

Stereo Ogg Vorbis, 44.1 kHz, quality 4 (about 122–126 kbps), each level-matched to about
−14 LUFS with a static gain (no dynamics processing) and its true peak below 0 dBTP.

The jukebox uses a fixed manifest (`LaneSmashJukebox.PERSONAL`) and plays whichever of these
files exist; with none it loops the original Night Drive track in the parent folder and hides
the track picker. To add or replace a track, convert it the same way and update the manifest:

```
ffmpeg -i source.mp3 -vn -map_metadata -1 -af volume=-6.5dB -c:a libvorbis -q:a 4 -ar 44100 -ac 2 devloe_dns_mix.ogg
```

Pick the `volume` value from an `ffmpeg -af loudnorm=print_format=json -f null -` measurement
so the track lands near −14 LUFS.
