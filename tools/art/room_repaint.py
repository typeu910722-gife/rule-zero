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
from room_guide import CANVAS, band, load_room  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]


def repaint(level: str, rid: str, src: str) -> None:
    room, art, art_dir = load_room(level, rid)
    if art.get("painted"):
        art = json.loads((art_dir / "room.blender.json").read_text(encoding="utf-8"))
    else:
        (art_dir / "room.blender.json").write_text(json.dumps(art, ensure_ascii=False, indent=1), encoding="utf-8")
    w, h = room.get("size", [1280, 720])
    im = Image.open(src).convert("RGB")
    k = im.width / CANVAS[0]
    s, top, bh = band(room)
    bw = round(w * s)
    left = (CANVAS[0] - bw) // 2
    box = (round(left * k), round(top * k), round((left + bw) * k), round((top + bh) * k))
    bg = im.crop(box).resize((w, h), Image.LANCZOS)
    bg.save(art_dir / "bg_paint.jpg", quality=90)
    new_props = {}
    for key, p in art.get("props", {}).items():
        x, y, pw, ph = [int(v) for v in key.split("@")[1].split(",")]
        old = Image.open(art_dir / p["tex"]).convert("RGBA")
        ox, oy = x + int(p["off"][0]), y + ph + int(p["off"][1])
        mask = old.getchannel("A").point(lambda a: 255 if a > 24 else 0).filter(ImageFilter.MaxFilter(7))
        piece = Image.new("RGBA", old.size, (0, 0, 0, 0))
        crop = bg.crop((ox, oy, ox + old.width, oy + old.height)).convert("RGBA")
        piece.paste(crop, (0, 0), mask)
        name = "prop_paint_" + p["tex"].removeprefix("prop_")
        piece.save(art_dir / name)
        new_props[key] = {"tex": name, "off": p["off"]}
    art_out = {"bg": "bg_paint.jpg", "size": [w, h], "props": new_props, "painted": True, "source": Path(src).name}
    (art_dir / "room.json").write_text(json.dumps(art_out, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{rid}: 背景 {w}×{h}，家具 {len(new_props)} 件（ChatGPT 圖 {im.size}，切 {box}）")


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
