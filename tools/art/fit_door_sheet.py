"""ChatGPT 畫的門（2×2、白底）→ 探索地圖用的 4 張透明 PNG（全遊戲美術清單第 4 節 C）。

左上＝正面鎖著、右上＝正面開著、左下＝俯視鎖著、右下＝俯視開著。
俯視的兩張轉成「直的」（牆是上下方向）；ChatGPT 偶爾畫成橫的，就轉 90 度。
輸出：<輸出資料夾>/door_<場景>_front_locked.png、_front_open、_side_locked、_side_open，高 256px。
用法：py -3.11 tools/art/fit_door_sheet.py <輸入.png> <輸出資料夾> <場景，如 school>
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from fit_walk_sheet import cutout  # noqa: E402

NAMES = ["front_locked", "front_open", "side_locked", "side_open"]
H = 256


def pieces(a):
    h, w = a.shape[:2]
    mask = a[..., 3] > 40
    out = []
    for r in range(2):
        for c in range(2):
            y0, y1, x0, x1 = h * r // 2, h * (r + 1) // 2, w * c // 2, w * (c + 1) // 2
            m = mask[y0:y1, x0:x1]
            lab, n = ndimage.label(m)
            if n == 0:
                sys.exit("第 %d 列第 %d 格是空的" % (r + 1, c + 1))
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.05])
            ys, xs = np.nonzero(keep)
            crop = a[y0:y1, x0:x1].copy()
            crop[..., 3] = np.where(keep, crop[..., 3], 0)
            out.append(crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return out


def fit(src, out_dir, theme):
    os.makedirs(out_dir, exist_ok=True)
    for name, p in zip(NAMES, pieces(cutout(Image.open(src)))):
        im = Image.fromarray(p)
        if name.startswith("side") and im.width > im.height:
            im = im.rotate(90, expand=True)
        im = im.resize((max(1, round(im.width * H / im.height)), H), Image.LANCZOS)
        im.save(os.path.join(out_dir, "door_%s_%s.png" % (theme, name)))
    print(theme, "ok")


if __name__ == "__main__":
    fit(sys.argv[1], sys.argv[2], sys.argv[3])
