#!/usr/bin/env python3
"""第三章〈慈愛實驗醫院〉配樂。

把全作的音樂盒動機改成心電圖、玻璃琴與醫院機械聲。輸出皆為可循環的
立體聲 OGG；追逐曲另有速度較快的版本。

用法：python3 tools/make_ch3_bgm.py
"""
from pathlib import Path
import subprocess
import tempfile

import numpy as np
from scipy import signal


SR = 44100
OUT = Path("game/audio/ch3/bgm")
RNG = np.random.default_rng(31)
MOTIF = [76, 81, 79, 76, 77, 76, 74, 71]  # Mi La Sol Mi｜Fa Mi Re｜Si


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def lp(x, cutoff):
    b, a = signal.butter(2, cutoff / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, cutoff):
    b, a = signal.butter(2, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def pan(x, pos):
    """pos -1..1"""
    a = (pos + 1.0) * np.pi / 4.0
    return np.column_stack((x * np.cos(a), x * np.sin(a)))


def add(buf, x, sec, pos=0.0):
    i = int(sec * SR) % len(buf)
    s = pan(x, pos)
    n = min(len(s), len(buf) - i)
    buf[i:i + n] += s[:n]
    if n < len(s):
        buf[:len(s) - n] += s[n:]


def room(x, seconds=2.0, wet=0.18):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = lp(RNG.standard_normal(n) * np.exp(-t * 5.0 / seconds), 4800)
    out = np.zeros_like(x)
    for ch in range(2):
        w = signal.fftconvolve(x[:, ch], ir, mode="full")[:len(x)]
        w /= np.max(np.abs(w)) + 1e-9
        out[:, ch] = x[:, ch] * (1.0 - wet) + w * np.max(np.abs(x[:, ch])) * wet
    return out


def glass(midi, dur=2.2, detune=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(midi) * 2 ** (detune / 1200)
    x = np.sin(2 * np.pi * f * t)
    x += 0.36 * np.sin(2 * np.pi * f * 2.71 * t) * np.exp(-t * 4.5)
    x += 0.18 * np.sin(2 * np.pi * f * 5.18 * t) * np.exp(-t * 8.0)
    return x * np.exp(-t * 1.7) * np.minimum(1, t * 180)


def pad(midi, dur, dark=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    x = sum(signal.sawtooth(2 * np.pi * f * (2 ** (c / 1200)) * t)
            for c in (-9, -3, 4, 11)) / 4
    x = lp(x, 750 if dark else 1500)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return x * env * 0.22


def ecg(midi, dur=0.18):
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = signal.square(2 * np.pi * hz(midi) * t) * np.exp(-t * 22)
    return lp(x, 3300) * 0.28


def kick():
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    f = 42 + 105 * np.exp(-t * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def metal(dur=0.20):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return hp(RNG.standard_normal(n), 2500) * np.exp(-t * 22) * 0.18


def drone(n, dark=0.0):
    t = np.arange(n) / SR
    noise = lp(RNG.standard_normal(n), 180 + dark * 120)
    hum = np.sin(2 * np.pi * 48 * t) + 0.35 * np.sin(2 * np.pi * 96.4 * t)
    return (noise * 0.13 + hum * 0.05) * (0.75 + 0.25 * np.sin(2 * np.pi * 0.07 * t))


def base(seconds):
    n = int(seconds * SR)
    d = drone(n)
    return np.column_stack((d, np.roll(d, 1700))) * 0.55


def ambient(seconds, bpm, chords, voice="glass", pulse=False, dark=False):
    buf = base(seconds)
    beat = 60.0 / bpm
    bars = int(seconds / (beat * 4))
    for bar in range(bars):
        root = chords[bar % len(chords)]
        start = bar * beat * 4
        for k, m in enumerate((root, root + 7, root + 12)):
            add(buf, pad(m, beat * 4.2, dark), start, (-0.65, 0.0, 0.65)[k])
        if pulse:
            for q in range(4):
                add(buf, kick() * (0.34 if q in (0, 2) else 0.18), start + q * beat, 0)
    for i, m in enumerate(MOTIF):
        sec = (i * 2 + 2) * beat
        while sec < seconds:
            note = ecg(m - 12) if voice == "ecg" else glass(m, 1.8, RNG.normal(0, 5))
            add(buf, note, sec, -0.55 + (i % 3) * 0.55)
            sec += beat * 16
    return room(buf, 2.8 if not dark else 4.0, 0.24 if not dark else 0.32)


def chase(seconds=31.578947):
    bpm = 152
    beat = 60 / bpm
    buf = base(seconds) * 0.55
    bars = int(seconds / (beat * 4))
    bass = [38, 38, 50, 41, 38, 49, 36, 37]
    for bar in range(bars):
        for q in range(8):
            sec = bar * beat * 4 + q * beat / 2
            m = bass[(bar * 2 + q) % len(bass)]
            n = int(beat * 0.46 * SR)
            t = np.arange(n) / SR
            x = signal.sawtooth(2 * np.pi * hz(m) * t) * np.exp(-t * 5.5)
            add(buf, lp(x, 900) * 0.42, sec)
        for q in range(4):
            add(buf, kick() * (0.8 if q in (0, 2) else 0.38), bar * beat * 4 + q * beat)
            add(buf, metal(), bar * beat * 4 + q * beat + beat / 2, 0.5 if q % 2 else -0.5)
        if bar >= 2:
            for q, m in enumerate(MOTIF):
                add(buf, ecg(m - 5), bar * beat * 4 + q * beat / 2, -0.4 + 0.8 * (q % 2))
    return room(np.tanh(buf * 1.3), 1.3, 0.14)


def ending(seconds=33.6):
    buf = ambient(seconds, 75, [45, 41, 38, 43], "glass", False, True)
    beat = 60 / 75
    # 四段開燈；每段把動機多加一層，但最後仍不解決。
    for layer in range(4):
        for i, m in enumerate(MOTIF[:4 + layer]):
            add(buf, glass(m - 12 + (12 if layer == 3 else 0), 3.4, layer * 4),
                layer * beat * 8 + i * beat, -0.7 + layer * 0.46)
    return room(buf, 4.5, 0.30)


def save(name, x):
    peak = np.max(np.abs(x)) + 1e-9
    x = np.tanh(x / peak * 1.35) * 0.78
    fade = int(0.08 * SR)
    x[:fade] *= np.linspace(0, 1, fade)[:, None]
    x[-fade:] *= np.linspace(1, 0, fade)[:, None]
    raw = (x * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le",
                        "-ar", str(SR), "-ac", "2", "-i", "-", tmp.name],
                       input=raw.tobytes(), check=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name,
                        "-c:a", "libvorbis", "-q:a", "6", str(OUT / f"{name}.ogg")],
                       check=True)
    print("完成", OUT / f"{name}.ogg", f"{len(x) / SR:.1f} 秒")


def main():
    save("ch3_bgm01_arrival", ambient(33.6, 75, [38, 41, 36, 37], "ecg", True, True))
    save("ch3_bgm02_sterile", ambient(33.6, 75, [48, 45, 41, 43], "glass", False, False))
    save("ch3_bgm03_nirvana", ambient(33.6, 75, [41, 38, 45, 36], "ecg", False, False))
    save("ch3_bgm04_old_ward", ambient(33.6, 75, [34, 33, 38, 36], "glass", True, True))
    save("ch3_bgm05_chase", chase())
    save("ch3_bgm06_basement", ambient(33.6, 75, [33, 36, 34, 31], "ecg", True, True))
    save("ch3_bgm07_welcome_home", ending())


if __name__ == "__main__":
    main()
