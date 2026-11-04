"""ChatGPT 畫的追逐戰動作表（4 欄 × 3 列、白底）→ 12 張 512×512 透明 PNG（需求 v2 第 2-4 節）。

第 1、2 列＝run_00～07，第 3 列＝idle、look_back、stumble、breath。
每一格各自找出人物，12 格用同一個縮放比例；腳底在 y=488，身體（頭＋上半身）的中心在 x=256。
用法：py -3.11 tools/art/fit_chase_sheet.py <輸入.png> <輸出資料夾> <前綴，如 h_haruka_chase_uniform>
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from fit_walk_sheet import cutout  # noqa: E402
from scipy import ndimage  # noqa: E402

CELL, FOOT, CX = 512, 488, 256
MAX_H, MAX_W = 440, 480
POSES = ["run_%02d" % i for i in range(8)] + ["idle", "look_back", "stumble", "breath"]


def figures(a):
    h, w = a.shape[:2]
    mask = a[..., 3] > 40
    out = []
    for r in range(3):
        for c in range(4):
            y0, y1, x0, x1 = h * r // 3, h * (r + 1) // 3, w * c // 4, w * (c + 1) // 4
            m = mask[y0:y1, x0:x1]
            lab, n = ndimage.label(m)
            if n == 0:
                sys.exit("第 %d 列第 %d 格是空的" % (r + 1, c + 1))
            sizes = ndimage.sum(m, lab, range(1, n + 1))
            # 只留人：最大的一塊＋夠大的碎塊（頭髮、手）；喘氣的小符號、汗滴丟掉
            keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s > sizes.max() * 0.05])
            ys, xs = np.nonzero(keep)
            crop = a[y0:y1, x0:x1].copy()
            crop[..., 3] = np.where(keep, crop[..., 3], 0)
            out.append(crop[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return out


def body_cx(f):
    """頭＋上半身（上面 40%）的不透明像素平均 x：跑步時腳前後擺，用這個當身體中心線。"""
    top = f[: max(1, int(f.shape[0] * 0.4)), :, 3] > 40
    xs = np.nonzero(top)[1]
    return xs.mean() if len(xs) else f.shape[1] / 2


def fit(src, out_dir, prefix):
    figs = figures(cutout(Image.open(src)))
    s = min(MAX_H / max(f.shape[0] for f in figs), MAX_W / max(f.shape[1] for f in figs))
    os.makedirs(out_dir, exist_ok=True)
    for pose, f in zip(POSES, figs):
        im = Image.fromarray(f)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        x = round(CX - body_cx(f) * s)
        x = min(max(x, 0), CELL - im.width)
        cell.alpha_composite(im, (x, FOOT - im.height))
        cell.save(os.path.join(out_dir, "%s_%s.png" % (prefix, pose)))
    print("%s：12 張，縮放 %.3f" % (prefix, s))


if __name__ == "__main__":
    fit(sys.argv[1], sys.argv[2], sys.argv[3])
