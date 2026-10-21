#!/usr/bin/env python3
"""第四章學校地圖 → game/levels/chapter4.json。
同一間學校有「白天」與「放學後（_eve）」兩種；每個視角用旗標 c4_pov_<視角> 決定誰在、能調查什麼（when 條件）。
用法：python3 tools/levels/build_ch4_level.py"""
import json, copy

def room(name, size, theme, **kw):
    r = {"name": name, "size": size, "theme": theme, "wall_h": 110}
    r.update(kw)
    return r

H = "c4_pov_haruka"
M = "c4_pov_mochi"

rooms = {}
# ── 校門 ──
rooms["gate"] = room("校門", [1600, 720], "school",
    spawns={"start": [800, 640], "from_entrance": [800, 220]},
    props=[{"kind": "pillar", "rect": [300, 160, 60, 50]}, {"kind": "pillar", "rect": [1240, 160, 60, 50]},
           {"kind": "box", "rect": [1380, 320, 80, 60], "label": "郵筒"}, {"kind": "plant", "rect": [120, 420, 70, 50]}],
    spots=[
        {"id": "c4_h_gate_sign", "name": "校名牌", "pos": [800, 160], "when": H},
        {"id": "c4_h_gate_tree", "name": "校門口的樹", "pos": [160, 520], "when": H},
        {"id": "c4_m_gate", "name": "在校門口等", "pos": [800, 520], "when": M + "&c4_m_bag_done", "done_when": "c4_m_done"},
        {"id": "c4_m_gate_early", "name": "校門口", "pos": [800, 520], "when": M + "&!c4_m_bag_done"},
    ],
    doors=[{"id": "c4_door_gate_in", "name": "玄關", "pos": [800, 125], "size": [140, 30], "to": "entrance", "spawn": "from_gate"}])
# ── 玄關（鞋櫃）──
rooms["entrance"] = room("玄關", [1400, 720], "school",
    spawns={"from_gate": [700, 640], "from_hall": [1250, 420]},
    props=[{"kind": "shelf", "rect": [140, 170, 500, 40], "label": "鞋櫃"}, {"kind": "shelf", "rect": [760, 170, 500, 40], "label": "鞋櫃"}],
    spots=[
        {"id": "c4_h_shoebox", "name": "你的鞋櫃", "pos": [400, 270], "when": H},
        {"id": "c4_h_notice", "name": "布告欄", "pos": [1000, 270], "when": H},
        {"id": "c4_m_shoes", "name": "小滿的鞋櫃", "pos": [400, 270], "when": M},
    ],
    doors=[{"id": "c4_door_ent_gate", "name": "回校門", "pos": [700, 700], "size": [140, 30], "to": "gate", "spawn": "from_entrance"},
           {"id": "c4_door_ent_hall", "name": "一樓走廊", "pos": [1360, 420], "size": [60, 120], "to": "hall1", "spawn": "from_entrance"}])
# ── 一樓走廊 ──
rooms["hall1"] = room("一樓走廊", [2400, 700], "school",
    spawns={"from_entrance": [140, 450], "from_class": [1200, 220], "from_office": [1900, 220]},
    props=[{"kind": "cabinet", "rect": [500, 160, 200, 40], "label": "獎盃櫃"}, {"kind": "window", "rect": [900, 20, 200, 80], "solid": False},
           {"kind": "plant", "rect": [2200, 170, 60, 40]}],
    spots=[
        {"id": "c4_h_trophy", "name": "獎盃櫃", "pos": [600, 250], "when": H},
        {"id": "c4_h_classsign", "name": "班級牌", "pos": [1350, 160], "when": H},
        {"id": "c4_m_hall", "name": "走廊", "pos": [900, 500], "when": M},
    ],
    npcs=[{"id": "c4_h_li_en", "name": "李恩", "char": "human:#5b6b78", "pos": [800, 420], "when": H}],
    doors=[{"id": "c4_door_hall_ent", "name": "玄關", "pos": [40, 450], "size": [60, 120], "to": "entrance", "spawn": "from_hall"},
           {"id": "c4_door_hall_class", "name": "三年二班", "pos": [1200, 125], "size": [130, 30], "to": "classroom", "spawn": "from_hall"},
           {"id": "c4_door_hall_office", "name": "教師辦公室", "pos": [1900, 125], "size": [130, 30], "to": "office", "spawn": "from_hall",
            "open": "!" + M, "locked_text": "辦公室的燈關了。門鎖著。"}])
# ── 三年二班 ──
desks = []
for row in range(3):
    for k in range(5):
        desks.append({"kind": "desk", "rect": [260 + k * 230, 420 + row * 130, 140, 50]})
rooms["classroom"] = room("三年二班", [1600, 900], "school",
    spawns={"from_hall": [800, 820]},
    props=[{"kind": "blackboard", "rect": [520, 20, 560, 80], "solid": False}, {"kind": "desk", "rect": [700, 230, 200, 60], "label": "講台"},
           {"kind": "window", "rect": [1360, 20, 200, 80], "solid": False}] + desks,
    spots=[
        {"id": "c4_haruka_rules", "name": "教室後面的紙", "pos": [130, 820], "when": H},
        {"id": "c4_haruka_board", "name": "黑板", "pos": [800, 160], "when": H},
        {"id": "c4_haruka_window", "name": "窗外", "pos": [1460, 160], "when": H},
        {"id": "c4_haruka_desk", "name": "你的座位", "pos": [1250, 740], "when": H},
        {"id": "c4_m_bag", "name": "講台上的書包", "pos": [800, 330], "when": M, "done_when": "c4_m_bag_done"},
        {"id": "c4_m_board", "name": "黑板", "pos": [800, 160], "when": M},
        {"id": "c4_m_window", "name": "窗外", "pos": [1460, 160], "when": M},
    ],
    npcs=[
        {"id": "c4_h_teacher", "name": "導師", "char": "human:#6f6a5e", "pos": [800, 210], "when": H, "done_when": "c4_h_spoke", "reach": 120},
        {"id": "c4_h_fen", "name": "芬", "char": "human:#c8642b", "pos": [1250, 640], "when": H},
        {"id": "c4_h_lulu", "name": "希露飛", "char": "human:#e7a3b4", "pos": [330, 400], "when": H},
        {"id": "c4_h_popo", "name": "銘越", "char": "human:#3b4a73", "pos": [560, 530], "when": H},
        {"id": "c4_h_mochi", "name": "小滿", "char": "human:#8b9a7b", "pos": [1480, 820], "when": H},
        {"id": "c4_h_xinhe", "name": "辛禾", "char": "human:#3a3a3a", "pos": [1020, 530], "when": H},
        {"id": "c4_h_tiaoma", "name": "薙文", "char": "human:#d9d9d4", "pos": [330, 660], "when": H},
        {"id": "c4_h_junzhu", "name": "郡主", "char": "human:#7d7d7d", "pos": [790, 660], "when": H},
        {"id": "c4_h_qiuge", "name": "秋歌", "char": "human:#4a4a4a", "pos": [1020, 790], "when": H},
    ],
    doors=[{"id": "c4_door_class_out", "name": "走廊", "pos": [800, 880], "size": [140, 30], "to": "hall1", "spawn": "from_class"}])
# ── 教師辦公室 ──
rooms["office"] = room("教師辦公室", [1280, 720], "school",
    spawns={"from_hall": [640, 620]},
    props=[{"kind": "desk", "rect": [200, 260, 260, 70]}, {"kind": "desk", "rect": [820, 260, 260, 70]}, {"kind": "cabinet", "rect": [520, 150, 240, 40]}],
    spots=[{"id": "c4_h_office", "name": "導師的桌子", "pos": [330, 380], "when": H}],
    doors=[{"id": "c4_door_office_out", "name": "走廊", "pos": [640, 700], "size": [140, 30], "to": "hall1", "spawn": "from_office"}])

level = {"items": {"c4_m_found_shoes": "自己的室內鞋"}, "keypads": {}, "rooms": rooms}
json.dump(level, open("game/levels/chapter4.json", "w"), ensure_ascii=False, indent=1)
print("完成", len(rooms), "個房間")
