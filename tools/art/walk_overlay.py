"""每間房間的「可以走的地方」疊在重畫的畫面上（檢查會不會走到牆上用）。
紅色＝擋住（上面的牆 wall_h、walls、會擋路的家具）；綠點＝調查點、人物、門。
用法：py -3.11 tools/art/walk_overlay.py <chapter3|chapter4|chapter5> <輸出資料夾>
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

lv, out = sys.argv[1], Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
L = json.load(open(f"game/levels/{lv}.json", encoding="utf-8"))
font = ImageFont.truetype("msjh.ttc", 26)
tiles = []
for rid, r in L["rooms"].items():
    bg = Path(f"game/art/rooms/{lv}/{rid}/bg_paint.jpg")
    if not bg.exists():
        continue
    w, h = r.get("size", [1280, 720])
    im = Image.open(bg).convert("RGB").resize((int(w), int(h)))
    ov = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    wall = float(r.get("wall_h", 90))
    d.rectangle((0, 0, w, wall), fill=(255, 0, 0, 90))
    for x, y, ww, hh in r.get("walls", []):
        d.rectangle((x, y, x + ww, y + hh), fill=(255, 0, 0, 90), outline=(255, 0, 0, 255))
    for p in r.get("props", []):
        if p.get("solid", True):
            x, y, ww, hh = p["rect"]
            d.rectangle((x, y, x + ww, y + hh), outline=(255, 60, 60, 255), width=3)
    for g in ("spots", "npcs", "doors"):
        for s in r.get(g, []):
            x, y = s["pos"]
            d.ellipse((x - 7, y - 7, x + 7, y + 7), fill=(0, 255, 0, 255))
    d.line((0, wall, w, wall), fill=(255, 255, 0, 255), width=3)
    im = Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")
    ImageDraw.Draw(im).text((10, 6), f"{rid}  wall_h={int(wall)}", fill="yellow", font=font, stroke_width=3, stroke_fill="black")
    im.thumbnail((900, 520))
    tiles.append(im)
cols = 2
for i in range(0, len(tiles), 6):
    part = tiles[i:i + 6]
    rows = (len(part) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * 900, rows * 520), "#111")
    for k, t in enumerate(part):
        sheet.paste(t, ((k % cols) * 900, (k // cols) * 520))
    sheet.save(out / f"{lv}_{i // 6:02d}.jpg", quality=82)
print(len(tiles), "rooms")
