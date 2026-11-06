#!/usr/bin/env python3
"""地圖房間重畫：ChatGPT 照 room_guide.py 的版型參考圖重畫回來 → 放回遊戲。

1. 從 ChatGPT 的圖（任何大小，比例和 1536×1024 一樣）切出房間那一條，縮放成房間大小 → bg_paint.jpg
2. 家具：用舊家具圖（Blender 算的）的形狀當遮罩，從新背景切出同一塊 → prop_paint_*.png
   （角色走到家具後面時，家具一樣會擋住角色；遮罩外擴 3px，避免邊緣露出舊的顏色）
3. room.json 改成指向新圖，"painted": true（舊圖留著，可以退回：py room_repaint.py --undo <章> <房間>）

用法：py -3.11 tools/art/room_repaint.py <chapter3> <room_id> <ChatGPT 原圖>
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from room_guide import CANVAS, anchor, band, load_room  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def repaint(level: str, rid: str, src: str) -> None:
    room, art, art_dir = load_room(level, rid)
    if art.get("painted"):
        art = json.loads((art_dir / "room.blender.json").read_text(encoding="utf-8"))
    else:
        (art_dir / "room.blender.json").write_text(json.dumps(art, ensure_ascii=False, indent=1), encoding="utf-8")
    w, h = room.get("size", [1280, 720])
    im = Image.open(src).convert("RGB")
    # 房間那一條：找不是黑邊的範圍（ChatGPT 有時候會換畫布比例，不能只照參考圖的座標切）
    import numpy as np
    g = np.asarray(im.convert("L"), dtype=float)
    rows = np.nonzero(g.mean(1) > 14)[0]
    cols = np.nonzero(g.mean(0) > 14)[0]
    box = (int(cols.min()), int(rows.min()), int(cols.max()) + 1, int(rows.max()) + 1)
    s, top, bh = band(room)
    if abs(im.width / im.height - CANVAS[0] / CANVAS[1]) < 0.02:
        # 畫布比例和參考圖一樣：照參考圖的座標切最準（ChatGPT 常常把畫面稍微畫進黑邊）
        k = im.width / CANVAS[0]
        bw = round(w * s)
        left = (CANVAS[0] - bw) // 2
        geo = (round(left * k), round(top * k), round((left + bw) * k), round((top + bh) * k))
        det = box
        box = geo
        # 但 ChatGPT 把畫面畫得比參考圖小（上下多出黑條）時，改用實際有畫的範圍
        if (det[3] - det[1]) < (geo[3] - geo[1]) * 0.97 or (det[2] - det[0]) < (geo[2] - geo[0]) * 0.97:
            box = (max(geo[0], det[0]), max(geo[1], det[1]), min(geo[2], det[2]), min(geo[3], det[3]))
    want = w / h
    got = (box[2] - box[0]) / (box[3] - box[1])
    if abs(got / want - 1) > 0.15:
        print(f"  注意：重畫的比例 {got:.2f} 和房間 {want:.2f} 差很多，位置可能對不準")
    bg = im.crop(box).resize((w, h), Image.LANCZOS)
    bg.save(art_dir / "bg_paint.jpg", quality=90)
    new_props = {}
    for key, p in art.get("props", {}).items():
        a = anchor(room, key)
        if a is None:
            continue
        old = Image.open(art_dir / p["tex"]).convert("RGBA")
        ox, oy = a[0] + int(p["off"][0]), a[1] + int(p["off"][1])
        mask = old.getchannel("A").point(lambda a: 255 if a > 24 else 0).filter(ImageFilter.MaxFilter(7))
        piece = Image.new("RGBA", old.size, (0, 0, 0, 0))
        crop = bg.crop((ox, oy, ox + old.width, oy + old.height)).convert("RGBA")
        piece.paste(crop, (0, 0), mask)
        name = "paint_" + p["tex"]
        piece.save(art_dir / name)
        new_props[key] = {"tex": name, "off": p["off"]}
    art_out = {"bg": "bg_paint.jpg", "size": [w, h], "props": new_props, "painted": True, "source": Path(src).name}
    (art_dir / "room.json").write_text(json.dumps(art_out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{rid}: 背景 {w}×{h}，家具 {len(new_props)} 件（ChatGPT 圖 {im.size}，切 {box}）")
    check(room, bg, rid)


def check(room, bg, rid):
    """對位檢查圖：紅框＝家具的佔地（碰撞），藍點＝調查點，綠框＝門。存到 E:/rzw/check_<房間>.jpg"""
    from PIL import ImageDraw
    im = bg.convert("RGB").copy()
    d = ImageDraw.Draw(im)
    for p in room.get("props", []):
        x, y, pw, ph = p["rect"]
        d.rectangle((x, y, x + pw, y + ph), outline=(255, 40, 40), width=4)
    for sp in room.get("spots", []) + room.get("hides", []):
        x, y = sp["pos"]
        d.ellipse((x - 9, y - 9, x + 9, y + 9), outline=(40, 120, 255), width=4)
    for dd in room.get("doors", []):
        x, y = dd["pos"]
        sw, sh = dd.get("size", [90, 26])
        d.rectangle((x - sw / 2, y - sh / 2, x + sw / 2, y + sh / 2), outline=(40, 220, 80), width=4)
    out = Path("E:/rzw") / f"check_{rid}.jpg"
    if out.parent.exists():
        im.thumbnail((1400, 700))
        im.save(out, quality=85)


def undo(level: str, rid: str) -> None:
    art_dir = ROOT / "game/art/rooms" / level / rid
    old = art_dir / "room.blender.json"
    (art_dir / "room.json").write_text(old.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"{rid}: 退回 Blender 的圖")


if __name__ == "__main__":
    if sys.argv[1] == "--undo":
        undo(sys.argv[2], sys.argv[3])
    else:
        repaint(sys.argv[1], sys.argv[2], sys.argv[3])
