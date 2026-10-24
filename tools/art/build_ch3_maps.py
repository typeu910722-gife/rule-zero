#!/usr/bin/env python3
"""依 chapter3.json 的碰撞座標繪製 22 張可直接遊玩的醫院地圖美術。

背景、家具、門都烘焙進同一張圖，所以畫面和實際可走區域一定對齊。
輸出：game/art/ch3/maps/ch3_map_<room>.jpg
"""
from __future__ import annotations

import json
from pathlib import Path
import random

from PIL import Image, ImageDraw, ImageFilter
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
LEVEL = ROOT / "game/levels/chapter3.json"
OUT = ROOT / "game/art/ch3/maps"
SEED = 303

PALETTES = {
    "hospital": dict(wall=(218, 229, 232), wall2=(239, 246, 247), floor=(190, 207, 211), line=(126, 153, 160), glow=(210, 242, 247)),
    "hospital_old": dict(wall=(92, 109, 108), wall2=(128, 143, 139), floor=(78, 91, 89), line=(45, 57, 56), glow=(159, 142, 105)),
    "basement": dict(wall=(34, 46, 48), wall2=(49, 63, 64), floor=(28, 39, 41), line=(64, 85, 86), glow=(80, 119, 105)),
    "lab": dict(wall=(202, 221, 226), wall2=(239, 248, 249), floor=(178, 202, 208), line=(115, 145, 153), glow=(190, 232, 241)),
    "platform": dict(wall=(151, 164, 165), wall2=(199, 209, 209), floor=(105, 117, 118), line=(71, 82, 83), glow=(211, 223, 218)),
}


def rect(v):
    return tuple(int(round(x)) for x in v)


def noisy_base(size, color, amount=7, seed=0):
    w, h = size
    rng = np.random.default_rng(seed)
    arr = np.empty((h, w, 3), np.int16)
    arr[:] = color
    noise = rng.normal(0, amount, (h, w, 1))
    arr = np.clip(arr + noise, 0, 255).astype(np.uint8)
    return Image.fromarray(arr, "RGB")


def gradient_rect(im, box, c1, c2):
    x0, y0, x1, y1 = map(int, box)
    if x1 <= x0 or y1 <= y0:
        return
    a = np.array(c1, float)
    b = np.array(c2, float)
    t = np.linspace(0, 1, y1 - y0)[:, None, None]
    arr = (a * (1 - t) + b * t).astype(np.uint8)
    arr = np.tile(arr, (1, x1 - x0, 1))
    im.paste(Image.fromarray(arr), (x0, y0))


def shadow(layer, box, radius=14, alpha=80):
    d = ImageDraw.Draw(layer)
    x0, y0, x1, y1 = box
    d.rounded_rectangle((x0 + 8, y0 + 10, x1 + 13, y1 + 15), radius=radius, fill=(0, 0, 0, alpha))


def prop(layer, p, pal):
    kind = p.get("kind", "crate")
    x, y, w, h = rect(p["rect"])
    x1, y1 = x + w, y + h
    d = ImageDraw.Draw(layer)
    shadow(layer, (x, y, x1, y1))
    steel = (178, 194, 197, 255)
    edge = (*pal["line"], 255)
    if kind == "bed":
        d.rounded_rectangle((x, y - 26, x1, y1), 12, fill=(223, 232, 232, 255), outline=edge, width=3)
        d.rounded_rectangle((x + 7, y - 20, x1 - 7, y + h * .54), 10, fill=(244, 245, 239, 255))
        d.rounded_rectangle((x + 12, y - 16, x + w * .36, y + 8), 8, fill=(255, 254, 247, 255))
        d.rounded_rectangle((x + 8, y + h * .18, x1 - 8, y + h * .72), 7, fill=(190, 210, 213, 255))
        for xx in (x + 14, x1 - 14):
            d.line((xx, y1 - 4, xx, y1 + 10), fill=edge, width=4)
            d.ellipse((xx - 5, y1 + 6, xx + 5, y1 + 16), fill=(48, 55, 57, 255))
    elif kind == "chair":
        n = max(1, round(w / 90))
        gap = 7
        cw = (w - gap * (n - 1)) / n
        for i in range(n):
            xx = x + i * (cw + gap)
            d.rounded_rectangle((xx, y - 28, xx + cw, y + h), 8, fill=(139, 165, 170, 255), outline=edge, width=2)
            d.line((xx + 7, y + h, xx + 5, y + h + 12), fill=edge, width=4)
            d.line((xx + cw - 7, y + h, xx + cw - 5, y + h + 12), fill=edge, width=4)
            d.line((xx + 5, y - 2, xx + cw - 5, y - 2), fill=(205, 219, 221, 255), width=3)
    elif kind in ("desk", "table"):
        top = (167, 137, 105, 255) if kind == "desk" else steel
        d.rounded_rectangle((x, y - 24, x1, y + h * .45), 7, fill=top, outline=edge, width=3)
        d.rectangle((x + 5, y + h * .42, x1 - 5, y1), fill=(126, 110, 93, 255) if kind == "desk" else (145, 161, 164, 255), outline=edge, width=2)
        if kind == "desk":
            for xx in (x + w * .2, x + w * .65):
                d.rounded_rectangle((xx, y + h * .5, xx + w * .25, y1 - 5), 3, outline=(88, 76, 66, 255), width=2)
                d.ellipse((xx + w * .2, y + h * .67, xx + w * .2 + 4, y + h * .67 + 4), fill=(220, 188, 107, 255))
    elif kind in ("cabinet", "locker", "shelf"):
        col = (137, 151, 151, 255) if kind != "shelf" else (128, 105, 79, 255)
        d.rounded_rectangle((x, y - 45, x1, y1), 5, fill=col, outline=edge, width=3)
        if kind == "shelf":
            for yy in range(y - 28, y1, 27):
                d.line((x + 4, yy, x1 - 4, yy), fill=(75, 67, 56, 255), width=3)
                for k in range(max(1, w // 60)):
                    bx = x + 12 + k * 48
                    d.rectangle((bx, yy - 18, min(x1 - 5, bx + 28), yy - 3), fill=(183, 171, 143, 255))
        else:
            cells = max(1, w // 70)
            for k in range(1, cells):
                xx = x + k * w / cells
                d.line((xx, y - 42, xx, y1), fill=edge, width=2)
            for k in range(cells):
                xx = x + (k + .5) * w / cells
                d.line((xx - 5, y + h * .1, xx + 5, y + h * .1), fill=(55, 67, 68, 255), width=2)
    elif kind == "machine":
        d.rounded_rectangle((x, y - 54, x1, y1), 7, fill=(169, 184, 187, 255), outline=edge, width=3)
        d.rounded_rectangle((x + 8, y - 45, x1 - 8, y - 10), 4, fill=(21, 36, 39, 255))
        d.line((x + 13, y - 28, x1 - 13, y - 28), fill=(92, 227, 154, 255), width=3)
        for k in range(3):
            d.ellipse((x + 10 + k * 15, y + 2, x + 17 + k * 15, y + 9), fill=((227, 117, 117, 255), (224, 194, 95, 255), (97, 193, 139, 255))[k])
    elif kind == "plant":
        d.rounded_rectangle((x + w * .25, y + h * .35, x + w * .75, y1 + 7), 5, fill=(138, 102, 75, 255), outline=edge, width=2)
        rng = random.Random(x * 11 + y)
        for k in range(9):
            cx = x + w / 2 + rng.uniform(-w * .42, w * .42)
            cy = y + rng.uniform(-45, h * .3)
            rr = rng.uniform(10, 19)
            d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(72, 116 + k * 3, 85, 245))
    elif kind == "window":
        d.rectangle((x, y - 90, x1, y1), fill=(64, 83, 91, 255), outline=edge, width=5)
        d.rectangle((x + 7, y - 82, x1 - 7, y1 - 7), fill=(143, 185, 196, 255))
        d.line((x + w / 2, y - 82, x + w / 2, y1 - 7), fill=edge, width=3)
        d.line((x + 7, y - 35, x1 - 7, y - 35), fill=edge, width=3)
        # 醫院裡每一扇窗都有白鴿。
        d.ellipse((x + w * .7, y - 31, x + w * .7 + 15, y - 17), fill=(238, 240, 234, 255))
        d.polygon([(x + w * .75, y - 24), (x + w * .83, y - 20), (x + w * .75, y - 17)], fill=(238, 240, 234, 255))
    elif kind == "rug":
        d.rounded_rectangle((x, y, x1, y1), 12, fill=(112, 136, 137, 150), outline=(174, 194, 195, 200), width=3)
        for k in range(5):
            yy = y + (k + 1) * h / 6
            d.line((x + 10, yy, x1 - 10, yy), fill=(151, 174, 174, 100), width=2)
    elif kind in ("crate", "box"):
        d.rectangle((x, y - 18, x1, y1), fill=(143, 112, 76, 255), outline=(86, 66, 47, 255), width=3)
        d.line((x + 6, y - 13, x1 - 6, y1 - 5), fill=(100, 78, 56, 255), width=3)
        d.line((x1 - 6, y - 13, x + 6, y1 - 5), fill=(100, 78, 56, 255), width=3)
    elif kind == "sink":
        d.rounded_rectangle((x, y - 26, x1, y1), 6, fill=(205, 218, 219, 255), outline=edge, width=3)
        d.ellipse((x + 12, y - 18, x1 - 12, y + h * .45), fill=(116, 145, 150, 255))
        d.arc((x + w * .35, y - 48, x + w * .65, y - 5), 180, 360, fill=(90, 106, 108, 255), width=4)
    elif kind == "pillar":
        d.rounded_rectangle((x, y - 90, x1, y1), 4, fill=(183, 193, 193, 255), outline=edge, width=3)
        d.rectangle((x - 5, y1 - 9, x1 + 5, y1 + 4), fill=(113, 127, 128, 255))
    else:
        d.rounded_rectangle((x, y - 14, x1, y1), 6, fill=steel, outline=edge, width=3)


def draw_door(layer, door, pal):
    d = ImageDraw.Draw(layer)
    x, y = map(int, door["pos"])
    w, h = map(int, door.get("size", [90, 26]))
    edge = (*pal["line"], 255)
    if w >= h:  # 上／下牆的橫門
        box = (x - w // 2, y - 18, x + w // 2, y + 18)
        shadow(layer, box, 4, 90)
        d.rectangle(box, fill=(48, 60, 62, 255), outline=edge, width=4)
        d.rectangle((box[0] + 7, box[1] + 5, box[2] - 7, box[3] - 4), fill=(116, 140, 143, 255))
        d.line((x, box[1] + 5, x, box[3] - 4), fill=edge, width=3)
    else:  # 左／右牆的直門
        box = (x - 18, y - h // 2, x + 18, y + h // 2)
        shadow(layer, box, 4, 90)
        d.rectangle(box, fill=(48, 60, 62, 255), outline=edge, width=4)
        d.line((box[0] + 6, y, box[2] - 5, y), fill=(137, 164, 165, 255), width=5)
        d.ellipse((x + 7, y - 4, x + 13, y + 2), fill=(226, 190, 88, 255))


def render(room_id, room):
    size = tuple(map(int, room.get("size", [1280, 720])))
    w, h = size
    pal = PALETTES.get(room.get("theme", "hospital"), PALETTES["hospital"])
    wall_h = int(room.get("wall_h", 100))
    room_seed = SEED + sum((i + 1) * ord(c) for i, c in enumerate(room_id))
    im = noisy_base(size, pal["floor"], 4 if not room.get("dark") else 7, room_seed)
    gradient_rect(im, (0, 0, w, wall_h), pal["wall2"], pal["wall"])
    d = ImageDraw.Draw(im, "RGBA")
    # 牆板、扶手與踢腳板
    for x in range(0, w, 190):
        d.line((x, 4, x, wall_h - 9), fill=(*pal["line"], 55), width=2)
    d.line((0, wall_h - 12, w, wall_h - 12), fill=(*pal["line"], 220), width=6)
    d.line((0, wall_h - 4, w, wall_h - 4), fill=(245, 248, 245, 130), width=3)
    # 細緻地磚而不是偵錯網格
    tile_x, tile_y = (96, 72)
    for yy in range(wall_h, h, tile_y):
        off = (yy // tile_y % 2) * tile_x // 2
        d.line((0, yy, w, yy), fill=(*pal["line"], 30), width=1)
        for xx in range(-off, w, tile_x):
            d.line((xx, yy, xx, min(h, yy + tile_y)), fill=(*pal["line"], 24), width=1)
    # 天花燈在地面的柔光
    lights = Image.new("RGBA", size)
    ld = ImageDraw.Draw(lights)
    for x in range(170, w, 410):
        ld.ellipse((x - 190, wall_h - 20, x + 190, min(h, wall_h + 340)), fill=(*pal["glow"], 30))
    lights = lights.filter(ImageFilter.GaussianBlur(45))
    im = Image.alpha_composite(im.convert("RGBA"), lights)
    layer = Image.new("RGBA", size)
    # 額外牆塊
    dd = ImageDraw.Draw(layer)
    for wr in room.get("walls", []):
        x, y, ww, hh = rect(wr)
        shadow(layer, (x, y, x + ww, y + hh), 5, 75)
        dd.rounded_rectangle((x, y - 24, x + ww, y + hh), 4, fill=(*pal["wall"], 255), outline=(*pal["line"], 255), width=3)
        dd.line((x + 4, y - 18, x + ww - 4, y - 18), fill=(*pal["wall2"], 255), width=5)
    for p in room.get("props", []):
        prop(layer, p, pal)
    # 躲藏點本身也是場景家具（有些不在 props）
    for hd in room.get("hides", []):
        sz = hd.get("size", [90, 40])
        x, y = hd["pos"]
        fake = {"kind": hd.get("kind", "locker"), "rect": [x - sz[0] / 2, y - sz[1], sz[0], sz[1]]}
        prop(layer, fake, pal)
    for door in room.get("doors", []):
        draw_door(layer, door, pal)
    im = Image.alpha_composite(im, layer)
    # 路線與區域標記烘焙成地板材質
    d = ImageDraw.Draw(im, "RGBA")
    for decal in room.get("decals", []):
        if decal.get("kind") == "line":
            pts = [tuple(map(int, p)) for p in decal["points"]]
            col = decal.get("color", "#f5a3b8").lstrip("#")
            rgb = tuple(int(col[i:i + 2], 16) for i in (0, 2, 4))
            d.line(pts, fill=(*rgb, 190), width=int(decal.get("width", 6)), joint="curve")
        elif decal.get("kind") == "rect":
            x, y, ww, hh = rect(decal["rect"])
            col = decal.get("color", "#ffffff").lstrip("#")
            rgb = tuple(int(col[i:i + 2], 16) for i in (0, 2, 4))
            d.rounded_rectangle((x, y, x + ww, y + hh), 3, fill=(*rgb, 170))
    # 暗房：保留美術，只壓低整體；遊戲內手電筒再疊上去。
    if room.get("dark", False):
        shade = Image.new("RGBA", size, (6, 12, 15, 98))
        im = Image.alpha_composite(im, shade)
    # 邊緣暗角與一點膠片顆粒
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum.reduce([xx / max(1, w * .18), (w - 1 - xx) / max(1, w * .18),
                              yy / max(1, h * .22), (h - 1 - yy) / max(1, h * .22)])
    alpha = ((1 - np.clip(edge, 0, 1)) * 52).astype(np.uint8)
    vig = np.zeros((h, w, 4), np.uint8)
    vig[..., 3] = alpha
    im = Image.alpha_composite(im, Image.fromarray(vig, "RGBA"))
    return im.convert("RGB")


def main():
    data = json.loads(LEVEL.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    for room_id, room in data["rooms"].items():
        out = OUT / f"ch3_map_{room_id}.jpg"
        render(room_id, room).save(out, quality=90, subsampling=1, optimize=True)
        print("完成", out.relative_to(ROOT), Image.open(out).size)


if __name__ == "__main__":
    main()
