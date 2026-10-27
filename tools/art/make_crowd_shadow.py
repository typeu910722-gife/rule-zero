"""第四章的群眾與「影子」走路圖（從已經逐格檢查過的走路圖組合）。
  crowd：三個沒有名字的同學站成一小群（每格三個人；女生在後面、兩個男生在前面左右）。WALK_SCALE 要配 0.69（每個人約跟同學一樣高）。
  shadow：「那一天之後」「第一個晚上」的你——像影子一樣走過那些地方，沒有人看得到（docs/script/chapter4.md 4、8 節）。
          用一個同學的輪廓，變成半透明的暗藍灰色人影，看不到臉和衣服。
用法：py -3.11 tools/art/make_crowd_shadow.py <stu_a.png> <stu_b.png> <stu_c.png> <輸出 crowd.png> <輸出 shadow.png>
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

A, B, C, OUT_CROWD, OUT_SHADOW = sys.argv[1:6]
CELL = 160
a, b, c = (Image.open(p).convert("RGBA") for p in (A, B, C))

# ── 群眾：每一格，三個人縮成 0.8 倍，後面的先畫 ──
crowd = Image.new("RGBA", a.size, (0, 0, 0, 0))
S = 0.8
for r in range(4):
    for f in range(4):
        box = (f * CELL, r * CELL, (f + 1) * CELL, (r + 1) * CELL)
        cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        # (圖, x 位移, y 位移)：腳底對齊在 152，後面的人高一點（站在後面）
        for src, dx, dy in ((b, 0, -10), (a, -36, 0), (c, 36, 2)):
            p = src.crop(box).resize((int(CELL * S), int(CELL * S)), Image.LANCZOS)
            x = int(CELL / 2 - p.width / 2 + dx)
            y = int(152 - 152 * S + dy)
            cell.alpha_composite(p, (max(0, x), max(0, y)) if x >= 0 else (0, y))
        crowd.paste(cell, box[:2])
crowd.save(OUT_CROWD)

# ── 影子 ──
arr = np.array(c).astype(float)
alpha = arr[..., 3] / 255.0
lum = arr[..., :3].mean(axis=2) / 255.0
col = np.zeros_like(arr)
base = np.array([38, 46, 60], float)
col[..., :3] = base * (0.85 + 0.3 * lum[..., None])      # 一點點明暗，看得出是人形
col[..., 3] = np.clip(alpha * 0.62, 0, 1) * 255
sh = Image.fromarray(col.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(1.2))
sh.save(OUT_SHADOW)
print("完成", OUT_CROWD, OUT_SHADOW)
