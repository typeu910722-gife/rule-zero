#!/usr/bin/env python3
"""全作的主旋律動機「棉花糖鎮的音樂盒」與它的變形（docs/script/future_chapters.md 第 5 節）。

旋律（3/4 拍）：Mi La Sol Mi ｜ Fa Mi Re ｜ Si——最後停在 Si，不回到 Do：永遠沒有唱完。
（就像車掌從來沒把站名說完。真結局之後才會聽到唱完的版本 motif_resolved。）

輸出 game/audio/motif/：
  musicbox      棉花糖鎮：乾淨的音樂盒
  bleach        漂白鎮：同一段，少了兩個音（被漂白），每個音都微微走音、悶住
  whistle       和平鴿的口哨：最後一個音往上滑
  ecg           醫院：心電圖的「嗶」彈出同一段旋律
  resolved      唱完的版本（回到 Do）
  start_<w> / clear_<w> / fail_<w>   小遊戲的開始、成功、失敗（w＝musicbox／bleach／ecg）
  sting_<w>     章節標題卡
用法：python3 tools/make_motif_audio.py
"""
import os, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
OUT = "game/audio/motif"
BEAT = 0.42                       # 一拍的秒數（約 143 BPM 的三拍子，像音樂盒的發條）
rng = np.random.default_rng(3)

# (MIDI, 拍數)
MOTIF = [(76, 1), (81, 1), (79, 1), (76, 1.5), (77, 0.5), (76, 1), (74, 1), (71, 2)]
RESOLVED_TAIL = [(72, 3)]         # Si → Do


def hz(m, cents=0.0):
    return 440.0 * 2 ** ((m - 69 + cents / 100) / 12)


def adsr(n, a, d, s, r):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na)
    e[na:na + nd] = np.linspace(1, s, nd)[: max(0, min(nd, n - na))]
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr)
    return e


def musicbox_note(f, dur, damp=1.0):
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    # 音樂盒的簧片：基音＋不和諧的高泛音（金屬感），很快衰減
    v = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 9)
         + 0.18 * np.sin(2 * np.pi * f * 5.43 * t) * np.exp(-t * 18) + 0.08 * np.sin(2 * np.pi * f * 8.9 * t) * np.exp(-t * 30))
    return v * np.exp(-t * 3.2 * damp) * np.minimum(1, t * 800)


def felt_note(f, dur):
    # 漂白鎮：同一個簧片，但像被毛線包住——高頻被吃掉、衰減更快
    v = musicbox_note(f, dur, damp=1.7)
    b, a = signal.butter(2, 1800 / (SR / 2), "low")
    return signal.lfilter(b, a, v) * 1.4


def whistle_note(f, dur, slide_up=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f_t = np.full(n, f) * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t * 3))   # 抖音
    if slide_up:
        f_t *= 2 ** (np.clip((t - dur * 0.45) / (dur * 0.55), 0, 1) * 4 / 12)   # 往上滑一個大三度
    ph = np.cumsum(f_t / SR)
    tone = np.sin(2 * np.pi * ph) + 0.06 * np.sin(4 * np.pi * ph)
    breath = signal.lfilter(*signal.butter(2, [f * 0.8 / (SR / 2), min(0.99, f * 1.6 / (SR / 2))], "band"), rng.standard_normal(n)) * 0.03
    return (tone + breath) * adsr(n, 0.04, 0.05, 0.85, 0.08)


def ecg_note(f, dur):
    # 心電圖的「嗶」：方波偏一點、短促；音高照旋律
    n = int(min(dur, 0.22) * SR)
    t = np.arange(n) / SR
    v = signal.square(2 * np.pi * f * t, 0.5) * 0.5 + np.sin(2 * np.pi * f * t) * 0.5
    v = signal.lfilter(*signal.butter(2, 3500 / (SR / 2), "low"), v)
    out = np.zeros(int(dur * SR))
    out[:n] = v * adsr(n, 0.004, 0.02, 0.8, 0.03)
    return out


def render(notes, voice, beat=BEAT, drop=(), cents_jitter=0.0, transpose=0, slide_last=False, gap=0.0):
    total = sum(b for _, b in notes) * beat + 1.6
    out = np.zeros(int(total * SR))
    pos = 0.0
    for i, (m, b) in enumerate(notes):
        dur = b * beat
        if i not in drop:
            f = hz(m + transpose, rng.normal(0, cents_jitter) if cents_jitter else 0.0)
            if voice == "musicbox":
                x = musicbox_note(f, dur)
            elif voice == "bleach":
                x = felt_note(f, dur)
            elif voice == "whistle":
                x = whistle_note(f, dur * (1 - gap), slide_up=slide_last and i == len(notes) - 1)
            else:
                x = ecg_note(f, dur)
            s = int(pos * SR)
            out[s:s + len(x)] += x[: len(out) - s]
        pos += dur
    return out


def room(x, wet=0.25, decay=2.6):
    ir_t = np.arange(int(decay * SR * 0.5)) / SR
    ir = rng.standard_normal(len(ir_t)) * np.exp(-ir_t * (6.9 / decay))
    ir = signal.lfilter(*signal.butter(1, 4000 / (SR / 2), "low"), ir)
    ir /= np.max(np.abs(ir)) + 1e-9
    wetx = signal.fftconvolve(x, ir)
    wetx = wetx / (np.max(np.abs(wetx)) + 1e-9) * np.max(np.abs(x)) * 0.6
    dry = np.concatenate([x, np.zeros(len(wetx) - len(x))])
    return dry * (1 - wet * 0.5) + wetx * wet


def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.7
    nz = np.where(np.abs(x) > 1e-3)[0]
    x = x[: (nz[-1] + int(0.05 * SR)) if len(nz) else len(x)]
    fade = int(0.03 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    with tempfile.NamedTemporaryFile(suffix=".wav") as tmp:
        wavfile.write(tmp.name, SR, (x * 32767).astype(np.int16))
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "6", f"{OUT}/{name}.ogg"], check=True)
    print("完成", f"{OUT}/{name}.ogg", "%.1f 秒" % (len(x) / SR))


def main():
    os.makedirs(OUT, exist_ok=True)
    save("musicbox", room(render(MOTIF, "musicbox")))
    save("bleach", room(render(MOTIF, "bleach", drop=(2, 5), cents_jitter=18, beat=BEAT * 1.08), wet=0.15))
    save("whistle", room(render(MOTIF, "whistle", transpose=12, slide_last=True, gap=0.12, beat=BEAT * 1.15), wet=0.35, decay=3.2))
    save("ecg", room(render(MOTIF, "ecg", transpose=-5), wet=0.1, decay=1.2))
    save("resolved", room(render(MOTIF[:-1] + [(71, 1)] + RESOLVED_TAIL, "musicbox", beat=BEAT * 1.1), wet=0.35))
    # 小遊戲的短樂句（都是動機的開頭兩個音變形）
    start = [(76, 0.5), (81, 1)]                              # Mi La：一聽就知道「要開始了」
    clear = [(76, 0.4), (81, 0.4), (84, 0.4), (88, 1.5)]      # 往上翻到高音 Mi
    fail = [(76, 0.6), (74, 0.6), (71, 1.6)]                  # 動機的結尾往下掉，停在 Si
    sting = [(76, 1.2), (81, 1.2), (79, 1.2), (76, 2.4)]      # 前四個音，慢
    for w, kw in (("musicbox", {}), ("bleach", {"cents_jitter": 15}), ("ecg", {"transpose": -5})):
        save(f"start_{w}", room(render(start, w, beat=0.36, **kw), wet=0.15))
        save(f"clear_{w}", room(render(clear, w, beat=0.36, **kw), wet=0.2))
        fkw = dict(kw)
        fkw["cents_jitter"] = kw.get("cents_jitter", 0) + 30   # 失敗：走音
        save(f"fail_{w}", room(render(fail, w, beat=0.4, **fkw), wet=0.2))
        save(f"sting_{w}", room(render(sting, w, beat=0.5, **kw), wet=0.4, decay=3.5))


if __name__ == "__main__":
    main()
