"""ChatGPT 畫的零件表（N 欄 × M 列、白底）→ 每格一張透明 PNG（小遊戲零件、道具）。

每一格各自找出物件（最大的一塊＋夠大的碎塊），切掉白底、裁到物件邊緣，
再縮到「最長邊＝指定像素」。名字照格子順序（左到右、上到下），名字是 "-" 的格子跳過。
用法：py -3.11 tools/art/fit_parts_sheet.py <輸入.png> <輸出資料夾> <欄> <列> <最長邊> 名字1 名字2 …
      名字可以寫成 name:長邊 個別指定大小；結尾加 ! ＝把物件裡面的洞補滿（白色的棉花）。
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))


def cutout(im, lo=246, spread=8):
    """白底挖掉：只挖「跟邊緣連通、很白」的地方（比走路圖的 cutout 嚴格，白色的棉花、床單才不會被挖掉）。
    名字後面加 ! 的格子另外補洞（整塊白的東西，如棉花）。"""
    a = np.array(im.convert("RGBA"))
    rgb = a[..., :3].astype(int)
    light = (rgb.min(-1) > lo) & (rgb.max(-1) - rgb.min(-1) < spread)
    lab, _ = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    a[..., 3] = np.where(np.isin(lab, list(edge)), 0, 255)
    return a


def pieces(a, cols, rows, fill=()):
    h, w = a.shape[:2]
    mask = a[..., 3] > 40
    out = []
    for r in range(rows):
        for c in range(cols):
            y0, y1, x0, x1 = h * r // rows, h * (r + 1) // rows, w * c // cols, w * (c + 1) // cols
            m = mask[y0:y1, x0:x1]
            if r * cols + c in fill:
                m = ndimage.binary_fill_holes(ndimage.binary_closing(m, iterations=3))
            lab, n = ndimage.label(m)
            if n == 0:
                out.append(None)
                continue
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.05])
            ys, xs = np.nonzero(keep)
            crop = a[y0:y1, x0:x1].copy()
            crop[..., 3] = np.where(keep, 255 if r * cols + c in fill else crop[..., 3], 0)
            out.append(crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return out


def fit(src, out_dir, cols, rows, size, names):
    os.makedirs(out_dir, exist_ok=True)
    fill = {i for i, n in enumerate(names) if n.endswith("!")}
    for spec, p in zip(names, pieces(cutout(Image.open(src)), cols, rows, fill)):
        if spec == "-":
            continue
        name, _, s = spec.rstrip("!").partition(":")
        s = int(s) if s else size
        if p is None:
            sys.exit("%s 那一格是空的" % name)
        im = Image.fromarray(p)
        k = s / max(im.width, im.height)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
        im.save(os.path.join(out_dir, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    a = sys.argv
    fit(a[1], a[2], int(a[3]), int(a[4]), int(a[5]), a[6:])
