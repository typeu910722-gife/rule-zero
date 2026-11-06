#!/usr/bin/env python3
"""重畫過的房間：把家具的碰撞範圍（關卡 JSON 的 rect）改成和畫面上的家具對齊。

ChatGPT 畫的床常常比原本的佔地往下（或往上）多出一截，玩家會走到床上、或撞到看不見的牆。
這支把 rect 換成新的值，同時更新 room.json（和 room.blender.json）裡的鍵與 off，
讓遮擋圖留在原來的位置（只改碰撞和前後排序的腳的位置）。
改完會檢查：出生點、調查點、人物、門有沒有被新的碰撞範圍蓋住。

用法：py -3.11 tools/art/fit_prop_rect.py <chapter5> <房間> "x,y,w,h=>x,y,w,h" ...
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def key(kind, r):
    return "prop:%s@%d,%d,%d,%d" % (kind, r[0], r[1], r[2], r[3])


def main(level, rid, changes):
    lp = ROOT / "game/levels" / f"{level}.json"
    raw = lp.read_text(encoding="utf-8")
    data = json.loads(raw)
    room = data["rooms"][rid]
    arts = [p for p in (ROOT / "game/art/rooms" / level / rid).glob("room*.json")]
    art_data = {p: json.loads(p.read_text(encoding="utf-8")) for p in arts}
    for ch in changes:
        old, new = [[int(v) for v in s.split(",")] for s in ch.split("=>")]
        hit = [p for p in room["props"] if p["rect"] == old]
        if not hit:
            sys.exit(f"找不到 rect {old}")
        p = hit[0]
        p["rect"] = new
        ok, nk = key(p["kind"], old), key(p["kind"], new)
        for path, a in art_data.items():
            props = a.get("props", {})
            if ok in props:
                e = props.pop(ok)
                # 節點在 (x, y+h)；圖畫在節點 + off。保持圖的絕對位置不變
                e["off"] = [e["off"][0] + old[0] - new[0], e["off"][1] + (old[1] + old[3]) - (new[1] + new[3])]
                props[nk] = e
        print(f"{rid}: {p['kind']} {old} → {new}")
    # 檢查有沒有東西被蓋住
    rects = [p["rect"] for p in room["props"] if p.get("solid", True)]
    pts = [("出生點 " + k, v) for k, v in room.get("spawns", {}).items()]
    for g in ("spots", "npcs", "doors", "hides"):
        pts += [(f"{g} {s.get('id')}", s["pos"]) for s in room.get(g, [])]
    for name, (x, y) in pts:
        for r in rects:
            if r[0] <= x <= r[0] + r[2] and r[1] <= y <= r[1] + r[3]:
                print(f"  注意：{name} {x},{y} 在碰撞範圍 {r} 裡面")
    fx = ROOT / "tools/levels/prop_rect_fixes.json"
    fixes = json.loads(fx.read_text(encoding="utf-8")) if fx.exists() else {}
    lst = fixes.setdefault(level, {}).setdefault(rid, [])
    for ch in changes:
        old, new = [[int(v) for v in s.split(",")] for s in ch.split("=>")]
        for pair in lst:
            if pair[1] == old:      # 之前改過：從最原本的值直接對到新的值
                old = pair[0]
                lst.remove(pair)
                break
        lst.append([old, new])
    fx.write_text(json.dumps(fixes, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")
    lp.write_text(json.dumps(data, ensure_ascii=False, indent=1 if "\n " in raw[:200] else None), encoding="utf-8", newline="\n")
    for path, a in art_data.items():
        path.write_text(json.dumps(a, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
