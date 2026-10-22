#!/usr/bin/env python3
"""第一章走路圖（3 格 × 4 列：下、左、右、上）的「左」→ 側面構圖控制用的線稿（832×1216）。
用法：side_ctrl.py walk_xxx.png out.png [--flip] [--erase-right 0.0~1.0（把右邊某比例擦掉，去掉尾巴）]"""
import sys, argparse
from PIL import Image, ImageFilter, ImageOps, ImageDraw
ap = argparse.ArgumentParser(); ap.add_argument("src"); ap.add_argument("out")
ap.add_argument("--row", type=int, default=1); ap.add_argument("--cols", type=int, default=3); ap.add_argument("--rows", type=int, default=4)
ap.add_argument("--flip", action="store_true"); ap.add_argument("--erase-right", type=float, default=0.0)
a = ap.parse_args()
s = Image.open(a.src).convert("RGBA")
cw, ch = s.width // a.cols, s.height // a.rows
f = s.crop((0, ch * a.row, cw, ch * (a.row + 1)))
f = f.crop(f.getchannel("A").getbbox())
if a.flip: f = f.transpose(Image.FLIP_LEFT_RIGHT)
if a.erase_right > 0:
    d = ImageDraw.Draw(f); d.rectangle((int(f.width * (1 - a.erase_right)), int(f.height * 0.35), f.width, f.height), fill=(0, 0, 0, 0))
    f = f.crop(f.getchannel("A").getbbox())
sc = 1000 / f.height
f = f.resize((int(f.width * sc), 1000), Image.LANCZOS)
bg = Image.new("RGBA", (832, 1216), (255, 255, 255, 255))
bg.alpha_composite(f, ((832 - f.width) // 2, 1216 - 60 - f.height))
g = bg.convert("L").filter(ImageFilter.FIND_EDGES)
g = ImageOps.autocontrast(g).point(lambda v: 255 if v > 40 else 0)
g.save(a.out)
