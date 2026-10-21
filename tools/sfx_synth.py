#!/usr/bin/env python3
"""合成音效的共用工具（tools/make_ch3_sfx.py、tools/make_ch45_sfx.py 用）。

目標是「像真實錄音」而不是電子嗶聲：
- 物件的聲音用「模態合成」（一組會衰減的共振頻率，像真的金屬／木頭被敲到時那樣，每次頻率、相位都有一點隨機）。
- 摩擦、空氣、水用「顆粒」或濾波過的噪音，包絡用不規則的形狀（不是單純的指數或 sin²）。
- 最後一律經過「房間」：用合成的衝擊響應（早期反射＋分頻衰減的殘響尾巴，左右聲道不同）做卷積。
- 輸出前用 BS.1770 響度正規化（和 tools/audio_measure.py 同一套算法），再用前看限幅器把真峰值壓在 -1 dBTP 以下，
  頭尾加短淡入淡出，去掉直流。

取樣率 48 kHz（K 加權係數是 48 kHz 的），立體聲 Ogg Vorbis。
"""
import os, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

import audio_measure as am  # 同一個資料夾：響度量測

SR = 48000


class Synth:
    def __init__(self, seed):
        self.rng = np.random.default_rng(seed)

    # ── 基本 ──
    def n(self, d):
        return int(round(d * SR))

    def t(self, d):
        return np.arange(self.n(d)) / SR

    def noise(self, d):
        return self.rng.standard_normal(self.n(d))

    def pink(self, d):
        """粉紅噪音（-3 dB/八度）：自然界的背景聲比白噪音更像這個"""
        x = self.noise(d)
        X = np.fft.rfft(x)
        f = np.fft.rfftfreq(len(x), 1 / SR)
        f[0] = f[1]
        return np.fft.irfft(X / np.sqrt(f), len(x)) * 30

    def brown(self, d):
        x = np.cumsum(self.noise(d))
        return hp(x - np.mean(x), 20) * 0.02

    def jit(self, v, amount):
        """隨機微變化：v × (1 ± amount)"""
        return v * (1 + self.rng.uniform(-amount, amount))

    def slow_rand(self, d, rate, depth):
        """慢慢飄的隨機起伏（1 ± depth），rate＝每秒幾次變化"""
        k = max(2, int(d * rate) + 2)
        pts = self.rng.uniform(-1, 1, k)
        x = np.interp(np.linspace(0, k - 1, self.n(d)), np.arange(k), pts)
        return 1 + depth * lp(x, max(rate, 0.5), 1)

    # ── 物件 ──
    def modal(self, d, modes, jitter=0.02, strike=0.0008):
        """模態合成：modes＝[(頻率 Hz, 衰減時間常數 s, 振幅)]。
        strike＝敲擊的接觸時間（秒）：越長，高頻越少（軟的東西敲到）"""
        tt = self.t(d)
        x = np.zeros(len(tt))
        for f, tau, a in modes:
            f = self.jit(f, jitter)
            tau = self.jit(tau, 0.15)
            # 接觸時間越長，高頻模態被激發得越少
            a = a / (1 + (f * strike) ** 2) if strike > 0 else a
            x += a * np.sin(2 * np.pi * f * tt + self.rng.uniform(0, 2 * np.pi)) * np.exp(-tt / tau)
        return x * self.attack(len(tt), 0.0004)

    def attack(self, n, a):
        """很短的起音（避免第一個樣本就跳到最大）"""
        k = max(1, int(a * SR))
        e = np.ones(n)
        e[:k] = np.linspace(0, 1, k) ** 1.5
        return e

    def burst(self, d, tau, lo=None, hi=None, a=0.0003):
        """一下衝擊的噪音（接觸的瞬間）"""
        tt = self.t(d)
        x = self.noise(d) * np.exp(-tt / tau) * self.attack(len(tt), a)
        if lo and hi:
            return bp(x, lo, hi)
        if hi:
            return lp(x, hi)
        if lo:
            return hp(x, lo)
        return x

    def grains(self, d, rate, glen, lo, hi, env=None, amp_sd=0.5):
        """顆粒（摩擦、粉筆、布、羽毛）：隨機時間點的小噪音顆粒；rate 可以是常數或跟長度一樣的陣列"""
        N = self.n(d)
        out = np.zeros(N)
        if np.ndim(rate) == 0:
            r = np.full(N, float(rate))
        else:
            rate = np.asarray(rate, dtype=float)
            r = np.interp(np.linspace(0, 1, N), np.linspace(0, 1, len(rate)), rate)
        i = 0
        g = self.n(glen)
        while i < N:
            rr = max(r[min(i, N - 1)], 1e-3)
            i += max(1, int(self.rng.exponential(SR / rr)))
            if i >= N:
                break
            gg = max(8, int(g * self.rng.uniform(0.5, 1.6)))
            w = np.hanning(gg) * self.rng.standard_normal(gg) * np.exp(self.rng.normal(0, amp_sd))
            k = min(gg, N - i)
            out[i:i + k] += w[:k]
        out = bp(out, lo, hi)
        return out * (env if env is not None else 1)

    def bubbles(self, d, rate, fmin, fmax, env=None):
        """水：很多個小氣泡（Minnaert 共振，頻率往上滑、很快衰減）"""
        N = self.n(d)
        out = np.zeros(N)
        k = int(d * rate)
        for _ in range(k):
            at = self.rng.integers(0, N)
            f0 = np.exp(self.rng.uniform(np.log(fmin), np.log(fmax)))
            dec = 0.043 * f0 + 0.0014 * f0 ** 1.5
            L = min(int(6 / dec * SR), N - at)
            if L < 8:
                continue
            tt = np.arange(L) / SR
            f = f0 * (1 + 0.1 * dec * tt)
            ph = 2 * np.pi * np.cumsum(f) / SR
            a = self.rng.uniform(0.1, 1.0) ** 2 * (2000 / f0) ** 0.5
            out[at:at + L] += a * np.sin(ph) * np.exp(-dec * tt)
        return out * (env if env is not None else 1)

    # ── 空間 ──
    ROOMS = {
        # rt60（低、中、高頻，秒）、預延遲、早期反射的時間範圍、早期反射數
        "tile":     dict(rt=(0.9, 1.1, 0.7), pre=0.003, er=0.025, taps=18),   # 磁磚廁所
        "corridor": dict(rt=(1.0, 0.9, 0.5), pre=0.006, er=0.045, taps=14),   # 學校走廊
        "classroom": dict(rt=(0.7, 0.6, 0.4), pre=0.005, er=0.035, taps=12),
        "small":    dict(rt=(0.35, 0.3, 0.2), pre=0.002, er=0.012, taps=8),    # 小房間、近距離
        "lab":      dict(rt=(1.6, 1.4, 0.9), pre=0.010, er=0.060, taps=16),   # 很大的水泥實驗室
        "hall":     dict(rt=(2.2, 1.9, 1.1), pre=0.018, er=0.080, taps=16),   # 很大的空間（宿舍、病房）
        "outdoor":  dict(rt=(0.6, 0.4, 0.2), pre=0.090, er=0.300, taps=6),    # 戶外：遠處建築物的回音
    }

    def room_ir(self, kind):
        p = self.ROOMS[kind]
        rt = p["rt"]
        d = max(rt) * 1.3 + p["pre"] + p["er"]
        N = self.n(d)
        tt = np.arange(N) / SR
        ir = np.zeros((N, 2))
        for ch in range(2):
            tail = np.zeros(N)
            for (lo, hi), r in zip([(None, 400), (400, 3500), (3500, None)], rt):
                z = self.rng.standard_normal(N)
                z = lp(z, hi) if lo is None else (hp(z, lo) if hi is None else bp(z, lo, hi))
                tail += z * np.exp(-6.91 * tt / r)
            # 殘響密度慢慢長起來（先是零散的反射，後來才是一片）
            onset = p["pre"] + p["er"] * 0.4
            tail *= np.clip((tt - onset) / (p["er"] * 0.8 + 0.005), 0, 1) ** 2
            er = np.zeros(N)
            for k in range(p["taps"]):
                at = p["pre"] + self.rng.uniform(0, p["er"])
                i = int(at * SR)
                if i < N:
                    er[i] += self.rng.choice([-1, 1]) * self.rng.uniform(0.3, 1.0) * (1 - at / (p["pre"] + p["er"] + 0.01)) ** 1.5
            er = lp(er, 7000)  # 牆面吸掉一些高頻
            e_er = np.sqrt(np.sum(er ** 2)) + 1e-9
            e_tail = np.sqrt(np.sum(tail ** 2)) + 1e-9
            ir[:, ch] = er / e_er * 0.8 + tail / e_tail
        return ir / np.sqrt(np.sum(ir ** 2) / 2)

    def room(self, x, kind, wet_db=-10.0, width=0.3):
        """把乾聲 x（單聲道）放進房間：回傳立體聲（樣本×2）。wet_db＝殘響相對乾聲的大小"""
        ir = self.room_ir(kind)
        n = len(x) + len(ir) - 1
        out = np.zeros((n, 2))
        g = 10 ** (wet_db / 20)
        for ch in range(2):
            out[:, ch] = signal.fftconvolve(x, ir[:, ch]) * g
        # 乾聲：中間偏一點點（width 越大，左右越不一樣）
        pan = self.rng.uniform(-width, width) * 0.3
        out[:len(x), 0] += x * (1 - pan)
        out[:len(x), 1] += x * (1 + pan)
        return out

    def far(self, x, amount):
        """距離：空氣吸收高頻（amount 0～1）"""
        return lp(x, 16000 * (1 - amount) + 1500 * amount, 2)


# ── 濾波 ──
def _sos(kind, f, order=2):
    nyq = SR / 2
    if isinstance(f, (list, tuple)):
        f = [max(10, f[0]) / nyq, min(0.99 * nyq, f[1]) / nyq]
    else:
        f = min(0.99 * nyq, max(10, f)) / nyq
    return signal.butter(order, f, kind, output="sos")


def lp(x, f, order=2):
    return signal.sosfilt(_sos("low", f, order), x, axis=0)


def hp(x, f, order=2):
    return signal.sosfilt(_sos("high", f, order), x, axis=0)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("band", [lo, hi], order), x, axis=0)


def peq(x, f, gain_db, q=1.0):
    """峰值等化（RBJ biquad）"""
    A = 10 ** (gain_db / 40)
    w = 2 * np.pi * f / SR
    al = np.sin(w) / (2 * q)
    b = [1 + al * A, -2 * np.cos(w), 1 - al * A]
    a = [1 + al / A, -2 * np.cos(w), 1 - al / A]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def door(x, fc=650.0):
    """隔著一扇門：門板只讓低中頻通過（板子共振在 150～250 Hz），門縫漏一點點中高頻"""
    body = peq(lp(x, fc, 4), 190, 5.0, 1.2)
    leak = bp(x, 900, 2600) * 10 ** (-24 / 20)
    return body + leak


def mix(*xs):
    """把長度不同的幾段聲音加在一起（短的補零）"""
    n = max(len(x) for x in xs)
    out = np.zeros(n)
    for x in xs:
        out[:len(x)] += x
    return out


def place(buf, x, at, gain=1.0):
    i = int(round(at * SR))
    if i >= len(buf):
        return buf
    k = min(len(x), len(buf) - i)
    buf[i:i + k] += x[:k] * gain
    return buf


def shape(x, pts):
    """分段線性包絡：pts＝[(秒, 值), …]"""
    tt = np.arange(len(x)) / SR
    a = np.array(pts)
    return x * np.interp(tt, a[:, 0], a[:, 1])


# ── 輸出 ──
def stereo(x):
    return np.stack([x, x], axis=1) if x.ndim == 1 else x


def loudness(x):
    """回傳（整合響度, 最大瞬時響度），和 tools/audio_measure.py 同一套"""
    x = stereo(x)
    y = am.kweight(x)
    mom, _ = am.block_loudness(y, int(0.4 * SR), int(0.1 * SR))
    return am.integrated(y), float(np.max(mom))


def true_peak_db(x):
    return 20 * np.log10(np.max(np.abs(signal.resample_poly(stereo(x), 4, 1, axis=0))) + 1e-12)


def limiter(x, ceiling_db=-2.0, release=0.08, look=0.0015):
    """前看限幅器：只壓住超過上限的瞬間（槍聲、電閘這種很尖的峰）。
    增益＝（每個樣本需要的增益）→ 前後 look 秒取最小 → 再平均（保證不會超過）→ 放開時慢慢回到 1"""
    from scipy.ndimage import minimum_filter1d, uniform_filter1d
    x = stereo(x)
    c = 10 ** (ceiling_db / 20)
    g = np.minimum(1.0, c / (np.max(np.abs(x), axis=1) + 1e-12))
    L = max(2, int(look * SR))
    g = uniform_filter1d(minimum_filter1d(g, 2 * L + 1), L)
    r = np.exp(-1 / (release * SR))
    out = np.empty_like(g)
    prev = 1.0
    for i in range(len(g)):
        prev = min(g[i], 1 - (1 - prev) * r)
        out[i] = prev
    return x * out[:, None]


def finish(x, target, mode="mom", ceiling=-1.5, fade_in=0.002, fade_out=0.03, tail_db=-70):
    """去直流 → 修掉尾巴的靜音 → 響度正規化到 target（mode＝'mom' 最大瞬時、'int' 整合）→ 限幅 → 淡入淡出"""
    x = hp(stereo(x), 18, 2)
    # 尾巴低於 tail_db 的部分剪掉（保留一點）
    env = np.max(np.abs(x), axis=1)
    thr = np.max(env) * 10 ** (tail_db / 20)
    idx = np.nonzero(env > thr)[0]
    if len(idx):
        x = x[:min(len(x), idx[-1] + int(0.05 * SR))]
    for _ in range(6):
        li, lm = loudness(x)
        cur = lm if mode == "mom" else li
        x = x * 10 ** ((target - cur) / 20)
        if true_peak_db(x) > ceiling:
            x = limiter(x, ceiling - 0.6)
        li, lm = loudness(x)
        if abs(target - (lm if mode == "mom" else li)) < 0.25:
            break
    fi, fo = int(fade_in * SR), int(fade_out * SR)
    if fi:
        x[:fi] *= np.linspace(0, 1, fi)[:, None]
    if fo:
        x[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 2
    return x


def save(path, x, quality=6):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = stereo(x)
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        wavfile.write(f.name, SR, x.astype(np.float32))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f.name, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    li, lm = loudness(x)
    print(f"完成 {os.path.basename(path):24s} {len(x) / SR:5.2f}s  整合 {li:6.1f}  瞬時最大 {lm:6.1f}  真峰值 {true_peak_db(x):5.1f}")
