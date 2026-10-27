"""3D 追逐（scripts/ch3/chase3d.gd）的模型：追兵、障礙物，匯出成 Godot 用的 .glb。
設定（docs/script/chapter3.md 2.2）：追兵是意識回到人類身體、神志不清的畢業生：人類、病人服、拖著點滴架，
頭髮沒剪、手腕上還有沒拆的名牌線。第三章是「乾淨的恐怖」：沒有血。臉被長髮蓋住，看不到。
玩偶的視線只有 0.75 公尺，人類 1.85 公尺：抬頭才看得到他。

用法：blender --background --factory-startup --python tools/art/blender/chase_assets.py -- <輸出資料夾>
輸出：graduate.glb（面向 +Y＝Godot 的 -Z）、gurney.glb、ivpole.glb、wheelchair.glb、預覽 *_preview.png
"""
import math
import os
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
os.makedirs(OUT, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, col, rough=0.7, metal=0.0, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*col, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    if emit:
        p.inputs["Emission Color"].default_value = (*col, 1)
        p.inputs["Emission Strength"].default_value = emit
    return m


def put(o, m, smooth=True):
    o.data.materials.append(m)
    if smooth:
        for poly in o.data.polygons:
            poly.use_smooth = True
    return o


def cyl(a, b, r1, r2, m, verts=12):
    """從點 a 到點 b 的圓柱（兩頭半徑 r1、r2）"""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=d.length, location=(a + b) / 2)
    o = bpy.context.active_object
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d.normalized())
    return put(o, m)


def ball(c, r, m, s=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=r, location=c)
    o = bpy.context.active_object
    o.scale = s
    return put(o, m)


def cube(c, size, m, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=c)
    o = bpy.context.active_object
    o.scale = size
    if bevel:
        md = o.modifiers.new("bv", "BEVEL")
        md.width = bevel
        md.segments = 2
    return put(o, m, smooth=False)


def join_all(name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def export(name):
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", export_apply=True, export_yup=True)


def preview(name, target_h, dist):
    """檢查用：從前、側兩個方向渲染（玩偶的高度往上看）"""
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.05, 0.06, 0.065, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    for loc, e in (((2, 3, 4), 400), ((-3, 2, 2), 150)):
        ld = bpy.data.lights.new("l", "POINT")
        ld.energy = e
        lo = bpy.data.objects.new("l", ld)
        lo.location = loc
        sc.collection.objects.link(lo)
    cd = bpy.data.cameras.new("c")
    cd.lens = 28
    cam = bpy.data.objects.new("c", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 600, 800
    sc.view_settings.view_transform = "AgX"
    for tag, ang in (("front", 0), ("side", 90)):
        a = math.radians(ang)
        cam.location = (math.sin(a) * dist, math.cos(a) * dist, 0.75)       # 正面在 +Y
        d = Vector((0, 0, target_h)) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(OUT, f"{name}_{tag}_preview.png")
        bpy.ops.render.render(write_still=True)


# ───────── 追兵：神志不清的畢業生 ─────────
def graduate():
    reset()
    GOWN = mat("gown", (0.70, 0.80, 0.80), 0.9)
    GOWN_D = mat("gown_dots", (0.50, 0.62, 0.66), 0.9)
    SKIN = mat("skin", (0.80, 0.70, 0.64), 0.6)
    HAIR = mat("hair", (0.035, 0.03, 0.03), 0.5)
    TAG = mat("name_tag", (0.95, 0.95, 0.93), 0.4)
    METAL = mat("metal", (0.75, 0.77, 0.78), 0.25, 0.9)
    BAG = mat("iv_bag", (0.88, 0.94, 0.95), 0.1)
    # 往前駝著：上半身往前（+Y）傾
    hip = Vector((0, 0, 0.95))
    neck = Vector((0, 0.16, 1.52))
    head = Vector((0, 0.24, 1.62))
    # 病人服：一件長到膝蓋的寬袍子（上窄下寬）
    cyl(hip + Vector((0, 0.02, -0.45)), hip + Vector((0, 0.03, 0.05)), 0.25, 0.2, GOWN, 16)
    cyl(hip, neck - Vector((0, 0.02, 0.05)), 0.2, 0.17, GOWN, 16)
    ball(neck - Vector((0, 0.02, 0.06)), 0.18, GOWN, (1.25, 0.8, 0.5))               # 肩膀
    for k in range(5):                                                                 # 病人服的小點點
        ball(hip + Vector((0.12 - k * 0.06, 0.2 + (k % 2) * 0.01, -0.1 + k * 0.12)), 0.018, GOWN_D)
    # 腿、腳（光腳）
    for sx in (-0.1, 0.1):
        cyl((sx, 0.03, 0.5), (sx * 0.9, 0.0, 0.05), 0.055, 0.045, SKIN)
        ball((sx * 0.9, 0.05, 0.03), 0.05, SKIN, (0.9, 1.9, 0.5))
    # 頭：低著頭，頭髮很長、沒剪，整個蓋住臉
    cyl(neck, head, 0.055, 0.05, SKIN)
    ball(head, 0.12, SKIN, (0.95, 1.0, 1.1))
    ball(head + Vector((0, -0.02, 0.03)), 0.13, HAIR, (1.0, 1.05, 1.05))
    for i in range(34):
        a = i / 34 * 2 * math.pi
        top = head + Vector((math.sin(a) * 0.11, math.cos(a) * 0.11 - 0.01, 0.04))
        hang = 0.42 + 0.12 * math.sin(i * 1.7) + (0.12 if math.cos(a) > 0 else 0.0)   # 前面那幾綹比較長，垂到胸口
        low = top + Vector((math.sin(a) * 0.05, math.cos(a) * 0.07 + 0.04, -hang))
        cyl(top, low, 0.026, 0.008, HAIR, 6)
    # 左手：伸向前、往下（要抓玩偶）；右手：拖著點滴架
    sh_l, sh_r = neck + Vector((-0.2, -0.02, -0.06)), neck + Vector((0.2, -0.02, -0.06))
    el_l = sh_l + Vector((-0.04, 0.22, -0.22))
    wr_l = el_l + Vector((0.02, 0.32, -0.12))
    cyl(sh_l, el_l, 0.05, 0.042, GOWN)
    cyl(el_l, wr_l, 0.038, 0.03, SKIN)
    for f in range(4):                                                                 # 張開的手指
        base = wr_l + Vector((-0.03 + f * 0.02, 0.04, -0.01))
        cyl(base, base + Vector((-0.01 + f * 0.008, 0.09, -0.04)), 0.009, 0.006, SKIN, 6)
    cyl(wr_l + Vector((0, -0.02, 0)), wr_l + Vector((0, 0.005, 0)), 0.036, 0.036, TAG, 10)   # 手腕的名牌線
    el_r = sh_r + Vector((0.08, -0.02, -0.28))
    wr_r = el_r + Vector((0.05, 0.02, -0.25))
    cyl(sh_r, el_r, 0.05, 0.042, GOWN)
    cyl(el_r, wr_r, 0.038, 0.03, SKIN)
    ball(wr_r + Vector((0.01, 0.0, -0.04)), 0.04, SKIN, (0.8, 1.0, 1.2))
    # 點滴架（握在右手，有輪子）
    px, py = wr_r.x + 0.05, wr_r.y
    cyl((px, py, 0.08), (px, py, 1.95), 0.012, 0.012, METAL, 8)
    for k in range(5):
        a = k / 5 * 2 * math.pi
        cyl((px, py, 0.08), (px + math.cos(a) * 0.26, py + math.sin(a) * 0.26, 0.05), 0.012, 0.012, METAL, 6)
        ball((px + math.cos(a) * 0.26, py + math.sin(a) * 0.26, 0.03), 0.03, METAL)
    cyl((px - 0.12, py, 1.92), (px + 0.12, py, 1.92), 0.008, 0.008, METAL, 6)
    ball((px + 0.1, py, 1.78), 0.07, BAG, (0.7, 0.35, 1.4))
    cyl((px + 0.1, py, 1.66), wr_l * 0 + Vector((px - 0.02, py + 0.05, 1.0)), 0.004, 0.004, BAG, 5)   # 管子
    join_all("graduate")
    export("graduate")
    preview("graduate", 1.3, 3.0)


# ───────── 障礙物 ─────────
def gurney():
    reset()
    METAL = mat("metal", (0.75, 0.77, 0.78), 0.25, 0.9)
    SHEET = mat("sheet", (0.93, 0.94, 0.94), 0.9)
    PAD = mat("pad", (0.55, 0.68, 0.72), 0.6)
    L, W, H = 1.9, 0.62, 0.78
    for x in (-L / 2 + 0.08, L / 2 - 0.08):
        for y in (-W / 2 + 0.06, W / 2 - 0.06):
            cyl((x, y, 0.08), (x, y, H - 0.08), 0.018, 0.018, METAL, 8)
            ball((x, y, 0.05), 0.05, METAL)
    cube((0, 0, H - 0.06), (L, W, 0.05), METAL, 0.01)
    cube((0, 0, H), (L - 0.04, W - 0.04, 0.09), PAD, 0.03)
    cube((0.15, 0, H + 0.06), (L - 0.4, W - 0.02, 0.05), SHEET, 0.02)
    cube((-L / 2 + 0.22, 0, H + 0.1), (0.3, 0.42, 0.1), SHEET, 0.04)
    for y in (-W / 2, W / 2):
        cyl((-0.5, y, H + 0.05), (0.6, y, H + 0.05), 0.012, 0.012, METAL, 6)
    join_all("gurney")
    export("gurney")


def ivpole():
    reset()
    METAL = mat("metal", (0.75, 0.77, 0.78), 0.25, 0.9)
    BAG = mat("iv_bag", (0.88, 0.94, 0.95), 0.1)
    cyl((0, 0, 0.08), (0, 0, 1.95), 0.013, 0.013, METAL, 8)
    for k in range(5):
        a = k / 5 * 2 * math.pi
        cyl((0, 0, 0.08), (math.cos(a) * 0.28, math.sin(a) * 0.28, 0.05), 0.012, 0.012, METAL, 6)
        ball((math.cos(a) * 0.28, math.sin(a) * 0.28, 0.03), 0.03, METAL)
    cyl((-0.13, 0, 1.92), (0.13, 0, 1.92), 0.008, 0.008, METAL, 6)
    ball((0.11, 0, 1.78), 0.07, BAG, (0.7, 0.35, 1.4))
    cyl((0.11, 0, 1.66), (0.05, 0.1, 0.6), 0.004, 0.004, BAG, 5)
    join_all("ivpole")
    export("ivpole")


def wheelchair():
    reset()
    METAL = mat("metal", (0.75, 0.77, 0.78), 0.25, 0.9)
    SEAT = mat("seat", (0.18, 0.22, 0.25), 0.7)
    TYRE = mat("tyre", (0.05, 0.05, 0.05), 0.8)
    for x in (-0.3, 0.3):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.02, location=(x, 0.05, 0.32), rotation=(0, math.pi / 2, 0))
        put(bpy.context.active_object, TYRE)
        cyl((x, -0.25, 0.05), (x, -0.25, 0.5), 0.012, 0.012, METAL, 6)
        ball((x, -0.3, 0.05), 0.05, TYRE)
        cyl((x, 0.25, 0.48), (x, 0.3, 1.0), 0.013, 0.013, METAL, 8)
    cube((0, -0.02, 0.5), (0.56, 0.48, 0.05), SEAT, 0.01)
    cube((0, 0.27, 0.78), (0.56, 0.03, 0.42), SEAT, 0.01)
    join_all("wheelchair")
    export("wheelchair")


graduate()
gurney()
ivpole()
wheelchair()
print("CHASE ASSETS DONE")
