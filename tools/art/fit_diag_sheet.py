"""ChatGPT 畫的 4×4 斜向走路圖 → 遊戲用的 <id>_diag.png（1280×1280，每格 320px）。

只用第 1 列（往左下）、第 2 列（往左上）；右下、右上用左右翻過來的同一列，方向才不會畫錯。
高度照同一個角色原本的四方向走路圖（game/art/walk4/<id>.png）裡最高的那格，畫面上一樣大。
用法：py -3.11 tools/art/fit_diag_sheet.py <ChatGPT 原圖> <角色 id，例如 h_haruka>
輸出：game/art/walk4/<id>_diag.png；列 0 左下、1 左上、2 右下、3 右上（explore_art.gd draw_walk）
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))
from fit_walk_sheet import CELL, CX, FOOT, cutout, figures  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def tallest(sheet_path: Path) -> int:
    a = np.array(Image.open(sheet_path).convert("RGBA"))[..., 3] > 40
    cell = a.shape[0] // 4
    best = 0
    for r in range(4):
        for c in range(4):
            ys = np.nonzero(a[r * cell:(r + 1) * cell, c * cell:(c + 1) * cell].any(1))[0]
            if len(ys):
                best = max(best, (ys.max() - ys.min() + 1) * CELL // cell)
    return best


def holes(a):
    """被頭髮包住、沒有連到邊緣的白底（例如頭頂的髮絲之間）：大塊的純白也挖掉。眼白很小，留著。"""
    from scipy import ndimage
    rgb = a[..., :3].astype(int)
    white = (a[..., 3] > 0) & (rgb.min(-1) > 236) & (rgb.max(-1) - rgb.min(-1) < 10)
    lab, n = ndimage.label(white)
    if n:
        sizes = ndimage.sum(white, lab, range(1, n + 1))
        big = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v > 120])
        a[..., 3] = np.where(big, 0, a[..., 3])
    return a


def fit(src: str, cid: str) -> Path:
    base = ROOT / "game/art/walk4" / f"{cid}.png"
    figs = figures(holes(cutout(Image.open(src))))[:8]
    s = tallest(base) / max(f.shape[0] for f in figs)
    sheet = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    for i, f in enumerate(figs):
        im = Image.fromarray(f)
        im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
        r, c = divmod(i, 4)
        for row, img in ((r, im), (r + 2, ImageOps.mirror(im))):
            sheet.paste(img, (c * CELL + CX - img.width // 2, row * CELL + FOOT - img.height), img)
    out = ROOT / "game/art/walk4" / f"{cid}_diag.png"
    sheet.save(out)
    return out


if __name__ == "__main__":
    print(fit(sys.argv[1], sys.argv[2]))
