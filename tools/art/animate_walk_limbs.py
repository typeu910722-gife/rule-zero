#!/usr/bin/env python3
"""把四方向站姿圖做成真正有四肢跨步的 4×4 走路 sheet。

舊版 make_walk_sheet 只是整隻角色左右傾斜；這支工具會切出左右手腳，
以肩、髖為軸反向擺動，再把身體蓋回關節，讓跟隨角色和小布一樣有跨步。
"""
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "game/art/walk4"
IDS = [
    "lulu", "mochi", "popo", "fen", "baimian", "xiaoji", "zhongzhong",
    "gaga", "youyou", "staff", "h_nurse", "h_graduate", "conductor", "dove",
]
CELL = 160


def mask_image(im, mask):
    a = np.asarray(im).copy()
    a[..., 3] = np.where(mask, a[..., 3], 0)
    return Image.fromarray(a)


def clear_mask(im, mask):
    a = np.asarray(im).copy()
    a[..., 3] = np.where(mask, 0, a[..., 3])
    return Image.fromarray(a)


def animated_frame(src, phase):
    if phase == 0:
        return src.copy()
    a = np.asarray(src)
    alpha = a[..., 3] > 35
    ys, xs = np.where(alpha)
    if not len(xs):
        return src.copy()
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    cx = (x0 + x1) / 2
    width, height = x1 - x0 + 1, y1 - y0 + 1
    shoulder = y0 + height * .39
    hip = y0 + height * .66

    yy, xx = np.mgrid[:CELL, :CELL]
    # 手臂：身體外側、肩膀到髖部；腳：髖部以下的左右半邊。
    arm_band = (yy >= shoulder) & (yy < hip + height * .09)
    left_arm = alpha & arm_band & (xx < cx - width * .16)
    right_arm = alpha & arm_band & (xx > cx + width * .16)
    left_leg = alpha & (yy >= hip) & (xx < cx - 1)
    right_leg = alpha & (yy >= hip) & (xx >= cx + 1)
    # 關節多取 1px，旋轉後不會留下透明裂縫。
    masks = [ndimage.binary_dilation(m, iterations=1) & alpha for m in (left_arm, right_arm, left_leg, right_leg)]
    remove = np.logical_or.reduce(masks)
    body = clear_mask(src, remove)
    out = Image.new("RGBA", (CELL, CELL))
    angles = [
        -phase * 10, phase * 10,   # 左右手反向擺
        phase * 8, -phase * 8,     # 左右腳反向跨
    ]
    centers = [
        (cx - width * .22, shoulder),
        (cx + width * .22, shoulder),
        (cx - width * .12, hip),
        (cx + width * .12, hip),
    ]
    # 四肢在身體後面，關節由身體蓋住。
    for m, deg, center in zip(masks, angles, centers):
        limb = mask_image(src, m)
        limb = limb.rotate(deg, Image.Resampling.BICUBIC, center=center)
        out.alpha_composite(limb)
    out.alpha_composite(body)
    # 落腳幀微微下降，跨步幀身體抬高；腳底位置仍維持在 152px 內。
    lifted = Image.new("RGBA", (CELL, CELL))
    lifted.alpha_composite(out, (0, -2))
    return lifted


def animate(path):
    old = Image.open(path).convert("RGBA")
    if old.size != (CELL * 4, CELL * 4):
        raise ValueError(f"{path}: 預期 640×640，得到 {old.size}")
    sheet = Image.new("RGBA", old.size)
    # 每一列第一格一定是中立站姿；1、3 格做相反跨步，2 格回中立。
    for row in range(4):
        neutral = old.crop((0, row * CELL, CELL, (row + 1) * CELL))
        for col, phase in enumerate((0, -1, 0, 1)):
            frame = animated_frame(neutral, phase)
            sheet.alpha_composite(frame, (col * CELL, row * CELL))
    sheet.save(path, optimize=True)


def main():
    for char_id in IDS:
        path = DIR / f"{char_id}.png"
        animate(path)
        print("完成", path.relative_to(ROOT))


if __name__ == "__main__":
    main()
