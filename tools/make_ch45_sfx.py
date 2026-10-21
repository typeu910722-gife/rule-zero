#!/usr/bin/env python3
"""第四、五章的合成音效 → game/audio/ch4/（Sfx.stream() 找不到 FILES 時會找 res://audio/ch4/<名字>.ogg）。
全部自己合成（笑聲用遊戲裡既有的角色小聲音再加工），可商用。

第四章「那一天」只用**門外聽得到的聲音**（docs/script/chapter4.md 6.2）：門被撞的悶響、門把轉不動、隔著門的笑聲、
水聲、手機錄影提示音、髮夾掉在磁磚上、白鴿振翅、遠處的警笛。**不做任何身體、衣物、性相關的聲音**，也不新增清單以外的聲音。
其他：粉筆、訊息、按讚、電話、電閘、繩子（第五章開場，只有規律的吱聲）、耳鳴、老鷹、喘氣（第五章終章 A 的小遊戲）。

2026-10-21 混音 QA 重做（docs/audio_mix_qa.md）：舊版多半是「純正弦」或「帶通白噪音」，用峰值正規化，
所以警笛、電話、耳鳴非常大聲，門把、髮夾又太小、太像電子音。新版：
- 物件用模態合成（門板、門把、髮夾、電閘各自的共振頻率），摩擦／羽毛／粉筆用顆粒，水用很多個小氣泡；
- 每個聲音都放進合成的房間（磁磚廁所、走廊、教室、很大的空間、戶外）；隔著門的再經過「門板」濾波；
- 用 BS.1770 響度正規化到下面的目標（檔案響度；實際播放再加上程式／劇本給的 volume_db，預設 -3 dB）。

| 檔名 | 用在哪（播放音量） | 檔案目標 |
|---|---|---|
| door_thud | 劇本 @sfx（-3）、hold_door（-2）、guard（-10）、鞋子那段（-18） | 瞬時 -15 |
| handle_rattle | 劇本（-3）：從走廊盡頭聽到門把被轉 | 瞬時 -15 |
| laugh_muffled | 劇本（-3）：隔著門、走廊盡頭 | 瞬時 -21 |
| water／water_stop | 劇本（-3）：水龍頭開著／慢慢停下來 | 整合 -24／瞬時 -21 |
| rec_beep | 第四章取景框（-6） | 瞬時 -15 |
| hairpin | 劇本（-3）：很小的一聲 | 瞬時 -19 |
| wings | 劇本（-3）、hold_door（0） | 瞬時 -16 |
| siren | 劇本（-3）：很遠 | 整合 -24 |
| chalk | 劇本（-3） | 瞬時 -16 |
| msg_pop | 群組聊天（-6） | 瞬時 -15 |
| like_tap | 群組聊天（-4）、密碼鎖（-10） | 瞬時 -16 |
| phone_ring | 劇本（-3）：聽筒裡的回鈴音 | 整合 -20 |
| breaker／breaker_soft | 第四章結尾（-2） | 瞬時 -11／-18 |
| rope_creak | 第五章開場（-3） | 整合 -22 |
| tinnitus | 第五章開場（-3） | 整合 -26 |
| hawk | 第五章（-3）：遠遠的 | 瞬時 -18 |
| breath | 第五章呼吸小遊戲（-4） | 瞬時 -18 |

用法：python3 tools/make_ch45_sfx.py [名字…]（在專案根目錄；不給名字＝全部）
"""
import os, sys, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfx_synth import Synth, SR, lp, hp, bp, peq, door, place, mix, shape, finish, save  # noqa: E402

OUT = "game/audio/ch4"
VOICE = "game/audio/voice"
S = Synth(45)


def load_mono(path):
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), f.name], check=True)
        sr, x = wavfile.read(f.name)
    return x.astype(np.float64) / 32768.0


def mono(y):
    return y.mean(axis=1) if y.ndim == 2 else y


def resonators(x, freqs, q=8.0, gains=None):
    """一組窄的共振（木頭、繩子纖維、金屬板）"""
    out = np.zeros_like(x)
    for k, f in enumerate(freqs):
        b, a = signal.iirpeak(f / (SR / 2), q)
        out += signal.lfilter(b, a, x) * (gains[k] if gains else 1.0)
    return out


# ── 門外聽得到的聲音（「那一天」） ──
def door_thud():
    """木門被撞了一下／被用力關上：門板的低頻共振、撞到的那一下、門框和門鎖的小小震動。在走廊上聽到"""
    d = 0.9
    x = np.zeros(S.n(d))
    panel = [(68, 0.08, 0.5), (104, 0.07, 0.6), (161, 0.05, 0.9), (236, 0.04, 1.0), (342, 0.03, 0.8),
             (515, 0.02, 0.55), (780, 0.012, 0.3), (1150, 0.008, 0.15)]
    place(x, S.modal(d, panel, jitter=0.04, strike=0.004), 0)
    place(x, S.burst(0.06, 0.006, hi=1800) * 0.5, 0)                          # 撞到的那一下
    place(x, S.modal(0.1, [(285, 0.03, 1), (610, 0.02, 0.5)], strike=0.002) * 0.25, S.jit(0.004, 0.3))  # 門框
    for at in (S.jit(0.018, 0.2), S.jit(0.045, 0.2)):                         # 門鎖在鎖孔裡晃了一下
        place(x, S.modal(0.03, [(S.jit(1900, .05), 0.008, 1), (S.jit(3100, .05), 0.006, 0.6)]) * 0.06, at)
    x = lp(x, 3000)
    y = S.room(x, "corridor", wet_db=-9.0)
    return finish(y, -15.0, fade_out=0.08)


def handle_rattle():
    """門把被轉、被往下壓，可是門外卡了一根拖把，轉不動：喀、喀……喀喀。從走廊另一頭聽到"""
    d = 1.9
    x = np.zeros(S.n(d))
    at = 0.02
    for k in range(6):
        g = S.jit(0.85 if k % 2 == 0 else 0.6, 0.15)
        # 門把的彈簧（很短的摩擦）
        place(x, S.grains(0.04, 2500, 0.0004, 1500, 5000) * np.hanning(S.n(0.04)) * 0.12 * g, at)
        # 卡住：金屬撞到拖把柄（金屬＋一點木頭）、門在門框裡動了一下
        hit = at + S.jit(0.035, 0.2)
        place(x, S.modal(0.06, [(S.jit(1300, .04), 0.02, 1), (S.jit(2200, .04), 0.015, 0.8), (S.jit(3500, .04), 0.01, 0.5),
                                (S.jit(5200, .04), 0.008, 0.3)]) * 0.5 * g, hit)
        place(x, S.modal(0.08, [(220, 0.03, 1), (410, 0.02, 0.6)], strike=0.002) * 0.35 * g, hit + 0.001)
        place(x, S.modal(0.2, [(90, 0.05, 1), (150, 0.04, 0.6)], strike=0.004) * 0.2 * g, hit + 0.003)
        # 有時候馬上又轉一次（喀喀），有時候停一下
        at += S.jit(0.11, 0.2) if k in (1, 4) else S.jit(0.28, 0.25)
    y = S.room(S.far(x, 0.35), "corridor", wet_db=-6.0)
    return finish(y, -15.0, fade_out=0.15)


def laugh_muffled():
    """隔著廁所的門、從走廊盡頭聽到很多人在笑：遊戲裡的笑聲疊好幾層（音高、速度、時間都錯開＝不同的人），
    先放進磁磚廁所，再隔著門板（只剩低中頻），再經過走廊"""
    d = 3.6
    inner = np.zeros(S.n(d))
    files = [f for f in sorted(os.listdir(VOICE)) if f.startswith(("laugh_", "giggle_", "chuckle_")) and f.endswith(".ogg")]
    order = S.rng.permutation(len(files))
    at = 0.1
    for k in range(9):
        v = load_mono(os.path.join(VOICE, files[order[k % len(files)]]))
        rate = S.rng.uniform(0.74, 0.95)                      # 比布偶低：國中男生
        v = signal.resample(v, int(len(v) / rate))
        place(inner, v * S.rng.uniform(0.45, 1.0), at)
        at += S.rng.uniform(0.12, 0.42)
        if at > d - 0.8:
            at = S.rng.uniform(0.2, 1.0)
    inner *= np.clip(np.linspace(0, d, len(inner)) / 0.08, 0, 1)
    room = mono(S.room(inner, "tile", wet_db=-4.0))
    through = door(room, 800)
    y = S.room(S.far(through, 0.3), "corridor", wet_db=-8.0)
    return finish(y, -21.0, fade_in=0.05, fade_out=0.4)


def _faucet(d, flow):
    """水龍頭流進洗手台：flow＝每個時間點的水量（0～1）"""
    N = S.n(d)
    fl = np.interp(np.arange(N), np.linspace(0, N - 1, len(flow)), flow)
    # 水柱打在水面：很多小氣泡，加上濺開的寬頻噪音（量會不規則地起伏）
    bub = S.bubbles(d, 1100, 350, 4200) * fl
    splash = bp(S.pink(d), 250, 7000) * S.slow_rand(d, 9, 0.25) * fl * 0.06
    x = peq(bub * 0.05 + splash, 420, 4.0, 1.5)           # 洗手台的共振
    return x


def water():
    """水龍頭一直開著（磁磚廁所裡）"""
    d = 5.0
    x = _faucet(d, np.ones(50))
    y = S.room(x, "tile", wet_db=-7.0)
    return finish(y, -24.0, mode="int", fade_in=0.4, fade_out=0.8)


def water_stop():
    """水聲慢慢停下來（第 9 個視角：黑畫面）：水柱越來越細、斷斷續續，最後剩幾滴"""
    d = 6.0
    k = np.linspace(0, 1, 120)
    flow = np.clip(1 - k / 0.6, 0, 1) ** 1.6
    flow *= 1 + 0.5 * (S.rng.random(120) - 0.5) * (k > 0.3)   # 快停的時候斷斷續續
    x = _faucet(d, np.clip(flow, 0, 1))
    # 最後的幾滴：一滴一個比較大的氣泡（「咚」），間隔越來越長
    at = 3.5
    gap = 0.35
    for _ in range(6):
        if at > d - 0.3:
            break
        tt = S.t(0.08)
        f0 = S.rng.uniform(900, 1700)
        drop = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 4 * tt)) / SR) * np.exp(-tt / 0.012)
        place(x, drop * 0.05 * S.jit(1, 0.3), at)
        at += gap
        gap *= S.jit(1.45, 0.15)
    y = S.room(x, "tile", wet_db=-6.0)
    return finish(y, -21.0, fade_in=0.05, fade_out=0.3)


def rec_beep():
    """手機開始錄影的提示音（手機喇叭：小、中高頻，有一點房間）"""
    d = 0.5
    x = np.zeros(S.n(d))
    for at, f, L in ((0.0, 1318.5, 0.075), (0.11, 1760.0, 0.11)):
        tt = S.t(L)
        tone = np.sin(2 * np.pi * f * tt) + 0.18 * np.sin(4 * np.pi * f * tt) + 0.05 * np.sin(6 * np.pi * f * tt)
        env = np.clip(tt / 0.004, 0, 1) * np.clip((L - tt) / 0.02, 0, 1) ** 1.5
        place(x, tone * env * 0.5, at)
    x = peq(hp(lp(x, 7000), 500), 2400, 3.0, 1.0)        # 手機的小喇叭
    y = S.room(x, "corridor", wet_db=-20.0)
    return finish(y, -15.0, fade_out=0.06)


def hairpin():
    """很小的金屬髮夾掉在磁磚上：彈了幾下（間隔越來越短、越來越小），最後滑一下停住。空蕩蕩的磁磚廁所"""
    d = 1.4
    x = np.zeros(S.n(d))
    clip = lambda: [(S.jit(3300, .04), 0.06, 1), (S.jit(4950, .04), 0.05, 0.7), (S.jit(7400, .04), 0.04, 0.5),
                    (S.jit(9800, .04), 0.03, 0.3), (S.jit(12600, .04), 0.02, 0.15)]
    at, gap, v = 0.02, 0.16, 1.0
    for k in range(6):
        place(x, mix(S.modal(0.2, clip(), strike=0.00005) * v, S.burst(0.01, 0.0004, 2000, 14000) * 0.5 * v), at)
        at += gap
        gap *= S.jit(0.55, 0.1)                           # 恢復係數 ~0.55
        v *= S.jit(0.55, 0.1)
    place(x, S.grains(0.05, 1500, 0.0004, 3000, 12000) * np.hanning(S.n(0.05)) * 0.05, at)   # 滑一下
    y = S.room(x, "tile", wet_db=-7.0)
    return finish(y, -19.0, fade_out=0.2)


def wings():
    """白鴿起飛：第一下翅膀互拍（「啪」），然後一下一下拍翅（空氣「噗」＋羽毛沙沙），飛遠"""
    d = 1.7
    x = np.zeros(S.n(d))
    place(x, S.burst(0.03, 0.003, 500, 5000) * 0.9, 0.0)    # 翅膀在背上互拍
    at = S.jit(0.05, 0.1)
    for k in range(10):
        L = S.jit(0.1, 0.1)
        tt = S.t(L)
        env = np.clip(tt / 0.018, 0, 1) * np.exp(-np.clip(tt - 0.018, 0, None) / 0.035)
        dist = min(1.0, k / 9)
        flap = bp(S.noise(L), 140, 1800) * env * 0.9
        flap += S.grains(L, 2500, 0.0005, 2000, 7000) * env * 0.25          # 羽毛
        g = (0.7 + 0.3 * min(1, k / 2)) * (1 - 0.75 * dist)
        place(x, S.far(flap, dist * 0.6) * g, at)
        at += S.jit(0.115, 0.08) * (1 + 0.04 * k)
    y = S.room(x, "corridor", wet_db=-11.0)
    return finish(y, -16.0, fade_out=0.2)


def siren(d=6.0):
    """很遠的警笛：喇叭的聲音（有泛音），高音被距離吃掉，被建築物反射好幾次，風讓它忽大忽小"""
    tt = S.t(d)
    f = 650 + 700 * (0.5 - 0.5 * np.cos(2 * np.pi * tt / 2.9))       # 慢慢上去、下來
    f *= S.slow_rand(d, 0.4, 0.004)                                     # 車在動：一點點都卜勒
    ph = 2 * np.pi * np.cumsum(f) / SR
    horn = np.tanh(2.5 * np.sin(ph)) + 0.25 * np.sin(2 * ph)
    x = np.zeros(len(tt))
    for delay, g, cut in ((0.0, 1.0, 2400), (S.jit(0.06, .2), 0.55, 1800), (S.jit(0.14, .2), 0.4, 1400), (S.jit(0.27, .2), 0.25, 1100)):
        place(x, lp(horn, cut, 2) * g, delay)
    x = hp(x, 300) * S.slow_rand(d, 1.3, 0.35)
    x += lp(S.pink(d), 260) * 0.02                                      # 城市的低頻背景
    y = S.room(x, "outdoor", wet_db=-4.0)
    y *= np.clip(np.arange(len(y)) / SR / 1.8, 0, 1)[:, None]
    return finish(y, -24.0, mode="int", fade_out=1.8)


# ── 其他 ──
def chalk():
    """粉筆寫黑板：每一筆開頭「叩」一下，然後粉筆的顆粒摩擦（筆畫的速度決定沙沙的密度），最後點一下"""
    d = 1.3
    x = np.zeros(S.n(d))
    board = lambda: [(S.jit(480, .05), 0.015, 1), (S.jit(950, .05), 0.01, 0.6), (S.jit(1800, .05), 0.006, 0.3)]
    at = 0.02
    for k in range(4):
        L = S.rng.uniform(0.08, 0.22)
        place(x, mix(S.modal(0.05, board(), strike=0.0008) * 0.5, S.burst(0.006, 0.0005, 1500, 9000) * 0.4), at)
        n = S.n(L)
        speed = np.sin(np.linspace(0.15, np.pi - 0.15, n)) ** 0.8 * S.slow_rand(L, 30, 0.3)
        place(x, S.grains(L, 2500 + 3000 * speed, 0.0004, 1200, 7500) * speed * 0.35, at + 0.004)
        at += L + S.rng.uniform(0.05, 0.12)
    place(x, mix(S.modal(0.05, board(), strike=0.0008) * 0.6, S.burst(0.006, 0.0005, 1500, 9000) * 0.5), at)  # 句點
    x = peq(x, 900, 3.0, 1.2)
    y = S.room(x, "classroom", wet_db=-12.0)
    return finish(y, -16.0, fade_out=0.15)


def msg_pop():
    """通訊軟體的新訊息「啵」（手機喇叭）"""
    d = 0.25
    x = np.zeros(S.n(d))
    tt = S.t(0.09)
    f = 700 + 650 * (1 - np.exp(-tt / 0.012))
    ph = 2 * np.pi * np.cumsum(f) / SR
    place(x, (np.sin(ph) + 0.12 * np.sin(2 * ph)) * np.clip(tt / 0.002, 0, 1) * np.exp(-tt / 0.03), 0)
    x = peq(hp(lp(x, 8000), 450), 2200, 2.0, 1.0)
    y = S.room(x, "small", wet_db=-20.0)
    return finish(y, -15.0, fade_out=0.04)


def like_tap():
    """手指點一下手機螢幕：指腹碰到玻璃的悶「嗒」＋很小的介面「滴」"""
    d = 0.2
    x = np.zeros(S.n(d))
    place(x, S.modal(0.05, [(170, 0.012, 1), (330, 0.008, 0.6), (900, 0.004, 0.3)], strike=0.003) * 0.8, 0)
    place(x, S.burst(0.008, 0.0005, 2000, 8000) * 0.12, 0)
    tt = S.t(0.04)
    place(x, np.sin(2 * np.pi * 1850 * tt) * np.clip(tt / 0.002, 0, 1) * np.exp(-tt / 0.01) * 0.25, 0.012)
    y = S.room(x, "small", wet_db=-22.0)
    return finish(y, -16.0, fade_out=0.03)


def phone_ring():
    """電話接通前的回鈴音「嘟——（停兩秒）嘟——」，從聽筒裡聽到：電話的頻寬（300～3400 Hz）、一點點線路雜音"""
    d = 4.8
    x = np.zeros(S.n(d))
    for at in (0.3, 3.3):
        tt = S.t(1.0)
        tone = np.sin(2 * np.pi * 440 * tt) + np.sin(2 * np.pi * 480 * tt + 1.0)
        env = np.clip(tt / 0.01, 0, 1) * np.clip((1.0 - tt) / 0.01, 0, 1)
        place(x, tone * env * 0.35, at)
    x = np.tanh(x * 1.6) / 1.6                              # 編碼器的一點點失真
    x += bp(S.pink(d), 300, 3400) * 0.004                    # 線路雜音
    x = bp(x, 300, 3400, 4)
    x = peq(x, 1000, 2.0, 0.7)                               # 聽筒
    y = S.room(x, "small", wet_db=-24.0)
    return finish(y, -20.0, mode="int", fade_in=0.05, fade_out=0.3)


def _breaker_clunk(heavy=1.0):
    """大型閘刀開關被拉下：握把在鉸鏈上摩擦 → 很重的金屬「喀鏘」"""
    d = 0.9
    x = np.zeros(S.n(d))
    place(x, S.grains(0.16, 1800, 0.0008, 600, 3000) * np.linspace(0.3, 1, S.n(0.16)) * 0.08, 0)
    metal = [(95, 0.12, 0.8), (182, 0.1, 1.0), (410, 0.07, 0.8), (760, 0.05, 0.6), (1230, 0.04, 0.45),
             (2100, 0.03, 0.3), (3400, 0.02, 0.18), (5200, 0.012, 0.08)]
    place(x, mix(S.modal(0.7, metal, jitter=0.03, strike=0.0008) * heavy, S.burst(0.04, 0.0015, 300, 9000) * 0.6 * heavy), 0.17)
    place(x, S.modal(0.3, [(S.jit(1500, .05), 0.03, 1), (S.jit(2600, .05), 0.02, 0.6)]) * 0.15, S.jit(0.215, 0.05))  # 回彈
    return x


def breaker():
    """很大的電閘被拉下來：金屬『喀鏘』＋接點的電弧劈啪＋一瞬間很重的電流嗡聲，然後全部停住。很大的房間"""
    x = _breaker_clunk()
    d = 2.4
    buf = np.zeros(S.n(d))
    place(buf, x, 0)
    # 電弧：接點碰到的瞬間，零散的劈啪
    arc = np.zeros(S.n(0.25))
    for at in np.sort(S.rng.uniform(0, 0.22, 60)):
        place(arc, S.burst(0.006, S.rng.uniform(0.0002, 0.0008), 1500, 12000) * S.rng.uniform(0.1, 1.0), at)
    place(buf, arc * np.exp(-np.arange(len(arc)) / SR / 0.1) * 0.35, 0.175)
    # 電流的嗡聲：60 Hz 的電 → 120 Hz 為主、很多倍頻，加上被 120 Hz 調變的嘶嘶聲；1.1 秒後一下子斷掉
    L = 1.1
    th = S.t(L)
    hum = sum(a * np.sin(2 * np.pi * f * th + S.rng.uniform(0, 6.3))
              for f, a in [(60, 0.5), (120, 1.0), (180, 0.6), (240, 0.55), (360, 0.35), (480, 0.25), (600, 0.18), (840, 0.1), (1080, 0.06)])
    buzz = bp(S.noise(L), 1500, 6000) * (0.5 + 0.5 * np.sin(2 * np.pi * 120 * th)) ** 4 * 0.5
    env = np.clip(th / 0.015, 0, 1) * S.slow_rand(L, 12, 0.12) * np.clip((L - th) / 0.008, 0, 1)
    place(buf, lp(hum * 0.3 + buzz * 0.25, 5000) * env, 0.19)
    y = S.room(buf, "hall", wet_db=-7.0)
    return finish(y, -11.0, ceiling=-1.0, fade_out=0.3)


def breaker_soft():
    """減少驚嚇版：只有拉下電閘的聲音，比較悶、比較遠"""
    x = lp(_breaker_clunk(0.8), 2500)
    y = S.room(x, "hall", wet_db=-6.0)
    return finish(y, -18.0, fade_out=0.3)


def rope_creak():
    """第五章開場（只有聲音）：規律的『吱——吱——』。繩子在木頭橫樑上的摩擦：
    黏住→滑開→黏住的一串小脈衝（擺動的速度決定脈衝多密），激發木頭和纖維的共振。每一下都不太一樣"""
    d = 7.0
    buf = np.zeros(S.n(d))
    at = 0.4
    for k in range(4):
        L = S.jit(0.85, 0.12)
        n = S.n(L)
        speed = np.sin(np.linspace(0, np.pi, n)) ** 1.3
        rate = 40 + 230 * speed * S.jit(1, 0.15)
        pulses = np.zeros(n)
        i = 0.0
        while i < n:
            ii = int(i)
            pulses[ii] = S.rng.uniform(0.5, 1.0) * speed[ii]
            i += SR / rate[ii] * S.rng.uniform(0.8, 1.2)       # 不規則的黏滑
        res = resonators(pulses, [S.jit(f, .04) for f in (410, 870, 1640, 2850)], q=9, gains=[1.0, 0.8, 0.5, 0.25])
        res += lp(pulses, 300) * 0.5                          # 橫樑本身的低頻
        place(buf, res * S.jit(1, 0.15), at)
        at += S.jit(1.5, 0.05)
    buf += lp(S.pink(d), 200) * 0.0015                        # 房間的底噪
    y = S.room(buf, "lab", wet_db=-10.0)
    return finish(y, -22.0, mode="int", fade_in=0.1, fade_out=0.5)


def tinnitus():
    """耳鳴：槍聲之後，一條很細的高音慢慢消失；周圍的聲音像被棉花塞住（很低的悶聲）"""
    d = 5.0
    tt = S.t(d)
    f = 6100 * S.slow_rand(d, 0.8, 0.002)
    ring = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 2.2) * S.slow_rand(d, 2, 0.08)
    ring *= np.clip(tt / 0.08, 0, 1)
    world = lp(S.brown(d), 180) * 0.25 * np.clip(tt / 1.5, 0, 1)
    y = S.room(ring * 0.3 + world, "small", wet_db=-20.0)
    return finish(y, -26.0, mode="int", fade_in=0.02, fade_out=0.8)


def hawk():
    """老鷹：遠遠的一聲「咿——兒」：音高先上去一點再往下滑，聲音是沙啞的（頻率抖動＋粗糙的振幅調變），在空曠的地方"""
    d = 1.6
    tt = S.t(d)
    f = 2900 + 350 * np.exp(-((tt - 0.08) / 0.07) ** 2) - 1000 * np.clip((tt - 0.12) / 1.1, 0, 1) ** 1.2
    f *= 1 + 0.012 * lp(S.noise(d), 60, 1) * 20                 # 沙啞：頻率不穩
    ph = 2 * np.pi * np.cumsum(f) / SR
    rough = 1 + 0.35 * np.sin(2 * np.pi * S.jit(110, 0.1) * tt)
    voice = (np.sin(ph) + 0.35 * np.sin(2 * ph + 0.5) + 0.12 * np.sin(3 * ph)) * rough
    breathy = bp(S.noise(d), 1800, 4200) * 0.25
    env = np.clip(tt / 0.04, 0, 1) * np.clip((1.25 - tt) / 0.35, 0, 1) ** 1.5
    x = (voice + breathy) * env
    y = S.room(S.far(x, 0.55), "outdoor", wet_db=-5.0)
    return finish(y, -18.0, fade_out=0.25)


def breath():
    """終章 A：回到人類的身體，喘不過氣——急促、不規則的吸氣（比較大、比較尖）和吐氣（比較小、比較低）"""
    d = 2.8
    buf = np.zeros(S.n(d))
    at = 0.02
    for k in range(3):
        Li = S.jit(0.38, 0.15)
        ti = S.t(Li)
        inh = S.noise(Li) * np.clip(ti / (Li * 0.7), 0, 1) ** 1.5 * np.clip((Li - ti) / 0.05, 0, 1)
        inh = peq(peq(peq(bp(inh, 350, 6000), 650, 6, 2), 1250, 5, 2.5), 2700, 4, 3)    # 喉嚨、口腔的共鳴
        place(buf, inh * 0.5 * S.jit(1, 0.15) * (1 - 0.12 * k), at)
        at += Li + S.jit(0.06, 0.3)
        Le = S.jit(0.45, 0.15)
        te = S.t(Le)
        exh = S.noise(Le) * np.clip(te / 0.04, 0, 1) * np.exp(-te / (Le * 0.45))
        exh = peq(peq(lp(bp(exh, 200, 4000), 2200), 500, 5, 2), 1100, 4, 2.5)
        place(buf, exh * 0.32 * S.jit(1, 0.15), at)
        at += Le + S.jit(0.12, 0.3)
    y = S.room(buf, "small", wet_db=-16.0)
    return finish(y, -18.0, fade_out=0.1)


ALL = [("door_thud", door_thud), ("handle_rattle", handle_rattle), ("laugh_muffled", laugh_muffled),
       ("water", water), ("water_stop", water_stop), ("rec_beep", rec_beep), ("hairpin", hairpin),
       ("wings", wings), ("siren", siren), ("chalk", chalk), ("msg_pop", msg_pop), ("like_tap", like_tap),
       ("phone_ring", phone_ring), ("breaker", breaker), ("breaker_soft", breaker_soft),
       ("rope_creak", rope_creak), ("tinnitus", tinnitus), ("hawk", hawk), ("breath", breath)]

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    want = set(sys.argv[1:])
    for name, fn in ALL:
        if not want or name in want:
            save(f"{OUT}/{name}.ogg", fn())
