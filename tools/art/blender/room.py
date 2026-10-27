"""地圖房間美術：照關卡 JSON 在 Blender 蓋出房間，渲染成遊戲用的背景圖＋每件家具一張去背小圖。

遊戲的地圖是「斜投影」：地上的位置照 JSON 的座標畫（不縮），東西的高度往畫面上方長。
這裡用 45° 的正交鏡頭，把場景的 Y、Z 都拉長 √2 倍，畫出來就是 螢幕 y ＝ 地上 y − 高度，跟遊戲一像素不差。

用法：
  blender --background --factory-startup --python tools/art/blender/room.py -- <關卡.json> <房間 id> <輸出資料夾> [取樣數]
輸出（輸出資料夾/<房間 id>/）：
  bg.jpg            地板、牆、窗、地上的線（家具不在裡面，只有它們的影子）
  <key>.png         每件家具一張（遊戲照前後順序疊，角色才會被櫃子擋住）
  room.json         對照表：{"bg": ..., "props": {key: {"tex": 檔名, "off": [dx, dy]}}}
key：家具 "prop:種類@x,y,w,h"；有 kind 的躲藏點 "hide:<id>"、調查點 "spot:<id>"（家具改了位置，對不到就自動用舊的程式畫法）。
"""
import json
import math
import os
import random
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
LEVEL, RID, OUT = argv[0], argv[1], argv[2]
SAMPLES = int(argv[3]) if len(argv) > 3 else 96
room = json.load(open(LEVEL, encoding="utf-8"))["rooms"][RID]
W, H = room.get("size", [1280, 720])
WALL = float(room.get("wall_h", 90))
THEME = room.get("theme", "hospital")
# 家具的高度倍數：第三、五章主角是玩偶（只到人的膝蓋），人類的醫院家具要大到壓人；第四章是人類時期，照正常比例
_ch = os.path.basename(LEVEL)
SC = float(argv[4]) if len(argv) > 4 else (1.0 if "chapter4" in _ch or THEME in ("school", "school_dark", "home", "town", "real") else 1.6)
# 窗台上的鳥（docs/script/chapter3.md 2.3、story.md）：慈愛組織讓三個人各自操控真的動物——和平鴿＝白鴿、車掌＝烏鴉、理事＝老鷹。
# 是真的動物，所以人類世界也有（第四章「那一天」白鴿就在學校窗外）。第五章和平鴿死了：窗台上的白鴿全部不見，只剩一根褐色的老鷹羽毛。
CH5 = "chapter5" in _ch
DOVE_P = 0.0 if CH5 else (0.85 if "chapter3" in _ch else (0.6 if THEME in ("hospital", "hospital_old", "lab") else 0.3))
DOVES = DOVE_P > 0
DARK = room.get("dark", False)
ODIR = os.path.join(OUT, RID)
os.makedirs(ODIR, exist_ok=True)
random.seed(hash(RID) & 0xFFFF)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
S2 = math.sqrt(2.0)
root = bpy.data.objects.new("room", None)
root.scale = (1.0, S2, S2)
scene.collection.objects.link(root)


def P(x, y, z=0.0):
    """遊戲座標（像素；z＝高度像素）→ 場景座標（未拉長）"""
    return (x / 100.0, -y / 100.0, z / 100.0)


# ───────── 材質 ─────────
def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple((v / 12.92) if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


_mats = {}


def mat(name, color, rough=0.6, metal=0.0, bump=0.0, emit=0.0, coat=0.0, noise=0.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    col = srgb(color) if isinstance(color, str) else color
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if coat:
        p.inputs["Coat Weight"].default_value = coat
    if emit:
        p.inputs["Emission Color"].default_value = (*col, 1)
        p.inputs["Emission Strength"].default_value = emit
    if noise:   # 一點點髒、不均勻（不是血、不是腐爛：第三章是「乾淨的恐怖」）
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 3.0
        n.inputs["Detail"].default_value = 8.0
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.inputs["Factor"].default_value = noise
        mix.inputs[6].default_value = (*col, 1)
        mix.inputs[7].default_value = (col[0] * 0.78, col[1] * 0.78, col[2] * 0.76, 1)
        nt.links.new(n.outputs["Fac"], mix.inputs["Factor"])
        nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    if bump:
        t = nt.nodes.new("ShaderNodeTexNoise")
        t.inputs["Scale"].default_value = 60.0
        t.inputs["Detail"].default_value = 4.0
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        nt.links.new(t.outputs["Fac"], b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    _mats[name] = m
    return m


def tile_mat(name, c1, c2, mortar, size_px, rough=0.25, noise=0.0, row_px=None):
    """地磚：磁磚＋縫，有一點反光"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Roughness"].default_value = rough
    tc = nt.nodes.new("ShaderNodeTexCoord")
    br = nt.nodes.new("ShaderNodeTexBrick")
    br.offset = 0.5 if row_px else 0.0
    br.inputs["Color1"].default_value = (*srgb(c1), 1)
    br.inputs["Color2"].default_value = (*srgb(c2), 1)
    br.inputs["Mortar"].default_value = (*srgb(mortar), 1)
    br.inputs["Scale"].default_value = 1.0
    br.inputs["Mortar Size"].default_value = 0.012 if not row_px else 0.005
    br.inputs["Brick Width"].default_value = size_px / 100.0
    br.inputs["Row Height"].default_value = (row_px or size_px) / 100.0
    br.inputs["Bias"].default_value = 0.0
    nt.links.new(tc.outputs["Object"], br.inputs["Vector"])
    out = br.outputs["Color"]
    if noise:
        n = nt.nodes.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = 0.6
        n.inputs["Detail"].default_value = 6.0
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = noise
        nt.links.new(out, mix.inputs[6])
        nt.links.new(n.outputs["Color"], mix.inputs[7])
        out = mix.outputs[2]
    nt.links.new(out, p.inputs["Base Color"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.25
    nt.links.new(br.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], p.inputs["Normal"])
    return m


# 每個主題：地板（兩色＋縫、磚寬）、牆、下半牆、扶手、燈的顏色與亮度、髒的程度
THEMES = {
    "hospital":     dict(floor=("#dfe6e6", "#d5dede", "#a9b8ba", 80), wall="#d3e0dc", low="#9fbab3", rail="#eef2f1", light=(0.92, 0.98, 1.0), power=1.0, dirt=0.0),
    "hospital_old": dict(floor=("#a9b1ab", "#9aa39c", "#6c756f", 80), wall="#9fa9a2", low="#7f8c84", rail="#b9c0bb", light=(0.85, 0.95, 0.88), power=0.55, dirt=0.55),
    "basement":     dict(floor=("#4a5254", "#434b4d", "#2c3233", 100), wall="#3d4547", low="#323a3c", rail="#566062", light=(0.80, 0.90, 1.0), power=0.35, dirt=0.6),
    "lab":          dict(floor=("#e4eaec", "#dce3e6", "#aab7bc", 60), wall="#d6dfe2", low="#c2ced2", rail="#eef3f4", light=(0.90, 0.97, 1.0), power=1.1, dirt=0.0),
    "platform":     dict(floor=("#d4d6d4", "#cbcdcb", "#9a9e9b", 100), wall="#b7bcba", low="#a1a7a4", rail="#d2d5d3", light=(1.0, 0.97, 0.9), power=0.8, dirt=0.2),
    "school":       dict(floor=("#b8956a", "#a8875e", "#6e5638", 180, 24), wall="#e6dccb", low="#9c8466", rail="#7d6a52", light=(1.0, 0.93, 0.82), power=0.9, dirt=0.15),
    "school_dark":  dict(floor=("#7e6a50", "#735f47", "#4a3d2c", 180, 24), wall="#a99d88", low="#6d5c48", rail="#5d4e3b", light=(0.75, 0.80, 1.0), power=0.4, dirt=0.35),
    "home":         dict(floor=("#a8835f", "#9b7854", "#6b5139", 150, 20), wall="#e8ddd2", low="#cbbcae", rail="#a58e79", light=(1.0, 0.9, 0.78), power=0.85, dirt=0.05),
    "real":         dict(floor=("#dcdfdc", "#d3d7d3", "#aeb4ae", 80), wall="#f0f2f0", low="#dfe3df", rail="#f8f9f8", light=(1.0, 1.0, 1.0), power=1.25, dirt=0.0),
    "town":         dict(floor=("#f3dbe3", "#ecd0da", "#d6aebb", 60), wall="#fae9ef", low="#f1cfda", rail="#fff4f7", light=(1.0, 0.92, 0.94), power=1.0, dirt=0.0),
}
T = THEMES.get(THEME, THEMES["hospital"])
FLOOR = tile_mat("floor", *T["floor"][:4], rough=0.18 if THEME in ("hospital", "lab", "real") else 0.45, noise=T["dirt"] * 0.6, row_px=T["floor"][4] if len(T["floor"]) > 4 else None)
WALLM = mat("wall", T["wall"], rough=0.7, noise=T["dirt"] * 0.5, bump=0.05)
LOWM = mat("wall_low", T["low"], rough=0.5, noise=T["dirt"] * 0.5)
RAILM = mat("rail", T["rail"], rough=0.3, coat=0.4)
METAL = mat("metal", "#c8ced1", rough=0.25, metal=0.9)
DMETAL = mat("dark_metal", "#5c6366", rough=0.35, metal=0.8)
WHITE = mat("white_paint", "#f1f3f2", rough=0.35, coat=0.3, noise=T["dirt"] * 0.4)
SHEET = mat("sheet", "#f6f7f7", rough=0.9, bump=0.15)
BLUESHEET = mat("blanket", "#cfe0e6", rough=0.95, bump=0.2)
WOOD = mat("wood", "#b48e62", rough=0.5, bump=0.08)
DWOOD = mat("dark_wood", "#6e5137", rough=0.55, bump=0.08)
CARD = mat("cardboard", "#b99a70", rough=0.9, bump=0.1)
LOCKER = mat("locker", "#8ea2a8", rough=0.35, metal=0.4, noise=T["dirt"] * 0.5)
GLASS = mat("glass", "#cfe3ea", rough=0.05)
SCREEN = mat("screen", "#0c1512", rough=0.1)
GREEN = mat("screen_line", "#7ce0a2", emit=6.0)
LEAF = mat("leaf", "#6f9a74", rough=0.6, bump=0.2)
POT = mat("pot", "#b4876a", rough=0.7)
BOARD = mat("blackboard", "#33493b", rough=0.85, bump=0.05)
CHALK = mat("chalk_tray", "#8f7d64", rough=0.6)
RUG = mat("rug", "#f2c9d5", rough=1.0, bump=0.3)
CURTAIN = mat("curtain", "#d8e6e3", rough=0.95, bump=0.1)
BLACK = mat("void", "#08090a", rough=1.0)


# ───────── 造型工具 ─────────
cur_group = None   # 目前在蓋哪一件家具（每件家具一個 collection，方便分開渲染）


def link(o):
    o.parent = root
    (cur_group or scene.collection).objects.link(o)
    return o


def box(x, y, w, d, z0, h, m, bevel=0.0):
    """地上 (x,y) 為左上、寬 w、深 d（往畫面下方）、從高度 z0 到 z0+h（都是像素）"""
    me = bpy.data.meshes.new("b")
    x0, y0, z = x / 100, -(y + d) / 100, z0 / 100
    x1, y1, z1 = (x + w) / 100, -y / 100, (z0 + h) / 100
    v = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z), (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me.from_pydata(v, [], f)
    o = link(bpy.data.objects.new("box", me))
    o.data.materials.append(m)
    if bevel:
        mod = o.modifiers.new("bv", "BEVEL")
        mod.width = bevel / 100
        mod.segments = 3
        mod.limit_method = "NONE"
    return o


def cyl(x, y, z0, r, h, m, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r / 100, depth=h / 100, location=(x / 100, -y / 100, (z0 + h / 2) / 100))
    o = bpy.context.active_object
    scene.collection.objects.unlink(o) if o.name in scene.collection.objects else None
    for c in o.users_collection:
        c.objects.unlink(o)
    link(o)
    o.data.materials.append(m)
    return o


def ball(x, y, z, r, m, sx=1.0, sy=1.0, sz=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=r / 100, location=(x / 100, -y / 100, z / 100))
    o = bpy.context.active_object
    for c in o.users_collection:
        c.objects.unlink(o)
    link(o)
    o.scale = (sx, sy, sz)
    o.data.materials.append(m)
    bpy.ops.object.shade_smooth() if False else None
    for poly in o.data.polygons:
        poly.use_smooth = True
    return o


# ───────── 家具（rect＝在地上佔的位置＝碰撞框；高度往上長） ─────────
def f_bed(x, y, w, d):
    hosp = THEME not in ("home", "school", "school_dark", "town")
    leg = METAL if hosp else WOOD
    for lx in (x + 6, x + w - 12):
        for ly in (y + 4, y + d - 8):
            cyl(lx + 3, ly + 2, 0, 3, 34, leg, 8)
    box(x, y, w, d, 32, 8, leg if hosp else WOOD, 1)
    box(x + 2, y + 1, w - 4, d - 2, 40, 16, SHEET, 5)                          # 床墊
    box(x + w * 0.38, y, w * 0.62 - 2, d, 50, 10, BLUESHEET if hosp else mat("quilt", "#e9c8b5", 0.95, bump=0.2), 4)   # 被子
    box(x + 8, y + 6, w * 0.22, d - 12, 54, 12, SHEET, 6)                      # 枕頭
    box(x - 2, y + 2, 6, d - 4, 0, 96 if hosp else 80, leg if hosp else WOOD, 1.5)          # 床頭
    if hosp:
        for k in range(3):
            box(x + w * 0.3 + k * w * 0.2, y + d - 3, 3, 3, 56, 18, METAL)   # 床邊欄杆
        box(x + w * 0.28, y + d - 3, w * 0.45, 3, 72, 3, METAL)


def f_desk(x, y, w, d, top=WOOD, legm=DWOOD, h=74):
    box(x, y, w, d, h - 6, 6, top, 1.5)
    for lx in (x + 3, x + w - 9):
        for ly in (y + 3, y + d - 9):
            box(lx, ly, 6, 6, 0, h - 6, legm)
    if w > 80:
        box(x + w - 46, y + 4, 40, d - 8, h - 30, 24, top, 1)                  # 抽屜


def f_cart(x, y, w, d):
    for lx in (x + 4, x + w - 8):
        for ly in (y + 4, y + d - 8):
            box(lx, ly, 4, 4, 6, 64, METAL)
            ball(lx + 2, ly + 2, 4, 4, DMETAL)
    box(x, y, w, d, 66, 4, WHITE, 1)
    box(x, y, w, d, 24, 3, WHITE, 1)
    for k in range(3):    # 托盤上的瓶瓶罐罐
        cyl(x + 18 + k * (w - 36) / 2, y + d / 2, 70, 5, 14 + k * 4, GLASS, 10)


def f_cabinet(x, y, w, d, h=118):
    box(x, y, w, d, 0, h, WHITE, 2)
    box(x + 4, y + d - 1, w / 2 - 6, 2, 46, h - 56, GLASS)                   # 玻璃門
    box(x + w / 2 + 2, y + d - 1, w / 2 - 6, 2, 46, h - 56, GLASS)
    box(x + 4, y + d - 1, w - 8, 2, 8, 34, WHITE, 1)
    for k in range(int(w // 30)):
        cyl(x + 14 + k * 26, y + d / 2, 60, 5, 18, mat("bottle", "#9fbfc9", 0.1), 8)


def f_locker(x, y, w, d, h=136):
    n = max(1, int(round(w / 40)))
    cw = w / n
    for k in range(n):
        box(x + k * cw + 1, y, cw - 2, d, 0, h, LOCKER, 1)
        for v in range(4):
            box(x + k * cw + cw * 0.3, y + d - 1, cw * 0.4, 1.5, h - 24 - v * 5, 2, DMETAL)
        box(x + k * cw + cw - 9, y + d - 1, 3, 2, h * 0.5, 14, METAL)


def f_shelf(x, y, w, d, h=146):
    side = DWOOD if THEME in ("school", "school_dark", "home") else METAL
    box(x, y, 4, d, 0, h, side)
    box(x + w - 4, y, 4, d, 0, h, side)
    box(x, y, w, 4, 0, h, side)
    for k in range(5):
        box(x, y, w, d, 4 + k * (h - 8) / 4, 3, side)
        if k < 4:
            px = x + 6
            while px < x + w - 12:
                bw = random.uniform(5, 12)
                bh = random.uniform(16, (h - 8) / 4 - 6)
                col = random.choice(["#c9b9a0", "#9fb3ba", "#d9cfc0", "#b7a58a", "#8fa0a6", "#e0d8cc"])
                box(px, y + 6, bw, d - 10, 7 + k * (h - 8) / 4, bh, mat("binder" + col, col, 0.8))
                px += bw + random.uniform(0.5, 3)


def f_chair(x, y, w, d):
    for lx in (x + 3, x + w - 6):
        for ly in (y + 3, y + d - 6):
            box(lx, ly, 3, 3, 0, 26, METAL)
    box(x, y, w, d, 26, 5, mat("seat", "#9fb3ba", 0.6), 2)
    box(x, y, w, 4, 26, 30, mat("seat", "#9fb3ba", 0.6), 2)


def f_plant(x, y, w, d):
    cx, cy = x + w / 2, y + d / 2
    cyl(cx, cy, 0, w * 0.32, 28, POT, 16)
    for k in range(9):
        a = k * 2.4
        ball(cx + math.cos(a) * w * 0.22, cy + math.sin(a) * d * 0.25, 46 + (k % 3) * 14, w * 0.22, LEAF, 1.0, 1.0, 0.7)


def f_machine(x, y, w, d):
    box(x, y, w, d, 0, 54, WHITE, 2)
    box(x + 6, y + d * 0.3, w - 12, 8, 54, 40, mat("monitor_case", "#d7dcdd", 0.4), 2)
    box(x + 10, y + d * 0.3 + 7.5, w - 20, 1.5, 59, 30, SCREEN)
    box(x + 13, y + d * 0.3 + 9, w - 26, 1, 72, 1.6, GREEN)
    cyl(x + w - 12, y + d / 2, 54, 1.5, 70, METAL, 8)                          # 點滴架
    ball(x + w - 12, y + d / 2, 120, 7, mat("iv_bag", "#e6f0f2", 0.1), 0.7, 0.4, 1.3)


def f_sink(x, y, w, d):
    box(x, y, w, d, 0, 62, WHITE, 3)
    box(x + 8, y + 6, w - 16, d - 12, 58, 6, mat("basin", "#dfe6e8", 0.15), 4)
    cyl(x + w / 2, y + 6, 62, 2.5, 18, METAL, 10)
    box(x + w / 2 - 2, y + 4, 4, 12, 78, 3, METAL)


def f_crate(x, y, w, d):
    box(x, y, w, d, 0, 36, CARD, 1)
    box(x, y + d / 2 - 2, w, 4, 36, 0.6, mat("tape", "#d8c9a6", 0.4))


def f_pillar(x, y, w, d):
    box(x, y, w, d, 0, 220, WALLM, 2)
    box(x - 2, y - 2, w + 4, d + 4, 0, 14, LOWM, 1)


def f_curtain(x, y, w, d):
    box(x, y + d / 2, w, 2, 150, 2, METAL)
    n = int(w // 10)
    for k in range(n):
        cyl(x + 5 + k * w / n, y + d / 2 + (2 if k % 2 else -2), 8, 6, 140, CURTAIN, 10)


def f_default(x, y, w, d):
    box(x, y, w, d, 0, 30, WHITE, 2)


FURN = {"bed": f_bed, "desk": f_desk, "table": (lambda x, y, w, d: f_cart(x, y, w, d) if THEME in ("hospital", "hospital_old", "lab", "basement", "real") else f_desk(x, y, w, d, mat("table_top", "#d9d2c4", 0.5), METAL, 70)),
        "cabinet": f_cabinet, "locker": f_locker, "shelf": f_shelf, "chair": f_chair, "plant": f_plant, "machine": f_machine,
        "sink": f_sink, "crate": f_crate, "box": f_crate, "pillar": f_pillar, "curtain": f_curtain}
FLAT = ("window", "rug", "blackboard")


# ───────── 房間本體 ─────────
groups = []   # (key, collection, 遊戲裡節點的位置, 畫面上的範圍 [x0,y0,x1,y1])
HEIGHT = {"bed": 100, "desk": 80, "table": 90, "cabinet": 124, "locker": 140, "shelf": 150, "chair": 60, "plant": 95,
          "machine": 135, "sink": 85, "crate": 40, "box": 40, "pillar": 400, "curtain": 155}


def furniture(key, kind, x, y, w, d, node):
    global cur_group
    col = bpy.data.collections.new(key)
    scene.collection.children.link(col)
    cur_group = col
    FURN.get(kind, f_default)(x, y, w, d)
    cur_group = None
    for o in col.objects:        # 只拉高，地上佔的位置不變
        o.location.z *= SC
        o.scale.z *= SC
    top = y - HEIGHT.get(kind, 34) * SC - 6
    groups.append((key, col, node, [x - 8, top, x + w + 8, y + d + 6]))


def flat(kind, x, y, w, d):
    if kind == "window":     # 窗：在後牆上（rect 在牆的那一條）
        z0 = max(8.0, WALL - (y + d))
        zz = WALL - y
        onwall(x - 4, w + 8, z0 - 4, zz - z0 + 8, 0.5, RAILM, 3)
        onwall(x, w, z0, zz - z0, 2.0, mat("sky", "#dfeff5", emit=1.2 if THEME != "school_dark" else 0.2), 1.5)
        onwall(x + w / 2 - 1.5, 3, z0, zz - z0, 3.0, RAILM, 1.5)
    elif kind == "blackboard":
        z0 = max(6.0, WALL - (y + d))
        zz = WALL - y
        onwall(x, w, z0, zz - z0, 0.5, BOARD, 2)
        onwall(x - 4, w + 8, z0 - 5, 5, 0.5, CHALK, 6)
    elif kind == "rug":
        box(x, y, w, d, 0, 0.6, RUG, 2)


# 地板（往外多鋪一點，邊緣不會露底）
# 牆面在 WALL-12（牆上的東西掛在 WALL-12～WALL 之間，才不會埋進牆裡）
WF = WALL - 12


def onwall(x, w, z0, h, layer, m, depth=1.5, bevel=0.0):
    """掛在後牆上的東西：layer 越大越靠前（0～8）"""
    return box(x, WF + layer, w, depth, z0, h, m, bevel)


box(-40, WF, W + 80, H - WF + 60, -1, 1, FLOOR)
# 後牆：下半牆、扶手、踢腳板
box(-40, WF - 30, W + 80, 30, 0, WALL + 200, WALLM)
if THEME in ("hospital", "hospital_old", "lab", "real", "basement"):
    onwall(-40, W + 80, 0, WALL * 0.42, 0, LOWM, 0.5)
    onwall(-40, W + 80, WALL * 0.42, 4, 0, RAILM, 4, 1)
elif THEME in ("school", "school_dark", "home"):
    onwall(-40, W + 80, 0, WALL * 0.36, 0, LOWM, 0.5)
    onwall(-40, W + 80, WALL * 0.36, 3, 0, RAILM, 3)
onwall(-40, W + 80, 0, 7, 0, RAILM, 2)

# 牆上的東西：牆邊的調查點畫成牆上的物件；其他空的地方放巨大的門（門頂超出畫面＝很大）、醫院的窗台站著白鴿
DOVE = mat("dove", "#f4f4f2", rough=0.8, bump=0.1)
DOVE_EYE = mat("dove_eye", "#b3141c", rough=0.2, emit=0.6)   # 眼睛是紅色的，一眨也不眨（chapter3.md）
FEATHER = mat("eagle_feather", "#6b4a2c", rough=0.7)
DOOR = mat("door", {"hospital": "#d9e3e1", "hospital_old": "#8c978f", "basement": "#3a4244", "lab": "#cfd9dc", "platform": "#9da4a1",
                    "school": "#b08e66", "school_dark": "#6f5a43", "home": "#b49a80", "real": "#e6eae6", "town": "#f6d4df"}.get(THEME, "#d9e3e1"), rough=0.45, noise=T["dirt"] * 0.5)
used = []
for s in room.get("spots", []):
    if "kind" in s:
        continue
    sx, sy = s["pos"]
    if sy < WALL + 80:
        used.append(sx)
        fw = 70.0
        onwall(sx - fw / 2 - 4, fw + 8, WALL * 0.45, WALL * 0.5 + 4, 1, DMETAL, 1.5)
        onwall(sx - fw / 2, fw, WALL * 0.45 + 3, WALL * 0.5 - 2, 2.5, mat("poster", random.choice(["#f2efe6", "#e8eef0", "#efe6e9"]), 0.8), 1)
        for k in range(3):
            onwall(sx - fw / 2 + 8, fw * (0.8 - k * 0.2), WALL * 0.8 - k * 9, 3, 3.5, mat("print", "#7f8d92", 0.8), 0.5)
for dr in room.get("doors", []):
    used.append(dr["pos"][0])
for p in room.get("props", []):
    if p.get("kind") in ("window", "blackboard"):
        used.append(p["rect"][0] + p["rect"][2] / 2)


def free(x, half):
    return all(abs(x - u) > half + 60 for u in used) and half + 20 < x < W - half - 20


hosp = THEME in ("hospital", "hospital_old", "lab", "basement", "real")
windows = 0
x = 260.0
k = 0
while x < W - 200:
    if free(x, 90) and k % 2 == 0:
        # 巨大的門：只看得到下面那一截
        onwall(x - 82, 164, 0, WALL + 200, 0.5, mat("door_frame", T["rail"], 0.4), 3)
        onwall(x - 72, 144, 0, WALL + 200, 1.5, DOOR, 3, 1)
        onwall(x - 1, 2, 0, WALL + 200, 4.4, DMETAL, 0.4)                           # 兩扇門的縫
        onwall(x + 40, 22, WALL * 0.75, 6, 4.5, METAL, 3, 1)                       # 門把
        onwall(x - 72, 144, 0, 14, 4.5, DMETAL, 0.8)                                # 門下的踢板
        onwall(x + 10, 50, WALL * 0.82, 40, 4.5, mat("door_no", "#f7f8f7", 0.5), 0.6)   # 門牌（太高，看不清楚）
        used.append(x)
    elif free(x, 70) and ((hosp and THEME != "basement") or THEME in ("school", "school_dark")):
        # 窗＋窗台上的白鴿（和平鴿的眼睛）
        zs = WALL * 0.35
        school = THEME in ("school", "school_dark")
        onwall(x - 70, 140, zs, WALL * 0.9, 0.5, RAILM, 3)
        glass = mat("evening_glass", "#e3c49c", rough=0.05, emit=0.5) if THEME == "school" else mat("night_glass", "#2c383f", rough=0.05)
        onwall(x - 63, 126, zs + 6, WALL * 0.9 - 10, 2.0, glass, 1.5)
        onwall(x - 1.5, 3, zs + 6, WALL * 0.9 - 10, 3.0, RAILM, 1.5)
        box(x - 76, WF, 152, 16, zs - 3, 4, RAILM, 1)                                # 窗台
        if CH5 and windows == 0:
            # 第五章：白鴿都不見了，窗台上只剩一根褐色的大羽毛（老鷹的）
            fx = x + random.uniform(-30, 30)
            ball(fx, WF + 8, zs + 1.5, 16, FEATHER, 1.0, 0.18, 0.08)
        if DOVES and random.random() < DOVE_P:
            # 白鴿：面向這邊，一直看著
            dx = x + random.uniform(-30, 30)
            q = 2.2 if SC > 1 else 1.4   # 玩偶世界：鴿子跟玩偶差不多大
            ball(dx, WF + 8, zs + 10 * q, 8 * q, DOVE, 1.0, 0.55, 1.05)
            ball(dx, WF + 10, zs + 21 * q, 5.2 * q, DOVE, 1.0, 0.8, 1.0)
            for ex in (-2.3 * q, 2.3 * q):
                ball(dx + ex, WF + 10 + 4.1 * q, zs + 22 * q, 1.1 * q, DOVE_EYE)
            box(dx - 1 * q, WF + 10 + 4 * q, 2 * q, 2.5 * q, zs + 19.5 * q, 1.8 * q, mat("beak", "#d99a9a", 0.5))
            ball(dx, WF + 3, zs + 8 * q, 6 * q, DOVE, 1.6, 0.3, 0.5)                    # 尾巴、翅膀
        windows += 1
        used.append(x)
    x += 230
    k += 1

# 第三章理事室：窗邊一根空的鷹架、地上一根很大的褐色羽毛（只出現一次，不解釋）
if "chapter3" in _ch and RID == "director":
    px = next((xx for xx in range(int(W) - 160, 160, -40) if free(xx, 30)), W - 160)
    pz = 95 * SC
    cyl(px, WF + 14, 0, 16, 3, DMETAL, 16)
    cyl(px, WF + 14, 0, 2.2, pz, DMETAL, 10)
    box(px - 26, WF + 12, 52, 4, pz, 4, mat("perch_wood", "#6e5137", 0.6), 1)
    ball(px + 30, WF + 30, 1.2, 20, FEATHER, 1.0, 0.2, 0.07)
    used.append(px)

# 房間裡的牆：碰撞框 rect 在畫面上整塊都是牆（前面是牆面、上面是牆頂）
for wr in room.get("walls", []):
    x, y, w, d = wr
    hg = min(90.0, max(0.0, d - 14))
    box(x, y + hg, w, d - hg, 0, hg, WALLM)
    box(x, y + hg, w, d - hg, hg, 3, RAILM)

# 地上的線（例如醫院的指示線）、色塊
for dc in room.get("decals", []):
    if dc.get("kind") == "line":
        pts = dc["points"]
        wd = float(dc.get("width", 6))
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            x0, x1 = min(ax, bx), max(ax, bx)
            y0, y1 = min(ay, by), max(ay, by)
            box(x0 - wd / 2, y0 - wd / 2, x1 - x0 + wd, y1 - y0 + wd, 0, 0.3, mat("line" + dc.get("color", ""), dc.get("color", "#f5a3b8"), 0.5))
    elif dc.get("kind") == "rect":
        x, y, w, d = dc["rect"]
        box(x, y, w, d, 0, 0.3, mat("decal" + dc.get("color", ""), dc.get("color", "#ffffff"), 0.6))

for p in room.get("props", []):
    kind = p.get("kind", "box")
    x, y, w, d = p["rect"]
    if kind in FLAT:
        flat(kind, x, y, w, d)
    else:
        furniture("prop:%s@%d,%d,%d,%d" % (kind, x, y, w, d), kind, x, y, w, d, [x, y + d])
for key in ("hides", "spots"):
    for s in room.get(key, []):
        if "kind" not in s:
            continue
        sw, sd = s.get("size", [60, 30])
        px, py = s["pos"]
        furniture("%s:%s" % (key[:-1], s["id"]), s["kind"], px - sw / 2, py - sd, sw, sd, [px, py])

# ───────── 燈光 ─────────
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
bgn = world.node_tree.nodes["Background"]
bgn.inputs["Color"].default_value = (*T["light"], 1)
bgn.inputs["Strength"].default_value = 0.025 * T["power"]
# 天花板的燈：一盞一盞的亮區，中間、角落暗下去（壓迫感來自明暗，不是血）
step = 460
lx = step / 2 + random.uniform(-40, 40)
while lx < W + step / 2:
    for ly in ([WALL + (H - WALL) * 0.45] if H - WALL < 520 else [WALL + (H - WALL) * 0.28, WALL + (H - WALL) * 0.72]):
        ld = bpy.data.lights.new("ceiling", "AREA")
        ld.shape = "RECTANGLE"
        ld.size = 1.1
        ld.size_y = 0.35
        ld.color = T["light"]
        ld.energy = 420 * T["power"]
        ld.spread = math.radians(100)
        lo = bpy.data.objects.new("ceiling", ld)
        lo.location = P(lx, ly, 380)
        link(lo)
    lx += step
sun = bpy.data.lights.new("fill", "SUN")
sun.energy = 0.35 * T["power"]
sun.angle = 0.8
sun.color = T["light"]
so = bpy.data.objects.new("fill", sun)
so.rotation_euler = (math.radians(55), math.radians(-12), 0)   # 從鏡頭這邊斜斜照過去，家具正面才看得清楚
scene.collection.objects.link(so)

# ───────── 鏡頭（45° 正交）＋渲染設定 ─────────
cd = bpy.data.cameras.new("cam")
cd.type = "ORTHO"
cd.ortho_scale = max(W, H) / 100.0
cam = bpy.data.objects.new("cam", cd)
cam.rotation_euler = (math.radians(45), 0, 0)
cx, cy = W / 200.0, -H / 200.0 * S2
cam.location = (cx, cy - 40.0, 40.0)
scene.collection.objects.link(cam)
scene.camera = cam
cd.clip_end = 200
r = scene.render
r.engine = "CYCLES"
r.resolution_x, r.resolution_y = int(W), int(H)
r.resolution_percentage = 100
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
prefs = bpy.context.preferences.addons["cycles"].preferences
for dev in ("OPTIX", "CUDA"):
    try:
        prefs.compute_device_type = dev
        prefs.get_devices()
        if any(d.type == dev for d in prefs.devices):
            for d in prefs.devices:
                d.use = d.type == dev
            scene.cycles.device = "GPU"
            break
    except Exception:
        pass
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"
scene.view_settings.exposure = -0.6


def cam_vis(o, v):
    o.visible_camera = v


def everything():
    return [o for o in scene.objects if o.type == "MESH"]


prop_objs = {key: list(col.objects) for key, col, _, _ in groups}
all_prop = {o.name for objs in prop_objs.values() for o in objs}

# 1) 背景：家具不出現在畫面上，但影子、反光都在
for o in everything():
    cam_vis(o, o.name not in all_prop)
r.film_transparent = False
r.use_border = False
r.image_settings.file_format = "JPEG"
r.image_settings.quality = 90
r.filepath = os.path.join(ODIR, "bg.jpg")
bpy.ops.render.render(write_still=True)

# 2) 每件家具：只有它出現（其他東西還在，會投影子、反光到它身上）、去背、只算它那一塊
r.film_transparent = True
r.image_settings.file_format = "PNG"
r.image_settings.color_mode = "RGBA"
r.use_border = True
r.use_crop_to_border = True
out = {"bg": "bg.jpg", "size": [W, H], "props": {}}
for key, col, node, (x0, y0, x1, y1) in groups:
    x0, y0, x1, y1 = max(0, int(x0)), max(0, int(y0)), min(W, int(math.ceil(x1))), min(H, int(math.ceil(y1)))
    if x1 <= x0 or y1 <= y0:
        continue
    for o in everything():
        cam_vis(o, o.name in {ob.name for ob in prop_objs[key]})
    r.border_min_x, r.border_max_x = x0 / W, x1 / W
    r.border_min_y, r.border_max_y = 1 - y1 / H, 1 - y0 / H
    fn = key.replace(":", "_").replace("@", "_").replace(",", "_") + ".png"
    r.filepath = os.path.join(ODIR, fn)
    bpy.ops.render.render(write_still=True)
    out["props"][key] = {"tex": fn, "off": [x0 - node[0], y0 - node[1]]}

json.dump(out, open(os.path.join(ODIR, "room.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ODIR, RID + ".blend"))
print("ROOM DONE", RID, len(out["props"]))
