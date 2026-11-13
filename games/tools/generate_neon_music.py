"""Render Night Drive: an original 128 bpm dark techno instrumental, 64-bar seamless loop.
All oscillators and percussion are synthesized here; no samples or third-party music.
Run with numpy/scipy + ffmpeg. Intermediate WAV stays in the supplied work directory.
"""
from pathlib import Path
import subprocess
import sys
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io.wavfile import write

SR, BPM, BARS = 44100, 128, 64
BEAT = 60 / BPM
N = round(BARS * 4 * BEAT * SR)
rng = np.random.default_rng(20261113)
drums = np.zeros((N, 2), dtype=np.float32)
music = np.zeros_like(drums)


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def add(bus, signal, beat, gain=1.0, pan=0.0):
    start = round(beat * BEAT * SR) % N
    signal = signal.astype(np.float32)
    stereo = signal[:, None] * np.array([np.sqrt((1-pan)/2), np.sqrt((1+pan)/2)]) * gain
    end = min(N, start + len(signal))
    bus[start:end] += stereo[:end-start]
    if end-start < len(signal):
        bus[:len(signal)-(end-start)] += stereo[end-start:]


def tone(midi, duration, bright=10, decay=3.0):
    t = np.arange(round(duration * SR)) / SR
    f = note(midi)
    signal = np.zeros_like(t)
    for k in range(1, bright+1):
        # Two gently detuned, band-limited oscillators; harmonics decay at different rates.
        envelope = np.exp(-t * decay * (1 + k * .08))
        signal += (np.sin(2*np.pi*f*k*t) + .4*np.sin(2*np.pi*f*1.003*k*t)) / k * envelope
    signal *= np.minimum(t / .007, 1) * np.minimum((duration-t) / .045, 1)
    return signal

# Compact, punchy kick; no clipped sample edges.
t = np.arange(round(.36 * SR))/SR
phase = 2*np.pi*(48*t + 95*.025*(1-np.exp(-t/.025)))
kick = np.tanh(1.55*np.sin(phase)) * np.exp(-t*12) + .13*rng.normal(size=len(t))*np.exp(-t*170)
kick *= np.minimum(t/.001, 1)
t = np.arange(round(.23*SR))/SR
noise = rng.normal(size=len(t))
snare = sosfilt(butter(2, 1300, 'highpass', fs=SR, output='sos'), noise) * np.exp(-t*24)
snare += .22*np.sin(2*np.pi*190*t)*np.exp(-t*23)
snare *= np.minimum(t/.001, 1)
t = np.arange(round(.15*SR))/SR
hat = sosfilt(butter(2, 7000, 'highpass', fs=SR, output='sos'), rng.normal(size=len(t))) * np.exp(-t*55)

# Restrained minor harmony, deep syncopated bass and slowly opening acid texture.
# No upper-octave arcade hook; energy comes from drums and groove.
roots = [38, 38, 36, 33]  # D minor / C / A pedal tones
for bar in range(BARS):
    root = roots[(bar // 8) % 4]
    section = (bar // 8) % 4
    for beat in range(4):
        at = bar * 4 + beat
        add(drums, kick, at, .92)
        if beat in (1, 3):
            add(drums, snare, at, .19)
            add(drums, snare, at + .035, .065, .25)
        add(drums, hat, at + .5, .15, .18)
        for sub, gain in [(.25, .035), (.75, .055)]:
            add(drums, hat, at + sub + (.016 if sub == .75 else 0), gain, -.3)
    for step, octave, gain in [(0.75,0,.24),(1.5,0,.22),(2.25,0,.27),(2.75,12,.11),(3.5,0,.25)]:
        add(music, tone(root - 12 + octave, BEAT * .52, 5, 7), bar * 4 + step, gain)
    # Metallic, off-grid percussion, kept below the main kick and hats.
    for step in [1.75, 3.25]:
        add(drums, tone(root + 31, BEAT * .15, 3, 60), bar * 4 + step, .045, -.4 if step < 2 else .4)
    # Dark suspended pad with long overlapping tails, changes only every two bars.
    if bar % 2 == 0:
        for n, interval in enumerate([0, 7, 10]):
            pad = tone(root + 12 + interval, BEAT * 9, 3, .42)
            attack = np.minimum(np.arange(len(pad)) / (SR * .28), 1)
            add(music, pad * attack, bar * 4, .018, (n - 1) * .65)
    # Restrained resonant pulse: filter/harmonic density evolves across eight bars.
    if section != 2 or bar % 8 >= 4:
        pattern = [(0.5,0), (1.25,0), (2.5,7), (3.25,3)]
        for step, interval in pattern:
            acid = tone(root + 12 + interval, BEAT * .55, 3 + bar % 8, 12)
            add(music, acid, bar * 4 + step, .035, np.sin(bar * .4) * .35)
    if bar % 8 == 7:
        for j in range(3):
            add(drums, snare, bar * 4 + 3.5 + j / 6, .035 + j * .01, (j % 2 - .5) * .4)

# Tempo-synced stereo echoes wrap around the loop, including their tails.
wet = music.copy()
for beats, gain in [(.75,.23),(1.5,.11),(2.25,.055)]:
    wet += np.roll(music[:,::-1], round(beats*BEAT*SR), axis=0)*gain
phase = (np.arange(N)/SR/BEAT) % 1
pump = .38 + .62*(1-np.exp(-phase*7))
wave = drums + wet*pump[:,None]
wave = np.tanh(wave*1.25)
wave *= 10**(-1.5/20)/np.max(np.abs(wave))
work = Path(sys.argv[1]); work.mkdir(parents=True, exist_ok=True)
wav = work/'vector_drive.wav'
write(wav, SR, (wave*32767).astype(np.int16))
out = Path(__file__).resolve().parents[1]/'games/neon_vector/audio/vector_drive.ogg'
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','6',str(out)],check=True)
print(f'{out.name}: {N/SR:.3f}s, {BPM} bpm, peak {20*np.log10(np.max(np.abs(wave))):.2f} dBFS, RMS {20*np.log10(np.sqrt(np.mean(wave**2))):.2f} dBFS')
