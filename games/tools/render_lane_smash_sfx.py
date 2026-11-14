"""Original, restrained Lane Smash cues. Standard library only; mono 44.1 kHz PCM."""
from pathlib import Path
import math, random, struct, wave
RATE = 44100
OUT = Path(__file__).resolve().parents[1] / 'games/neon_vector/audio/sfx'

def render(name, seconds, tones, gain=0.13, noise=0.0, sweep=1.0, loop=False):
    rng = random.Random(9401)
    samples, phases, filtered = [], [0.0]*len(tones), 0.0
    for i in range(round(seconds*RATE)):
        t = i/RATE; u = t/seconds
        env = 1 if loop else min(1, t/0.008) * math.exp(-4*u) * min(1, (seconds-t)/0.025)
        value = 0.0
        for j, (freq, weight) in enumerate(tones):
            phases[j] += math.tau*freq*(1+(sweep-1)*u)/RATE
            value += weight*math.sin(phases[j])
        filtered += 0.08*(rng.uniform(-1,1)-filtered)
        value += noise*filtered
        if loop: value *= 0.85 + 0.15*math.sin(math.tau*t)
        samples.append(round(max(-1,min(1,value*env*gain))*32767))
    if not loop: samples[0]=samples[-1]=0
    OUT.mkdir(parents=True,exist_ok=True)
    with wave.open(str(OUT/f'{name}.wav'),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(struct.pack('<'+'h'*len(samples),*samples))
    print(name, len(samples)/RATE, 'peak', round(max(abs(n) for n in samples)/32767,4))

render('collect', .095, [(523.25,.7),(1046.5,.15)], .12)
render('cadence', .11, [(659.25,.65),(329.63,.25)], .105)
render('section', .32, [(261.63,.45),(392,.3),(523.25,.2)], .14)
render('power_finish', .48, [(220,.35),(330,.3),(440,.2),(660,.1)], .17, noise=.1, sweep=1.06)
render('power_loop', 1, [(110,.5),(165,.3),(220,.15)], .085, loop=True)
render('warning', .38, [(329.63,.5),(440,.25)], .15, sweep=.97)
render('launch', .30, [(240,.5),(480,.15)], .15, noise=.5, sweep=.5)
render('impact', .52, [(105,.6),(160,.2)], .24, noise=1.1, sweep=.45)
render('pass', .30, [(392,.5),(523.25,.3),(659.25,.1)], .15, sweep=1.05)
render('avoid', .22, [(196,.5),(293.66,.25)], .12, noise=.25)
