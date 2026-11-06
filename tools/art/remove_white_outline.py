"""ChatGPT 走路圖常常有「貼紙白邊」（人物外圍、頭髮縫隙裡的純白），fit_walk_sheet.py 只挖得掉跟外框連通的白。
這支把整張圖裡的純白大塊（≥25px）和白邊旁邊的半白像素拿掉；白襯衫（偏粉、偏灰）不會被拿掉。
用法：py -3.11 tools/art/remove_white_outline.py game/art/walk4/<id>.png [更多檔案…]
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

for p in sys.argv[1:]:
    a = np.array(Image.open(p).convert("RGBA"))
    rgb = a[..., :3].astype(int)
    white = (a[..., 3] > 0) & (rgb.min(-1) > 240) & (rgb.max(-1) - rgb.min(-1) < 10)
    lab, k = ndimage.label(white)
    sz = ndimage.sum(white, lab, range(1, k + 1))
    big = np.isin(lab, np.where(sz >= 25)[0] + 1)
    a[..., 3][big] = 0
    for _ in range(2):
        rgb = a[..., :3].astype(int)
        near = ndimage.binary_dilation(a[..., 3] == 0, iterations=1) & (a[..., 3] > 0)
        pale = near & (rgb.min(-1) > 215) & (rgb.max(-1) - rgb.min(-1) < 16)
        a[..., 3][pale] = 0
    Image.fromarray(a).save(p)
    print(p, int(big.sum()), "px")
