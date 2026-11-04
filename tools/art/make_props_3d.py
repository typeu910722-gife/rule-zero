"""第四、五章 3D 走廊的擺設（低面數 glb）：用 Blender 命令列產生，不用開視窗。

學校：school_desk（課桌＋椅子）、locker（三格置物櫃）；真實醫院：bench（候診長椅）、cart（推車）。
單位是公尺，原點在地上的中心，正面朝 +Y（Godot 匯入後是 -Z）。
用法："C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --python tools/art/make_props_3d.py -- game/art/3d
"""
import os
import sys

import bpy

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "game/art/3d"


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, rgb, rough=0.7, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m


def box(size, loc, m, name="part"):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(m)
    return o


def cyl(r, h, loc, m, name="leg"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=r, depth=h, location=loc)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(m)
    return o


def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.join()
    bpy.context.object.name = name
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB", use_selection=False)
    print("ok", name)


def school_desk():
    clear()
    wood = mat("wood", (0.62, 0.45, 0.28))
    steel = mat("steel", (0.35, 0.36, 0.38), 0.4, 0.8)
    # 課桌
    box((0.6, 0.42, 0.03), (0, 0.1, 0.72), wood, "top")
    box((0.56, 0.36, 0.02), (0, 0.1, 0.6), steel, "shelf")
    for x in (-0.27, 0.27):
        for y in (-0.08, 0.28):
            cyl(0.015, 0.7, (x, y, 0.35), steel)
    # 椅子（翻過來倒放在桌上：死巷裡疊起來的桌椅）
    box((0.4, 0.38, 0.025), (0, 0.1, 1.2), wood, "seat")
    box((0.4, 0.025, 0.28), (0, -0.08, 1.05), wood, "back")
    for x in (-0.18, 0.18):
        for y in (-0.06, 0.27):
            cyl(0.012, 0.42, (x, y, 0.95), steel)
    export("school_desk")


def locker():
    clear()
    paint = mat("locker", (0.52, 0.6, 0.62), 0.5, 0.4)
    dark = mat("vent", (0.15, 0.16, 0.17), 0.6)
    for i, x in enumerate((-0.31, 0.0, 0.31)):
        box((0.3, 0.45, 1.8), (x, 0, 0.9), paint, "door%d" % i)
        for k in range(3):
            box((0.16, 0.01, 0.015), (x, -0.226, 1.55 - k * 0.04), dark, "vent")
        box((0.02, 0.02, 0.1), (x + 0.1, -0.235, 1.0), dark, "handle")
    export("locker")


def bench():
    clear()
    seat = mat("seat", (0.55, 0.66, 0.72), 0.6)
    steel = mat("steel", (0.7, 0.71, 0.72), 0.35, 0.8)
    for i, x in enumerate((-0.5, 0.0, 0.5)):
        box((0.46, 0.44, 0.06), (x, 0, 0.45), seat, "s%d" % i)
        box((0.46, 0.05, 0.4), (x, 0.2, 0.72), seat, "b%d" % i)
    box((1.5, 0.06, 0.05), (0, 0.05, 0.4), steel, "beam")
    for x in (-0.7, 0.7):
        box((0.05, 0.4, 0.05), (x, 0, 0.02), steel, "foot")
        cyl(0.025, 0.4, (x, 0.05, 0.2), steel)
    export("bench")


def cart():
    clear()
    white = mat("cart", (0.9, 0.91, 0.9), 0.5)
    steel = mat("steel", (0.7, 0.71, 0.72), 0.35, 0.8)
    blue = mat("blue", (0.45, 0.62, 0.78), 0.6)
    for k, z in enumerate((0.2, 0.55, 0.9)):
        box((0.6, 0.45, 0.03), (0, 0, z), white, "tray%d" % k)
    box((0.3, 0.25, 0.1), (-0.1, 0, 0.97), blue, "box")
    for x in (-0.28, 0.28):
        for y in (-0.2, 0.2):
            cyl(0.015, 0.85, (x, y, 0.52), steel)
            cyl(0.04, 0.03, (x, y, 0.06), steel, "wheel")
    box((0.03, 0.4, 0.03), (0.33, 0, 1.0), steel, "handle")
    export("cart")


os.makedirs(OUT, exist_ok=True)
for f in (school_desk, locker, bench, cart):
    f()
