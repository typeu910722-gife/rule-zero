"""3D 追逐的追兵聲音（程式合成）：sfx_ivdrag.ogg＝點滴架被拖著走（輪子吱吱、金屬桿喀啦喀啦、光腳拖地），無縫循環。
遊戲裡掛在追兵身上（AudioStreamPlayer3D），越近越大聲、聽得出從哪個方向來。
用法：py -3.11 tools/audio/make_chase_sfx.py game/audio
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
LEN = 6.0
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "game/audio")
rng = np.random.default_rng(11)
N = int(SR * LEN)
t = np.arange(N) / SR


def lowpass(x, cut):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1 / (1 + (fr / cut) ** 4)
    return np.fft.irfft(f, len(x))


def bandpass(x, lo, hi):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f *= ((fr > lo) & (fr < hi))
    return np.fft.irfft(f, len(x))


x = np.zeros(N)
# 輪子在地磚上滾：低沉的隆隆聲，每過一條磚縫「喀」一下（步調不太穩）
roll = lowpass(rng.standard_normal(N), 260) * 0.25
x += roll * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t) ** 2)
# 小輪子的嘎啦嘎啦（中高頻雜訊，被很快的轉速調變）
rattle = bandpass(rng.standard_normal(N), 700, 3000)
am = np.abs(np.sin(2 * np.pi * (11 + 2 * np.sin(2 * np.pi * 0.3 * t)) * t)) ** 3
x += rattle * am * 0.22
pos = 0.0
while pos < LEN - 0.1:
    i = int(pos * SR)
    n = int(0.04 * SR)
    tt = np.arange(n) / SR
    x[i:i + n] += bandpass(rng.standard_normal(n), 400, 3000) * np.exp(-tt * 160) * 0.5
    pos += rng.uniform(0.32, 0.5)
# 輪子吱吱叫（沒上油）：頻率抖動的窄頻聲，斷斷續續
for start in (0.4, 2.1, 3.9, 5.0):
    i = int(start * SR)
    n = int(rng.uniform(0.35, 0.7) * SR)
    tt = np.arange(n) / SR
    f = 1900 + 300 * np.sin(2 * np.pi * 7 * tt) + rng.uniform(-200, 200)
    sq = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / tt[-1]) ** 2
    x[i:i + n] += sq * 0.16
# 金屬桿互相碰：短促的金屬聲
for start in rng.uniform(0.2, LEN - 0.6, 5):
    i = int(start * SR)
    n = int(0.5 * SR)
    tt = np.arange(n) / SR
    c = sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * np.exp(-tt * d) for f, d in ((1373, 38), (2291, 45), (3517, 60), (4880, 70)))
    c += bandpass(rng.standard_normal(n), 2000, 8000) * np.exp(-tt * 120) * 2
    x[i:i + n] += c * 0.06
# 光腳拖在地上（很慢、有點不規則）
for start in np.arange(0.15, LEN - 0.8, 1.15) + rng.uniform(-0.1, 0.1, len(np.arange(0.15, LEN - 0.8, 1.15))):
    i = int(start * SR)
    n = int(0.55 * SR)
    tt = np.arange(n) / SR
    drag = bandpass(rng.standard_normal(n), 300, 2500) * np.sin(np.pi * tt / tt[-1]) ** 1.5
    x[i:i + n] += drag * 0.18
# 無縫循環
m = int(0.3 * SR)
a = np.linspace(0, 1, m)
x = np.concatenate([x[:m] * np.sqrt(a) + x[-m:] * np.sqrt(1 - a), x[m:-m]])
x = x / np.max(np.abs(x)) * 0.7
wav = OUT / "sfx_ivdrag.tmp.wav"
sf.write(wav, x.astype(np.float32), SR, subtype="FLOAT")     # 單聲道：3D 定位用
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5", str(OUT / "sfx_ivdrag.ogg")], check=True)
wav.unlink()
print("wrote", OUT / "sfx_ivdrag.ogg")
