"""Gera as músicas e os efeitos sonoros do Aqua Caos (tudo original).

Uso (no PC, opcional):  python3 generate_audio.py <pasta_do_projeto>
Requer numpy, scipy e ffmpeg (com libvorbis). Os arquivos prontos já estão
no repositório em assets/audio, então não é preciso rodar no celular.
"""
import os
import subprocess
import sys

import numpy as np
from scipy.signal import butter, lfilter

SR = 32000
RNG = np.random.default_rng(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12.0)


def tvec(dur):
    return np.arange(int(SR * dur)) / SR


def lowpass(x, cutoff, order=2):
    b, a = butter(order, min(cutoff / (SR / 2), 0.99), "low")
    return lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = butter(order, cutoff / (SR / 2), "high")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], "band")
    return lfilter(b, a, x)


def fade(x, attack=0.004, release=0.02):
    n = len(x)
    a = min(int(attack * SR), n)
    r = min(int(release * SR), n)
    env = np.ones(n)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if r > 0:
        env[-r:] *= np.linspace(1, 0, r)
    return x * env


# --- Instrumentos -------------------------------------------------------------

def marimba(f, dur, vel=1.0):
    t = tvec(dur + 0.6)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 4.5)
    x += 0.22 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 16)
    x += 0.05 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 40)
    return fade(x * vel, 0.002, 0.08)


def glock(f, dur, vel=1.0):
    t = tvec(dur + 1.0)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.0)
    x += 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 7)
    x += 0.15 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 14)
    return fade(x * vel, 0.001, 0.2)


def pluck(f, dur, vel=1.0):
    """Ukulele/violão: harmônicos que somem mais rápido nas notas agudas."""
    t = tvec(dur + 0.4)
    x = np.zeros_like(t)
    for k in range(1, 9):
        x += (1.0 / k) * np.sin(2 * np.pi * f * k * t) * np.exp(-t * (3.0 + k * 2.2))
    return fade(x * vel * 0.6, 0.002, 0.08)


def bass(f, dur, vel=1.0):
    t = tvec(dur)
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t)
    env = np.minimum(1.0, t / 0.01) * (0.55 + 0.45 * np.exp(-t * 6))
    return fade(x * env * vel, 0.005, 0.05)


def pad(freqs, dur, vel=1.0):
    t = tvec(dur)
    x = np.zeros_like(t)
    for f in freqs:
        for detune in (-0.25, 0.25):
            ff = f * 2 ** (detune / 12)
            for k in range(1, 6):
                x += (0.5 / k) * np.sin(2 * np.pi * ff * k * t + k)
    x = lowpass(x, 1400)
    env = np.minimum(1.0, t / 0.35) * np.minimum(1.0, (dur - t) / 0.35 + 0.0001)
    return x * np.clip(env, 0, 1) * vel * 0.08


def flute(f, dur, vel=1.0):
    t = tvec(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.3)
    phase = 2 * np.pi * f * np.cumsum(vib) / SR
    x = np.sin(phase) + 0.12 * np.sin(2 * phase) + 0.04 * np.sin(3 * phase)
    x += 0.02 * lowpass(RNG.standard_normal(len(t)), 3000)
    env = np.minimum(1.0, t / 0.05) * np.minimum(1.0, (dur - t) / 0.06 + 0.0001)
    return x * np.clip(env, 0, 1) * vel * 0.5


def brass(f, dur, vel=1.0):
    t = tvec(dur)
    x = np.zeros_like(t)
    for k in range(1, 10):
        x += (1.0 / k) * np.sin(2 * np.pi * f * k * t)
    cutoff_env = 600 + 2600 * np.minimum(1, t / 0.08)
    x = lowpass(x, 2400) * 0.5 + lowpass(x, 900) * 0.5
    env = np.minimum(1.0, t / 0.03) * np.minimum(1.0, (dur - t) / 0.12 + 0.0001)
    return x * np.clip(env, 0, 1) * vel * 0.3


def kick(vel=1.0):
    t = tvec(0.35)
    f = 50 + 90 * np.exp(-t * 30)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)
    return fade(x * vel, 0.001, 0.05)


def clap(vel=1.0):
    t = tvec(0.25)
    noise = bandpass(RNG.standard_normal(len(t)), 900, 2500)
    env = np.zeros_like(t)
    for off in (0.0, 0.011, 0.022):
        env += np.where(t >= off, np.exp(-(t - off) * 60), 0)
    env += 0.4 * np.exp(-t * 14)
    return fade(noise * env * vel * 0.25, 0.001, 0.05)


def shaker(vel=1.0):
    t = tvec(0.09)
    noise = highpass(RNG.standard_normal(len(t)), 5500)
    env = np.minimum(1, t / 0.015) * np.exp(-t * 45)
    return noise * env * vel * 0.12


def cymbal(dur=1.5, vel=1.0):
    t = tvec(dur)
    noise = bandpass(RNG.standard_normal(len(t)), 3500, 8000)
    return fade(noise * np.exp(-t * 3.0) * vel * 0.05, 0.002, 0.3)


# --- Mixagem --------------------------------------------------------------------

def reverb(x, mix=0.2):
    out = np.zeros_like(x)
    for delay_ms, fb in ((29.7, 0.77), (37.1, 0.75), (41.1, 0.73), (43.7, 0.71)):
        d = int(SR * delay_ms / 1000)
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -fb
        out += lfilter([1.0], a, x)
    for delay_ms, g in ((5.0, 0.7), (1.7, 0.7)):
        d = int(SR * delay_ms / 1000)
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1
        a = np.zeros(d + 1)
        a[0] = 1
        a[d] = -g
        out = lfilter(b, a, out)
    out = lowpass(out, 5000) * 0.25
    return x * (1 - mix) + out * mix


class Track:
    def __init__(self, bpm, beats):
        self.bpm = bpm
        self.spb = 60.0 / bpm
        self.length = beats * self.spb
        self.buf = np.zeros(int(SR * (self.length * 2 + 4)))

    def add(self, beat, sound, gain=1.0):
        for copy in (0, 1):  # duas cópias para o laço ficar perfeito
            start = int(SR * (beat * self.spb + copy * self.length))
            end = min(start + len(sound), len(self.buf))
            self.buf[start:end] += sound[: end - start] * gain

    def render(self, rev=0.2):
        x = reverb(self.buf, rev)
        n = int(SR * self.length)
        loop = x[n: 2 * n]  # segunda cópia: já contém a cauda da reverberação
        return normalize(loop)


def normalize(x, peak=0.89):
    x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 1.2) / np.tanh(1.2)
    return x * peak


def save_ogg(x, path, quality=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
         "-c:a", "libvorbis", "-q:a", str(quality), path],
        input=pcm, check=True,
    )


# --- Teoria musical -------------------------------------------------------------

CHORDS = {
    "C": [60, 64, 67], "Dm": [62, 65, 69], "Em": [64, 67, 71], "F": [65, 69, 72], "G": [67, 71, 74],
    "Am": [69, 72, 76], "Bm": [71, 74, 78], "D": [62, 66, 69], "D7": [62, 66, 72], "Bb": [70, 74, 77],
    "A": [69, 73, 76], "Gm": [67, 70, 74], "C7": [60, 64, 70], "E7": [64, 68, 74],
}


def add_melody(track, notes, instrument, start_beat=0.0, gain=1.0, octave=0):
    beat = start_beat
    for note, dur in notes:
        if note is not None:
            track.add(beat, instrument(midi(note + 12 * octave), dur * track.spb), gain)
        beat += dur
    return beat


def groove(track, chords, beats_per_bar=4, style="bouncy", gain=1.0):
    for bar, name in enumerate(chords):
        root = CHORDS[name][0] - 24
        b0 = bar * beats_per_bar
        notes = CHORDS[name]
        track.add(b0, pad([midi(n) for n in notes], beats_per_bar * track.spb), 0.9 * gain)
        if style == "bouncy":
            for beat, n, d in ((0, root, 0.9), (1.5, root + 12, 0.4), (2, root + 7, 0.9), (3.5, root + 12, 0.4)):
                track.add(b0 + beat, bass(midi(n), d * track.spb), 0.55 * gain)
            for beat in (0.5, 1.5, 2.5, 3.5):
                for i, n in enumerate(notes):
                    track.add(b0 + beat + i * 0.012, pluck(midi(n), 0.4 * track.spb), 0.16 * gain)
        else:
            for beat, n, d in ((0, root, 1.8), (2, root + 7, 1.8)):
                track.add(b0 + beat, bass(midi(n), d * track.spb), 0.45 * gain)
            for i, n in enumerate(notes + [notes[0] + 12]):
                track.add(b0 + i * 0.5, pluck(midi(n), 0.9 * track.spb), 0.14 * gain)
                track.add(b0 + 2 + i * 0.5, pluck(midi(n), 0.9 * track.spb), 0.12 * gain)


def drums(track, bars, beats_per_bar=4, gain=1.0, claps=True):
    for bar in range(bars):
        b0 = bar * beats_per_bar
        track.add(b0, kick(), 0.5 * gain)
        track.add(b0 + 2, kick(), 0.45 * gain)
        if claps:
            track.add(b0 + 1, clap(), 0.5 * gain)
            track.add(b0 + 3, clap(), 0.5 * gain)
        for i in range(8):
            track.add(b0 + i * 0.5, shaker(1.0 if i % 2 else 0.6), gain)


# --- Músicas ----------------------------------------------------------------------

def song_race():
    t = Track(128, 64)
    chords = ["G", "Em", "C", "D", "G", "Em", "C", "D", "C", "D", "Bm", "Em", "C", "D", "G", "D7"]
    groove(t, chords)
    drums(t, 16)
    a = [(67, .5), (71, .5), (74, .5), (71, .5), (76, 1), (74, 1),
         (71, .5), (74, .5), (76, .5), (74, .5), (71, 1), (67, 1),
         (72, .5), (76, .5), (79, .5), (76, .5), (74, 1), (72, .5), (71, .5),
         (69, .5), (71, .5), (72, .5), (74, .5), (69, 2)]
    a2 = a[:18] + [(74, .5), (72, .5), (71, .5), (69, .5), (67, 2)]
    b = [(79, 1), (76, .5), (79, .5), (81, 1), (79, 1),
         (78, 1), (74, .5), (78, .5), (81, 1), (78, 1),
         (79, .5), (78, .5), (74, .5), (71, .5), (74, 1), (78, 1),
         (76, 2), (79, 1), (76, 1),
         (76, .5), (79, .5), (76, .5), (72, .5), (74, 1), (76, 1),
         (78, .5), (76, .5), (74, .5), (72, .5), (71, 1), (69, 1),
         (67, .5), (71, .5), (74, .5), (79, .5), (78, .5), (79, .5), (74, 1),
         (72, .5), (71, .5), (69, .5), (66, .5), (67, 2)]
    beat = add_melody(t, a, marimba, 0, 0.55)
    beat = add_melody(t, a2, marimba, beat, 0.55)
    add_melody(t, b, marimba, beat, 0.55)
    add_melody(t, b, glock, beat, 0.12, octave=1)
    return t.render(0.18)


def song_race2():
    t = Track(120, 64)
    chords = ["C", "Am", "F", "G", "C", "Am", "F", "G", "F", "G", "Em", "Am", "F", "G", "C", "G"]
    groove(t, chords)
    drums(t, 16, claps=True)
    a = [(72, .75), (74, .25), (76, .5), (79, .5), (76, 1), (72, 1),
         (69, .5), (72, .5), (76, .5), (72, .5), (69, 2),
         (65, .5), (69, .5), (72, .5), (77, .5), (76, 1), (74, 1),
         (71, .5), (74, .5), (79, .5), (77, .5), (74, 2)]
    a2 = a[:17] + [(74, .5), (76, .5), (74, .5), (71, .5), (72, 2)]
    b = [(77, 1), (76, .5), (77, .5), (81, 2),
         (79, 1), (77, .5), (79, .5), (83, 2),
         (79, .5), (76, .5), (72, .5), (76, .5), (79, 2),
         (81, .5), (79, .5), (76, .5), (72, .5), (69, 2),
         (77, .5), (76, .5), (74, .5), (72, .5), (69, 1), (72, 1),
         (74, .5), (76, .5), (77, .5), (79, .5), (74, 2),
         (76, .5), (79, .5), (84, .5), (79, .5), (76, 1), (72, 1),
         (74, 1), (71, 1), (67, 2)]
    beat = add_melody(t, a, flute, 0, 0.42)
    beat = add_melody(t, a2, flute, beat, 0.42)
    add_melody(t, b, marimba, beat, 0.55)
    return t.render(0.2)


def song_menu():
    t = Track(100, 64)
    chords = ["F", "Dm", "Bb", "C", "F", "Dm", "Bb", "C", "Bb", "C", "Am", "Dm", "Bb", "C", "F", "C7"]
    groove(t, chords, style="gentle", gain=0.9)
    for bar in range(16):
        t.add(bar * 4, kick(), 0.3)
        t.add(bar * 4 + 2, shaker(), 1.0)
    a = [(72, 1), (69, .5), (72, .5), (77, 1.5), (76, .5),
         (74, 1), (72, .5), (74, .5), (69, 2),
         (70, 1), (74, .5), (77, .5), (79, 1.5), (77, .5),
         (76, 1), (74, .5), (72, .5), (67, 2)]
    a2 = a[:14] + [(76, .5), (74, .5), (72, 1), (69, 2)]
    b = [(74, 1), (77, .5), (74, .5), (70, 2),
         (76, 1), (79, .5), (76, .5), (72, 2),
         (76, .5), (77, .5), (79, .5), (76, .5), (72, 2),
         (74, .5), (72, .5), (69, .5), (65, .5), (62, 2),
         (70, .5), (74, .5), (77, .5), (74, .5), (79, 1), (77, 1),
         (76, .5), (77, .5), (79, .5), (81, .5), (79, 2),
         (81, 1), (77, .5), (72, .5), (77, 2),
         (76, 1), (72, 1), (70, 1), (67, 1)]
    beat = add_melody(t, a, glock, 0, 0.32)
    beat = add_melody(t, a2, glock, beat, 0.32)
    add_melody(t, b, marimba, beat, 0.5)
    return t.render(0.28)


def song_map():
    t = Track(92, 32)
    chords = ["D", "Bm", "G", "A", "D", "Bm", "G", "A"]
    groove(t, chords, style="gentle", gain=0.8)
    melody = [(74, .5), (78, .5), (81, .5), (78, .5), (83, 1), (81, 1),
              (78, .5), (81, .5), (86, 1), (83, 2),
              (79, .5), (83, .5), (86, .5), (83, .5), (81, 1), (79, 1),
              (76, .5), (78, .5), (79, .5), (81, .5), (76, 2),
              (74, .5), (78, .5), (81, .5), (78, .5), (83, 1), (81, 1),
              (78, .5), (81, .5), (86, 1), (83, 2),
              (79, .5), (78, .5), (76, .5), (74, .5), (79, 1), (76, 1),
              (73, 1), (76, 1), (74, 2)]
    add_melody(t, melody, glock, 0, 0.3)
    add_melody(t, melody, pluck, 0, 0.18, octave=-1)
    return t.render(0.3)


def jingle_victory():
    spb = 60 / 132
    n = int(SR * 4.2)
    x = np.zeros(n)

    def put(time, s, g=1.0):
        a = int(time * SR)
        e = min(a + len(s), n)
        x[a:e] += s[: e - a] * g

    for i, note in enumerate([72, 76, 79]):
        put(i * spb / 3, brass(midi(note), spb / 3 * 0.9), 0.8)
    put(spb, brass(midi(84), spb * 2.5), 0.8)
    for note in (72, 76, 79):
        put(spb, brass(midi(note), spb * 2.5), 0.35)
    for i, note in enumerate([72, 76, 79, 84, 88, 91, 96]):
        put(spb + i * 0.07, glock(midi(note), 0.4), 0.25)
    put(spb, cymbal(2.5), 1.0)
    put(spb, kick(), 0.6)
    put(spb * 3.5, brass(midi(79), spb), 0.6)
    put(spb * 4.5, brass(midi(84), spb * 2.8), 0.8)
    for note in (60, 64, 67, 72):
        put(spb * 4.5, pad([midi(note)], spb * 3.0), 3.0)
    put(spb * 4.5, cymbal(2.0), 0.8)
    return normalize(lowpass(reverb(fade(x, 0.001, 0.4), 0.25), 7000), 0.85)


def jingle_finish():
    n = int(SR * 2.8)
    x = np.zeros(n)
    for i, note in enumerate([67, 72, 76, 79, 84]):
        a = int(i * 0.12 * SR)
        s = marimba(midi(note), 0.6)
        e = min(a + len(s), n)
        x[a:e] += s[: e - a] * 0.7
    a = int(0.6 * SR)
    s = glock(midi(84), 1.6)
    x[a:a + len(s)] += s[: n - a] * 0.4
    return normalize(reverb(fade(x, 0.001, 0.4), 0.25), 0.8)


# --- Efeitos sonoros (suaves) ------------------------------------------------------------

def sfx_all():
    out = {}
    t = tvec(0.28)
    f = 260 + 260 * (1 - np.exp(-t * 14))
    out["jump"] = fade(np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * 0.5, 0.004, 0.05)
    t = tvec(0.12)
    out["land"] = fade(lowpass(RNG.standard_normal(len(t)), 400) * np.exp(-t * 35) * 0.6 + np.sin(2 * np.pi * 90 * t) * np.exp(-t * 30) * 0.4, 0.002, 0.03)
    t = tvec(0.4)
    sweep = bandpass(RNG.standard_normal(len(t)), 250, 1600) * np.sin(np.pi * t / 0.4) ** 2
    out["dive"] = fade(sweep * 0.35, 0.01, 0.05)
    coin = np.zeros(int(SR * 0.9))
    for i, note in enumerate([84, 88]):
        s = glock(midi(note), 0.3)
        a = int(i * 0.07 * SR)
        e = min(a + len(s), len(coin))
        coin[a:e] += s[: e - a] * 0.5
    out["coin"] = reverb(coin, 0.15)
    t = tvec(0.5)
    vib = 210 + 160 * np.sin(np.pi * t / 0.5) + 25 * np.sin(2 * np.pi * 14 * t)
    out["bounce"] = fade(np.sin(2 * np.pi * np.cumsum(vib) / SR) * np.exp(-t * 4) * 0.5, 0.005, 0.06)
    t = tvec(0.3)
    bonk = np.sin(2 * np.pi * 330 * t) * np.exp(-t * 28) + 0.5 * np.sin(2 * np.pi * 520 * t) * np.exp(-t * 40)
    out["hit"] = fade(bonk * 0.55 + lowpass(RNG.standard_normal(len(t)), 900) * np.exp(-t * 40) * 0.2, 0.001, 0.05)
    t = tvec(0.9)
    splash = bandpass(RNG.standard_normal(len(t)), 300, 2800) * np.exp(-t * 4.5) * 0.45
    for k in range(6):
        start = 0.08 + k * 0.09
        bt = np.clip(t - start, 0, None)
        splash += np.where(t > start, np.sin(2 * np.pi * (500 + 300 * k + 900 * bt) * bt) * np.exp(-bt * 30), 0) * 0.12
    out["splash"] = fade(lowpass(splash, 3200), 0.005, 0.15)
    cp = np.zeros(int(SR * 0.9))
    for i, note in enumerate([72, 76, 79, 84]):
        s = marimba(midi(note), 0.3)
        a = int(i * 0.08 * SR)
        e = min(a + len(s), len(cp))
        cp[a:e] += s[: e - a] * 0.5
    out["checkpoint"] = reverb(cp, 0.2)
    out["beep"] = marimba(midi(76), 0.15) * 0.6
    go = marimba(midi(84), 0.4) * 0.5 + marimba(midi(79), 0.4) * 0.3 + marimba(midi(76), 0.4) * 0.3
    out["go"] = go
    t = tvec(0.06)
    out["click"] = fade(np.sin(2 * np.pi * (900 - 3000 * t) * t) * np.exp(-t * 60) * 0.35, 0.001, 0.01)
    out["whoosh"] = out["dive"]
    sparkle = np.zeros(int(SR * 1.2))
    for i, note in enumerate([79, 84, 88, 91, 96]):
        s = glock(midi(note), 0.4)
        a = int(i * 0.06 * SR)
        e = min(a + len(s), len(sparkle))
        sparkle[a:e] += s[: e - a] * 0.35
    out["unlock"] = reverb(sparkle, 0.25)
    t = tvec(0.25)
    pop = np.sin(2 * np.pi * (400 + 900 * t) * t) * np.exp(-t * 20)
    out["pop"] = fade(pop * 0.4, 0.002, 0.03)
    # Sininhos mais macios: corta o brilho excessivo e evita estalos no fim.
    soft = {}
    for k, v in out.items():
        v = lowpass(v, 6500)
        soft[k] = fade(normalize(v, 0.7), 0.001, 0.04)
    return soft


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    music_dir = os.path.join(root, "assets/audio/music")
    sfx_dir = os.path.join(root, "assets/audio/sfx")
    songs = {"race": song_race, "race2": song_race2, "menu": song_menu, "map": song_map,
             "victory": jingle_victory, "finish": jingle_finish}
    for name, fn in songs.items():
        save_ogg(fn(), os.path.join(music_dir, name + ".ogg"), 4)
        print("música:", name)
    for name, x in sfx_all().items():
        save_ogg(x, os.path.join(sfx_dir, name + ".ogg"), 5)
    print("efeitos ok")


if __name__ == "__main__":
    main()
