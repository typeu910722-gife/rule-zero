import sys
# 第二章 Fen 補尾巴：python3 tools/art/fix/fen_tail_ch2.py tools/art/fix game <輸出資料夾>（尾巴素材 tools/art/fix/tail/crop.png）
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
S = sys.argv[1]; GAME = sys.argv[2]; OUT = sys.argv[3]
t = Image.open(S + "/tail/crop.png").convert("RGBA")
m = Image.new("L", t.size, 255); d = ImageDraw.Draw(m)
d.polygon([(0, 390), (120, 470), (125, 650), (0, 650)], fill=0)      # 屁股
d.rectangle((175, 585, 340, 650), fill=0)                             # 地面
d.rectangle((0, 610, 340, 650), fill=0)
a = Image.composite(t.getchannel("A"), Image.new("L", t.size, 0), m.filter(ImageFilter.GaussianBlur(3)))
t.putalpha(a)
t = ImageEnhance.Color(t).enhance(1.15)
t = t.crop(t.getbbox())

def put(fen_path, out_path, h, base, angle, mirror, front):
    fen = Image.open(fen_path).convert("RGBA")
    tt = t.transpose(Image.FLIP_LEFT_RIGHT) if mirror else t
    s = h / tt.height
    tt = tt.resize((max(1, int(tt.width * s)), h), Image.LANCZOS).rotate(angle, expand=True, resample=Image.BICUBIC)
    layer = Image.new("RGBA", fen.size, (0, 0, 0, 0))
    # base：尾巴根部（圖的下緣中間）要放的位置
    layer.alpha_composite(tt, (int(base[0] - tt.width / 2), int(base[1] - tt.height)))
    if front:
        out = fen.copy(); out.alpha_composite(layer)
    else:
        out = layer; out.alpha_composite(fen)
    out.save(out_path)

P = GAME + "/art/ch2/characters/"
for f in ["ch2_fen_portrait_a_default", "ch2_fen_portrait_a_away"]:
    put(P + "portraits/%s.png" % f, OUT + "/%s.png" % f, 330, (405, 660), -12, False, False)
put(P + "sprites/ch2_fen_sprite_stand_sheet.png", OUT + "/ch2_fen_sprite_stand_sheet.png", 60, (52, 142), 24, True, True)
