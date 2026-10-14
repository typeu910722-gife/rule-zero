"""小布的 3D 模型（Blender，用程式產生）。

  python3 tools/blender/bu_model.py <輸出資料夾>

產生：bu.glb（遊戲用，低面數、上色）＋ bu_preview.png（Cycles 試算圖）＋ bu.blend
外型參考：docs/art/bu_design_updated.png（捲毛小綿羊、綠斗篷、皮革小背包、名牌）
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

OUT = Path(sys.argv[-1] if len(sys.argv) > 1 else "/tmp/bu")
OUT.mkdir(parents=True, exist_ok=True)
rng = random.Random(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, color, rough=0.8, sheen=0.0, sss=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    if sheen:
        b.inputs["Sheen Weight"].default_value = sheen
        b.inputs["Sheen Roughness"].default_value = 0.4
    if sss:
        b.inputs["Subsurface Weight"].default_value = sss
        b.inputs["Subsurface Radius"].default_value = (0.05, 0.03, 0.02)
    return m


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


WOOL = mat("wool", srgb("#f3e6cf"), 0.95, sheen=1.0, sss=0.15)
FACE = mat("face", srgb("#fbefe2"), 0.9, sheen=0.6, sss=0.25)
PINK = mat("ear_in", srgb("#f2b3ac"), 0.85, sheen=0.5)
HOOF = mat("hoof", srgb("#5a3a2c"), 0.9, sheen=0.3)
EYE = mat("eye", srgb("#2a1a14"), 0.08)
WHITE = mat("glint", (1, 1, 1), 0.1)
BLUSH = mat("blush", srgb("#f4a3a0"), 0.9)
CAPE = mat("cape", srgb("#7d8f5c"), 0.95, sheen=0.5)
LEATHER = mat("leather", srgb("#9a6236"), 0.6)
TAG = mat("tag", srgb("#e9d6ae"), 0.8)
ROPE = mat("rope", srgb("#d9c08a"), 0.9)
INK = mat("ink", srgb("#4a2f22"), 0.9)

parts = []


def add(obj, m):
    obj.data.materials.append(m)
    for p in obj.data.polygons:
        p.use_smooth = True
    parts.append(obj)
    return obj


def sphere(loc, scale, m, seg=32, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = scale
    return add(o, m)


# ── 身體與頭：一顆一顆的捲毛 ──
BODY_C = Vector((0, 0, 0.42))
HEAD_C = Vector((0, -0.02, 0.86))
sphere(BODY_C, (0.30, 0.27, 0.30), WOOL)
sphere(HEAD_C, (0.33, 0.30, 0.30), WOOL)


def curls(center, rx, ry, rz, n, size, skip=None):
    for _ in range(n):
        # 均勻分布在橢球表面
        u, v = rng.random(), rng.random()
        th, ph = 2 * math.pi * u, math.acos(2 * v - 1)
        d = Vector((math.sin(ph) * math.cos(th), math.sin(ph) * math.sin(th), math.cos(ph)))
        if skip and skip(d):
            continue
        p = center + Vector((d.x * rx, d.y * ry, d.z * rz))
        s = size * rng.uniform(0.75, 1.15)
        sphere(p, (s, s, s * 0.85), WOOL, seg=12)


curls(HEAD_C, 0.31, 0.28, 0.29, 150, 0.07, skip=lambda d: d.y < -0.35 and d.z < 0.55)   # 臉的地方不長毛
curls(BODY_C, 0.29, 0.26, 0.29, 140, 0.065, skip=lambda d: d.z < -0.7)

# ── 臉 ──
FACE_C = HEAD_C + Vector((0, -0.2, -0.05))
sphere(FACE_C, (0.2, 0.13, 0.17), FACE)
for sx in (-1, 1):
    e = HEAD_C + Vector((0.085 * sx, -0.325, -0.02))
    sphere(e, (0.045, 0.03, 0.055), EYE, seg=24)
    sphere(e + Vector((0.016 * sx * -1 + 0.012, -0.022, 0.022)), (0.013, 0.008, 0.013), WHITE, seg=12)
    sphere(HEAD_C + Vector((0.14 * sx, -0.3, -0.1)), (0.04, 0.012, 0.025), BLUSH, seg=12)
# 鼻子、嘴
sphere(HEAD_C + Vector((0, -0.345, -0.08)), (0.022, 0.014, 0.015), PINK, seg=12)
bpy.ops.mesh.primitive_torus_add(location=HEAD_C + Vector((0, -0.335, -0.125)), major_radius=0.02, minor_radius=0.005, rotation=(math.radians(90), 0, 0))
add(bpy.context.active_object, INK)

# ── 垂下來的耳朵 ──
for sx in (-1, 1):
    base = HEAD_C + Vector((0.27 * sx, -0.06, 0.02))
    o = sphere(base + Vector((0.07 * sx, 0, -0.08)), (0.07, 0.045, 0.17), FACE, rot=(0, math.radians(-38 * sx), 0))
    sphere(base + Vector((0.078 * sx, -0.03, -0.085)), (0.05, 0.02, 0.13), PINK, rot=(0, math.radians(-38 * sx), 0))

# ── 腳和手（深咖啡色的蹄） ──
for sx in (-1, 1):
    sphere(Vector((0.12 * sx, -0.03, 0.08)), (0.085, 0.1, 0.09), HOOF)
    sphere(Vector((0.29 * sx, -0.06, 0.42)), (0.07, 0.07, 0.08), HOOF)

# ── 綠斗篷（環繞脖子的布）＋ 繩結 ──
bpy.ops.mesh.primitive_cone_add(vertices=48, radius1=0.36, radius2=0.2, depth=0.2, location=(0, 0.01, 0.62))
cape = add(bpy.context.active_object, CAPE)
bpy.ops.object.modifier_add(type="SOLIDIFY")
cape.modifiers["Solidify"].thickness = 0.02
for sx in (-1, 1):
    sphere(Vector((0.03 * sx, -0.27, 0.66)), (0.03, 0.02, 0.025), ROPE, seg=12)

# ── 名牌（寫著「小布」） ──
bpy.ops.mesh.primitive_cube_add(location=(0, -0.29, 0.53))
tag = bpy.context.active_object
tag.scale = (0.05, 0.008, 0.07)
add(tag, TAG)
bpy.ops.object.text_add(location=(0, -0.3, 0.53), rotation=(math.radians(90), 0, 0))
txt = bpy.context.active_object
txt.data.body = "小布"
for fp in ["/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc", "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"]:
    try:
        txt.data.font = bpy.data.fonts.load(fp)
        break
    except Exception:
        pass
txt.data.size = 0.04
txt.data.align_x = "CENTER"
txt.data.align_y = "CENTER"
txt.data.extrude = 0.002
txt.data.materials.append(INK)
bpy.ops.object.convert(target="MESH")
parts.append(bpy.context.active_object)

# ── 皮革小背包（右邊）＋ 背帶 ──
bpy.ops.mesh.primitive_cube_add(location=(0.27, -0.12, 0.35))
bag = bpy.context.active_object
bag.scale = (0.05, 0.09, 0.08)
bpy.ops.object.modifier_add(type="BEVEL")
bag.modifiers["Bevel"].width = 0.02
bag.modifiers["Bevel"].segments = 3
add(bag, LEATHER)
bpy.ops.mesh.primitive_torus_add(location=(0.05, -0.02, 0.5), major_radius=0.33, minor_radius=0.012, rotation=(math.radians(8), math.radians(52), 0))
add(bpy.context.active_object, LEATHER)

# ── 尾巴 ──
sphere(Vector((0, 0.3, 0.32)), (0.08, 0.07, 0.08), WOOL)

# 合併成一個物件
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
for p in parts:
    bpy.context.view_layer.objects.active = p
    for m in list(p.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
bu = bpy.context.active_object
bu.name = "Bu"
print("faces", len(bu.data.polygons))

# ── 試算圖：Cycles，暖色主光＋冷色邊光 ──
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.film_transparent = True
cam_data = bpy.data.cameras.new("cam")
cam_data.lens = 60
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (0.55, -2.4, 0.95)
direction = Vector((0, 0, 0.6)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
for name, loc, energy, color, size in [("key", (1.5, -2.0, 2.4), 260, (1.0, 0.86, 0.72), 1.2),
                                       ("fill", (-2.0, -1.5, 1.2), 70, (0.75, 0.8, 1.0), 2.0),
                                       ("rim", (-0.8, 2.0, 1.8), 220, (1.0, 0.7, 0.8), 0.8)]:
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.color = color
    ld.size = size
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    lo.rotation_euler = (Vector((0, 0, 0.6)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(lo)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.08, 0.12, 1)
scene.world = world
scene.render.filepath = str(OUT / "bu_preview.png")
bpy.ops.render.render(write_still=True)

bpy.ops.export_scene.gltf(filepath=str(OUT / "bu.glb"), use_selection=False, export_apply=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "bu.blend"))
print("done")
