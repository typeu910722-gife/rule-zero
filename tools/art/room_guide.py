#!/usr/bin/env python3
"""地圖房間重畫用：把現有的房間美術（Blender 背景＋家具圖）合成一張「版型參考圖」給 ChatGPT。

ChatGPT 只出 1536×1024（3:2），房間多半更寬，所以參考圖把整個房間縮到寬 1536、
上下補黑邊（黑邊不用畫）。重畫回來後用 room_repaint.py 切回房間大小。

用法：py -3.11 tools/art/room_guide.py <chapter3> <room_id> <輸出.png>
同時印出給 ChatGPT 的物件位置清單（參考圖上的像素座標）。
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CANVAS = (1536, 1024)


def load_room(level: str, rid: str):
    lv = json.loads((ROOT / "game/levels" / f"{level}.json").read_text(encoding="utf-8"))
    room = lv["rooms"][rid]
    art_dir = ROOT / "game/art/rooms" / level / rid
    art = json.loads((art_dir / "room.json").read_text(encoding="utf-8"))
    return room, art, art_dir


def anchor(room, key: str):
    """一件美術在房間裡的錨點（遊戲畫它的節點位置）：
    家具 prop:<種類>@x,y,w,h → (x, y+h)；調查點、躲藏點 spot:<id>／hide:<id> → 那個點的 pos"""
    if "@" in key:
        x, y, pw, ph = [int(v) for v in key.split("@")[1].split(",")]
        return x, y + ph
    kind, sid = key.split(":", 1)
    for group in ("spots", "hides", "npcs", "doors"):
        for s in room.get(group, []):
            if str(s.get("id", "")) == sid:
                return int(s["pos"][0]), int(s["pos"][1])
    return None


def composite(room, art, art_dir) -> Image.Image:
    w, h = room.get("size", [1280, 720])
    im = Image.open(art_dir / art["bg"]).convert("RGBA").resize((w, h))
    # 家具照 y 排序疊上去（和遊戲一樣：腳的位置越下面越後畫）
    items = []
    for key, p in art.get("props", {}).items():
        a = anchor(room, key)
        if a:
            items.append((a[1], a[0], p))
    for foot, x, p in sorted(items, key=lambda t: t[0]):
        spr = Image.open(art_dir / p["tex"]).convert("RGBA")
        im.alpha_composite(spr, (x + int(p["off"][0]), foot + int(p["off"][1])))
    return im


def band(room):
    """房間縮進 1536×1024 畫布時的位置：回傳 (縮放, 上邊距, 帶子高度)"""
    w, h = room.get("size", [1280, 720])
    s = CANVAS[0] / w
    bh = round(h * s)
    if bh > CANVAS[1]:   # 比 3:2 還高的房間：改成以高度為準
        s = CANVAS[1] / h
        bh = CANVAS[1]
    return s, (CANVAS[1] - bh) // 2, bh


def guide(level: str, rid: str, out: str) -> None:
    room, art, art_dir = load_room(level, rid)
    im = composite(room, art, art_dir)
    s, top, bh = band(room)
    bw = round(im.width * s)
    canvas = Image.new("RGB", CANVAS, (0, 0, 0))
    canvas.paste(im.convert("RGB").resize((bw, bh), Image.LANCZOS), ((CANVAS[0] - bw) // 2, top))
    canvas.save(out)
    left = (CANVAS[0] - bw) // 2
    print(f"房間 {rid}：{room.get('size')}，畫面在參考圖的 x {left}–{left + bw}、y {top}–{top + bh}")

    def at(p):
        return f"({round(left + p[0] * s)}, {round(top + p[1] * s)})"

    for p in room.get("props", []):
        r = p["rect"]
        print(f"  家具 {p.get('kind')}：{at(r[:2])} 大小 {round(r[2] * s)}×{round(r[3] * s)}")
    for sp in room.get("spots", []):
        print(f"  調查點「{sp.get('name')}」：{at(sp['pos'])}")
    for d in room.get("doors", []):
        print(f"  門「{d.get('name')}」：{at(d['pos'])}")
    for n in room.get("npcs", []):
        print(f"  人物「{n.get('name')}」：{at(n['pos'])}")


if __name__ == "__main__":
    guide(sys.argv[1], sys.argv[2], sys.argv[3])
