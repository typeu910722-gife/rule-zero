#!/usr/bin/env python3
"""外包交的條碼小人 s2／s1（2 條、1 條斑紋）畫錯了（斑紋數跟 s3 一樣多）。
在外包修好之前，從 3 條斑紋的小人圖（ch2_tiaoma_sprite_sheet.png）把下面的斑紋「洗掉」，
產生 s2、s1。用法：python3 tools/derive_tiaoma_stripes.py"""
from pathlib import Path
from PIL import Image

D = Path(__file__).resolve().parent.parent / "game/art/ch2/characters/sprites"
src = Image.open(D / "ch2_tiaoma_sprite_sheet.png").convert("RGBA")
px = src.load()
# 軀幹的範圍（160×160 一格）
X0, X1, Y0, Y1 = 50, 102, 86, 128


def dark(p):
    return p[3] > 200 and (p[0] + p[1] + p[2]) / 3 < 115


rows = [y for y in range(Y0, Y1) if sum(dark(px[x, y]) for x in range(X0, X1)) > 8]
bands = []
for y in rows:
    if bands and y - bands[-1][-1] <= 1:
        bands[-1].append(y)
    else:
        bands.append([y])
bands = [b for b in bands if len(b) >= 2]
assert len(bands) >= 3, bands
print(bands)
cream = [px[x, y] for x in range(X0, X1) for y in range(Y0, Y1) if px[x, y][3] > 200 and sum(px[x, y][:3]) / 3 > 190]
cr = tuple(sum(c[i] for c in cream) // len(cream) for i in range(3))
for keep, name in ((2, "s2"), (1, "s1")):
    im = src.copy()
    q = im.load()
    for b in bands[keep:]:
        ys = range(b[0] - 2, b[-1] + 3)
        for x in range(X0, X1):
            # 這一欄斑紋上方（兩條斑紋之間）的米色，當作洗掉後的顏色
            ref = None
            for y in range(b[0] - 3, Y0 - 12, -1):
                r = q[x, y]
                if r[3] > 200 and sum(r[:3]) / 3 > 170:
                    ref = r
                    break
            if ref is None:
                ref = cr
            for y in ys:
                p = q[x, y]
                l = sum(p[:3]) / 3
                if p[3] > 200 and l < 175:
                    # 越黑越換成米色；邊緣的半調子按比例混合
                    t = min(1.0, (175 - l) / 60)
                    q[x, y] = tuple(int(p[i] * (1 - t) + ref[i] * t) for i in range(3)) + (p[3],)
    im.save(D / f"ch2_tiaoma_sprite_{name}_sheet.png", optimize=True)
    print(name, "去掉", len(bands) - keep, "條")
