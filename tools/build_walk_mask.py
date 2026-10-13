#!/usr/bin/env python3
"""從小鎮地圖產生「可以走的地方」遮罩：game/art/walk_mask.png

規則：米色的石板路＝可以走；草地、花圃、樹、房子、圍籬、河＝不能走。
另外手動補上顏色抓不到、但應該可以走的地方（樓梯、橋）。
只保留跟火車站連通的那一大塊，避免地圖邊緣零碎的米色區域。

用法：python3 tools/build_walk_mask.py
"""
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageFilter

SRC = "game/art/town_map.png"
OUT = "game/art/walk_mask.png"

# 手動補上可以走的地方（地圖原圖座標：x, y, w, h）
EXTRA = [
    (703, 374, 74, 102),   # 鎮長公館的樓梯與門前平台
    (555, 198, 44, 72),    # 鐘塔的樓梯
    (995, 658, 228, 42),   # 石橋
    (615, 150, 290, 52),   # 鎮長公館後面的空地（修理室門前）
    (585, 182, 45, 30),    # 鐘塔樓梯頂端 → 空地
    (183, 560, 60, 32),    # 小布家門口的台階
    (430, 1040, 500, 22),  # 火車站前的走道（月台屋頂上方，接到左邊的路）
    (480, 858, 200, 36),   # 車站屋頂上方的路（廣場 → 車站左邊）
]
# 強制不能走的地方（地圖上是石板，但走進去會站到物件「後面」，看起來像踩在上面）
BLOCK = [
    (556, 492, 114, 84),   # 公告欄與後面的小石板
    (512, 540, 58, 66),    # 公告欄左邊的熊雕像
    (656, 540, 58, 66),    # 公告欄右邊的熊雕像
    (590, 378, 113, 26),   # 鎮長公館前的矮牆頂（樓梯左邊）
    (777, 378, 113, 26),   # 鎮長公館前的矮牆頂（樓梯右邊）
    (112, 328, 218, 48),   # 露露家前面的白色圍籬
    # 建築物的米色牆面（顏色跟石板路很像，要特別擋掉）
    (535, 20, 90, 172),    # 鐘塔
    (700, 80, 180, 96),    # 修理室
    (1040, 190, 120, 118), # 鏡之屋
    (865, 470, 145, 106),  # 郵局
    (70, 690, 170, 128),   # 居民小屋（紅）
    (300, 725, 175, 128),  # 居民小屋（紫）
    (495, 895, 375, 128),  # 火車站
    (422, 1056, 196, 36),  # 月台的屋頂
    (615, 215, 250, 150),  # 鎮長公館
    (165, 160, 240, 168),  # 露露的家
    (45, 405, 235, 138),   # 小布的住處
]
# 從這裡開始找連通區域（火車站前月台）
SEED = (678, 1080)


def main() -> None:
    im = np.asarray(Image.open(SRC).convert("RGB")).astype(float) / 255
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mx = im.max(-1)
    mn = im.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = d / (mx + 1e-6)
    m = (h >= 18) & (h <= 50) & (s > 0.10) & (s < 0.5) & (mx > 0.80)
    img = Image.fromarray((m * 255).astype("uint8"))
    img = img.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    a = np.asarray(img) > 127
    a = a.copy()
    for x, y, w, hh in EXTRA:
        a[y:y + hh, x:x + w] = True
    for x, y, w, hh in BLOCK:
        a[y:y + hh, x:x + w] = False
    # 連通區域
    H, W = a.shape
    keep = np.zeros_like(a)
    q = deque([SEED[::-1]])
    if not a[SEED[1], SEED[0]]:
        sys.exit("起點不在路上")
    keep[SEED[1], SEED[0]] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and a[ny, nx] and not keep[ny, nx]:
                keep[ny, nx] = True
                q.append((ny, nx))
    # 邊緣放寬一點（約 4 個原圖像素），轉角和窄路比較好走
    # 邊緣放寬（約 12 個原圖像素）：路邊的草地也可以走，轉角和窄路不會一直被卡住
    keep_img = Image.fromarray((keep * 255).astype("uint8")).filter(ImageFilter.MaxFilter(25))
    for x, y, w, hh in BLOCK:
        keep_img.paste(0, (x, y, x + w, y + hh))
    # 一半解析度就夠了（每格 2 個原圖像素）
    out = keep_img.resize((W // 2, H // 2), Image.NEAREST)
    out.save(OUT, optimize=True)
    print("寫入", OUT, out.size, "可走比例 %.1f%%" % (100 * keep.mean()))


def forest() -> None:
    """森林地圖（game/art/forest_map.jpg）：土黃色的小徑可以走。"""
    src = "game/art/forest_map.jpg"
    im = np.asarray(Image.open(src).convert("RGB")).astype(float) / 255
    r, g, b = im[..., 0], im[..., 1], im[..., 2]
    mx = im.max(-1)
    mn = im.min(-1)
    d = mx - mn + 1e-6
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = d / (mx + 1e-6)
    m = (h >= 20) & (h <= 48) & (s > 0.18) & (s < 0.55) & (mx > 0.78)
    img = Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.MedianFilter(7))
    img = img.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    a = (np.asarray(img) > 127).copy()
    for x, y, w, hh in [(500, 370, 80, 70)]:   # 往左的岔路接回主路
        a[y:y + hh, x:x + w] = True
    H, W = a.shape
    seed = (770, 1050)
    keep = np.zeros_like(a)
    q = deque([(seed[1], seed[0])])
    keep[seed[1], seed[0]] = True
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and a[ny, nx] and not keep[ny, nx]:
                keep[ny, nx] = True
                q.append((ny, nx))
    out = Image.fromarray((keep * 255).astype("uint8")).filter(ImageFilter.MaxFilter(9))
    out = out.resize((W // 2, H // 2), Image.NEAREST)
    out.save("game/art/forest_mask.png", optimize=True)
    print("寫入 game/art/forest_mask.png", out.size, "可走比例 %.1f%%" % (100 * keep.mean()))


if __name__ == "__main__":
    main()
    forest()
