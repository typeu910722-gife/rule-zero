#!/usr/bin/env python3
"""合成環境音與驚悚音效（原創，全部用程式產生）。

輸出：
  game/audio/amb_forest.ogg   森林：風聲＋樹葉沙沙（可無縫循環）
  game/audio/amb_night.ogg    夜晚：蟲鳴＋微風（可無縫循環）
  game/audio/sfx_bell_far.ogg 遠處的鈴聲
  game/audio/sfx_creepy.wav   驚悚台詞：低沉的一聲＋雜訊
  game/audio/sfx_glitch.wav   畫面閃爍時的短雜訊

用法：python3 tools/make_ambience.py
"""
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 44100
OUT = "game/audio/"
rng = np.random.default_rng(47)


def save_wav(path, x):
    x = np.clip(x, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def save_ogg(path, x):
    tmp = path.replace(".ogg", ".tmp.wav")
    save_wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", path], check=True)
    subprocess.run(["rm", tmp])


def norm(x, peak=0.8):
    return x / (np.abs(x).max() + 1e-9) * peak


def loopable(x, fade=1.5):
    """尾巴交叉淡入到開頭，讓循環接縫聽不出來。"""
    n = int(fade * SR)
    head, body, tail = x[:n], x[n:-n], x[-n:]
    t = np.linspace(0, 1, n)
    mixed = tail * np.cos(t * np.pi / 2) + head * np.sin(t * np.pi / 2)
    return np.concatenate([body, mixed])


def lfo(n, rate, depth, phase=0.0):
    t = np.arange(n) / SR
    return 1 - depth + depth * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t + phase))


def wind(sec):
    n = int(sec * SR)
    white = rng.standard_normal(n)
    brown = np.cumsum(white)
    brown -= signal.savgol_filter(brown, 20001, 1) if n > 20001 else brown.mean()
    b, a = signal.butter(2, [120, 900], btype="band", fs=SR)
    w = signal.lfilter(b, a, brown)
    # 慢慢起伏的陣風（用整數倍頻率，循環時接得起來）
    gust = lfo(n, 1 / sec * 2, 0.6) * lfo(n, 1 / sec * 5, 0.3, 1.0)
    return norm(w * gust)


def rustle(sec, count):
    n = int(sec * SR)
    out = np.zeros(n)
    b, a = signal.butter(2, [2000, 7000], btype="band", fs=SR)
    for _ in range(count):
        L = int(rng.uniform(0.3, 0.9) * SR)
        s = int(rng.uniform(0, sec - 1) * SR)
        env = np.sin(np.linspace(0, np.pi, L)) ** 2
        crackle = rng.standard_normal(L) * (rng.random(L) < 0.15)
        out[s:s + L] += signal.lfilter(b, a, crackle) * env * rng.uniform(0.3, 1)
    return norm(out)


def crickets(sec, voices=3):
    n = int(sec * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for v in range(voices):
        f = rng.uniform(4200, 5200)
        rate = rng.uniform(1.2, 2.0)        # 每秒幾串
        pulses = rng.integers(3, 5)
        tone = np.sin(2 * np.pi * f * t)
        env = np.zeros(n)
        start = rng.uniform(0, 1 / rate)
        k = start
        while k < sec - 0.3:
            for p in range(pulses):
                s = int((k + p * 0.028) * SR)
                L = int(0.018 * SR)
                if s + L < n:
                    env[s:s + L] += np.hanning(L)
            k += 1 / rate * rng.uniform(0.85, 1.15)
            if rng.random() < 0.12:
                k += rng.uniform(0.5, 1.5)   # 偶爾停一下
        pan = rng.uniform(0.4, 1.0)
        out += tone * env * pan
    return norm(out)


def bell(dur=6.0, f0=392.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # 鐘的泛音不是整數倍
    for ratio, amp, decay in [(0.5, 0.6, 1.2), (1.0, 1.0, 0.9), (1.19, 0.5, 0.7), (1.5, 0.35, 0.6), (2.0, 0.3, 0.5), (2.74, 0.2, 0.35), (3.76, 0.12, 0.25)]:
        out += amp * np.sin(2 * np.pi * f0 * ratio * t + rng.uniform(0, 6)) * np.exp(-t / (dur * decay * 0.5))
    out *= np.minimum(1, t / 0.004)
    # 遠處：去掉高頻＋簡單的回音
    b, a = signal.butter(2, 1800, fs=SR)
    out = signal.lfilter(b, a, out)
    wet = np.zeros_like(out)
    for d, g in [(0.11, 0.5), (0.23, 0.35), (0.37, 0.25), (0.53, 0.18)]:
        k = int(d * SR)
        wet[k:] += out[:-k] * g
    return norm(out * 0.6 + wet, 0.7)


def creepy(dur=2.2):
    n = int(dur * SR)
    t = np.arange(n) / SR
    env = np.exp(-t / 0.7) * np.minimum(1, t / 0.01)
    # 低沉、有點走音的兩個音
    low = np.sin(2 * np.pi * 55 * t) + 0.6 * np.sin(2 * np.pi * 58.3 * t) + 0.3 * np.sin(2 * np.pi * 110.7 * t)
    # 反向的吸氣聲
    b, a = signal.butter(2, [300, 3000], btype="band", fs=SR)
    hiss = signal.lfilter(b, a, rng.standard_normal(n))
    swell = np.clip((t - 0.0) / 0.25, 0, 1) * np.exp(-np.maximum(t - 0.25, 0) / 0.15)
    tick = np.zeros(n)
    for k in [0.0, 0.47, 0.94]:
        s = int(k * SR)
        L = int(0.03 * SR)
        tick[s:s + L] += rng.standard_normal(L) * np.hanning(L)
    return norm(low * env + hiss * swell * 0.35 + tick * 0.25 * env, 0.85)


def glitch(dur=0.35):
    n = int(dur * SR)
    out = np.zeros(n)
    k = 0
    while k < n:
        L = int(rng.uniform(0.01, 0.05) * SR)
        kind = rng.integers(3)
        seg = rng.standard_normal(L)
        if kind == 1:
            seg = np.sign(np.sin(2 * np.pi * rng.uniform(200, 1500) * np.arange(L) / SR))
        elif kind == 2:
            seg = np.round(seg * 2) / 2
        out[k:k + L] = seg[: max(0, min(L, n - k))] * rng.uniform(0.3, 1)
        k += L
    out *= np.linspace(1, 0.2, n)
    return norm(out, 0.6)


def main():
    sec = 24.0
    forest = wind(sec + 1.5) * 0.8 + rustle(sec + 1.5, 9) * 0.25
    save_ogg(OUT + "amb_forest.ogg", norm(loopable(forest), 0.7))
    night = crickets(sec + 1.5) * 0.45 + wind(sec + 1.5) * 0.35
    save_ogg(OUT + "amb_night.ogg", norm(loopable(night), 0.6))
    save_ogg(OUT + "sfx_bell_far.ogg", bell(4.5))
    save_wav(OUT + "sfx_creepy.wav", creepy())
    save_wav(OUT + "sfx_glitch.wav", glitch())
    print("ok")


if __name__ == "__main__":
    main()
