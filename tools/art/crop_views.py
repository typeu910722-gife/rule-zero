#!/usr/bin/env python3
"""三視圖參考表 → 一個一個去背的角色圖（由左到右編號 0、1、2…）。
背景用四邊的顏色判斷（白底、淡色漸層都可以）；太小、太矮（背景裡模糊的小東西）的不算。
用法：python3 tools/art/crop_views.py sheet.png 輸出前綴 [--pick 0,1,3]
  不加 --pick：存成 前綴_0.png、前綴_1.png…，並印出每個的位置，讓人挑。
  加 --pick 0,1,3：依序存成 前綴_front.png、前綴_side.png、前綴_back.png。
"""
import argparse
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("sheet"); ap.add_argument("prefix")
ap.add_argument("--pick", help="正面,側面,背面 的編號")
ap.add_argument("--tol", type=float, default=30)
ap.add_argument("--n", type=int, default=0, help="應該有幾個角色（碰在一起時強制切開）")
a = ap.parse_args()

im = Image.open(a.sheet).convert("RGB")
px = np.asarray(im).astype(float)
h, w, _ = px.shape
# 背景色：每一欄頂端和底端的顏色（處理左右不同的漸層）
top = np.median(px[:12], axis=0)          # (w, 3)
bot = np.median(px[-12:], axis=0)
t = np.linspace(0, 1, h)[:, None, None]
bg = top[None] * (1 - t) + bot[None] * t
diff = np.sqrt(((px - bg) ** 2).sum(axis=2))
fg = diff > a.tol
fg = ndimage.binary_opening(fg, iterations=2)
# 只留和邊框不相連的背景之外的部分，再補洞
lab, n = ndimage.label(~fg)
border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
fg = ~np.isin(lab, list(border))
# 用直的空隙切開（角色常常靠得很近、碰在一起）：每一欄前景的量，低的地方就是空隙
prof = ndimage.uniform_filter1d(fg.sum(axis=0).astype(float), 9)
gap = prof < prof.max() * 0.06
segs = []
x = 0
while x < w:
    if gap[x]:
        x += 1; continue
    x1 = x
    while x < w and not gap[x]:
        x += 1
    if x - x1 > w * 0.05:
        segs.append([x1, x])
# 還不夠 n 個：把最寬的那段從中間附近最瘦的地方切開
while a.n and len(segs) < a.n:
    k = max(range(len(segs)), key=lambda q: segs[q][1] - segs[q][0])
    x1, x2 = segs[k]
    lo, hi = x1 + (x2 - x1) // 4, x2 - (x2 - x1) // 4
    cut = lo + int(np.argmin(prof[lo:hi]))
    segs[k:k + 1] = [[x1, cut], [cut, x2]]
alpha_np = np.asarray(Image.fromarray((fg * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1.0)))
outs = []
for k, (x1, x2) in enumerate(segs):
    col = fg[:, x1:x2]
    ys = np.where(col.any(axis=1))[0]
    if len(ys) == 0 or ys[-1] - ys[0] < h * 0.4:
        continue
    # 這一段裡只留最大的那一塊（丟掉隔壁角色的碎片、沒去乾淨的背景）
    seg_lab, nseg = ndimage.label(col)
    if nseg > 1:
        sizes = ndimage.sum(col, seg_lab, range(1, nseg + 1))
        col = seg_lab == (int(np.argmax(sizes)) + 1)
    ys = np.where(col.any(axis=1))[0]
    xs_ = np.where(col.any(axis=0))[0]
    a_seg = alpha_np[:, x1:x2].copy()
    a_seg[~ndimage.binary_dilation(col, iterations=2)] = 0
    piece = im.convert("RGBA").crop((x1, 0, x2, h))
    piece.putalpha(Image.fromarray(a_seg))
    piece = piece.crop((xs_[0], ys[0], xs_[-1] + 1, ys[-1] + 1))
    outs.append(piece)
    print(f"{len(outs) - 1}: x={x1}-{x2} y={ys[0]}-{ys[-1]}")
if a.pick:
    for name, idx in zip(["front", "side", "back"], [int(v) for v in a.pick.split(",")]):
        outs[idx].save(f"{a.prefix}_{name}.png")
else:
    for k, o in enumerate(outs):
        o.save(f"{a.prefix}_{k}.png")
print(len(outs), "個")
