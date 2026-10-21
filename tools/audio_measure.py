#!/usr/bin/env python3
"""音檔量測（混音 QA 用）：整合響度、最大瞬時響度、真峰值、削波、直流偏移、頭尾爆音、2–5 kHz 比例、頻譜平坦度。

用法：python3 tools/audio_measure.py [檔案或資料夾…] [--csv 輸出.csv]
（不給參數 → 量 game/audio 底下全部 .ogg/.wav）

- 響度照 ITU-R BS.1770-4（K 加權、400 ms 區塊、-70 LUFS 絕對門檻＋-10 LU 相對門檻）自己實作，和 ffmpeg ebur128 差 <0.3 LU。
- 太短（<0.4 s）的檔案沒有完整區塊，用補零後的 400 ms 區塊算（＝ ebur128 的 momentary）。
- 「最大瞬時響度」＝ 400 ms 視窗（每 100 ms）的最大值：短音效的「聽起來多大聲」以這個為準。
- 真峰值：4 倍超取樣後的最大絕對值（dBTP）。
- 頭尾爆音：第一個／最後一個樣本的絕對值，以及頭尾 2 ms 內的峰值對整體峰值的比例（> -20 dB 而且第一個樣本 > 0.02 就算「沒淡入」）。
- 2–5 kHz 比例：這個頻帶占全部能量（20 Hz–20 kHz）的百分比。
- 頻譜平坦度（0～1）：越接近 1 越像白噪音。
"""
import os, sys, subprocess, csv
import numpy as np
from scipy import signal

SR = 48000


def decode(path):
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    ch = channels(path)
    x = np.frombuffer(out, dtype=np.float32).astype(np.float64)
    return x.reshape(-1, ch)


def channels(path):
    o = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels",
                        "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip()
    return int(o or 1)


def kweight(x):
    # BS.1770 的兩段濾波（48 kHz 係數）
    b1 = [1.53512485958697, -2.69169618940638, 1.19839281085285]
    a1 = [1.0, -1.69065929318241, 0.73248077421585]
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, -1.99004745483398, 0.99007225036621]
    return signal.lfilter(b2, a2, signal.lfilter(b1, a1, x, axis=0), axis=0)


def block_loudness(y, win, hop):
    # y：K 加權後（樣本×聲道）；回傳每個區塊的響度（LUFS）
    n = len(y)
    if n < win:
        y = np.vstack([y, np.zeros((win - n, y.shape[1]))])
        n = win
    c = np.concatenate([[0.0], np.cumsum(np.sum(y ** 2, axis=1))])
    starts = np.arange(0, n - win + 1, hop)
    p = (c[starts + win] - c[starts]) / win
    return -0.691 + 10 * np.log10(p + 1e-20), p


def integrated(y):
    lk, p = block_loudness(y, int(0.4 * SR), int(0.1 * SR))
    keep = lk > -70
    if not keep.any():
        return -99.0
    rel = -0.691 + 10 * np.log10(np.mean(p[keep])) - 10
    keep &= lk > rel
    return -0.691 + 10 * np.log10(np.mean(p[keep]) + 1e-20)


def measure(path):
    x = decode(path)
    mono = x.mean(axis=1)
    dur = len(x) / SR
    y = kweight(x)
    lufs = integrated(y)
    mom, _ = block_loudness(y, int(0.4 * SR), int(0.1 * SR))
    peak = np.max(np.abs(x)) + 1e-12
    tp = np.max(np.abs(signal.resample_poly(x, 4, 1, axis=0))) + 1e-12
    clip = int(np.sum(np.abs(x) >= 0.999))
    dc = float(np.mean(mono))
    e = int(0.002 * SR)
    head = np.max(np.abs(mono[:e])) / peak
    tail = np.max(np.abs(mono[-e:])) / peak
    first, last = abs(mono[0]), abs(mono[-1])
    f, P = signal.welch(mono, SR, nperseg=min(4096, max(256, len(mono))))
    band = (f >= 20) & (f <= 20000)
    harsh = np.sum(P[(f >= 2000) & (f <= 5000)]) / (np.sum(P[band]) + 1e-20)
    Pb = P[band] + 1e-20
    flat = np.exp(np.mean(np.log(Pb))) / np.mean(Pb)
    cent = np.sum(f[band] * P[band]) / (np.sum(P[band]) + 1e-20)
    return {
        "file": path, "dur": round(dur, 2), "ch": x.shape[1], "lufs": round(lufs, 1), "mom_max": round(float(np.max(mom)), 1),
        "peak_db": round(20 * np.log10(peak), 1), "tp_db": round(20 * np.log10(tp), 1), "clip": clip, "dc": round(dc, 4),
        "pop_head": bool(head > 0.1 and first > 0.02), "pop_tail": bool(tail > 0.1 and last > 0.02),
        "first": round(float(first), 3), "last": round(float(last), 3),
        "harsh_2_5k": round(float(harsh) * 100, 1), "flatness": round(float(flat), 3), "centroid": int(cent),
    }


def files(args):
    out = []
    for a in args:
        if os.path.isdir(a):
            for root, _, fs in os.walk(a):
                out += [os.path.join(root, f) for f in sorted(fs) if f.endswith((".ogg", ".wav"))]
        else:
            out.append(a)
    return sorted(out)


if __name__ == "__main__":
    args = sys.argv[1:]
    out_csv = None
    if "--csv" in args:
        i = args.index("--csv"); out_csv = args[i + 1]; del args[i:i + 2]
    rows = [measure(p) for p in files(args or ["game/audio"])]
    keys = list(rows[0].keys())
    if out_csv:
        with open(out_csv, "w", newline="") as fh:
            w = csv.DictWriter(fh, keys); w.writeheader(); w.writerows(rows)
    for r in rows:
        print("\t".join(str(r[k]) for k in keys))
