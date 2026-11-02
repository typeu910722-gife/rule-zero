"""ChatGPT／Codex 出的人類時期半身立繪 → 遊戲用的 512×768 透明 PNG。

對齊方式和外包第一批一樣：人物左右置中，頭頂離上緣約 9%，身體往下延伸到畫面底部（半身圖下緣直接切掉）。
用法：py -3.11 tools/art/fit_human_portrait.py <輸入.png> <輸出.png> [--head 0.09] [--width 0.98]
  --head：頭頂到上緣的距離（畫布高度的比例）
  --width：人物（含手臂）最寬處佔畫布寬度的比例上限
"""
import sys

import numpy as np
from PIL import Image

W, H = 512, 768


def fit(src, dst, head=0.09, width=0.98):
    im = Image.open(src).convert("RGBA")
    a = np.array(im)[..., 3]
    ys, xs = np.nonzero(a > 40)
    if len(xs) == 0:
        sys.exit("圖是空的（沒有不透明的地方）：" + src)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    # 以「頭頂到人物最下面」的高度縮放，讓身體填滿到畫布底部
    s = (H * (1 - head)) / (y1 - y0 + 1)
    s = min(s, W * width / (x1 - x0 + 1))
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    cx = (x0 + x1) / 2 * s
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    c.paste(im, (round(W / 2 - cx), round(H * head - y0 * s)), im)   # paste 可以超出畫布（alpha_composite 不行）
    c.save(dst)


if __name__ == "__main__":
    args, opts, it = [], {}, iter(sys.argv[1:])
    for x in it:
        if x.startswith("--"):
            opts[x] = next(it)
        else:
            args.append(x)
    fit(args[0], args[1], float(opts.get("--head", 0.09)), float(opts.get("--width", 0.98)))
