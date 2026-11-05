#!/usr/bin/env python3
"""第四章〈三年二班〉、第五章（終章）配樂。

人類時期不用玩偶世界的音樂盒、玻璃琴，改成鋼琴（教室角落那台舊鋼琴）＋弦樂墊底。
旋律一樣是全作的動機（Mi La Sol Mi｜Fa Mi Re｜Si），只是換成「真的樂器」：
小布在玩偶世界聽到的音樂盒，原來是這首。

  ch4_bgm01_school       白天的教室（第四章各個視角的回憶段落）
  ch4_bgm02_after_school 放學後、夕陽（傍晚的段落）
  ch4_bgm03_night        晚上、一個人（夜晚的段落）
  ch4_bgm04_unease       事情開始不對勁（那一天之前）
  ch5_bgm01_lesson       最後一堂課（終章的選擇）
  ch5_bgm02_waking       醒來（終章 A）：動機第一次「解決」回到主音
  ch5_bgm03_hollow       空的病房（終章 B-2、B-3）：遠處的心電監護儀

全部是可以循環的立體聲 OGG（長度是整數小節）。
用法：python tools/make_ch45_bgm.py [名字…]
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal

SR = 44100
OUT = Path("game/audio/ch45/bgm")
RNG = np.random.default_rng(45)
MOTIF = [76, 81, 79, 76, 77, 76, 74, 71]  # Mi La Sol Mi｜Fa Mi Re｜Si（和第三章同一個動機）


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def lp(x, c):
    b, a = signal.butter(2, c / (SR / 2), "low")
    return signal.lfilter(b, a, x)


def hp(x, c):
    b, a = signal.butter(2, c / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def pan(x, pos):
    a = (pos + 1.0) * np.pi / 4.0
    return np.column_stack((x * np.cos(a), x * np.sin(a)))


def add(buf, x, sec, pos=0.0, gain=1.0):
    """加到循環的緩衝區裡；超過結尾的部分繞回開頭（循環時才不會斷）"""
    i = int(sec * SR) % len(buf)
    s = pan(x * gain, pos)
    n = min(len(s), len(buf) - i)
    buf[i:i + n] += s[:n]
    if n < len(s):
        buf[:len(s) - n] += s[n:]


def piano(m, dur=3.0, vel=0.7, soft=False):
    """簡單的鋼琴：每個泛音自己衰減（高的衰減快）、一點點不和諧（弦的硬度）、槌子的雜音"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    B = 0.0004
    x = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > SR / 2.2:
            break
        amp = (1.0 / k ** 1.25) * (vel ** (0.4 + 0.25 * k))
        decay = 1.1 + 0.9 * k + f / 600
        beat = 1 + 0.002 * np.sin(2 * np.pi * (0.7 + 0.3 * k) * t)   # 同一個音的三根弦稍微不準
        x += amp * np.sin(2 * np.pi * fk * t * beat) * np.exp(-t * decay)
    ham = hp(RNG.standard_normal(n), 1500) * np.exp(-t * 90) * 0.04 * vel
    x = x + ham
    x *= np.minimum(1, t * 400)
    rel = int(0.12 * SR)
    x[-rel:] *= np.linspace(1, 0, rel)
    x = lp(x, 2600 if soft else 5200)
    return x * vel * 0.55


def strings(m, dur, dark=False):
    """弦樂墊：幾個稍微走音的鋸齒波，濾得很暗，慢慢進來慢慢出去"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    vib = 1 + 0.003 * np.sin(2 * np.pi * 5.1 * t + RNG.uniform(0, 6))
    x = sum(signal.sawtooth(2 * np.pi * f * (2 ** (c / 1200)) * np.cumsum(vib) / SR * SR / SR * 1.0)
            for c in (-7, 0, 6)) / 3
    x = lp(x, 700 if dark else 1200)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.2
    return x * env * 0.12


def tick():
    n = int(0.03 * SR)
    t = np.arange(n) / SR
    return hp(RNG.standard_normal(n), 3000) * np.exp(-t * 300) * 0.05


def monitor(m=93):
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * hz(m) * t) * np.exp(-t * 30) * np.minimum(1, t * 800) * 0.07


def room(x, seconds=2.4, wet=0.22):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros_like(x)
    for ch in range(2):
        ir = lp(RNG.standard_normal(n) * np.exp(-t * 5.0 / seconds), 5000)
        w = signal.fftconvolve(x[:, ch], ir, mode="full")
        # 殘響尾巴繞回開頭，循環點聽不出來
        tail = w[len(x):]
        w = w[:len(x)].copy()
        w[:len(tail)] += tail[:len(x)]
        w /= np.max(np.abs(w)) + 1e-9
        out[:, ch] = x[:, ch] * (1 - wet) + w * np.max(np.abs(x[:, ch])) * wet
    return out


def track(bpm, bars, chords, motif_bars=(), arp="up", vel=0.55, dark=False, soft=False,
          shift=0, extra=None, resolve=False):
    """一般的段落曲：左手和弦分解、右手在某幾小節彈動機、弦樂墊底"""
    beat = 60.0 / bpm
    bar_len = beat * 4
    seconds = bars * bar_len
    buf = np.zeros((int(seconds * SR), 2))
    for b in range(bars):
        root = chords[b % len(chords)]
        start = b * bar_len
        third = 3 if root % 12 in (9, 2, 4) else 4   # La、Re、Mi 小調，其他大調（大致跟著動機的調性）
        tones = [root, root + 7, root + 12, root + 12 + third, root + 19]
        if arp == "up":
            pat = [0, 1, 2, 3, 4, 3, 2, 1]
        elif arp == "slow":
            pat = [0, None, 2, None, 3, None, 2, None]
        else:
            pat = [0, None, None, None, 2, None, None, None]
        for q, idx in enumerate(pat):
            if idx is None:
                continue
            v = vel * (0.75 if q else 0.95) * RNG.uniform(0.9, 1.05)
            add(buf, piano(tones[idx], bar_len * 1.1, v * 0.7, True), start + q * beat / 2 + RNG.normal(0, 0.006),
                -0.35 + 0.1 * idx, 1.0)
        add(buf, strings(root + 12, bar_len * 1.25, dark), start - bar_len * 0.1, -0.5)
        add(buf, strings(root + 19, bar_len * 1.25, dark), start - bar_len * 0.1, 0.5)
        if b % 8 in motif_bars or (b + 4) % 8 in motif_bars and resolve and b >= bars - 4:
            for i, m in enumerate(MOTIF):
                sec = start + i * beat / 2 + RNG.normal(0, 0.008)
                note = m + shift
                if resolve and b >= bars - 4 and i == len(MOTIF) - 1:
                    note = MOTIF[0] + shift - 4   # 最後一個音不留在 Si，落回主音：終於結束了
                add(buf, piano(note, beat * 2.5, vel * 1.1, soft), sec, 0.25)
        if extra:
            extra(buf, start, beat, b)
    return room(buf, 3.2 if dark else 2.4, 0.30 if dark else 0.22)


def school():
    return track(84, 16, [57, 53, 48, 52], motif_bars=(2, 6), arp="up", vel=0.5)


def after_school():
    return track(68, 16, [53, 48, 50, 45], motif_bars=(4,), arp="slow", vel=0.45, soft=True, shift=-12)


def night():
    def ext(buf, start, beat, b):
        for q in range(4):
            add(buf, tick(), start + q * beat, 0.6)
    return track(60, 12, [45, 41, 43, 40], motif_bars=(3,), arp="sparse", vel=0.4, dark=True, soft=True,
                 shift=-12, extra=ext)


def unease():
    def ext(buf, start, beat, b):
        for q in range(8):
            add(buf, tick(), start + q * beat / 2, 0.6 if q % 2 else -0.6, 1.4)
        # 低音的 Fa–Mi 半音，一直沒有離開
        add(buf, piano(29 if b % 2 == 0 else 28, beat * 4, 0.5, True), start, -0.2)
    return track(76, 12, [45, 46, 45, 44], motif_bars=(2, 6), arp="slow", vel=0.45, dark=True, soft=True,
                 shift=-1, extra=ext)   # 動機整個降半音：熟悉的旋律走了調


def lesson():
    return track(64, 16, [45, 41, 48, 52], motif_bars=(0, 4), arp="slow", vel=0.5, soft=True)


def waking():
    return track(72, 16, [48, 53, 45, 55], motif_bars=(2, 6), arp="up", vel=0.5, resolve=True, shift=-4)


def hollow():
    def ext(buf, start, beat, b):
        for q in range(0, 4, 1):
            add(buf, monitor(), start + q * beat + beat * 0.1, 0.7, 0.8)
    return track(60, 12, [40, 41, 40, 38], motif_bars=(5,), arp="sparse", vel=0.35, dark=True, soft=True,
                 shift=-12, extra=ext)


TRACKS = {
    "ch4_bgm01_school": school, "ch4_bgm02_after_school": after_school, "ch4_bgm03_night": night,
    "ch4_bgm04_unease": unease, "ch5_bgm01_lesson": lesson, "ch5_bgm02_waking": waking, "ch5_bgm03_hollow": hollow,
}


def save(name, x):
    peak = np.max(np.abs(x)) + 1e-9
    x = np.tanh(x / peak * 1.2) * 0.7
    raw = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(suffix=".wav")
    os.close(fd)
    try:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-", tmp],
                       input=raw.tobytes(), check=True)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "6",
                        str(OUT / f"{name}.ogg")], check=True)
    finally:
        os.remove(tmp)
    print("done", name, f"{len(x) / SR:.1f}s")


if __name__ == "__main__":
    want = set(sys.argv[1:])
    for name, fn in TRACKS.items():
        if not want or name in want:
            save(name, fn())
