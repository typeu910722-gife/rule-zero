"""把出圖結果整理成遊戲立繪：只留最大的一塊（清掉去背殘渣），裁邊後等比例放進固定畫布，腳底貼齊下緣。
用法：py -3.11 tools/art/fit_portrait.py <輸入.png> <輸出.png> [寬x高，預設 512x768] [--margin 4]"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage


def keep_main(im):
    a = np.array(im)
    mask = a[..., 3] > 40
    lab, n = ndimage.label(mask)
    if n > 1:
        sizes = ndimage.sum(mask, lab, range(1, n + 1))
        big = np.argmax(sizes) + 1
        keep = ndimage.binary_dilation(lab == big, iterations=3)
        # 夠大的其他區塊（例如分開的老鷹、手）也留下
        for i, s in enumerate(sizes, 1):
            if s > sizes.max() * 0.03:
                keep |= lab == i
        a[..., 3] = np.where(keep, a[..., 3], 0)
    return Image.fromarray(a)


def fit(src, dst, size="512x768", margin=4):
    W, H = (int(x) for x in size.split("x"))
    im = keep_main(Image.open(src).convert("RGBA"))
    im = im.crop(im.getbbox())
    s = min((W - 2 * margin) / im.width, (H - 2 * margin) / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    c = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    c.alpha_composite(im, ((W - im.width) // 2, H - im.height - margin))
    c.save(dst)


if __name__ == "__main__":
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    fit(args[0], args[1], args[2] if len(args) > 2 else "512x768")
