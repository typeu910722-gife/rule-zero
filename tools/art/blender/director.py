"""理事（車掌的哥哥）的 3D 模型 → 四個方向的去背渲染圖（給 make_walk_sheet.py 做走路圖）。

設定（CLAUDE.md 1-5）：玩偶世界裡的真人，大人的人類比例、布料質感、臉不畫出來。
很高、白色大衣、白手套、肩上（左肩）一隻老鷹。臉照車掌的做法：藏在帽簷的黑影裡。

用法（Blender 背景模式，用 CPU 渲染，不會搶訓練中的顯示卡）：
  blender --background --factory-startup --python tools/art/blender/director.py -- <輸出資料夾>
輸出：front.png、left.png（朝左）、right.png（朝右）、back.png、director.blend
"""
import math
import os
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(os.getcwd(), "director_views")
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
root = bpy.data.objects.new("Director", None)
scene.collection.objects.link(root)


# ---------- 材質（布料：低反光、絨毛、細細的布紋） ----------
def mat(name, color, rough=0.85, sheen=0.6, bump=0.12, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rough
    p.inputs["Metallic"].default_value = metal
    for key in ("Sheen Weight", "Sheen"):
        if key in p.inputs:
            p.inputs[key].default_value = sheen
            break
    if bump:
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 180.0
        tex.inputs["Detail"].default_value = 6.0
        b = nt.nodes.new("ShaderNodeBump")
        b.inputs["Strength"].default_value = bump
        nt.links.new(tex.outputs["Fac"], b.inputs["Height"])
        nt.links.new(b.outputs["Normal"], p.inputs["Normal"])
    return m


COAT = mat("coat_white", (0.86, 0.85, 0.82))
GLOVE = mat("glove_white", (0.95, 0.95, 0.96), rough=0.6, sheen=0.3, bump=0.04)
TROUSER = mat("trouser", (0.16, 0.16, 0.18))
SHOE = mat("shoe", (0.04, 0.04, 0.045), rough=0.35, sheen=0.0, bump=0.0)
SHADOW = mat("face_shadow", (0.0, 0.0, 0.0), rough=1.0, sheen=0.0, bump=0.0)
VISOR = mat("visor", (0.03, 0.03, 0.035), rough=0.3, sheen=0.0, bump=0.0)
BAND = mat("cap_band", (0.12, 0.12, 0.13))
GOLD = mat("gold", (0.75, 0.55, 0.22), rough=0.35, sheen=0.0, bump=0.0, metal=0.8)
E_BROWN = mat("eagle_brown", (0.22, 0.12, 0.06), sheen=0.8)
E_DARK = mat("eagle_wing", (0.13, 0.07, 0.035), sheen=0.8)
E_WHITE = mat("eagle_white", (0.93, 0.92, 0.88), sheen=0.8)
E_YELLOW = mat("eagle_yellow", (0.95, 0.68, 0.12), rough=0.5, sheen=0.2, bump=0.0)
E_EYE = mat("eagle_eye", (0.01, 0.01, 0.01), rough=0.15, sheen=0.0, bump=0.0)


def finish(o, m, smooth=True, subsurf=0, name=None):
    o.data.materials.append(m)
    if smooth:
        for poly in o.data.polygons:
            poly.use_smooth = True
    if subsurf:
        mod = o.modifiers.new("smooth", "SUBSURF")
        mod.levels = mod.render_levels = subsurf
    o.parent = root
    if name:
        o.name = name
    return o


def ball(loc, scale, m, name=None, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, location=loc)
    o = bpy.context.object
    o.scale = scale
    return finish(o, m, name=name)


def cyl(loc, r1, r2, depth, m, rot=(0, 0, 0), scale=(1, 1, 1), name=None, verts=48, subsurf=0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    if not subsurf:
        bev = o.modifiers.new("bevel", "BEVEL")
        bev.width, bev.segments = 0.012, 3
    return finish(o, m, name=name, subsurf=subsurf)


def box(loc, size, m, rot=(0, 0, 0), name=None):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bev = o.modifiers.new("bevel", "BEVEL")
    bev.width, bev.segments = min(size) * 0.3, 2
    return finish(o, m, name=name)


# ---------- 身體（朝 -Y：面對鏡頭；角色的左邊是 +X） ----------
# 很高：約 8 頭身，衣擺長到小腿
for sx in (-1, 1):
    cyl((sx * 0.085, 0, 0.36), 0.062, 0.058, 0.62, TROUSER, name=f"leg_{sx}")
    ball((sx * 0.085, -0.04, 0.045), (0.065, 0.095, 0.055), SHOE, name=f"shoe_{sx}")

HEM, SHOULDER = 0.42, 1.44
R_HEM, R_TOP, YS = 0.27, 0.19, 0.68   # 大衣下襬比肩膀寬一點（A 字），前後比左右薄


def coat_r(z):
    return R_HEM + (R_TOP - R_HEM) * (z - HEM) / (SHOULDER - HEM)


cyl((0, 0, (HEM + SHOULDER) / 2), R_HEM, R_TOP, SHOULDER - HEM, COAT, scale=(1, YS, 1), name="coat")
ball((0, 0, SHOULDER - 0.02), (0.235, 0.155, 0.1), COAT, name="shoulders")
cyl((0, 0, 1.5), 0.085, 0.075, 0.09, COAT, name="collar")
# 衣領翻領（前面兩片）
for sx in (-1, 1):
    box((sx * 0.06, -coat_r(1.32) * YS - 0.004, 1.32), (0.07, 0.012, 0.2), COAT, rot=(0, sx * math.radians(-18), 0), name=f"lapel_{sx}")
# 前襟：兩排金扣子
for z in (1.22, 1.06, 0.9, 0.74):
    for sx in (-1, 1):
        ball((sx * 0.055, -coat_r(z) * YS - 0.006, z), (0.014, 0.008, 0.014), GOLD, name="button", seg=16)
# 背面：腰帶片（兩顆扣子），讓背面一眼就和正面不同
box((0, coat_r(1.02) * YS + 0.006, 1.02), (0.24, 0.014, 0.05), COAT, name="back_belt")
for sx in (-1, 1):
    ball((sx * 0.09, coat_r(1.02) * YS + 0.016, 1.02), (0.012, 0.007, 0.012), GOLD, name="back_button", seg=16)

# 袖子＋白手套
for sx in (-1, 1):
    top = Vector((sx * 0.235, 0, 1.4))
    hand = Vector((sx * 0.27, -0.01, 0.84))
    mid, d = (top + hand) / 2, (hand - top)
    ang = math.atan2(d.x, -d.z)
    cyl(tuple(mid), 0.07, 0.06, d.length, COAT, rot=(0, -ang, 0), name=f"sleeve_{sx}")
    cyl(tuple(hand + Vector((0, 0, 0.035))), 0.064, 0.064, 0.03, COAT, rot=(0, -ang, 0), name=f"cuff_{sx}")
    ball(tuple(hand - Vector((0, 0, 0.03))), (0.052, 0.045, 0.075), GLOVE, name=f"glove_{sx}")
    ball(tuple(hand - Vector((-sx * 0.035, 0.02, 0.0))), (0.02, 0.02, 0.035), GLOVE, name=f"thumb_{sx}")

# 頭：臉在帽簷的影子裡（全黑，和車掌一樣），白色大簷帽
ball((0, 0, 1.64), (0.12, 0.12, 0.135), SHADOW, name="head_shadow")
cyl((0, 0, 1.755), 0.13, 0.135, 0.07, BAND, name="cap_band")
cyl((0, 0.01, 1.815), 0.136, 0.17, 0.06, COAT, scale=(1, 1.02, 1), name="cap_crown")
cyl((0, 0.01, 1.85), 0.17, 0.165, 0.02, COAT, scale=(1, 1.02, 1), name="cap_top")
cyl((0, -0.11, 1.73), 0.12, 0.12, 0.014, VISOR, rot=(math.radians(-14), 0, 0), scale=(1, 0.6, 1), name="cap_visor")
ball((0, -0.14, 1.79), (0.025, 0.01, 0.022), GOLD, name="cap_badge", seg=16)

# ---------- 老鷹（站在理事的左肩：+X） ----------
EX, EZ = 0.2, 1.47
ball((EX, 0.01, EZ + 0.12), (0.075, 0.085, 0.11), E_BROWN, name="eagle_body")
for sx in (-1, 1):
    ball((EX + sx * 0.06, 0.03, EZ + 0.11), (0.03, 0.085, 0.1), E_DARK, name=f"eagle_wing_{sx}")
    ball((EX + sx * 0.022, -0.02, EZ + 0.01), (0.014, 0.025, 0.012), E_YELLOW, name=f"eagle_talon_{sx}")
ball((EX, 0.09, EZ + 0.02), (0.045, 0.06, 0.018), E_WHITE, name="eagle_tail")
ball((EX, -0.025, EZ + 0.255), (0.058, 0.06, 0.058), E_WHITE, name="eagle_head")
cyl((EX, -0.095, EZ + 0.245), 0.022, 0.004, 0.06, E_YELLOW, rot=(math.radians(100), 0, 0), name="eagle_beak", verts=24)
for sx in (-1, 1):
    ball((EX + sx * 0.04, -0.06, EZ + 0.27), (0.009, 0.009, 0.009), E_EYE, name=f"eagle_eye_{sx}", seg=16)

# ---------- 燈光、鏡頭、渲染 ----------
world = bpy.data.worlds.new("studio")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.75, 0.77, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.25
scene.world = world


def light(name, loc, energy, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size = energy, size
    o = bpy.data.objects.new(name, ld)
    o.location = loc
    scene.collection.objects.link(o)
    o.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


# 燈跟著鏡頭（角色轉，燈不動），每個方向的光線都一樣
light("key", (-2.5, -3.5, 3.2), 160, 3.0)
light("fill", (3.0, -3.0, 1.6), 45, 3.0)
light("rim", (0.5, 3.5, 2.8), 120, 2.0)

cam_d = bpy.data.cameras.new("cam")
cam_d.type = "ORTHO"
cam_d.ortho_scale = 2.15
cam = bpy.data.objects.new("cam", cam_d)
cam.location = (0, -10, 2.6)
cam.rotation_euler = (Vector((0, 0, 0.95)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 96
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x, scene.render.resolution_y = 640, 960
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "AgX"
scene.view_settings.exposure = 0.55

# 角色朝 -Y。轉 -90° → 朝畫面左邊（-X）；+90° → 朝右；180° → 背面
for name, deg in (("front", 0), ("left", -90), ("right", 90), ("back", 180)):
    root.rotation_euler = (0, 0, math.radians(deg))
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("render", name)

root.rotation_euler = (0, 0, 0)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, "director.blend"))
print("done", OUT)
