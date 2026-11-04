"""ChatGPT／Codex 畫的劇情 CG → 遊戲用的 2560×1440 JPG（16:9，不透明）。

ChatGPT 的橫幅圖通常是 3:2（1536×1024），這裡從中間裁成 16:9；--top 可以把裁切往上移
（0＝貼上緣、0.5＝置中），因為畫面下方 1/3 會被對話框蓋住，重要的東西要留在上面。
用法：py -3.11 tools/art/fit_cg.py <輸入.png> <輸出.jpg> [--top 0.5]
"""
import sys

from PIL import Image

W, H = 2560, 1440


def fit(src, dst, top=0.5):
    im = Image.open(src).convert("RGB")
    w, h = im.size
    if w / h > W / H:          # 太寬：裁左右
        nw = round(h * W / H)
        x = (w - nw) // 2
        im = im.crop((x, 0, x + nw, h))
    else:                      # 太高：裁上下
        nh = round(w * H / W)
        y = round((h - nh) * top)
        im = im.crop((0, y, w, y + nh))
    im.resize((W, H), Image.LANCZOS).save(dst, quality=92)


if __name__ == "__main__":
    args, opts, it = [], {}, iter(sys.argv[1:])
    for x in it:
        if x.startswith("--"):
            opts[x] = next(it)
        else:
            args.append(x)
    fit(args[0], args[1], float(opts.get("--top", 0.5)))
