# Night Drive

Original 128 BPM dark electronic instrumental for Lane Smash: 64 bars, 120 seconds, stereo Ogg Vorbis. Deep syncopated bass, restrained acid pulses, industrial percussion and suspended minor pads. Synthesized from oscillators and deterministic noise, without third-party recordings or samples. Licensed under the repository's Apache-2.0 license.

Reproduce from the repository root with `python3 games/tools/generate_neon_music.py ../lane-smash-audio`. The directory argument holds the intermediate WAV. Requires NumPy, SciPy and ffmpeg. AudioDirector sets the stream to loop from zero; its import flag alone does not enable looping. The master peaks at -1.5 dBFS with approximately -14.32 dBFS RMS. Music is optional and never affects scoring.
