#!/usr/bin/env python3
"""第三章的合成音效 → game/audio/ch3/：gunshot（槍聲）、gunshot_soft（減少驚嚇版：悶響）、gun_cock（上膛）、
light_on（燈一盞一盞亮起的「喀」）、card（撲克牌拍下）、needle（針穿過布）。全部自己合成，可商用。"""
import os, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile
SR = 44100
OUT = "game/audio/ch3"
rng = np.random.default_rng(11)

def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.8
    with tempfile.NamedTemporaryFile(suffix=".wav") as t:
        wavfile.write(t.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", t.name, "-c:a", "libvorbis", "-q:a", "6", f"{OUT}/{name}.ogg"], check=True)
    print("完成", name)

def t(d): return np.arange(int(d * SR)) / SR

def gunshot(soft=False):
    d = 2.5; tt = t(d)
    crack = rng.standard_normal(len(tt)) * np.exp(-tt * (60 if not soft else 25))
    boom = np.sin(2 * np.pi * (70 - 30 * tt) * tt) * np.exp(-tt * 6)
    tail = signal.lfilter(*signal.butter(2, 900 / (SR / 2), "low"), rng.standard_normal(len(tt))) * np.exp(-tt * 2.2) * 0.5
    x = (crack * (0.2 if soft else 1.0) + boom * 1.2 + tail)
    if soft:
        x = signal.lfilter(*signal.butter(2, 400 / (SR / 2), "low"), x)
    return x

def click(f=3500, d=0.05, decay=120):
    tt = t(d)
    return signal.lfilter(*signal.butter(2, [f * 0.6 / (SR / 2), min(0.99, f * 1.4 / (SR / 2))], "band"), rng.standard_normal(len(tt))) * np.exp(-tt * decay)

def gun_cock():
    a = click(2800, 0.08, 90); b = click(1800, 0.12, 60)
    gap = np.zeros(int(0.12 * SR))
    return np.concatenate([a, gap, b * 1.3])

def light_on():
    tt = t(0.6)
    thunk = np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 25)
    hum = np.sin(2 * np.pi * 120 * tt) * 0.15 * np.minimum(1, tt * 4) * np.exp(-tt * 3)
    return np.concatenate([click(4000, 0.03, 200), thunk + hum])

def card():
    tt = t(0.12)
    return signal.lfilter(*signal.butter(2, 2500 / (SR / 2), "high"), rng.standard_normal(len(tt))) * np.exp(-tt * 70) + np.sin(2 * np.pi * 180 * tt) * np.exp(-tt * 50) * 0.5

def needle():
    tt = t(0.18)
    return signal.lfilter(*signal.butter(2, [3000 / (SR / 2), 9000 / (SR / 2)], "band"), rng.standard_normal(len(tt))) * np.sin(np.pi * tt / 0.18) ** 2

os.makedirs(OUT, exist_ok=True)
save("gunshot", gunshot()); save("gunshot_soft", gunshot(True)); save("gun_cock", gun_cock())
save("light_on", light_on()); save("card", card()); save("needle", needle())
