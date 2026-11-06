#!/usr/bin/env python3
"""給 ChatGPT 的房間重畫指令（英文，接在「Repaint Room Map」對話後面；第一間月台已經定下畫風）。
用法：py -3.11 tools/art/room_prompt.py chapter3 <房間> > 指令.txt
"""
import sys

from room_guide import CANVAS, band, load_room

THEMES = {
    "platform": "an old dim underground train platform",
    "hospital": "the doll-world 'Mercy Experimental Hospital': clean white-and-pale-mint tiles, sterile and quiet, slightly eerie, soft cold fluorescent light",
    "lab": "a sterile white laboratory/treatment ward of the same hospital, steel and white enamel, cold light",
    "hospital_old": "the abandoned OLD wing of the same hospital: peeling paint, stained grey-green tiles, dust, broken things, dim",
    "basement": "the hospital's second basement: dark concrete, pipes on the walls, damp stains, very dim and oppressive",
}


def prompt(level: str, rid: str) -> str:
    room, art, _ = load_room(level, rid)
    s, top, bh = band(room)
    bw = round(room.get("size", [1280, 720])[0] * s)
    left = (CANVAS[0] - bw) // 2

    def at(p):
        return f"({round(left + p[0] * s)}, {round(top + p[1] * s)})"

    lines = []
    for p in room.get("props", []):
        r = p["rect"]
        lines.append(f"- {p.get('kind')} footprint at {at(r[:2])}, size {round(r[2] * s)}x{round(r[3] * s)}"
                     + (" (tall furniture standing up from that footprint, as in the guide)" if p.get("kind") in ("shelf", "cabinet", "locker", "pillar", "machine", "bed") else ""))
    for sp in room.get("spots", []):
        lines.append(f"- inspectable object '{sp.get('name')}' at {at(sp['pos'])}: paint this object there (no readable text)")
    for h in room.get("hides", []):
        lines.append(f"- hiding place '{h.get('name')}' at {at(h['pos'])}: paint it there")
    for d in room.get("doors", []):
        lines.append(f"- door '{d.get('name')}' at {at(d['pos'])}: leave plain wall/floor there, the game draws its own door")
    for n in room.get("npcs", []):
        lines.append(f"- a character stands at {at(n['pos'])}: leave empty floor there")
    return (f"Next room, same style and same rules as the platform you painted: '{room.get('name')}' — "
            f"{THEMES.get(room.get('theme', 'hospital'), THEMES['hospital'])}. "
            f"The attached image is its LAYOUT GUIDE (room area x {left}-{left + bw}, y {top}-{top + bh}; black bars outside stay pure black). "
            f"Keep the exact overhead 3/4 camera and every object's position and size. The back wall is ONLY a thin band at the very top "
            f"(y {top} to {round(top + float(room.get('wall_h', 90)) * s)}); everything below that line is walkable floor seen from above - do not make the wall taller. "
            "No readable text, no people, no dolls, floor stays open and walkable. Make it look lived-in and detailed, not empty. Objects:\n"
            + "\n".join(lines))


if __name__ == "__main__":
    print(prompt(sys.argv[1], sys.argv[2]))
