"""3D 追逐的牆、地板、天花板貼圖（程式畫的，不外包）。一格＝2 公尺；牆高 2.6 公尺。
  hosp_*：第三章醫院（淡綠下半牆、扶手、白地磚，牆腳有一點擦痕；乾淨的恐怖，沒有血）
  school_*：第四章放學後的學校（木頭下半牆、木地板）
  real_*：第五章真的醫院（很白、很亮）
用法：py -3.11 tools/art/make_chase_textures.py game/art/3d/tex
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "game/art/3d/tex")
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(3)
WW, WH = 512, 666          # 牆：2m × 2.6m
PX = WW / 2.0              # 每公尺幾個像素


def noise(w, h, scale, amt):
    small = rng.standard_normal((max(2, h // scale), max(2, w // scale)))
    n = np.array(Image.fromarray(((small - small.min()) / (np.ptp(small) + 1e-6) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), float)
    return (n / 255.0 - 0.5) * amt


def tint(img, amt=10, scale=24, fine=4):
    a = np.array(img, float)
    n = noise(img.width, img.height, scale, amt) + noise(img.width, img.height, 3, fine)
    a += n[..., None]
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def y_of(m):
    """離地 m 公尺 → 牆貼圖的 y（上面是天花板）"""
    return int(WH - m * PX)


def wall(top, low, rail, base, rail_h=0.9, rail_w=0.06, planks=False, scuff=0.0, low_h=None):
    im = Image.new("RGB", (WW, WH), top)
    d = ImageDraw.Draw(im)
    lh = low_h if low_h is not None else rail_h
    d.rectangle([0, y_of(lh), WW, WH], fill=low)
    if planks:
        for x in range(0, WW, 32):
            d.line([x, y_of(lh), x, WH], fill=tuple(max(0, c - 22) for c in low), width=2)
    d.rectangle([0, y_of(rail_h + rail_w / 2), WW, y_of(rail_h - rail_w / 2)], fill=rail)
    d.line([0, y_of(rail_h - rail_w / 2) + 1, WW, y_of(rail_h - rail_w / 2) + 1], fill=tuple(max(0, c - 60) for c in low), width=3)   # 扶手下的影子
    d.rectangle([0, y_of(0.12), WW, WH], fill=base)
    im = tint(im, 9)
    if scuff:   # 牆腳的擦痕、髒（越下面越多）
        a = np.array(im, float)
        g = np.clip((np.arange(WH)[:, None] - y_of(0.6)) / (WH - y_of(0.6)), 0, 1) ** 2
        a *= (1 - scuff * g * (0.6 + noise(WW, WH, 12, 0.8)))[..., None]
        im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    return im


def tiles(c1, c2, grout, n, size=512, gw=3, check=True):
    im = Image.new("RGB", (size, size), c1)
    d = ImageDraw.Draw(im)
    s = size / n
    for i in range(n):
        for j in range(n):
            if check and (i + j) % 2:
                d.rectangle([i * s, j * s, (i + 1) * s, (j + 1) * s], fill=c2)
    for k in range(n + 1):
        d.line([k * s, 0, k * s, size], fill=grout, width=gw)
        d.line([0, k * s, size, k * s], fill=grout, width=gw)
    return tint(im, 7, 40, 3)


def planks(c, size=512, n=8):
    im = Image.new("RGB", (size, size), c)
    d = ImageDraw.Draw(im)
    s = size / n
    for k in range(n):
        shade = int(rng.integers(-14, 14))
        d.rectangle([0, k * s, size, (k + 1) * s], fill=tuple(int(np.clip(v + shade, 0, 255)) for v in c))
        d.line([0, k * s, size, k * s], fill=tuple(max(0, v - 50) for v in c), width=2)
        off = rng.integers(0, size)
        d.line([off, k * s, off, (k + 1) * s], fill=tuple(max(0, v - 40) for v in c), width=2)
    im = tint(im, 10, 6, 6).filter(ImageFilter.GaussianBlur(0.6))
    return im


def ceiling(c, line, n=3, dots=True):
    im = tiles(c, c, line, n, gw=4, check=False)
    if dots:
        d = ImageDraw.Draw(im)
        for _ in range(900):
            x, y = rng.integers(0, 512, 2)
            d.point((int(x), int(y)), fill=tuple(v - 35 for v in c))
    return im


sets = {
    "hosp": dict(
        wall=wall((216, 228, 224), (163, 189, 181), (236, 240, 238), (120, 138, 134), scuff=0.35),
        floor=tiles((214, 222, 222), (204, 213, 213), (150, 164, 166), 4),
        ceil=ceiling((214, 218, 216), (160, 166, 164))),
    "school": dict(
        wall=wall((226, 214, 194), (150, 116, 80), (110, 84, 58), (92, 70, 48), rail_h=1.0, planks=True, scuff=0.2),
        floor=planks((168, 140, 104)),
        ceil=ceiling((236, 228, 214), (190, 180, 165), 2, False)),
    "real": dict(
        wall=wall((242, 244, 242), (230, 233, 230), (250, 251, 250), (200, 205, 200), rail_h=0.9, rail_w=0.04),
        floor=tiles((222, 226, 222), (218, 222, 218), (186, 192, 186), 2),
        ceil=ceiling((246, 247, 246), (215, 218, 215))),
}
for name, s in sets.items():
    for part, im in s.items():
        im.save(OUT / f"{name}_{part}.png")
        print("wrote", OUT / f"{name}_{part}.png")
