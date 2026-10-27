"""把一個 .glb 模型渲染成走路圖用的四個方向（front／left／right／back，去背），燈光、鏡頭跟 director.py 一樣。
模型要面向 Godot 的 -Z（＝Blender 的 +Y；chase_assets.py 做的都是）。
用法：blender --background --factory-startup --python tools/art/blender/glb_views.py -- <模型.glb> <輸出資料夾>
之後：py -3.11 tools/art/make_walk_sheet.py 輸出/front.png 輸出/left.png 輸出/back.png walk4/<id>.png --right 輸出/right.png
"""
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, OUT = argv[0], argv[1]
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=GLB)
root = bpy.data.objects.new("root", None)
scene.collection.objects.link(root)
for o in list(scene.objects):
    if o is not root and o.parent is None:
        o.parent = root
# 模型面向 +Y → 轉 180° 變成面向 -Y（鏡頭在 -Y）
base = math.pi
# 高度：鏡頭框住整個人
zs = [(o.matrix_world @ Vector(c)).z for o in scene.objects if o.type == "MESH" for c in o.bound_box]
top = max(zs)

world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.8, 0.82, 0.85, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
scene.world = world


def light(name, loc, energy, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size = energy, size
    o = bpy.data.objects.new(name, ld)
    o.location = loc
    scene.collection.objects.link(o)
    o.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


light("key", (-2.5, -3.5, 3.2), 160, 3.0)
light("fill", (3.0, -3.0, 1.6), 45, 3.0)
light("rim", (0.5, 3.5, 2.8), 120, 2.0)
cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = top * 1.12
cam = bpy.data.objects.new("cam", cam_d)
cam.location = (0, -10, top * 0.5 + 1.6)
cam.rotation_euler = (Vector((0, 0, top * 0.47)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "CYCLES"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x, scene.render.resolution_y = 640, 960
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "AgX"
scene.view_settings.exposure = 0.55
for name, deg in (("front", 0), ("left", -90), ("right", 90), ("back", 180)):
    root.rotation_euler = (0, 0, base + math.radians(deg))
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
print("VIEWS DONE", OUT)
