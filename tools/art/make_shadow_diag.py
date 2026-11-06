"""第四章「影子」的斜向走路圖：用遙的斜向圖（h_haruka_diag）做成和 h_shadow 一樣的半透明暗藍灰人影。
高度照 h_shadow 原本最高的那格；輸出 640×640（每格 160px，和 h_shadow 一樣）。
用法：py -3.11 tools/art/make_shadow_diag.py
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fit_diag_sheet import tallest  # noqa: E402

W = Path(__file__).resolve().parents[2] / "game/art/walk4"
src = Image.open(W / "h_haruka_diag.png").convert("RGBA")
k = tallest(W / "h_shadow.png") / tallest(W / "h_haruka_diag.png")
big = Image.new("RGBA", src.size, (0, 0, 0, 0))
for r in range(4):
    for c in range(4):
        cell = src.crop((c * 320, r * 320, (c + 1) * 320, (r + 1) * 320))
        cell = cell.resize((round(320 * k), round(320 * k)), Image.LANCZOS)
        # 腳 (160, 304) 對回原位
        big.alpha_composite(cell, (c * 320 + round(160 - 160 * k), r * 320 + round(304 - 304 * k)))
small = big.resize((640, 640), Image.LANCZOS)
arr = np.array(small).astype(float)
alpha = arr[..., 3] / 255.0
lum = arr[..., :3].mean(axis=2) / 255.0
col = np.zeros_like(arr)
col[..., :3] = np.array([38, 46, 60], float) * (0.85 + 0.3 * lum[..., None])
col[..., 3] = np.clip(alpha * 0.62, 0, 1) * 255
Image.fromarray(col.astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(1.2)).save(W / "h_shadow_diag.png")
print("完成", W / "h_shadow_diag.png")
