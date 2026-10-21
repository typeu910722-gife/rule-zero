#!/usr/bin/env python3
"""把現有的音檔拉到目標響度（只乘一個增益，不改聲音本身），必要時補很短的淡入淡出（修頭尾爆音）。
混音 QA 2026-10-21（docs/audio_mix_qa.md）用；重新產生角色小聲音（make_voice_sfx.py）或主旋律（make_motif_audio.py）之後要再跑一次。

用法：python3 tools/audio_normalize.py            → 照下面的 RULES 處理
      python3 tools/audio_normalize.py --dry      → 只印出會改多少，不寫檔

- 響度用 tools/audio_measure.py 同一套（BS.1770）。「mom」＝最大瞬時響度（短音效）、「int」＝整合響度。
- 已經在目標 ±0.5 LU 內、而且沒有要修的爆音 → 不動（可以重複跑）。
- 輸出保持原本的格式、取樣率、聲道數（ogg 用 Vorbis q6 重新編碼一次）。
"""
import glob, os, subprocess, sys, tempfile
import numpy as np
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audio_measure as am  # noqa: E402

# （檔案樣式, 模式, 目標）；播放時程式再加上自己的 volume_db
RULES = [
    ("game/audio/voice/*.ogg", "mom", -17.0),     # dialogue.gd VOICE_DB -3 → 播放約 -20
    ("game/audio/motif/*.ogg", "mom", -14.0),     # Motif.play 預設 -4 → 播放約 -18
]
# 只補淡入淡出（第二章外包音效裡頭尾沒處理好的；不改響度）
FADES = {
    "game/audio/ch2/se/ch2_se01_text_01.ogg": (0.0008, 0.0),
    "game/audio/ch2/se/ch2_se01_text_03.ogg": (0.0008, 0.0),
    "game/audio/ch2/se/ch2_se02_cursor_02.ogg": (0.0, 0.006),
    "game/audio/sfx_impact.wav": (0.0008, 0.0),   # 第一章：第一個樣本就很大
    "game/audio/sfx_stab.wav": (0.0008, 0.0),
}


def info(path):
    o = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=sample_rate,channels",
                        "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip().split(",")
    return int(o[0]), int(o[1])


def read(path, sr):
    out = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-"], capture_output=True, check=True).stdout
    _, ch = info(path)
    return np.frombuffer(out, dtype=np.float32).astype(np.float64).reshape(-1, ch)


def write(path, x, sr):
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        wavfile.write(f.name, sr, x.astype(np.float32))
        args = ["-c:a", "libvorbis", "-q:a", "6"] if path.endswith(".ogg") else ["-c:a", "pcm_s16le"]
        tmp = path + ".tmp" + os.path.splitext(path)[1]
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f.name, *args, tmp], check=True)
        os.replace(tmp, path)


def measure(path):
    r = am.measure(path)
    return r["lufs"], r["mom_max"], r["tp_db"], r["pop_head"] or r["pop_tail"]


def main(dry):
    jobs = {}
    for pat, mode, target in RULES:
        for p in sorted(glob.glob(pat)):
            jobs[p] = (mode, target)
    for p in FADES:
        jobs.setdefault(p, None)
    for p, rule in jobs.items():
        li, lm, tp, pop = measure(p)
        gain = 0.0
        if rule:
            mode, target = rule
            gain = target - (lm if mode == "mom" else li)
            gain = min(gain, -1.0 - tp)          # 不要把真峰值推過 -1 dBTP
            if abs(gain) < 0.5:
                gain = 0.0
        fade = FADES.get(p) if pop else None   # 已經修好的不再重做
        if gain == 0.0 and not fade:
            print(f"不用改   {p}  ({li:.1f} / {lm:.1f})")
            continue
        print(f"{'會改' if dry else '改'}     {p}  整合 {li:.1f} 瞬時 {lm:.1f} → 增益 {gain:+.1f} dB{'  淡入淡出' if fade else ''}")
        if dry:
            continue
        sr, _ = info(p)
        x = read(p, sr) * 10 ** (gain / 20)
        if fade:
            fi, fo = int(fade[0] * sr), int(fade[1] * sr)
            if fi:
                x[:fi] *= np.linspace(0, 1, fi)[:, None]
            if fo:
                x[-fo:] *= np.linspace(1, 0, fo)[:, None]
        write(p, x, sr)


if __name__ == "__main__":
    main("--dry" in sys.argv)
