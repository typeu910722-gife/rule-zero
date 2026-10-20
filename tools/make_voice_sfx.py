#!/usr/bin/env python3
"""布偶的「聲音」：嘆氣、笑、咯咯笑、低笑、倒抽一口氣、啜泣、吸鼻子、嗯、吞口水。
不是真人錄音——用聲門脈衝＋共振峰濾波合成，聽起來像絨毛娃娃小小聲的反應（全部自己產生，可商用）。
遊戲裡依角色調音高（Dialogue 的 VOICE_PITCH）。

用法：python3 tools/make_voice_sfx.py   → game/audio/voice/<種類>_<n>.ogg
"""
import os, subprocess, tempfile
import numpy as np
from scipy import signal

SR = 44100
OUT = "game/audio/voice"
rng = np.random.default_rng(7)

# 母音的共振峰（Hz、頻寬）
VOWEL = {
    "a": [(800, 90), (1250, 110), (2600, 160)],
    "e": [(480, 70), (1900, 120), (2600, 160)],
    "i": [(320, 60), (2300, 130), (3000, 180)],
    "u": [(350, 60), (850, 90), (2400, 160)],
    "o": [(500, 70), (900, 90), (2500, 160)],
    "m": [(260, 50), (1000, 200), (2300, 300)],   # 閉著嘴的鼻音
}


def resonate(x, formants, gains=(1.0, 0.5, 0.25)):
    out = np.zeros_like(x)
    for (f, bw), g in zip(formants, gains):
        r = np.exp(-np.pi * bw / SR)
        th = 2 * np.pi * f / SR
        b, a = [1 - r], [1, -2 * r * np.cos(th), r * r]
        out += g * signal.lfilter(b, a, x)
    return out


def glottal(f0, dur, jitter=0.01, shimmer=0.05):
    """聲門脈衝列：f0 可以是常數或陣列（音高曲線）"""
    n = int(dur * SR)
    f = np.full(n, f0) if np.isscalar(f0) else np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f0)), f0)
    f = f * (1 + jitter * rng.standard_normal(n).cumsum() / np.sqrt(n))
    ph = np.cumsum(f / SR)
    saw = ph % 1.0
    pulse = np.where(saw < 0.6, np.sin(np.pi * saw / 0.6) ** 2, 0.0)        # 開相
    pulse = np.diff(pulse, prepend=0) * (1 + shimmer * rng.standard_normal(n))
    return pulse


def noise(dur):
    n = int(dur * SR)
    w = rng.standard_normal(n)
    b, a = signal.butter(1, 1500 / (SR / 2), "low")          # 偏粉紅
    return signal.lfilter(b, a, w) * 0.6 + w * 0.15


def env(dur, a=0.02, r=0.1, shape=1.0):
    n = int(dur * SR)
    t = np.linspace(0, dur, n)
    e = np.minimum(1, t / max(a, 1e-4)) * np.minimum(1, (dur - t) / max(r, 1e-4))
    return np.clip(e, 0, 1) ** shape


def syllable(f0, dur, vowel, breath=0.25, voice=1.0, a=0.015, r=0.06):
    v = resonate(glottal(f0, dur), VOWEL[vowel]) * voice
    h = resonate(noise(dur), VOWEL[vowel]) * breath * 0.08
    return (v + h) * env(dur, a, r)


def seq(parts, gap):
    out = []
    for p in parts:
        out += [p, np.zeros(int(gap * SR))]
    return np.concatenate(out)


def sigh(var):
    dur = [1.0, 1.25, 0.85][var]
    b = resonate(noise(dur), VOWEL[["a", "u", "a"][var]]) * 0.09
    e = env(dur, 0.12, dur * 0.75, 1.3)
    v = resonate(glottal(np.linspace(210, 150, 50), dur), VOWEL["a"]) * 0.35
    ve = env(dur, 0.25, dur * 0.6) * np.linspace(1, 0.2, int(dur * SR))
    return b * e + v * ve * [0.5, 0.25, 0.7][var]


def laugh(var):
    n = [3, 4, 3][var]
    f = [300, 280, 330][var]
    parts = [syllable(f * (1 - 0.05 * k), 0.10, "e", breath=0.6, r=0.05) for k in range(n)]
    return seq(parts, 0.06)


def giggle(var):
    n = [5, 6, 4][var]
    f = [420, 390, 450][var]
    parts = [syllable(f * (1 + 0.04 * np.sin(k)), 0.065, "i", breath=0.5, r=0.03) for k in range(n)]
    return seq(parts, 0.045)


def chuckle(var):
    # 和平鴿：閉著嘴、很輕、很低的「哼、哼」
    n = [3, 2][var]
    parts = [syllable(170 - 8 * k, 0.12, "m", breath=0.9, voice=0.6, r=0.08) for k in range(n)]
    return seq(parts, 0.13)


def gasp(var):
    dur = [0.32, 0.4, 0.28][var]
    b = resonate(noise(dur), VOWEL["a"]) * 0.14
    e = env(dur, dur * 0.8, 0.03, 1.5)                        # 吸氣：漸強、突然停
    hp = signal.butter(2, 600 / (SR / 2), "high")
    return signal.lfilter(*hp, b * e)


def sob(var):
    parts = []
    for k in range([3, 2, 3][var]):
        d = 0.16
        inh = resonate(noise(d), VOWEL["u"]) * 0.07 * env(d, d * 0.7, 0.02)
        parts.append(inh)
    tail_d = 0.6
    f0 = np.linspace(330, 250, 40) * (1 + 0.04 * np.sin(np.linspace(0, 30, 40)))
    tail = resonate(glottal(f0, tail_d, jitter=0.03, shimmer=0.15), VOWEL["u"]) * 0.6 * env(tail_d, 0.05, 0.35)
    tail = tail * (1 + 0.35 * np.sin(np.linspace(0, 2 * np.pi * 7 * tail_d, len(tail))))   # 抖音
    return np.concatenate([seq(parts, 0.07), tail])


def sniff(var):
    parts = []
    for k in range([2, 1][var]):
        d = 0.12
        hp = signal.butter(2, 2500 / (SR / 2), "high")
        parts.append(signal.lfilter(*hp, noise(d)) * 0.25 * env(d, 0.06, 0.03))
    return seq(parts, 0.08)


def hmm(var):
    dur = [0.5, 0.65][var]
    f0 = [np.array([200, 230, 205]), np.array([210, 190, 225])][var]
    return resonate(glottal(f0, dur), VOWEL["m"]) * 0.8 * env(dur, 0.05, 0.2)


def gulp(var):
    d = 0.18
    t = np.linspace(0, d, int(d * SR))
    thump = np.sin(2 * np.pi * (180 - 400 * t) * t) * np.exp(-t * 25) * 0.6
    click = signal.lfilter(*signal.butter(2, 1500 / (SR / 2), "high"), noise(d)) * np.exp(-t * 80) * 0.3
    return thump + click


KINDS = {"sigh": (sigh, 3), "laugh": (laugh, 3), "giggle": (giggle, 3), "chuckle": (chuckle, 2),
         "gasp": (gasp, 3), "sob": (sob, 3), "sniff": (sniff, 2), "hmm": (hmm, 2), "gulp": (gulp, 1)}


def finish(x):
    b, a = signal.butter(2, 6000 / (SR / 2), "low")            # 布偶：悶一點、軟一點
    x = signal.lfilter(b, a, x)
    # 小房間的殘響
    ir_t = np.linspace(0, 0.25, int(0.25 * SR))
    ir = rng.standard_normal(len(ir_t)) * np.exp(-ir_t * 22) * 0.05
    ir[0] = 1.0
    x = signal.fftconvolve(x, ir)[: len(x) + int(0.15 * SR)]
    x = np.concatenate([np.zeros(int(0.01 * SR)), x])
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.7                    # 峰值 -3 dB
    fade = int(0.02 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def main():
    os.makedirs(OUT, exist_ok=True)
    for kind, (fn, n) in KINDS.items():
        for v in range(n):
            x = finish(fn(v))
            with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
                from scipy.io import wavfile
                wavfile.write(tmp.name, SR, (x * 32767).astype(np.int16))
                out = f"{OUT}/{kind}_{v + 1}.ogg"
                subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
            print("完成", out)


if __name__ == "__main__":
    main()
