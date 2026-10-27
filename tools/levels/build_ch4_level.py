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
T = "c4_pov_tiaoma"
L = "c4_pov_lulu"
X = "c4_pov_xinhe"
P = "c4_pov_popo"
TE = "c4_pov_teacher"
F = "c4_pov_fen"
# 那一天（畫面永遠在門外；廁所的門不能進去）
D1 = "c4_pov_d1"
D2 = "c4_pov_d2"
D5 = "c4_pov_d5"
D8 = "c4_pov_d8"
O = "c4_pov_org"     # 那一天之後：像回憶裡的影子一樣走過
N = "c4_pov_night"   # 慈愛組織的第一個晚上

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
        {"id": "c4_x_mailbox", "name": "郵筒", "pos": [1420, 420], "when": X, "label": "c4_xinhe", "done_when": "c4_x_done"},
        {"id": "c4_p_mailbox", "name": "學校的信箱", "pos": [1420, 420], "when": P + "&done_c4_p_crowd", "done_when": "c4_p_done"},
        {"id": "c4_l_gate", "name": "校門口", "pos": [800, 520], "when": L},
        {"id": "c4_d1_gate", "name": "放假的校門", "pos": [800, 520], "when": D1},
        {"id": "c4_o_gate", "name": "校門口的警車", "pos": [800, 520], "when": O},
    ],
    doors=[{"id": "c4_door_gate_in", "name": "玄關", "pos": [800, 125], "size": [140, 30], "to": "entrance", "spawn": "from_gate"},
           {"id": "c4_door_gate_hosp", "name": "醫院", "pos": [160, 700], "size": [160, 30], "to": "hospital4", "spawn": "start", "when": O + "&done_c4_org_board&done_c4_org_teacher"},
           {"id": "c4_door_gate_home", "name": "回家", "pos": [800, 700], "size": [160, 30], "to": "lulu_room", "spawn": "start", "when": L}])
# ── 玄關（鞋櫃）──
rooms["entrance"] = room("玄關", [1400, 720], "school",
    spawns={"from_gate": [700, 640], "from_hall": [1250, 420]},
    props=[{"kind": "shelf", "rect": [140, 170, 500, 40], "label": "鞋櫃"}, {"kind": "shelf", "rect": [760, 170, 500, 40], "label": "鞋櫃"}],
    spots=[
        {"id": "c4_h_shoebox", "name": "你的鞋櫃", "pos": [400, 270], "when": H},
        {"id": "c4_h_notice", "name": "布告欄", "pos": [1000, 270], "when": H},
        {"id": "c4_m_shoes", "name": "小滿的鞋櫃", "pos": [400, 270], "when": M},
        {"id": "c4_l_shoebox", "name": "自己的鞋櫃", "pos": [560, 270], "when": L},
        {"id": "c4_p_shoes", "name": "自己的鞋櫃", "pos": [900, 270], "when": P},
        {"id": "c4_f_shoebox", "name": "遙的鞋櫃", "pos": [400, 270], "when": F},
    ],
    doors=[{"id": "c4_door_ent_gate", "name": "回校門", "pos": [700, 700], "size": [140, 30], "to": "gate", "spawn": "from_entrance"},
           {"id": "c4_door_ent_hall", "name": "一樓走廊", "pos": [1360, 420], "size": [60, 120], "to": "hall1", "spawn": "from_entrance"}])
# ── 一樓走廊 ──
rooms["hall1"] = room("一樓走廊", [2400, 700], "school",
    spawns={"from_entrance": [140, 450], "from_class": [1200, 220], "from_office": [1900, 220], "from_toilet": [2250, 450], "from_principal": [500, 220]},
    props=[{"kind": "cabinet", "rect": [500, 160, 200, 40], "label": "獎盃櫃"}, {"kind": "window", "rect": [900, 20, 200, 80], "solid": False},
           {"kind": "plant", "rect": [2200, 170, 60, 40]}],
    spots=[
        {"id": "c4_h_trophy", "name": "獎盃櫃", "pos": [600, 250], "when": H},
        {"id": "c4_h_classsign", "name": "班級牌", "pos": [1350, 160], "when": H},
        {"id": "c4_m_hall", "name": "走廊", "pos": [900, 500], "when": M},
        {"id": "c4_p_trophy", "name": "獎盃櫃", "pos": [600, 250], "when": P},
        {"id": "c4_x_hall", "name": "走廊角落的聲音", "pos": [1700, 500], "when": X},
        {"id": "c4_fen_trash", "name": "垃圾桶", "pos": [300, 580], "when": F},
        {"id": "c4_d1_practice", "name": "沒有人的走廊", "pos": [1000, 500], "when": D1},
        {"id": "c4_fen_why", "name": "走廊盡頭", "pos": [2300, 450], "when": F + "&done_c4_fen_desk&done_c4_fen_trash", "done_when": "c4_f_done"},
    ],
    npcs=[{"id": "c4_h_li_en", "name": "李恩", "char": "h_lien", "pos": [800, 420], "when": H},
          {"id": "c4_l_whisper", "name": "同學們", "char": "h_crowd", "pos": [1500, 420], "when": L},
          {"id": "c4_p_crowd", "name": "圍過來的人", "char": "h_crowd", "pos": [1000, 420], "when": P},
          {"id": "c4_d5_teacher_stop", "name": "導師", "char": "h_teacher", "pos": [1700, 450], "when": D5 + "&c4_d5_called"}],
    doors=[{"id": "c4_door_hall_ent", "name": "玄關", "pos": [40, 450], "size": [60, 120], "to": "entrance", "spawn": "from_hall"},
           {"id": "c4_door_hall_class", "name": "三年二班", "pos": [1200, 125], "size": [130, 30], "to": "classroom", "spawn": "from_hall"},
           {"id": "c4_door_hall_toilet", "name": "往廁所的走廊", "pos": [2360, 450], "size": [60, 120], "to": "toilet_hall", "spawn": "from_hall1",
            "when": D1 + "|" + D5, "open": D1 + "|c4_d5_called", "locked_text": "（要先去找人。）"},
           {"id": "c4_door_hall_principal", "name": "校長室", "pos": [500, 125], "size": [120, 30], "to": "principal", "spawn": "from_hall", "when": O},
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
        {"id": "c4_l_desk", "name": "自己的座位", "pos": [330, 480], "when": L},
        {"id": "c4_l_popo", "name": "銘越的背影", "pos": [560, 600], "when": L},
        {"id": "c4_x_trash", "name": "垃圾桶", "pos": [130, 300], "when": X},
        {"id": "c4_x_desk", "name": "銘越的座位", "pos": [560, 600], "when": X},
        {"id": "c4_p_desk", "name": "自己的座位", "pos": [560, 600], "when": P},
        {"id": "c4_te_chalk", "name": "黑板", "pos": [800, 160], "when": TE},
        {"id": "c4_te_roll", "name": "講台上的點名簿", "pos": [800, 330], "when": TE},
        {"id": "c4_teacher_rules", "name": "教室後面的班規", "pos": [130, 820], "when": TE + "&c4_te_night", "done_when": "c4_te_done"},
        {"id": "c4_fen_desk", "name": "遙的座位", "pos": [1250, 740], "when": F},
        {"id": "c4_f_book", "name": "自己的座位", "pos": [1250, 640], "when": F},
        {"id": "c4_d2_bucket", "name": "水桶", "pos": [1400, 400], "when": D2},
        {"id": "c4_org_board", "name": "黑板", "pos": [800, 160], "when": O},
        {"id": "c4_d2_board", "name": "值日表", "pos": [800, 160], "when": D2},
        {"id": "c4_d2_window", "name": "窗戶", "pos": [1460, 160], "when": D2 + "&done_c4_d2_bucket", "label": "c4_day_2", "done_when": "c4_d2_done"},
        {"id": "c4_d5_desk", "name": "自己的座位", "pos": [1250, 640], "when": D5, "done_when": "c4_d5_heard"},
    ],
    npcs=[
        {"id": "c4_h_teacher", "name": "導師", "char": "h_teacher", "pos": [800, 210], "when": H, "done_when": "c4_h_spoke", "reach": 120},
        {"id": "c4_h_fen", "name": "芬", "char": "h_fen", "pos": [1250, 640], "when": H},
        {"id": "c4_h_lulu", "name": "希露飛", "char": "h_hilufei", "pos": [330, 400], "when": H},
        {"id": "c4_h_popo", "name": "銘越", "char": "h_mingyue", "pos": [560, 530], "when": H},
        {"id": "c4_h_mochi", "name": "小滿", "char": "h_xiaoman", "pos": [1480, 820], "when": H},
        {"id": "c4_h_xinhe", "name": "辛禾", "char": "h_xinhe", "pos": [1020, 530], "when": H},
        {"id": "c4_h_tiaoma", "name": "薙文", "char": "h_tiwen", "pos": [330, 660], "when": H},
        {"id": "c4_h_junzhu", "name": "郡主", "char": "h_junzhu", "pos": [790, 660], "when": H},
        {"id": "c4_h_qiuge", "name": "秋歌", "char": "h_qiuge", "pos": [1020, 790], "when": H},
        {"id": "c4_te_students", "name": "學生們", "char": "h_crowd", "pos": [800, 560], "when": TE + "&!c4_te_night"},
    ],
    doors=[{"id": "c4_door_class_out", "name": "走廊", "pos": [800, 880], "size": [140, 30], "to": "hall1", "spawn": "from_class"}])
# ── 教師辦公室 ──
rooms["office"] = room("教師辦公室", [1280, 720], "school",
    spawns={"from_hall": [640, 620]},
    props=[{"kind": "desk", "rect": [200, 260, 260, 70]}, {"kind": "desk", "rect": [820, 260, 260, 70]}, {"kind": "cabinet", "rect": [520, 150, 240, 40]}],
    spots=[{"id": "c4_h_office", "name": "導師的桌子", "pos": [330, 380], "when": H},
           {"id": "c4_te_desk", "name": "自己的桌子", "pos": [330, 380], "when": TE},
           {"id": "c4_te_memo", "name": "校長轉來的公文", "pos": [950, 380], "when": TE},
           {"id": "c4_org_teacher", "name": "導師", "pos": [330, 380], "when": O},
           {"id": "c4_d5_teacher", "name": "導師", "pos": [330, 300], "when": D5 + "&c4_d5_heard&!c4_d5_called", "done_when": "c4_d5_called"},
           {"id": "c4_te_stay", "name": "留到晚上", "pos": [640, 520], "when": TE + "&done_c4_te_desk&!c4_te_night"}],
    doors=[{"id": "c4_door_office_out", "name": "走廊", "pos": [640, 700], "size": [140, 30], "to": "hall1", "spawn": "from_office"}])

# ── 薙文的房間（夜晚）──
rooms["tiaoma_room"] = room("薙文的房間", [1280, 720], "home",
    spawns={"start": [640, 560]},
    props=[{"kind": "desk", "rect": [140, 260, 260, 70]}, {"kind": "bed", "rect": [860, 300, 280, 110]},
           {"kind": "shelf", "rect": [480, 150, 200, 40]}, {"kind": "window", "rect": [980, 20, 200, 80], "solid": False}],
    spots=[
        {"id": "c4_t_desk", "name": "書桌", "pos": [270, 380], "when": T},
        {"id": "c4_t_window", "name": "窗外", "pos": [1080, 160], "when": T},
        {"id": "c4_t_shelf", "name": "書架上的相框", "pos": [580, 250], "when": T},
        {"id": "c4_t_door", "name": "房門外", "pos": [640, 690], "when": T},
        {"id": "c4_t_phone", "name": "床上的手機", "pos": [1000, 470], "when": T, "label": "c4_tiaoma", "done_when": "c4_t_done"},
    ])
# ── 希露飛的房間 ──
rooms["lulu_room"] = room("希露飛的房間", [1280, 720], "home",
    spawns={"start": [640, 600]},
    props=[{"kind": "bed", "rect": [140, 280, 260, 110]}, {"kind": "desk", "rect": [880, 280, 240, 70]},
           {"kind": "window", "rect": [540, 20, 200, 80], "solid": False}, {"kind": "rug", "rect": [500, 380, 280, 160], "solid": False}],
    spots=[
        {"id": "c4_l_shard1", "name": "鏡子的碎片", "pos": [560, 430], "when": L, "once": True},
        {"id": "c4_l_shard2", "name": "鏡子的碎片", "pos": [700, 470], "when": L, "once": True},
        {"id": "c4_l_shard3", "name": "鏡子的碎片", "pos": [640, 520], "when": L, "once": True},
        {"id": "c4_l_window", "name": "破掉的窗", "pos": [640, 160], "when": L},
        {"id": "c4_l_drawer", "name": "書桌的抽屜", "pos": [1000, 400], "when": L + "&done_c4_l_shard1&done_c4_l_shard2&done_c4_l_shard3", "done_when": "c4_l_done"},
    ])

# ── 那一天：廁所前、樓梯口（廁所的門只是牆上的一扇門，不能進去）──
rooms["toilet_hall"] = room("廁所前　樓梯口", [1600, 720], "school",
    spawns={"from_hall1": [120, 450]},
    walls=[[1180, 110, 40, 300]],
    decals=[{"kind": "rect", "rect": [1240, 110, 300, 260], "color": "#b8ad9b"},
            {"kind": "text", "pos": [1240, 240], "text": "往下的樓梯", "w": 300, "size": 18, "color": "#7a6c58"}],
    props=[{"kind": "window", "rect": [500, 20, 220, 80], "solid": False}, {"kind": "sink", "rect": [140, 160, 120, 40]}],
    spots=[
        {"id": "c4_d1_door", "name": "廁所前", "pos": [900, 260], "when": D1, "done_when": "c4_d1_done"},
        {"id": "c4_day_5_window", "name": "看窗外", "pos": [610, 160], "when": D5},
        {"id": "c4_d5_hold", "name": "擋在門前", "pos": [900, 260], "when": D5, "label": "c4_day_5_hold", "done_when": "c4_d5_done"},
    ],
    doors=[{"id": "c4_door_toilet_hall1", "name": "回走廊", "pos": [40, 450], "size": [60, 120], "to": "hall1", "spawn": "from_toilet",
            "open": "!" + D1 + "&!" + D5, "locked_text": "（回不去了。）"}])
# ── 樓下（李恩）──
rooms["downstairs"] = room("樓下　樓梯底", [1280, 720], "school_dark",
    spawns={"start": [300, 560]},
    decals=[{"kind": "rect", "rect": [700, 110, 400, 220], "color": "#9a8d78"}],
    spots=[
        {"id": "c4_d8_fen", "name": "樓梯底下", "pos": [880, 420], "when": D8},
        {"id": "c4_d8_phone", "name": "打電話", "pos": [300, 470], "when": D8 + "&done_c4_d8_fen", "label": "c4_day_8", "done_when": "c4_d8_done"},
    ])

# ── 那一天之後 ──
rooms["principal"] = room("校長室", [1280, 720], "school",
    spawns={"start": [640, 600], "from_hall": [640, 600]},
    props=[{"kind": "desk", "rect": [420, 300, 440, 80]}, {"kind": "table", "rect": [160, 420, 200, 60], "label": "沙發"},
           {"kind": "window", "rect": [980, 20, 220, 80], "solid": False}],
    spots=[{"id": "c4_org_principal", "name": "桌上的信封", "pos": [640, 440], "when": O},
           {"id": "c4_o_window", "name": "窗外", "pos": [1090, 160], "when": O}],
    doors=[{"id": "c4_door_principal_out", "name": "走廊", "pos": [640, 700], "size": [140, 30], "to": "hall1", "spawn": "from_principal"}])
rooms["hospital4"] = room("醫院（很多年以前）", [1600, 720], "hospital",
    spawns={"start": [160, 600]},
    props=[{"kind": "bed", "rect": [420, 280, 200, 80]}, {"kind": "bed", "rect": [820, 280, 200, 80]}, {"kind": "machine", "rect": [640, 200, 80, 50]}],
    spots=[{"id": "c4_org_hospital", "name": "遙的床", "pos": [520, 420], "when": O},
           {"id": "c4_o_fenbed", "name": "芬的床", "pos": [920, 420], "when": O}],
    npcs=[{"id": "c4_org_father", "name": "芬的父親", "char": "h_fen_father", "pos": [1200, 450], "when": O},
          {"id": "c4_org_whitecoat", "name": "穿白大衣的人", "char": "h_whitecoat", "pos": [1320, 450], "when": O, "flip": True}],
    doors=[{"id": "c4_door_hosp_platform", "name": "很遠的月台", "pos": [1560, 450], "size": [60, 120], "to": "platform4", "spawn": "start",
            "when": O, "open": "done_c4_org_hospital&done_c4_org_father", "locked_text": "（還沒看完。）"}])
rooms["platform4"] = room("白色的月台", [1600, 720], "platform",
    spawns={"start": [160, 500]},
    walls=[[0, 110, 1600, 100]],
    spots=[{"id": "c4_org_platform", "name": "月台上的人", "pos": [1100, 330], "when": O, "done_when": "c4_o_done"}])
# ── 第一個晚上：白線分開的病房 ──
rooms["ward4"] = room("慈愛組織的醫院　很多年以前", [1800, 900], "hospital",
    spawns={"start": [900, 840]},
    decals=[{"kind": "rect", "rect": [895, 110, 10, 790], "color": "#ffffff"}],
    props=[{"kind": "bed", "rect": [120 + (k % 3) * 240, 220 + (k // 3) * 220, 180, 80]} for k in range(6)] +
          [{"kind": "bed", "rect": [1000 + (k % 3) * 240, 220 + (k // 3) * 220, 180, 80]} for k in range(6)] +
          [{"kind": "machine", "rect": [1660, 130, 100, 60], "label": "電閘", "solid": True}],
    spots=[
        {"id": "c4_n_left", "name": "白線的左邊", "pos": [450, 560], "when": N},
        {"id": "c4_n_fen", "name": "最邊邊的床", "pos": [210, 340], "when": N},
        {"id": "c4_n_right", "name": "白線的右邊", "pos": [1330, 560], "when": N},
        {"id": "c4_n_haruka", "name": "最裡面的床", "pos": [1570, 340], "when": N},
        {"id": "c4_n_end", "name": "門的聲音", "pos": [900, 760], "when": N + "&done_c4_n_left&done_c4_n_right&done_c4_n_haruka", "done_when": "c4_n_done"},
    ],
    npcs=[{"id": "c4_n_zz", "name": "郡主", "char": "h_junzhu", "pos": [690, 560], "when": N}])

level = {"items": {"c4_m_found_shoes": "自己的室內鞋"}, "keypads": {}, "rooms": rooms}
json.dump(level, open("game/levels/chapter4.json", "w", encoding="utf-8", newline="\n"), ensure_ascii=False, indent=1)
print("完成", len(rooms), "個房間")
