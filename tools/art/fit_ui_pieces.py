"""ChatGPT 畫的介面零件（白底、幾塊分開的東西）→ 依「面積由大到小」各存一張透明 PNG。

對話框這種很寬的東西不能用格子切（會被從中間切斷），所以改成直接找整張圖裡連在一起的幾塊。
每一塊裡面的洞會補滿（對話框中間的米色不會被當成白底挖掉）。
用法：py -3.11 tools/art/fit_ui_pieces.py <輸入.png> <輸出資料夾> 名字:寬 名字:寬 …（第一個名字＝最大的那塊）
      加 --pos：改成照位置排（由上到下一列一列、每列由左到右），格子大小不平均的零件表用這個。
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from fit_parts_sheet import cutout  # noqa: E402


def fit(src, out_dir, specs, by_pos=False):
    os.makedirs(out_dir, exist_ok=True)
    a = cutout(Image.open(src))
    m = a[..., 3] > 40
    lab, n = ndimage.label(m)
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    order = np.argsort(sizes)[::-1]
    if by_pos:
        h = a.shape[0]
        big = [i for i in range(n) if sizes[i] > sizes.max() * 0.03]
        cents = ndimage.center_of_mass(m, lab, [i + 1 for i in big])
        order = [i for _, i in sorted(zip(cents, big), key=lambda t: (int(t[0][0] // (h * 0.15)), t[0][1]))]
    for spec, idx in zip(specs, order):
        name, _, w = spec.partition(":")
        ys, xs = np.nonzero(lab == idx + 1)
        sl = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
        keep = ndimage.binary_fill_holes(lab[sl] == idx + 1)
        crop = a[sl].copy()
        crop[..., 3] = np.where(keep, 255, 0)
        im = Image.fromarray(crop)
        w = int(w) if w else im.width
        im = im.resize((w, max(1, round(im.height * w / im.width))), Image.LANCZOS)
        im.save(os.path.join(out_dir, name + ".png"))
        print(name, im.size)


if __name__ == "__main__":
    args = [x for x in sys.argv[3:] if x != "--pos"]
    fit(sys.argv[1], sys.argv[2], args, "--pos" in sys.argv)
