#!/usr/bin/env python3
"""第四、五章的合成音效 → game/audio/ch4/。全部自己合成（或用遊戲裡既有的聲音再加工），可商用。

第四章「那一天」只用門外聽得到的聲音（docs/script/chapter4.md 6.2）：門被撞的悶響、門把轉不動、隔著門的笑聲、
水聲、手機錄影提示音、髮夾掉在磁磚上、白鴿振翅、遠處的警笛。不做任何身體、衣物、性相關的聲音。
其他：粉筆、訊息、按讚、電話、電閘、繩子（第五章開場，只有規律的吱聲）、耳鳴、老鷹。

用法：python3 tools/make_ch45_sfx.py（在專案根目錄）
"""
import os, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = "game/audio/ch4"
VOICE = "game/audio/voice"
rng = np.random.default_rng(45)


def t(d):
    return np.arange(int(d * SR)) / SR


def lp(x, f, order=2):
    return signal.lfilter(*signal.butter(order, f / (SR / 2), "low"), x)


def bp(x, lo, hi, order=2):
    return signal.lfilter(*signal.butter(order, [lo / (SR / 2), min(0.99, hi / (SR / 2))], "band"), x)


def noise(d):
    return rng.standard_normal(int(d * SR))


def save(name, x, peak=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        wavfile.write(f.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f.name, "-c:a", "libvorbis", "-q:a", "5", f"{OUT}/{name}.ogg"], check=True)
    print("完成", name)


def load_ogg(path):
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), f.name], check=True)
        sr, x = wavfile.read(f.name)
    return x.astype(np.float64) / 32768.0


def place(buf, x, at):
    i = int(at * SR)
    n = min(len(x), len(buf) - i)
    if n > 0:
        buf[i:i + n] += x[:n]


# ── 門外聽得到的聲音 ──
def door_thud():
    """隔著門被撞的悶響：低頻一下，門板共振一點點"""
    tt = t(0.9)
    body = np.sin(2 * np.pi * (85 - 25 * tt) * tt) * np.exp(-tt * 9)
    panel = bp(noise(0.9), 180, 420) * np.exp(-tt * 14) * 0.6
    rattle = bp(noise(0.9), 1800, 3500) * np.exp(-((tt - 0.05) ** 2) / 0.0004) * 0.15
    return lp(body + panel + rattle, 900)


def handle_rattle():
    """門把被壓住、轉不動：喀、喀、喀"""
    buf = np.zeros(int(1.4 * SR))
    for k, at in enumerate([0.0, 0.22, 0.41, 0.75, 0.93]):
        tt = t(0.07)
        c = bp(noise(0.07), 1500, 4200) * np.exp(-tt * 70) + np.sin(2 * np.pi * 620 * tt) * np.exp(-tt * 60) * 0.4
        place(buf, c * (1.0 if k % 2 == 0 else 0.7), at)
    return buf


def laugh_muffled():
    """隔著門、很多人的笑聲：用遊戲裡的笑聲疊幾層、錯開、壓成悶悶的"""
    buf = np.zeros(int(3.2 * SR))
    files = [f for f in sorted(os.listdir(VOICE)) if f.startswith(("laugh_", "giggle_", "chuckle_")) and f.endswith(".ogg")]
    for k in range(7):
        x = load_ogg(os.path.join(VOICE, files[k % len(files)]))
        rate = 0.82 + 0.06 * (k % 4)            # 音高、速度不一樣＝不同的人
        x = signal.resample(x, int(len(x) / rate))
        place(buf, x * (0.6 + 0.1 * (k % 3)), 0.15 + k * 0.33)
    buf = lp(buf, 520, 3)                         # 隔著一扇門
    buf += lp(noise(len(buf) / SR), 300) * 0.01
    return buf


def water():
    """水龍頭一直開著"""
    d = 4.0
    tt = t(d)
    x = bp(noise(d), 600, 5200) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 7.3 * tt + np.sin(2 * np.pi * 1.1 * tt))))
    drops = np.zeros(len(tt))
    for at in rng.uniform(0, d - 0.1, 40):
        dt = t(0.05)
        place(drops, np.sin(2 * np.pi * rng.uniform(900, 1600) * dt) * np.exp(-dt * 90) * 0.4, at)
    fade = np.minimum(1, tt * 2) * np.minimum(1, (d - tt) * 2)
    return lp(x * 0.5 + drops, 3500) * fade


def water_stop():
    """水聲慢慢停下來（第 9 個視角：只有黑畫面）"""
    x = water()
    tt = np.arange(len(x)) / SR
    return x * np.clip(1 - tt / (len(x) / SR), 0, 1) ** 2


def rec_beep():
    """手機開始錄影的提示音"""
    a = np.sin(2 * np.pi * 1320 * t(0.09)) * np.exp(-t(0.09) * 20)
    b = np.sin(2 * np.pi * 1760 * t(0.12)) * np.exp(-t(0.12) * 18)
    return np.concatenate([a, np.zeros(int(0.05 * SR)), b])


def hairpin():
    """很小的金屬髮夾掉在磁磚上：叮、叮、叮…越來越小"""
    buf = np.zeros(int(1.2 * SR))
    for k, at in enumerate([0.0, 0.16, 0.27, 0.34, 0.39]):
        tt = t(0.25)
        tone = sum(np.sin(2 * np.pi * f * tt) * a for f, a in [(4200, 1), (6100, 0.5), (8800, 0.25)])
        place(buf, tone * np.exp(-tt * 40) * (0.8 ** k), at)
    return buf


def wings():
    """白鴿振翅：幾下拍打"""
    buf = np.zeros(int(1.3 * SR))
    for k in range(6):
        tt = t(0.12)
        f = bp(noise(0.12), 300, 2400) * np.sin(np.pi * tt / 0.12) ** 2
        place(buf, f * (1 - k * 0.1), k * 0.17)
    return buf


def siren(d=6.0):
    """很遠的警笛"""
    tt = t(d)
    f = 700 + 250 * np.sin(2 * np.pi * 0.45 * tt)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.3 * np.sin(2 * ph)
    env = np.minimum(1, tt / 2.0) * np.minimum(1, (d - tt) / 1.5)
    return lp(x * env, 1400) + lp(noise(d), 200) * 0.02


# ── 其他 ──
def chalk():
    buf = np.zeros(int(0.9 * SR))
    for k in range(3):
        tt = t(0.18)
        place(buf, bp(noise(0.18), 2500, 7000) * np.sin(np.pi * tt / 0.18) * (0.7 + 0.3 * np.sin(2 * np.pi * 40 * tt)), k * 0.26)
    return buf


def msg_pop():
    tt = t(0.12)
    return np.sin(2 * np.pi * (880 + 900 * tt) * tt) * np.exp(-tt * 30)


def like_tap():
    tt = t(0.08)
    return np.sin(2 * np.pi * 1560 * tt) * np.exp(-tt * 55) + bp(noise(0.08), 3000, 6000) * np.exp(-tt * 120) * 0.3


def phone_ring():
    """電話接通前的嘟——嘟——"""
    buf = np.zeros(int(3.0 * SR))
    for at in (0.0, 1.5):
        tt = t(0.9)
        place(buf, (np.sin(2 * np.pi * 425 * tt)) * np.minimum(1, tt * 50) * np.minimum(1, (0.9 - tt) * 50), at)
    return lp(buf, 3000)


def breaker():
    """很大的電閘被拉下來：金屬『喀鏘』＋一瞬間的電流嗡聲，然後全部停住"""
    clunk_t = t(0.35)
    clunk = np.sin(2 * np.pi * 110 * clunk_t) * np.exp(-clunk_t * 18) + bp(noise(0.35), 900, 3000) * np.exp(-clunk_t * 35) * 0.8
    hum_t = t(1.1)
    hum = (np.sign(np.sin(2 * np.pi * 60 * hum_t)) * 0.5 + np.sin(2 * np.pi * 120 * hum_t)) * 0.45
    hum += bp(noise(1.1), 2000, 6000) * 0.25 * (rng.random(len(hum_t)) > 0.7)
    hum *= np.minimum(1, hum_t * 30)
    return np.concatenate([clunk, hum, np.zeros(int(0.6 * SR))])


def breaker_soft():
    """減少驚嚇版：只有拉下電閘的聲音"""
    clunk_t = t(0.6)
    return lp(np.sin(2 * np.pi * 110 * clunk_t) * np.exp(-clunk_t * 12) + bp(noise(0.6), 900, 3000) * np.exp(-clunk_t * 30) * 0.5, 1500)


def rope_creak():
    """第五章開場：規律的『吱——吱——』（只有聲音）"""
    buf = np.zeros(int(6.0 * SR))
    for k in range(4):
        d = 0.9
        tt = t(d)
        f0 = 210 + 30 * np.sin(np.pi * tt / d)
        ph = 2 * np.pi * np.cumsum(f0) / SR
        saw = signal.sawtooth(ph) * (0.6 + 0.4 * (rng.random(len(tt)) > 0.5))
        x = bp(saw, 300, 2200) * np.sin(np.pi * tt / d) ** 2
        place(buf, x * 0.7, 0.4 + k * 1.45)
    return buf


def tinnitus():
    d = 5.0
    tt = t(d)
    return np.sin(2 * np.pi * 6200 * tt) * np.exp(-tt * 0.5) * 0.4 + lp(noise(d), 150) * 0.05


def hawk():
    """老鷹：遠遠的一聲尖叫"""
    d = 1.4
    tt = t(d)
    f = 2400 + 600 * np.exp(-tt * 3) - 500 * tt
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.2 * np.sin(3 * ph)
    env = np.minimum(1, tt * 20) * np.exp(-tt * 1.8)
    return bp(x * env * (1 + 0.3 * np.sin(2 * np.pi * 28 * tt)), 900, 7000)


def breath():
    """終章 A：人類的身體，喘不過氣"""
    buf = np.zeros(int(2.6 * SR))
    for k in range(3):
        tt = t(0.55)
        place(buf, bp(noise(0.55), 500, 2500) * np.sin(np.pi * tt / 0.55) ** 3 * (1 - 0.2 * k), k * 0.8)
    return buf


os.makedirs(OUT, exist_ok=True)
for name, fn in [("door_thud", door_thud), ("handle_rattle", handle_rattle), ("laugh_muffled", laugh_muffled),
                 ("water", water), ("water_stop", water_stop), ("rec_beep", rec_beep), ("hairpin", hairpin),
                 ("wings", wings), ("siren", siren), ("chalk", chalk), ("msg_pop", msg_pop), ("like_tap", like_tap),
                 ("phone_ring", phone_ring), ("breaker", breaker), ("breaker_soft", breaker_soft),
                 ("rope_creak", rope_creak), ("tinnitus", tinnitus), ("hawk", hawk), ("breath", breath)]:
    save(name, fn())
