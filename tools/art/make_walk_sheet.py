#!/usr/bin/env python3
"""三張去背的視角圖（正面、側面朝左、背面）→ 四方向走路圖（照小布的 ch2_pip_sprite_walk_sheet.png）。
4 列：下（正面）、左、右（側面左右翻）、上（背面）；每列 4 格，每格 160px。
玩偶走路是左右搖擺：第 1、3 格站直，第 2、4 格往兩邊歪一點、身體抬高一點、壓扁一點。
用法：python3 tools/art/make_walk_sheet.py front.png side.png back.png out.png [--cell 160] [--side-faces right]
"""
import argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("front"); ap.add_argument("side"); ap.add_argument("back"); ap.add_argument("out")
ap.add_argument("--cell", type=int, default=160)
ap.add_argument("--side-faces", choices=["left", "right"], default="left", help="側面圖的角色朝哪邊")
ap.add_argument("--height", type=float, default=0.9, help="角色佔一格高度的比例")
a = ap.parse_args()
C = a.cell


def trim(im):
    im = im.convert("RGBA")
    box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
    return im.crop(box) if box else im


views = [trim(Image.open(p)) for p in (a.front, a.side, a.back)]
# 三個視角用同一個縮放（以最高的那張為準），大小才一致
scale = C * a.height / max(v.height for v in views)
views = [v.resize((max(1, round(v.width * scale)), max(1, round(v.height * scale))), Image.LANCZOS) for v in views]
front, side, back = views
left = side if a.side_faces == "left" else side.transpose(Image.FLIP_LEFT_RIGHT)
right = left.transpose(Image.FLIP_LEFT_RIGHT)

# 每格：（傾斜角度、往上抬幾 px、高度壓扁比例）
STEPS = [(0, 0, 1.0), (-4, 3, 0.97), (0, 0, 1.0), (4, 3, 0.97)]
FOOT = C - 8  # 腳底的 y（和 ExploreArt 的腳底位置一致：160 → 152）

sheet = Image.new("RGBA", (C * 4, C * 4), (0, 0, 0, 0))
for row, img in enumerate([front, left, right, back]):
    for col, (deg, lift, squash) in enumerate(STEPS):
        f = img.resize((img.width, max(1, round(img.height * squash))), Image.LANCZOS)
        f = f.rotate(deg, resample=Image.BICUBIC, expand=True)
        x = col * C + (C - f.width) // 2
        y = row * C + FOOT - f.height - lift
        sheet.alpha_composite(f, (max(col * C, x), max(row * C, y)))
sheet.save(a.out)
print("完成", a.out, sheet.size)
