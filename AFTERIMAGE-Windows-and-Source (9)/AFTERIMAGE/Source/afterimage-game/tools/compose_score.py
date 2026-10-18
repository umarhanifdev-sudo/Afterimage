"""What Remains: original 96-second instrumental loop for AFTERIMAGE.
No samples or melodies from other recordings. Run with numpy/scipy + ffmpeg.
"""
from pathlib import Path
import subprocess
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt
import tempfile

SR, LENGTH = 44100, 96
rng = np.random.default_rng(28106)
mix = np.zeros((SR * LENGTH, 2), dtype=np.float64)

def note(start, midi, length, gain, pan, pad=False):
    n = int(length * SR)
    t = np.arange(n) / SR
    f = 440 * 2 ** ((midi - 69) / 12)
    sig = np.zeros(n)
    if pad:
        env = np.sin(np.pi * np.clip(t / length, 0, 1)) ** 1.8
        for h, amp in [(1, .66), (2, .17), (3, .09), (4, .035)]:
            sig += amp * np.sin(2*np.pi*f*h*t + .09*np.sin(t*2.1+h))
        sig *= env
    else:
        # Soft hammer attack, dispersive partials and a long felt-like decay.
        env = (1-np.exp(-t*120)) * np.exp(-t/(2.0 + 160/f))
        for h, amp in [(1, 1), (2, .29), (3, .10), (4, .055), (7, .012)]:
            sig += amp*np.sin(2*np.pi*f*h*(1+.00016*h*h)*t)*np.exp(-t*h*.12)
        sig *= env
        sig[-int(SR*.15):] *= np.linspace(1,0,int(SR*.15))
    samples = np.arange(n) + int(start*SR)
    # Circular accumulation makes the composition and reverb tails loop cleanly.
    samples %= len(mix)
    mix[samples,0] += sig*gain*np.sqrt((1-pan)/2)
    mix[samples,1] += sig*gain*np.sqrt((1+pan)/2)

chords = [(40,55,59,66),(36,55,59,62),(45,55,59,64),(47,54,62,66),
          (43,54,59,62),(38,54,57,64),(45,55,60,64),(40,54,59,66)]
melodies = [[71,66,67],[67,62,59],[64,71,69],[66,62,66],
            [71,74,69],[69,66,64],[67,64,62],[66,59,64]]
for bar in range(16):
    start = bar*6
    chord = chords[bar%8]
    note(start,chord[0],8.5,.105,0,True)
    for i, pitch in enumerate(chord[1:]):
        note(start+.08*i,pitch,8.2,.035,(-.45+i*.45),True)
        note(start+.12+i*.32,pitch,6,.085,(-.35+i*.3))
    melody = melodies[bar%8]
    for i,pitch in enumerate(melody):
        if bar%4==3 and i==1: continue
        note(start+1.1+i*1.55,pitch+(12 if bar>=8 and i==1 else 0),7,.13 if i==0 else .095, rng.uniform(-.2,.2))

dry = mix.copy()
for delay, level in [(.127,.18),(.293,.14),(.479,.10),(.761,.075),(1.137,.06),(1.817,.04),(2.571,.025)]:
    echo = np.roll(dry,int(delay*SR),axis=0)[:,::-1]
    mix += sosfilt(butter(2,2800,fs=SR,output='sos'),echo,axis=0)*level
mix -= mix.mean(axis=0)
mix *= .70/np.max(np.abs(mix))
out = Path(__file__).resolve().parents[1]/'assets/audio/what-remains.ogg'
with tempfile.TemporaryDirectory() as temp:
    wav = Path(temp)/'score.wav'
    encoded = Path(temp)/'score.ogg'
    wavfile.write(wav,SR,(mix*32767).astype(np.int16))
    subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(encoded)],check=True)
    out.write_bytes(encoded.read_bytes())
print(f'{out}: {LENGTH}s, stereo, peak {20*np.log10(np.max(np.abs(mix))):.2f} dBFS')
