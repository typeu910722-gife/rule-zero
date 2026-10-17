#!/usr/bin/env python3
"""把外包第二章交付包（rulezero_ch2_complete/）轉成遊戲用的尺寸與格式，放進 game/。

用法：python3 tools/import_vendor_ch2.py <解壓後的 rulezero_ch2_complete 或修正包 rulezero_ch2_revision 資料夾>
（修正包只含要換掉的檔案，照樣丟進來即可；沒附的檔案保持原樣）

- 圖：交付是 2 倍尺寸，遊戲用 1 倍（立繪 512×768、背景／CG 1280×720、地圖 1600×1150、零件 ×0.5）。
- 大圖在 Godot 裡用有損 WebP 匯入（寫好 .import 的 compress/mode=1），網頁版才不會太大。
- 小人圖集保持原尺寸、無損（遊戲以 0.5 倍顯示，腳底原點照交付）。
- 音樂只拿 OGG；音效 WAV 轉成 OGG（單聲道）。
"""
import os
import subprocess
import sys
from pathlib import Path

from PIL import Image

SRC = Path(sys.argv[1])
GAME = Path(__file__).resolve().parent.parent / "game"
ART = SRC / "game/art/ch2"
AUD = SRC / "game/audio/ch2"
DST = GAME / "art/ch2"

LOSSY_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=1
compress/lossy_quality=0.85
mipmaps/generate=false
process/fix_alpha_border=true
"""

count = {"img": 0, "snd": 0}


def save(im: Image.Image, out: Path, jpg=False, lossy=None):
    out.parent.mkdir(parents=True, exist_ok=True)
    if jpg:
        im.convert("RGB").save(out, quality=86, optimize=True)
    else:
        im.save(out, optimize=True)
    big = im.width * im.height >= 256 * 256
    imp = Path(str(out) + ".import")
    if (big if lossy is None else lossy):
        imp.write_text(LOSSY_IMPORT)
    elif imp.exists():
        imp.unlink()
    count["img"] += 1


def scaled(path: Path, size=None, factor=None) -> Image.Image:
    im = Image.open(path)
    im = im.convert("RGBA") if im.mode in ("RGBA", "LA", "P") else im.convert("RGB")
    if factor:
        size = (max(1, round(im.width * factor)), max(1, round(im.height * factor)))
    if size and im.size != tuple(size):
        im = im.resize(size, Image.LANCZOS)
    return im


# 立繪
for f in sorted((ART / "characters/portraits").glob("*.png")):
    save(scaled(f, (512, 768)), DST / "characters/portraits" / f.name)

# 小人圖集
for f in sorted((ART / "characters/sprites").glob("*_sheet.png")):
    save(scaled(f), DST / "characters/sprites" / f.name, lossy=False)

# 地圖與背景
for f in sorted((ART / "backgrounds").iterdir()):
    if f.name.startswith("ch2_bg_town_"):
        stem = f.stem
        if stem.endswith("_overlay") or stem.endswith("_closed"):
            save(scaled(f, (1600, 1150)), DST / "backgrounds" / (stem + ".png"))
        else:
            save(scaled(f, (1600, 1150)), DST / "backgrounds" / (stem + ".jpg"), jpg=True)
    else:
        save(scaled(f, (1280, 720)), DST / "backgrounds" / (f.stem + ".jpg"), jpg=True)

# CG
for f in sorted((ART / "cg").glob("*.png")):
    im = scaled(f, (1280, 720))
    if "overlay" in f.stem:
        save(im, DST / "cg" / f.name)
    else:
        save(im, DST / "cg" / (f.stem + ".jpg"), jpg=True)
for f in sorted((ART / "cg/ending_layers").glob("*.png")):
    save(scaled(f, (1280, 720)), DST / "cg/ending_layers" / f.name)

# 小遊戲零件（預覽圖不拿）
for d in sorted((ART / "minigames").iterdir()):
    for f in sorted(d.glob("*.png")):
        if f.stem.endswith("_preview"):
            continue
        save(scaled(f, factor=0.5), DST / "minigames" / d.name / f.name)

# UI
for f in sorted((ART / "ui").glob("*.png")):
    if f.stem.endswith("title_preview"):
        continue
    im = Image.open(f)
    save(scaled(f, factor=1 if max(im.size) <= 160 else 0.5), DST / "ui" / f.name)

# 音樂
bgm = GAME / "audio/ch2/bgm"
bgm.mkdir(parents=True, exist_ok=True)
for f in sorted((AUD / "bgm").glob("*.ogg")):
    (bgm / f.name).write_bytes(f.read_bytes())
    count["snd"] += 1

# 音效：WAV → OGG
se = GAME / "audio/ch2/se"
se.mkdir(parents=True, exist_ok=True)
for f in sorted((AUD / "se").glob("*.wav")):
    out = se / (f.stem + ".ogg")
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(f), "-ac", "1",
                    "-c:a", "libvorbis", "-q:a", "5", str(out)], check=True)
    old = se / f.name
    for p in (old, Path(str(old) + ".import")):
        if p.exists():
            p.unlink()
    count["snd"] += 1

print(f"圖 {count['img']} 張、聲音 {count['snd']} 個")
