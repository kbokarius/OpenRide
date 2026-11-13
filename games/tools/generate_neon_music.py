"""Render Vector Drive: an original 138 bpm instrumental, 64-bar seamless loop.
All oscillators and percussion are synthesized here; no samples or third-party music.
Run with numpy/scipy + ffmpeg. Intermediate WAV stays in the supplied work directory.
"""
from pathlib import Path
import subprocess
import sys
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io.wavfile import write

SR, BPM, BARS = 44100, 138, 64
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

roots = [42, 38, 45, 40] # F# minor / D / A / E
melody = [12, 7, 10, 14, 12, 7, 3, 7, 12, 15, 14, 10, 7, 10, 14, 7]
for bar in range(BARS):
    root = roots[(bar//4) % 4]
    section = (bar//8) % 4
    for beat in range(4):
        at = bar*4+beat
        add(drums, kick, at, .84)
        if beat in (1,3):
            add(drums, snare, at, .32)
            add(drums, snare, at+.028, .10, .25)
        add(drums, hat, at+.5, .20, .25 if beat%2 else -.25)
        if section != 2 or bar%8 >= 4:
            for sub in (.25,.75):
                add(drums, hat, at+sub, .055, -.35 if sub==.25 else .35)
    # Alternating octaves and off-beat bass keep the groove moving.
    for eighth in range(8):
        pitch = root - 12 + (12 if eighth in (3,7) else 0)
        add(music, tone(pitch, BEAT*.46, 9, 8), bar*4+eighth*.5+.08, .19)
    # Pulsed, wide harmonic bed.
    third = 3 if (bar//4)%4 == 0 else 4
    for off in (0,1.5,2.5):
        for n, interval in enumerate([0,third,7,12]):
            add(music, tone(root+12+interval, BEAT*1.4, 6, 2.5), bar*4+off, .025, (n-1.5)*.35)
    # Main hook varies every 16 bars; a lighter middle eight keeps the loop from tiring.
    if section != 2 or bar%8 >= 4:
        for eighth in range(8):
            midi = root + melody[(bar%2)*8+eighth] + (12 if section==3 else 0)
            add(music, tone(midi, BEAT*.75, 7, 7), bar*4+eighth*.5, .065, np.sin(eighth*1.7)*.35)
    if bar % 8 == 7:
        for j in range(6):
            add(drums, snare, bar*4+3+j/6, .07+j*.016, (j%2-.5)*.4)
    if bar % 16 == 15:
        t = np.arange(round(2*BEAT*SR))/SR
        rise = sosfilt(butter(2, 4000, 'highpass', fs=SR, output='sos'), rng.normal(size=len(t)))
        rise *= (t/t[-1])**2*.055
        add(music, rise, bar*4+2, 1, .1)

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
print(f'{out.name}: {N/SR:.3f}s, 138 bpm, peak {20*np.log10(np.max(np.abs(wave))):.2f} dBFS, RMS {20*np.log10(np.sqrt(np.mean(wave**2))):.2f} dBFS')
