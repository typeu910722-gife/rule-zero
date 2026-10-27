"""第三～五章的環境音（程式合成，不外包）：無縫循環的 ogg。
  amb_hum.ogg    醫院、實驗室：日光燈的嗡嗡聲＋通風口的氣流（太安靜、太乾淨）
  amb_drone.ogg  舊病棟、地下二樓、月台：很低的嗡鳴＋偶爾的水滴、遠處金屬聲
  amb_room.ogg   學校、家裡：空房間的空氣聲＋很遠的時鐘
用法：py -3.11 tools/audio/make_ambience.py game/audio
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 44100
LEN = 24.0                         # 秒；頭尾交叉淡入淡出做成無縫循環
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "game/audio")
rng = np.random.default_rng(7)
N = int(SR * LEN)
t = np.arange(N) / SR


def pink(n):
    w = rng.standard_normal(n)
    f = np.fft.rfft(w)
    k = np.arange(len(f))
    k[0] = 1
    f /= np.sqrt(k)
    p = np.fft.irfft(f, n)
    return p / np.max(np.abs(p))


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


def loopify(x, fade=2.0):
    """尾巴疊到頭上（等功率交叉），長度變成 LEN-fade，接起來沒有縫"""
    m = int(SR * fade)
    a = np.linspace(0, 1, m)
    head = x[:m] * np.sqrt(a) + x[-m:] * np.sqrt(1 - a)
    return np.concatenate([head, x[m:-m]])


def stereo(l, r=None):
    r = l if r is None else r
    return np.stack([l, r], axis=1)


def norm(x, peak=0.5):
    return x / np.max(np.abs(x)) * peak


def hum():
    # 日光燈：100/120Hz 的電源聲＋奇次諧波，音量慢慢地呼吸；加上很細的高頻嘶嘶聲
    base = 120.0
    h = sum((0.6 / k) * np.sin(2 * np.pi * base * k * t + k) for k in (1, 2, 3, 5, 7))
    h *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.11 * t) ** 2
    buzz = bandpass(rng.standard_normal(N), 6000, 9000) * 0.05
    air = lowpass(pink(N), 500) * 0.55
    l = norm(h, 0.16) + norm(air, 0.35) + buzz
    r = norm(h, 0.15) + norm(lowpass(pink(N), 500), 0.35) + buzz
    return stereo(loopify(l), loopify(r))


def drone():
    # 很低的嗡鳴（兩個靠很近的頻率互相拍打）＋水滴＋遠處的金屬聲
    d = np.sin(2 * np.pi * 43 * t) + 0.8 * np.sin(2 * np.pi * 43.6 * t) + 0.3 * np.sin(2 * np.pi * 86.3 * t)
    rumble = lowpass(pink(N), 140)
    x = norm(d, 0.22) + norm(rumble, 0.4)
    for when in rng.uniform(1.5, LEN - 3, 6):       # 水滴
        i = int(when * SR)
        n = int(0.25 * SR)
        f = rng.uniform(900, 1500)
        tt = np.arange(n) / SR
        x[i:i + n] += 0.12 * np.sin(2 * np.pi * f * tt * (1 + 2.5 * tt)) * np.exp(-tt * 28)
    for when in rng.uniform(3, LEN - 5, 2):         # 遠處的金屬聲（很悶）
        i = int(when * SR)
        n = int(2.5 * SR)
        tt = np.arange(n) / SR
        clang = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * dcy) for f, dcy in ((182, 1.6), (431, 2.4), (697, 3.5)))
        x[i:i + n] += lowpass(clang, 900) * 0.05
    r = np.roll(x, int(0.013 * SR))
    return stereo(loopify(x), loopify(r))


def room():
    # 空房間的空氣聲＋很遠的時鐘（滴答，壓得很低）
    air = norm(lowpass(pink(N), 700), 0.6)
    x = air.copy()
    tick = np.zeros(N)
    n = int(0.03 * SR)
    tt = np.arange(n) / SR
    click = np.sin(2 * np.pi * 2400 * tt) * np.exp(-tt * 260)
    for k in range(int(LEN)):
        i = int(k * SR)
        if i + n < N:
            tick[i:i + n] += click * (0.07 if k % 2 else 0.056)
    x += lowpass(tick, 3000)
    r = norm(lowpass(pink(N), 700), 0.6) + lowpass(tick, 3000)
    return stereo(loopify(x), loopify(r))


OUT.mkdir(parents=True, exist_ok=True)
for name, fn in (("amb_hum", hum), ("amb_drone", drone), ("amb_room", room)):
    # soundfile 直接寫 ogg 在 Windows 會當掉：先寫 wav 再用 ffmpeg 轉
    wav = OUT / f"{name}.tmp.wav"
    sf.write(wav, fn().astype(np.float32), SR, subtype="FLOAT")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4", str(OUT / f"{name}.ogg")], check=True)
    wav.unlink()
    print("wrote", OUT / f"{name}.ogg")
