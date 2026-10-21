#!/usr/bin/env python3
"""第三章的合成音效 → game/audio/ch3/（檔名固定，程式直接用路徑讀）。全部自己合成，可商用。

2026-10-21 混音 QA 重做（docs/audio_mix_qa.md）：舊版是「一個正弦＋一段白噪音」，而且用峰值正規化，
所以槍聲比上膛小、減少驚嚇版反而比原版大。新版每個聲音都是多層（衝擊／物件共振／機構／空氣），
放進合成的房間殘響，最後用響度正規化（目標＝程式裡的播放音量加上去以後落在該有的位置）。

| 檔名 | 用途（播放音量） | 檔案目標（最大瞬時響度） |
|---|---|---|
| gunshot | 第三章結尾的槍聲（0 dB） | -11 |
| gunshot_soft | 減少驚嚇版：隔著牆、很遠的悶響（0 dB） | -22 |
| gun_cock | 上膛：滑套往後拉、彈回去（-2 dB） | -15 |
| light_on | 實驗室的燈一盞一盞亮起：大開關＋日光燈啟動（-6 dB，連播 4 次） | -14 |
| card | 撲克牌拍在桌上（-8／-6 dB） | -13 |
| needle | 針穿過布、線被拉過去（-6 dB） | -16 |

用法：python3 tools/make_ch3_sfx.py（在專案根目錄；需要 numpy、scipy、ffmpeg）
"""
import os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfx_synth import Synth, SR, lp, hp, bp, peq, place, mix, shape, finish, save  # noqa: E402

OUT = "game/audio/ch3"
S = Synth(311)


def gunshot_dry():
    """手槍，室內。乾聲（還沒進房間）"""
    d = 1.6
    x = np.zeros(S.n(d))
    # 1. 槍口爆風：1～2 ms 的 N 形壓力波（真正的槍聲最前面就是這個「啪」）
    k = S.n(0.0026)
    tt = np.arange(k) / SR
    nwave = np.interp(tt, [0, 0.00008, 0.0011, 0.0019, 0.0026], [0, 1.0, -0.55, -0.1, 0])
    place(x, lp(nwave, 12000), 0)
    # 2. 火藥氣體：很寬的噪音，很快衰減（兩段：極短＋稍長）
    place(x, mix(S.burst(0.12, 0.004, hi=11000) * 0.9, S.burst(0.4, 0.03, hi=4500) * 0.35,
                 S.burst(0.3, 0.018, 300, 2500) * 0.9), 0)
    # 3. 低頻的「碰」：胸口感覺到的那一下，音高往下掉
    tb = S.t(0.35)
    f = 48 + 90 * np.exp(-tb / 0.018)
    place(x, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tb / 0.07) * 0.3, 0.0005)
    # 4. 機構：滑套往後、往前（金屬小共振）
    metal = [(2350, 0.012, 1), (3720, 0.01, 0.7), (5610, 0.008, 0.5), (8100, 0.005, 0.3)]
    place(x, S.modal(0.06, metal) * 0.18, 0.006)
    place(x, S.modal(0.06, metal) * 0.12, S.jit(0.034, 0.1))
    # 5. 彈殼掉到地上：叮、叮…（很小聲，越跳越近）
    brass = [(5200, 0.05, 1), (7900, 0.04, 0.6), (11300, 0.03, 0.4), (3100, 0.03, 0.3)]
    at, gap, a = S.jit(0.62, 0.05), 0.16, 0.035
    for _ in range(5):
        place(x, S.modal(0.15, brass, jitter=0.03) * a, at)
        at += gap
        gap *= S.jit(0.6, 0.1)
        a *= 0.6
    # 麥克風被打爆的那一點點飽和
    return np.tanh(x * 2.2) / 2.2


def gunshot():
    x = gunshot_dry()
    # 很大的水泥實驗室：殘響很明顯
    y = S.room(x, "lab", wet_db=-3.0)
    # 房間的低頻轟鳴（空間被撐開的感覺）
    rum = lp(S.brown(2.6), 160, 2) * np.exp(-S.t(2.6) / 0.55)
    y[:len(rum)] += np.stack([rum, rum * 0.9], axis=1) * 0.1
    return finish(y, -11.0, ceiling=-1.0, fade_out=0.15)


def gunshot_soft():
    """減少驚嚇版：隔著好幾道牆、很遠的地方「碰」一聲。沒有尖銳的部分"""
    x = gunshot_dry()
    x = lp(x, 900, 2)
    x = np.convolve(x, np.hanning(S.n(0.0015)) / np.sum(np.hanning(S.n(0.0015))))  # 起音變鈍
    y = S.room(x, "hall", wet_db=-1.0)
    return finish(y, -22.0, fade_in=0.004, fade_out=0.2)


def gun_cock():
    """手槍上膛：滑套被往後拉（摩擦）→ 卡到底（喀）→ 放開彈回去（比較大的喀嚓）"""
    d = 0.6
    x = np.zeros(S.n(d))
    steel = lambda: [(S.jit(1850, .03), 0.015, 1), (S.jit(3100, .03), 0.012, 0.8), (S.jit(4700, .03), 0.01, 0.6),
                     (S.jit(6900, .03), 0.006, 0.4), (S.jit(9600, .03), 0.004, 0.2)]
    body = [(420, 0.02, 1), (780, 0.015, 0.6)]
    # 往後拉：開始的一下小喀，然後金屬滑過金屬的摩擦
    place(x, mix(S.modal(0.05, steel()) * 0.35, S.burst(0.01, 0.0008, 2000, 12000) * 0.3), 0.0)
    pull = S.grains(0.075, 4200, 0.00035, 2200, 9000) * np.hanning(S.n(0.075)) ** 0.7
    place(x, pull * 0.25, 0.004)
    # 卡到底
    place(x, mix(S.modal(0.08, steel()) * 0.7, S.modal(0.06, body, strike=0.0006) * 0.4, S.burst(0.01, 0.0005, 1500, 12000) * 0.4),
          S.jit(0.082, 0.05))
    # 放開：很快的摩擦＋彈回去撞到底（最大的一下）
    at = S.jit(0.19, 0.05)
    place(x, S.grains(0.022, 6000, 0.0003, 2500, 10000) * 0.3, at - 0.022)
    slam = [(S.jit(1600, .03), 0.025, 1), (S.jit(2700, .03), 0.02, 0.8), (S.jit(4100, .03), 0.015, 0.7),
            (S.jit(5900, .03), 0.012, 0.5), (S.jit(8300, .03), 0.008, 0.3)]
    place(x, mix(S.modal(0.15, slam), S.modal(0.08, [(300, 0.03, 1), (610, 0.02, 0.5)], strike=0.0005) * 0.6,
              S.burst(0.015, 0.0006, 1200, 14000) * 0.6), at)
    y = S.room(x, "lab", wet_db=-15.0)
    return finish(y, -15.0, fade_out=0.08)


def light_on():
    """很大的燈開關「喀」，天花板的接觸器「咚」，日光燈的啟動器「滴滴」，然後鎮流器的嗡聲（60 Hz 電→120 Hz）"""
    d = 2.0
    x = np.zeros(S.n(d))
    # 開關的槓桿先走一點（小的一下），然後喀
    place(x, S.burst(0.008, 0.0006, 1500, 9000) * 0.25, 0)
    plastic = [(S.jit(1250, .05), 0.008, 1), (S.jit(2600, .05), 0.006, 0.7), (S.jit(4300, .05), 0.005, 0.4)]
    place(x, mix(S.modal(0.05, plastic) * 0.8, S.burst(0.02, 0.0012, 900, 9000) * 0.7), S.jit(0.018, 0.1))
    # 天花板裡的接觸器（遠一點、悶一點）
    place(x, lp(S.modal(0.2, [(110, 0.05, 1), (240, 0.03, 0.6), (520, 0.02, 0.4)], strike=0.002), 1500) * 0.5, S.jit(0.06, 0.1))
    # 啟動器：滴、滴
    for at in (S.jit(0.14, 0.1), S.jit(0.26, 0.1)):
        place(x, S.burst(0.006, 0.0005, 2500, 7000) * 0.08, at)
    # 鎮流器的嗡聲：120 Hz 和它的倍頻，慢慢起來、很快又淡掉（連播 4 次時會接成一片低低的嗡）
    th = S.t(1.6)
    hum = sum(a * np.sin(2 * np.pi * f * S.jit(1, 0.002) * th + S.rng.uniform(0, 6.3))
              for f, a in [(120, 1), (240, 0.5), (360, 0.35), (480, 0.2), (600, 0.12), (840, 0.06)])
    hum *= np.clip((th - 0.0) / 0.25, 0, 1) * np.exp(-th / 0.55) * S.slow_rand(1.6, 6, 0.15)
    place(x, lp(hum, 2000) * 0.05, 0.28)
    y = S.room(x, "lab", wet_db=-9.0)
    return finish(y, -14.0, fade_out=0.2)


def card():
    """撲克牌拍在桌上：牌劃過空氣「咻」→ 拍下去「啪」→ 桌面的木頭「咚」一點點"""
    d = 0.35
    x = np.zeros(S.n(d))
    swish = S.noise(0.045) * np.linspace(0, 1, S.n(0.045)) ** 2
    place(x, bp(swish, 700, 5000) * 0.12, 0)
    at = 0.045
    place(x, S.burst(0.03, 0.0016, hi=9000) * 1.0, at)               # 啪
    place(x, S.modal(0.02, [(950, 0.004, 1), (1800, 0.003, 0.6)]) * 0.25, at)   # 紙本身
    place(x, S.modal(0.12, [(185, 0.03, 1), (330, 0.02, 0.6), (610, 0.012, 0.4)], strike=0.0015) * 0.45, at + 0.0005)  # 桌子
    y = S.room(x, "small", wet_db=-16.0)
    return finish(y, -13.0, fade_out=0.04)


def needle():
    """針穿過布「噗」一下很小的，接著線被拉過布的沙沙聲（越拉越快，然後停）"""
    d = 0.42
    x = np.zeros(S.n(d))
    place(x, mix(S.burst(0.01, 0.0006, 2500, 11000) * 0.5, S.modal(0.03, [(720, 0.008, 1)], strike=0.0008) * 0.15), 0)
    n = S.n(0.3)
    speed = np.sin(np.linspace(0, np.pi, n)) ** 1.5
    pull = S.grains(0.3, 300 + 1500 * speed, 0.0012, 1400, 7000) * speed
    place(x, pull * 0.18 + lp(S.noise(0.3), 3500) * speed * 0.015, 0.035)
    y = S.room(x, "small", wet_db=-18.0)
    return finish(y, -16.0, fade_out=0.04)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("gunshot", gunshot), ("gunshot_soft", gunshot_soft), ("gun_cock", gun_cock),
                     ("light_on", light_on), ("card", card), ("needle", needle)]:
        save(f"{OUT}/{name}.ogg", fn())
