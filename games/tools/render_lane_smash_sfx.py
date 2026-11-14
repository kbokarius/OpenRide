"""Original Lane Smash sound effects, synthesised from oscillators and seeded noise.

No recordings or third-party samples: every cue is rendered here from layered FM/sine
partials, filtered deterministic noise, pitch envelopes, a few early reflections and soft
saturation. Output is mono 44.1 kHz 16-bit PCM under games/neon_vector/audio/sfx.

    python3 games/tools/render_lane_smash_sfx.py

Requires NumPy and SciPy. Re-running reproduces the same files bit for bit.
One-shots stay under 0.6 s (LaneSmashSound.FILES); loops are exactly periodic.
"""
from pathlib import Path
import wave

import numpy as np
from scipy import signal

RATE = 44100
OUT = Path(__file__).resolve().parents[1] / "games/neon_vector/audio/sfx"
TAU = 2.0 * np.pi


def samples(seconds):
    return int(round(seconds * RATE))


def clock(seconds):
    return np.arange(samples(seconds)) / RATE


def glide(start, end, count, curve=1.0):
    """Exponential pitch glide; curve > 1 holds the start longer, < 1 leaves it quickly."""
    u = np.linspace(0.0, 1.0, count) ** curve
    return start * (end / start) ** u


def phase_of(frequency):
    return TAU * np.cumsum(frequency) / RATE


def tone(frequency, count=None):
    if np.isscalar(frequency):
        frequency = np.full(count, float(frequency))
    return np.sin(phase_of(frequency))


def fm(frequency, ratio, index, count=None):
    """Two-operator FM; `index` may be an envelope. Index 0 is a plain sine."""
    if np.isscalar(frequency):
        frequency = np.full(count, float(frequency))
    carrier = phase_of(frequency)
    return np.sin(carrier + index * np.sin(carrier * ratio))


def decay(count, seconds, attack=0.004):
    t = np.arange(count) / RATE
    return np.minimum(1.0, t / max(attack, 1e-5)) * np.exp(-t / seconds)


def hann(count):
    return 0.5 - 0.5 * np.cos(TAU * np.arange(count) / max(1, count - 1))


def noise(count, seed):
    return np.random.default_rng(seed).uniform(-1.0, 1.0, count)


def band(x, low, high, order=2):
    nyquist = RATE / 2.0
    if low <= 0:
        sos = signal.butter(order, min(high, nyquist * 0.98) / nyquist, "lowpass", output="sos")
    elif high >= nyquist:
        sos = signal.butter(order, low / nyquist, "highpass", output="sos")
    else:
        sos = signal.butter(order, [low / nyquist, high / nyquist], "bandpass", output="sos")
    return signal.sosfilt(sos, x)


def swept_noise(count, seed, centre, width=0.6):
    """Noise through a band-pass whose centre follows `centre` (array, Hz): a whoosh."""
    source = noise(count, seed)
    out = np.zeros(count)
    block = 256
    state = None
    for start in range(0, count, block):
        stop = min(count, start + block)
        mid = float(centre[min(count - 1, (start + stop) // 2)])
        low = max(30.0, mid * (1.0 - width * 0.5))
        high = min(RATE * 0.45, mid * (1.0 + width * 0.5))
        sos = signal.butter(1, [low / (RATE / 2), high / (RATE / 2)], "bandpass", output="sos")
        if state is None:
            state = signal.sosfilt_zi(sos) * 0.0
        out[start:stop], state = signal.sosfilt(sos, source[start:stop], zi=state)
    return out


def periodic_noise(count, seed, low, high):
    """Band-limited noise that repeats exactly every `count` samples (for seamless loops)."""
    rng = np.random.default_rng(seed)
    bins = count // 2 + 1
    frequencies = np.fft.rfftfreq(count, 1.0 / RATE)
    spectrum = np.zeros(bins, dtype=complex)
    keep = (frequencies >= low) & (frequencies <= high)
    shape = np.exp(-((np.log(np.maximum(frequencies, 1.0)) - np.log(np.sqrt(low * high))) ** 2) * 1.5)
    spectrum[keep] = shape[keep] * np.exp(1j * rng.uniform(0, TAU, int(keep.sum())))
    out = np.fft.irfft(spectrum, count)
    return out / (np.max(np.abs(out)) + 1e-9)


def saturate(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def reflections(x, taps=((0.0113, 0.30), (0.0197, 0.21), (0.0311, 0.14), (0.0463, 0.08)), tone_hz=5200.0):
    """A small, bright room: a few low-passed early reflections folded into the same length."""
    wet = np.zeros_like(x)
    for seconds, gain in taps:
        shift = samples(seconds)
        if shift < len(x):
            wet[shift:] += x[: len(x) - shift] * gain
    return x + band(wet, 0, tone_hz, 1)


def place(target, piece, at_seconds):
    start = samples(at_seconds)
    stop = min(len(target), start + len(piece))
    if stop > start:
        target[start:stop] += piece[: stop - start]


def finish(x, peak_db, fade_in=0.004, fade_out=0.02, loop=False):
    x = np.asarray(x, dtype=float)
    if loop:
        x = x - np.mean(x)
    else:
        x = band(x, 22.0, RATE, 1)
        a = min(len(x) // 2, samples(fade_in))
        b = min(len(x) // 2, samples(fade_out))
        x[:a] *= np.linspace(0.0, 1.0, a) ** 2
        x[-b:] *= np.cos(np.linspace(0.0, np.pi / 2, b)) ** 2
        x[0] = 0.0
        x[-1] = 0.0
    return x / (np.max(np.abs(x)) + 1e-12) * 10.0 ** (peak_db / 20.0)


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(OUT / f"{name}.wav"), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    peak = 20.0 * np.log10(np.max(np.abs(pcm)) / 32767.0 + 1e-12)
    rms = 20.0 * np.log10(np.sqrt(np.mean((pcm / 32767.0) ** 2)) + 1e-12)
    print(f"{name:14s} {len(pcm) / RATE:6.3f} s   peak {peak:6.2f} dBFS   rms {rms:6.2f} dBFS")


def bell(frequency, seconds, tau, index=1.6, ratio=2.0, bright=0.3):
    """A glassy FM pluck whose brightness dies faster than its body."""
    count = samples(seconds)
    body = decay(count, tau, 0.003)
    sparkle = decay(count, tau * 0.35, 0.002)
    return fm(frequency, ratio, index * sparkle, count) * body + bright * tone(frequency * 3.01, count) * sparkle


# ---------------------------------------------------------------------------------------
# Frequent contact cues: short, rounded, quiet enough to repeat without fatigue.

def collect():
    count = samples(0.115)
    x = bell(783.99, 0.115, 0.030, 1.8, 2.0, 0.25)
    x += 0.35 * tone(1567.98, count) * decay(count, 0.018, 0.002)
    x += 0.10 * band(noise(count, 11), 5000, RATE) * decay(count, 0.004, 0.0005)
    return finish(reflections(x, ((0.009, 0.18), (0.017, 0.10))), -9.0, 0.003, 0.012)


def cadence():
    x = np.zeros(samples(0.135))
    place(x, bell(880.00, 0.08, 0.022, 0.9, 2.0, 0.15), 0.0)
    place(x, 0.8 * bell(1318.51, 0.08, 0.020, 0.9, 2.0, 0.15), 0.052)
    return finish(reflections(x, ((0.009, 0.16), (0.017, 0.08))), -10.0, 0.003, 0.012)


def lane():
    count = samples(0.092)
    blip = tone(glide(520.0, 700.0, count, 0.6)) * decay(count, 0.018, 0.004)
    air = swept_noise(count, 23, glide(1800.0, 4200.0, count), 0.8) * hann(count)
    return finish(0.8 * blip + 0.5 * air, -16.0, 0.004, 0.02)


def ui_tap():
    count = samples(0.085)
    x = tone(glide(1250.0, 900.0, count, 0.5)) * decay(count, 0.013, 0.002)
    x += 0.2 * band(noise(count, 31), 3500, RATE) * decay(count, 0.004, 0.0005)
    return finish(x, -14.0, 0.002, 0.02)


def ui_confirm():
    x = np.zeros(samples(0.24))
    place(x, bell(659.25, 0.14, 0.040, 1.0), 0.0)
    place(x, bell(880.00, 0.16, 0.050, 1.2), 0.075)
    return finish(reflections(x), -11.0, 0.003, 0.03)


# ---------------------------------------------------------------------------------------
# Section results.

def section():
    x = np.zeros(samples(0.42))
    for step, (frequency, gain) in enumerate(((523.25, 1.0), (659.25, 0.85), (783.99, 0.8), (1174.66, 0.6))):
        place(x, gain * bell(frequency, 0.36, 0.11, 1.3, 2.0, 0.2), step * 0.028)
    shimmer = tone(2349.32, len(x)) * (0.6 + 0.4 * np.sin(TAU * 17.0 * clock(0.42))) * decay(len(x), 0.09, 0.03)
    return finish(reflections(x + 0.12 * shimmer), -7.0, 0.004, 0.05)


def power_finish():
    seconds = 0.58
    count = samples(seconds)
    x = np.zeros(count)
    for step, (frequency, gain) in enumerate(((220.0, 1.0), (329.63, 0.8), (440.0, 0.8), (554.37, 0.6), (659.25, 0.55), (880.0, 0.4))):
        place(x, gain * bell(frequency, 0.52, 0.17, 1.9, 2.0, 0.25), step * 0.012)
    punch = tone(glide(120.0, 55.0, samples(0.14), 0.6)) * decay(samples(0.14), 0.045, 0.002)
    place(x, 1.2 * punch, 0.0)
    rise = swept_noise(count, 41, glide(700.0, 6500.0, count, 0.7), 0.7) * hann(count) ** 0.6 * decay(count, 0.30, 0.02)
    shimmer = tone(3520.0, count) * (0.5 + 0.5 * np.sin(TAU * 23.0 * clock(seconds))) * decay(count, 0.16, 0.05)
    return finish(reflections(saturate(x * 0.5, 1.4) + 0.35 * rise + 0.10 * shimmer), -5.0, 0.004, 0.07)


# ---------------------------------------------------------------------------------------
# Incoming fire.

def warning():
    x = np.zeros(samples(0.44))
    for at, frequency in ((0.0, 739.99), (0.205, 587.33)):
        count = samples(0.2)
        pulse = fm(frequency, 1.5, 0.7 * decay(count, 0.12, 0.004), count) * hann(count) ** 0.5
        pulse *= 0.82 + 0.18 * np.sin(TAU * 28.0 * np.arange(count) / RATE)
        place(x, pulse, at)
        place(x, 0.15 * band(noise(samples(0.02), 51), 4000, RATE) * decay(samples(0.02), 0.004, 0.0005), at)
    return finish(reflections(x), -8.0, 0.005, 0.04)


def launch():
    seconds = 0.36
    count = samples(seconds)
    thump = tone(glide(170.0, 62.0, samples(0.12), 0.5)) * decay(samples(0.12), 0.04, 0.002)
    whine_env = hann(count) ** 0.45 * np.linspace(1.0, 0.55, count)
    whine = fm(glide(300.0, 1500.0, count, 0.8), 2.01, np.linspace(0.4, 2.6, count)) * whine_env
    burst = band(noise(count, 61), 1400, 7000) * decay(count, 0.055, 0.002)
    x = 0.55 * whine + 0.7 * burst
    place(x, 1.1 * thump, 0.0)
    return finish(reflections(saturate(x, 1.6)), -6.0, 0.003, 0.05)


def impact():
    seconds = 0.59
    count = samples(seconds)
    sub = tone(glide(128.0, 40.0, count, 0.55)) * decay(count, 0.17, 0.003)
    body = band(noise(count, 71), 150, 1500, 2) * decay(count, 0.13, 0.004)
    rumble = band(noise(count, 72), 90, 420, 2) * decay(count, 0.22, 0.03) * (0.7 + 0.3 * np.sin(TAU * 21.0 * clock(seconds)))
    crunch = band(noise(count, 75), 600, 3200, 2) * decay(count, 0.085, 0.003)
    crack = band(noise(count, 73), 2600, RATE) * decay(count, 0.012, 0.0006)
    air = band(noise(count, 74), 900, 5200) * decay(count, 0.07, 0.004)
    # Small speakers carry the blast in its body and crunch; the sub only adds weight.
    x = saturate(0.55 * sub + 1.5 * body + 0.5 * rumble + 0.9 * crunch, 2.2) + 0.6 * crack + 0.4 * air
    return finish(reflections(x, ((0.017, 0.34), (0.031, 0.26), (0.053, 0.18), (0.079, 0.11)), 2600.0), -3.0, 0.002, 0.08)


def bomb():
    seconds = 0.48
    count = samples(seconds)
    crack = band(noise(count, 81), 3200, RATE) * decay(count, 0.007, 0.0004)
    thump = tone(glide(190.0, 60.0, count, 0.45)) * decay(count, 0.085, 0.002)
    blast = band(noise(count, 82), 220, 2800, 2) * decay(count, 0.06, 0.002)
    rng = np.random.default_rng(83)
    clicks = np.zeros(count)
    for _ in range(46):
        at = int(rng.uniform(0.03, 0.40) * RATE)
        clicks[at] += rng.uniform(0.3, 1.0) * rng.choice((-1.0, 1.0)) * np.exp(-(at / RATE) / 0.16)
    debris = band(clicks, 1300, 5600, 2) * 9.0
    ring = np.zeros(count)
    for frequency, gain in ((523.0, 1.0), (811.0, 0.7), (1307.0, 0.5), (2093.0, 0.3)):
        ring += gain * tone(frequency, count) * decay(count, 0.05, 0.002)
    x = saturate(0.5 * thump + 1.6 * blast, 2.0) + 0.9 * crack + 0.7 * debris + 0.14 * ring
    return finish(reflections(x, ((0.013, 0.24), (0.027, 0.16), (0.041, 0.09)), 4200.0), -3.5, 0.0015, 0.06)


def passed():
    seconds = 0.34
    count = samples(seconds)
    x = np.zeros(count)
    place(x, bell(783.99, 0.2, 0.06, 1.2), 0.0)
    place(x, 0.95 * bell(1174.66, 0.26, 0.085, 1.5, 2.0, 0.3), 0.07)
    whoosh = swept_noise(count, 91, glide(600.0, 5200.0, count, 0.8), 0.9) * hann(count) ** 0.7
    return finish(reflections(x + 0.22 * whoosh), -8.0, 0.004, 0.05)


def avoid():
    seconds = 0.28
    count = samples(seconds)
    centre = 500.0 + 1500.0 * hann(count) ** 1.5
    whoosh = swept_noise(count, 101, centre, 1.0) * hann(count)
    low = tone(196.0, count) * hann(count) ** 2
    return finish(whoosh + 0.18 * low, -12.0, 0.01, 0.05)


def charge():
    """The attacker's weapon gathering energy between target lock and launch (two seconds)."""
    seconds = 1.95
    count = samples(seconds)
    u = np.linspace(0.0, 1.0, count)
    rise = u ** 1.5
    core = fm(glide(92.0, 720.0, count, 1.35), 2.01, 0.5 + 2.6 * u)
    hum = tone(glide(46.0, 180.0, count, 1.35)) * 0.6
    tremolo = 1.0 - 0.35 * (0.5 + 0.5 * np.sin(phase_of(6.0 + 22.0 * u ** 2)))
    hiss = swept_noise(count, 111, glide(900.0, 7500.0, count, 1.2), 0.8) * u ** 2.2
    x = (0.8 * core + hum) * rise * tremolo + 0.45 * hiss
    return finish(reflections(saturate(x * 0.9, 1.3)), -9.0, 0.03, 0.02)


def gun_hit():
    """A round striking armour: a metallic crack, a short inharmonic ring and a ricochet zing."""
    seconds = 0.26
    count = samples(seconds)
    crack = band(noise(count, 141), 2800, RATE) * decay(count, 0.006, 0.0004)
    ring = np.zeros(count)
    for frequency, gain, tau in ((1870.0, 1.0, 0.030), (2930.0, 0.8, 0.026), (4410.0, 0.55, 0.020), (6230.0, 0.35, 0.014)):
        ring += gain * tone(frequency, count) * decay(count, tau, 0.001)
    zing = tone(glide(4300.0, 1500.0, count, 0.6)) * decay(count, 0.07, 0.004)
    thud = tone(glide(210.0, 120.0, count, 0.5)) * decay(count, 0.03, 0.002)
    x = 0.8 * crack + 0.45 * ring + 0.38 * zing + 0.7 * thud
    return finish(reflections(saturate(x, 1.3), ((0.011, 0.22), (0.023, 0.13))), -5.0, 0.0015, 0.04)


# ---------------------------------------------------------------------------------------
# Loops: every component completes whole cycles within the file, so they repeat seamlessly.

def gun_loop():
    """Heavy energy machine gun, eleven rounds a second. Each round is rendered alone and
    folded around the loop point, so the tail of the last round runs into the first."""
    count = samples(1.0)
    rounds = 11
    rng = np.random.default_rng(151)
    out = np.zeros(count)
    length = samples(0.16)
    for index in range(rounds):
        tune = 1.0 + rng.uniform(-0.035, 0.035)
        level = 1.0 + rng.uniform(-0.12, 0.08)
        crack = band(noise(length, 152 + index), 2200, 7000) * decay(length, 0.0045, 0.0004)
        body = band(noise(length, 172 + index), 240, 2300, 2) * decay(length, 0.020, 0.001)
        thump = tone(glide(205.0 * tune, 92.0 * tune, length, 0.5)) * decay(length, 0.022, 0.0015)
        zap = fm(glide(1700.0 * tune, 480.0 * tune, length, 0.6), 1.5, 1.2 * decay(length, 0.02, 0.001)) * decay(length, 0.028, 0.001)
        tail = band(noise(length, 192 + index), 400, 2600) * decay(length, 0.055, 0.012)
        # Weighted for small speakers: the body and crack carry it, the thump only supports.
        shot = saturate(0.42 * thump + 1.5 * body, 1.8) + 0.75 * crack + 0.5 * zap + 0.16 * tail
        shot = band(shot, 0, 7500, 1) * level
        shot[-samples(0.01):] *= np.linspace(1.0, 0.0, samples(0.01))
        start = int(round(index * count / rounds))
        positions = (start + np.arange(length)) % count
        np.add.at(out, positions, shot)
    return finish(out, -7.0, loop=True)


def power_loop():
    count = samples(1.0)
    t = np.arange(count) / RATE
    x = np.zeros(count)
    for frequency, gain in ((110.0, 0.5), (165.0, 0.34), (220.0, 0.22), (330.0, 0.12), (440.0, 0.07)):
        x += gain * np.sin(TAU * frequency * t + 0.4 * np.sin(TAU * 3.0 * t))
    x *= 0.86 + 0.14 * np.sin(TAU * 2.0 * t)
    x += 0.05 * periodic_noise(count, 121, 700.0, 2600.0) * (0.6 + 0.4 * np.sin(TAU * 4.0 * t))
    return finish(x, -14.0, loop=True)


def engine_loop():
    """Smooth electric turbine: a soft harmonic stack, a quiet whine and filtered air."""
    seconds = 2.0
    count = samples(seconds)
    t = np.arange(count) / RATE
    base = 96.0
    x = np.zeros(count)
    # A gentle roll-off keeps the hum audible on small speakers that lose the fundamental.
    for n in range(1, 9):
        x += np.sin(TAU * base * n * t + 0.15 * n * np.sin(TAU * 3.0 * t) + n * 0.7) / n ** 1.15
    x += 0.30 * np.sin(TAU * base * 1.5 * t)
    x *= 0.88 + 0.12 * np.sin(TAU * 6.0 * t)
    whine = 0.10 * np.sin(TAU * 768.0 * t + 0.8 * np.sin(TAU * 2.0 * t)) + 0.06 * np.sin(TAU * 1152.0 * t + 0.6 * np.sin(TAU * 3.0 * t))
    air = 0.10 * periodic_noise(count, 131, 300.0, 2600.0) * (0.75 + 0.25 * np.sin(TAU * 6.0 * t + 1.0))
    return finish(saturate(x * 0.55, 1.2) + whine + air, -12.0, loop=True)


if __name__ == "__main__":
    for name, render in (
        ("collect", collect), ("cadence", cadence), ("lane", lane), ("ui_tap", ui_tap), ("ui_confirm", ui_confirm),
        ("section", section), ("power_finish", power_finish), ("warning", warning), ("launch", launch),
        ("impact", impact), ("bomb", bomb), ("pass", passed), ("avoid", avoid), ("gun_hit", gun_hit), ("charge", charge),
        ("power_loop", power_loop), ("engine_loop", engine_loop), ("gun_loop", gun_loop),
    ):
        write(name, render())
