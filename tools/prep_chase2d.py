#!/usr/bin/env python3
"""追逐戰（裸眼 3D 版）素材整理：從美術交件包 → game/art/chase2d/

  python3 tools/prep_chase2d.py <交件包解壓後的 RuleZero_2D_Depth 資料夾>

做的事：
  1. 背景 bg_chase_depth.jpg：把遠方招牌的「修理室」改寫成「三年二班」（鎮長從學校追出來；
     修理室的門在鏡頭這一邊）。
  2. 依背景的一點透視，算出深度圖 bg_chase_depth_z.png（每個像素離鏡頭多遠），
     遊戲用它做視差：鏡頭左右移、上下晃的時候，近的東西動得多、遠的動得少。
  3. 道具、門縮到遊戲用得到的大小（太大的圖會讓網頁版變慢）。
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SRC = Path(sys.argv[1]) / "game/art/chase2d"
OUT = Path("game/art/chase2d")
FONT = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"

# 背景的幾何（1280×720 畫面座標；背景原圖 1920×1080 縮成 2/3）
VP = (877.0, 466.0)     # 消失點：遠方的大門
F = 425.0               # 焦距（像素）
CAM_H = 1.3             # 鏡頭高度（公尺）
CAM_X = 1.41            # 鏡頭在街道中線右邊多遠
WALL_L = -4.0           # 左邊房子的牆（離街道中線）
WALL_R = 3.5            # 右邊房子的牆
FAR = 45.0              # 最遠（天空、遠方城堡）


def patch_sign(im: Image.Image) -> Image.Image:
    im = im.copy()
    a = np.asarray(im).astype(float)
    x0, x1, y0, y1 = 1262, 1372, 566, 604
    # 招牌底色：用字的上下兩條補起來
    top = a[y0 - 4:y0 - 1, x0:x1].mean(axis=0)
    bot = a[y1 + 1:y1 + 4, x0:x1].mean(axis=0)
    for i, y in enumerate(range(y0, y1)):
        t = i / (y1 - y0 - 1)
        a[y, x0:x1] = top * (1 - t) + bot * t
    noise = np.random.default_rng(2).normal(0, 3, (y1 - y0, x1 - x0, 1))
    a[y0:y1, x0:x1] += noise
    im = Image.fromarray(np.clip(a, 0, 255).astype("uint8"))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 26, index=3)
    text = "三年二班"
    w = d.textlength(text, font=f)
    d.text(((x0 + x1) / 2 - w / 2, y0 + 3), text, font=f, fill=(66, 40, 28))
    return im.filter(ImageFilter.SMOOTH) if False else im


def depth_map() -> Image.Image:
    """每個像素的 1/距離（0＝無限遠，越亮越近），1280×720 → 存成 640×360。"""
    W, H = 640, 360
    s = 1280 / W
    yy, xx = np.mgrid[0:H, 0:W]
    sx = (xx + 0.5) * s
    sy = (yy + 0.5) * s
    inv = np.full((H, W), 1 / FAR)
    floor = np.where(sy > VP[1], (sy - VP[1]) / (F * CAM_H), 0)
    left = np.where(sx < VP[0], (sx - VP[0]) / (F * (WALL_L - CAM_X)), 0)
    right = np.where(sx > VP[0], (sx - VP[0]) / (F * (WALL_R - CAM_X)), 0)
    inv = np.maximum.reduce([inv, floor, left, right])
    inv = np.clip(inv, 0, 0.6)
    img = Image.fromarray((inv / 0.6 * 255).astype("uint8"))
    return img.filter(ImageFilter.GaussianBlur(3))


def fit(name: str, src: Path, max_side: int) -> None:
    im = Image.open(src)
    if max(im.size) > max_side:
        k = max_side / max(im.size)
        im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    im.save(OUT / name, optimize=True)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    bg = Image.open(SRC / "backgrounds/bg_chase_depth.jpg").convert("RGB")
    patch_sign(bg.resize((1920, 1080))).save(OUT / "bg.jpg", quality=90)
    depth_map().save(OUT / "bg_z.png")
    ch = SRC / "characters"
    for n in ["bu_run_00", "bu_run_01", "bu_run_02", "bu_run_03", "mayor_run_00", "mayor_run_01", "mayor_run_02", "mayor_run_03"]:
        shutil.copy(ch / f"chase_{n}.png", OUT / f"{n}.png")
    for n in ["bu_caught", "bu_idle", "bu_open_door", "mayor_grab", "mayor_twitch", "mayor_rise", "mayor_run"]:
        fit(f"{n}.png", ch / f"chase_{n}.png", 512)
    pr = SRC / "props"
    fit("needle.png", pr / "prop_needle.png", 512)
    fit("lamp.png", pr / "prop_lamp.png", 640)
    fit("cotton.png", pr / "prop_cotton.png", 640)
    fit("nametags.png", pr / "prop_nametags.png", 1024)
    fit("bench.png", pr / "prop_bench.png", 640)
    fit("noticeboard.png", pr / "prop_noticeboard.png", 640)
    fit("door.png", SRC / "kits/kit_repair_door.png", 900)
    print("ok", sorted(p.name for p in OUT.iterdir()))


if __name__ == "__main__":
    main()
