"""ChatGPT／Codex 畫的 4×4 Q 版走路圖 → 遊戲用的 1280×1280 走路圖（每格 320px）。

ChatGPT 的圖格子不一定整齊，所以每一格各自找出人物，再用同一個縮放比例放回 320×320 的格子：
左右置中（x=160）、腳底在 y=304（explore_art.gd 的 draw_walk 以這一點當腳）。
背景是白色或棋盤格（沒有真的透明）時，從四邊把接近白／灰的顏色挖掉。
用法：py -3.11 tools/art/fit_walk_sheet.py <輸入.png> <輸出.png> [--height 280]
  --height：16 格裡最高的那個人放進格子後的高度（px）
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

CELL, FOOT, CX = 320, 304, 160


def cutout(im):
    """沒有透明時：從邊緣連通的淺色（白、棋盤格的淺灰）當背景挖掉。"""
    a = np.array(im.convert("RGBA"))
    if (a[..., 3] == 0).mean() > 0.2:     # 真的透明
        return a
    # 白底、棋盤格，或 ChatGPT 偶爾給的「半透明白底」（alpha 約 140）：先疊在白色上再挖
    al = a[..., 3:4].astype(float) / 255
    rgb = (a[..., :3] * al + 255 * (1 - al)).astype(int)
    light = (rgb.min(-1) > 200) & (rgb.max(-1) - rgb.min(-1) < 18)
    lab, _ = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    a[..., 3] = np.where(bg, 0, 255)
    return a


def figures(a):
    """依 4×4 大致位置，每格取最大的一塊不透明區（含跟它重疊的小塊，如頭髮、手）。"""
    h, w = a.shape[:2]
    mask = a[..., 3] > 40
    out = []
    for r in range(4):
        for c in range(4):
            y0, y1, x0, x1 = h * r // 4, h * (r + 1) // 4, w * c // 4, w * (c + 1) // 4
            m = mask[y0:y1, x0:x1]
            lab, n = ndimage.label(m)
            if n == 0:
                sys.exit("第 %d 列第 %d 格是空的" % (r + 1, c + 1))
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.02])
            ys, xs = np.nonzero(keep)
            crop = a[y0:y1, x0:x1].copy()
            crop[..., 3] = np.where(keep, crop[..., 3], 0)
            out.append(crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return out


def fit(src, dst, height=280):
    figs = figures(cutout(Image.open(src)))
    s = height / max(f.shape[0] for f in figs)
    s = min(s, 200 / max(f.shape[1] for f in figs))   # 寬度也不能太寬（測試要求在 x 90～235 之間）
    sheet = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    for i, f in enumerate(figs):
        im = Image.fromarray(f)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        r, c = divmod(i, 4)
        sheet.paste(im, (c * CELL + CX - im.width // 2, r * CELL + FOOT - im.height), im)
    sheet.save(dst)


if __name__ == "__main__":
    args, opts, it = [], {}, iter(sys.argv[1:])
    for x in it:
        if x.startswith("--"):
            opts[x] = next(it)
        else:
            args.append(x)
    fit(args[0], args[1], int(opts.get("--height", 280)))
