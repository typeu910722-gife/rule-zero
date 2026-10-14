#!/usr/bin/env python3
"""追逐戰的貼圖（依 docs/art/concept_chase.jpg 的配色與質感，用程式產生）。

輸出到 game/art/：
  chase_wall.png    拼布圍牆（可無縫拼接，512×512 ＝ 3 公尺）
  chase_floor.png   石板路（可無縫拼接）
  chase_sky.png     天空全景（紫紅色的霧、遠方的城堡剪影）
  chase_window.png  發光的窗戶（貼在牆上）
  chase_tags.png    一串掛著的名牌（橫跨走廊）
  chase_cotton.png  一團棉花

美術之後交真的貼圖時，用同樣的檔名覆蓋就好。
用法：python3 tools/make_chase_textures.py
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = "game/art/"
rng = random.Random(47)
nrng = np.random.default_rng(47)

PATCH = [(110, 42, 53), (90, 50, 72), (47, 53, 80), (196, 176, 150), (140, 74, 85), (92, 64, 48), (128, 58, 66), (70, 44, 62)]
STITCH = (205, 168, 106)


def fabric_noise(w, h, amt=14):
    n = nrng.normal(0, amt, (h, w))
    # 布的織紋：橫、直的細線
    yy, xx = np.mgrid[0:h, 0:w]
    weave = (np.sin(xx * 1.9) * np.sin(yy * 1.9)) * 6
    return n + weave


def wall():
    S = 512
    img = np.zeros((S, S, 3), float)
    # 拼布：4×4 格，偶爾合併成 2×1，邊界做成可以無縫拼接
    cells = []
    taken = set()
    for gy in range(4):
        for gx in range(4):
            if (gx, gy) in taken:
                continue
            w = 2 if gx < 3 and rng.random() < 0.3 and (gx + 1, gy) not in taken else 1
            for k in range(w):
                taken.add((gx + k, gy))
            cells.append((gx * 128, gy * 128, w * 128, 128))
    for x, y, w, h in cells:
        col = np.array(rng.choice(PATCH), float)
        patch = np.ones((h, w, 3)) * col
        patch += fabric_noise(w, h)[..., None]
        style = rng.choice(["plain", "plain", "stripe", "check", "dots"])
        yy, xx = np.mgrid[0:h, 0:w]
        if style == "stripe":
            patch += ((xx // 10) % 2)[..., None] * 14
        elif style == "check":
            patch += (((xx // 16) + (yy // 16)) % 2)[..., None] * 16
        elif style == "dots":
            patch += (((xx % 22 - 11) ** 2 + (yy % 22 - 11) ** 2) < 12)[..., None] * 40
        img[y:y + h, x:x + w] = patch
    img = np.clip(img, 0, 255).astype("uint8")
    im = Image.fromarray(img)
    d = ImageDraw.Draw(im)
    # 縫線：每塊布的邊緣，黃銅色的捲邊縫
    for x, y, w, h in cells:
        d.rectangle([x, y, x + w - 1, y + h - 1], outline=(30, 18, 24), width=3)
        for t in range(0, w, 12):
            d.line([(x + t, y - 5), (x + t + 6, y + 6)], fill=STITCH, width=3)
        for t in range(0, h, 12):
            d.line([(x - 5, y + t), (x + 6, y + t + 6)], fill=STITCH, width=3)
    # 有幾個地方破了，棉花跑出來
    for _ in range(3):
        cx, cy = rng.randrange(40, S - 40), rng.randrange(40, S - 40)
        for k in range(9):
            r = rng.randrange(6, 13)
            ox, oy = rng.randrange(-14, 14), rng.randrange(-10, 10)
            d.ellipse([cx + ox - r, cy + oy - r, cx + ox + r, cy + oy + r], fill=(238, 232, 222))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    # 下面比較髒、比較暗
    a = np.asarray(im).astype(float)
    grad = np.linspace(1.0, 0.72, S)[:, None, None]
    a = a * grad
    Image.fromarray(np.clip(a, 0, 255).astype("uint8")).save(OUT + "chase_wall.png", optimize=True)


def floor():
    S = 512
    # 石板：Voronoi，四邊重複（可無縫）
    pts = [(rng.random() * S, rng.random() * S) for _ in range(70)]
    tiled = [(x + dx * S, y + dy * S) for x, y in pts for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
    P = np.array(tiled)
    yy, xx = np.mgrid[0:S, 0:S]
    d1 = np.full((S, S), 1e9)
    d2 = np.full((S, S), 1e9)
    idx = np.zeros((S, S), int)
    for i, (px, py) in enumerate(P):
        dd = np.hypot(xx - px, yy - py)
        closer = dd < d1
        d2 = np.where(closer, d1, np.minimum(d2, dd))
        idx = np.where(closer, i, idx)
        d1 = np.where(closer, dd, d1)
    edge = d2 - d1
    shade = np.array([rng.uniform(0.75, 1.15) for _ in range(len(P))])[idx]
    base = np.array([74, 60, 72], float)
    img = base[None, None, :] * shade[..., None]
    img += nrng.normal(0, 8, (S, S))[..., None]
    img = np.where((edge < 5)[..., None], np.array([28, 20, 26], float), img)
    # 石頭上緣一點點亮光（暖色的燈）
    img += np.clip((edge - 5) / 18, 0, 1)[..., None] * np.array([18, 10, 8])
    Image.fromarray(np.clip(img, 0, 255).astype("uint8")).filter(ImageFilter.GaussianBlur(0.7)).save(OUT + "chase_floor.png", optimize=True)


def sky():
    W, H = 2048, 1024
    y = np.linspace(0, 1, H)[:, None]
    top = np.array([28, 14, 40], float)
    mid = np.array([92, 34, 70], float)
    low = np.array([196, 84, 70], float)
    t = np.clip((y - 0.15) / 0.35, 0, 1)
    col = top * (1 - t[..., None]) + mid * t[..., None]
    t2 = np.clip((y - 0.38) / 0.14, 0, 1)
    col = col * (1 - t2[..., None]) + low * t2[..., None]
    img = np.repeat(col, W, axis=1)
    im = Image.fromarray(np.clip(img, 0, 255).astype("uint8"))
    d = ImageDraw.Draw(im)
    horizon = int(H * 0.5)
    # 遠方的城堡、鐘塔剪影（左右可以接起來）
    for layer, (shade, base, hmax) in enumerate([((70, 34, 62), horizon + 10, 150), ((44, 22, 44), horizon + 30, 230)]):
        x = 0
        while x < W:
            w = rng.randrange(40, 120)
            h = rng.randrange(40, hmax)
            d.rectangle([x, base - h, x + w, H], fill=shade)
            if rng.random() < 0.45:
                # 尖塔
                d.polygon([(x + w * 0.2, base - h), (x + w * 0.5, base - h - rng.randrange(40, 110)), (x + w * 0.8, base - h)], fill=shade)
            for _ in range(rng.randrange(0, 4)):
                wx = x + rng.randrange(6, max(8, w - 10))
                wy = base - rng.randrange(12, max(14, h - 8))
                d.rectangle([wx, wy, wx + 5, wy + 8], fill=(255, 190, 110) if layer == 1 else (220, 150, 110))
            x += w + rng.randrange(-10, 20)
    # 城牆底下：整片暗色（不要露出縫）
    d.rectangle([0, horizon + 60, W, H], fill=(36, 18, 36))
    # 月亮
    d.ellipse([1500, 160, 1580, 240], fill=(250, 220, 200))
    d.ellipse([1520, 150, 1600, 230], fill=(40, 18, 46))
    im = im.filter(ImageFilter.GaussianBlur(2.2))
    # 霧
    a = np.asarray(im).astype(float)
    fog = np.clip(1 - np.abs(np.linspace(0, 1, H) - 0.52) / 0.12, 0, 1)[:, None, None]
    a = a * (1 - fog * 0.45) + np.array([170, 90, 100]) * fog * 0.45
    Image.fromarray(np.clip(a, 0, 255).astype("uint8")).save(OUT + "chase_sky.png", optimize=True)


def window():
    im = Image.new("RGBA", (128, 160), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([4, 4, 124, 156], radius=10, fill=(70, 40, 30, 255))
    d.rectangle([14, 14, 114, 146], fill=(255, 176, 90, 255))
    glow = Image.new("RGBA", (128, 160), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([20, 30, 108, 130], fill=(255, 230, 170, 200))
    im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(im)
    d.line([(64, 14), (64, 146)], fill=(70, 40, 30, 255), width=7)
    d.line([(14, 80), (114, 80)], fill=(70, 40, 30, 255), width=7)
    im.save(OUT + "chase_window.png", optimize=True)


def tags():
    W, H = 768, 160
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(x, 18 + 26 * math.sin(math.pi * x / W)) for x in range(0, W + 1, 8)]
    d.line(pts, fill=(120, 90, 60, 255), width=4)
    for k in range(11):
        x = 34 + k * 70
        y = 18 + 26 * math.sin(math.pi * x / W)
        d.line([(x, y), (x, y + 22)], fill=(120, 90, 60, 255), width=2)
        tw, th = 46, 60
        rot = rng.uniform(-12, 12)
        tag = Image.new("RGBA", (tw + 10, th + 10), (0, 0, 0, 0))
        td = ImageDraw.Draw(tag)
        td.rounded_rectangle([5, 5, tw + 5, th + 5], radius=6, fill=(236, 222, 196, 255), outline=(150, 90, 80, 255), width=3)
        td.ellipse([tw // 2, 9, tw // 2 + 8, 17], fill=(120, 90, 60, 255))
        for ln in range(3):
            td.line([(13, 28 + ln * 10), (tw - 3, 28 + ln * 10)], fill=(150, 120, 110, 255), width=2)
        tag = tag.rotate(rot, resample=Image.BICUBIC, expand=True)
        im.alpha_composite(tag, (int(x - tag.width / 2), int(y + 18)))
    im.save(OUT + "chase_tags.png", optimize=True)


def cotton():
    im = Image.new("RGBA", (256, 192), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for _ in range(26):
        r = rng.randrange(18, 40)
        x = rng.randrange(40, 216)
        y = rng.randrange(80, 170) - (abs(x - 128) < 60) * rng.randrange(0, 40)
        c = rng.randrange(225, 250)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(c, c - 4, c - 10, 255))
    im = im.filter(ImageFilter.GaussianBlur(1.5))
    im.save(OUT + "chase_cotton.png", optimize=True)


if __name__ == "__main__":
    wall()
    floor()
    sky()
    window()
    tags()
    cotton()
    print("ok")
