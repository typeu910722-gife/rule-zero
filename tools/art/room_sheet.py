"""一章所有房間的總覽圖（逐間檢查用）：每間疊好家具、縮小、標上 id 與碰撞框。
用法：py -3.11 tools/art/room_sheet.py <關卡.json> <game/art/rooms/關卡 資料夾> <輸出.jpg> [每列幾張] [起] [迄]
"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

level, d, out = sys.argv[1], Path(sys.argv[2]), sys.argv[3]
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 3
rooms = list(json.load(open(level, encoding="utf-8"))["rooms"])
a, b = (int(sys.argv[5]), int(sys.argv[6])) if len(sys.argv) > 6 else (0, len(rooms))
rooms = rooms[a:b]
font = ImageFont.truetype("msjh.ttc", 22)
tiles = []
tmp = Path(tempfile.mkdtemp())
for rid in rooms:
    if not (d / rid / "room.json").exists():
        continue
    p = tmp / f"{rid}.png"
    subprocess.run([sys.executable, str(Path(__file__).with_name("room_preview.py")), level, str(d / rid), str(p), "--boxes"], check=True)
    im = Image.open(p).convert("RGB")
    im.thumbnail((620, 400))
    t = Image.new("RGB", (620, 430), "#222")
    t.paste(im, (0, 30))
    ImageDraw.Draw(t).text((6, 2), rid, fill="white", font=font)
    tiles.append(t)
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (620 * cols, 430 * rows), "#111")
for i, t in enumerate(tiles):
    sheet.paste(t, ((i % cols) * 620, (i // cols) * 430))
sheet.save(out, quality=85)
print(out, len(tiles))
