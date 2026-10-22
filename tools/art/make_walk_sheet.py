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
ap.add_argument("--match-color", action="store_true", help="把側面、背面的色調對齊正面（推算出來的角度常常偏色）")
a = ap.parse_args()
C = a.cell


def trim(im):
    """只看清楚不透明的部分（去背常留下一圈幾乎透明的雜點），也丟掉離主體很遠的小碎片。"""
    import numpy as np
    from scipy import ndimage
    im = im.convert("RGBA")
    al = np.asarray(im.getchannel("A")) > 128
    lab, n = ndimage.label(al)
    if n > 1:
        sizes = ndimage.sum(al, lab, range(1, n + 1))
        keep = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v >= sizes.max() * 0.05])
        arr = np.asarray(im).copy(); arr[..., 3] = np.where(ndimage.binary_dilation(keep, iterations=2), arr[..., 3], 0)
        im = Image.fromarray(arr); al = keep
    ys, xs = np.where(al)
    return im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)) if len(xs) else im


views = [trim(Image.open(p)) for p in (a.front, a.side, a.back)]
# 每個視角各自縮放到一樣的高度（不同來源的圖，角色在畫面裡的大小不一樣）
H = C * a.height
views = [v.resize((max(1, round(v.width * H / v.height)), round(H)), Image.LANCZOS) for v in views]
views = [v.resize((min(v.width, C - 4), v.height), Image.LANCZOS) if v.width > C - 4 else v for v in views]
if a.match_color:
    import numpy as np
    def stats(v):
        arr = np.asarray(v).astype(float); m = arr[..., 3] > 128
        return arr, m, arr[m][:, :3].mean(0), arr[m][:, :3].std(0) + 1e-3
    _, _, fm, fs = stats(views[0])
    out = [views[0]]
    for v in views[1:]:
        arr, m, mm, ss = stats(v)
        rgb = (arr[..., :3] - mm) / ss * fs + fm
        arr[..., :3] = np.where(m[..., None], np.clip(rgb, 0, 255), arr[..., :3])
        out.append(Image.fromarray(arr.astype("uint8")))
    views = out
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
