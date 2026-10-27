"""把 room.py 的輸出疊成一張預覽圖（檢查位置用）：可加 --boxes 畫出碰撞框。
用法：py -3.11 tools/art/room_preview.py <關卡.json> <房間輸出資料夾> <輸出.png> [--boxes]
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

level, d, out = sys.argv[1], Path(sys.argv[2]), sys.argv[3]
rid = d.name
room = json.load(open(level, encoding="utf-8"))["rooms"][rid]
meta = json.load(open(d / "room.json", encoding="utf-8"))
img = Image.open(d / meta["bg"]).convert("RGBA")
nodes = {}
for p in room.get("props", []):
    x, y, w, h = p["rect"]
    nodes["prop:%s@%d,%d,%d,%d" % (p.get("kind", "box"), x, y, w, h)] = (x, y + h)
for key in ("hides", "spots"):
    for s in room.get(key, []):
        nodes["%s:%s" % (key[:-1], s.get("id"))] = tuple(s["pos"])
items = sorted(meta["props"].items(), key=lambda kv: nodes.get(kv[0], (0, 0))[1])
for key, v in items:
    if key not in nodes:
        continue
    t = Image.open(d / v["tex"]).convert("RGBA")
    nx, ny = nodes[key]
    img.alpha_composite(t, (int(nx + v["off"][0]), int(ny + v["off"][1])))
if "--boxes" in sys.argv:
    dr = ImageDraw.Draw(img)
    for p in room.get("props", []):
        x, y, w, h = p["rect"]
        dr.rectangle([x, y, x + w, y + h], outline=(255, 0, 0, 255), width=2)
    for wr in room.get("walls", []):
        x, y, w, h = wr
        dr.rectangle([x, y, x + w, y + h], outline=(0, 0, 255, 255), width=2)
    dr.line([(0, room.get("wall_h", 90)), (img.width, room.get("wall_h", 90))], fill=(255, 0, 255, 255), width=1)
img.convert("RGB").save(out)
