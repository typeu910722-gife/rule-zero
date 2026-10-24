#!/usr/bin/env python3
"""第二章漂白鎮：「可以走的地方」遮罩 game/art/ch2/walk_mask_ch2.png

石板、屋頂、淺色草地亮度很接近。這裡只留暖色、表面比較平的石板，
扣掉房子、河對岸、診所門口那片花圃，再用窄線補上樹影切開的缺口。
線的位置對過背景：宿舍前貼著牆根的人行道、診所花圃外側的彎路、
月台走道。遮罩是原圖的一半解析度：白＝可以走。

用法：python3 tools/build_walk_mask_ch2.py [--preview 預覽.jpg]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.ndimage import uniform_filter, binary_closing, binary_dilation

SRC = "game/art/ch2/backgrounds/ch2_bg_town_day.jpg"
OUT = "game/art/ch2/walk_mask_ch2.png"
W, H = 1600, 1150

# 房子、屋頂、車站雨棚、鐵軌。底邊要停在牆根，不要蓋到外面的人行道。
BUILDINGS = [
    # 宿舍：牆根大約在 y=262，再往下是人行道
    [(40, 20), (605, 20), (605, 245), (500, 248), (430, 258), (180, 260), (120, 248), (40, 235)],
    [(40, 185), (185, 185), (185, 250), (40, 250)],
    [(20, 415), (130, 350), (562, 350), (562, 548), (470, 590), (20, 590)],
    # 食堂屋頂。台階和前面的石板在 y>690
    [(625, 490), (1015, 490), (1015, 688), (625, 688)],
    [(690, 0), (912, 0), (912, 238), (690, 238)],
    [(985, 0), (1525, 0), (1525, 278), (1200, 290), (1040, 290), (985, 268)],
    [(1392, 0), (1600, 0), (1600, 640), (1392, 640)],
    [(1050, 330), (1392, 330), (1392, 640), (1300, 640), (1300, 545), (1050, 545)],
    [(0, 812), (655, 812), (655, 956), (0, 956)],
    [(0, 1016), (1600, 1016), (1600, 1150), (0, 1150)],
]
# 河、對岸、鐵絲網外側的草叢。界線在這一側石板的外面。
FENCE = [(700, 1150), (760, 1040), (900, 960), (1080, 900), (1280, 840), (1500, 790), (1600, 760), (1600, 1150)]
# 診所門口的花圃。白花鋪在淺色地上，亮度跟石板一樣，要另外挖掉。
# 彎路從花圃北緣過去，多邊形上緣停在 y=340，不切到台階。
GARDEN = [(1000, 345), (1100, 340), (1140, 375), (1080, 415), (990, 405), (975, 370)]
# 樹影、燈柱把石板切成幾段的地方。只補畫面上看得到路的缺口。
BRIDGES = [
    # 宿舍前人行道：貼著牆根（約 y=285），不穿下面那排灌木
    (18, [(200, 292), (280, 286), (360, 284), (440, 286), (520, 292)]),
    # 教室門口接到公園那條彎路，從樹幹南側繞
    (16, [(190, 655), (250, 678), (320, 692)]),
    # 公園彎路接到廣場環道
    (20, [(490, 590), (530, 560)]),
    # 公園東端接到食堂前面的石板（中間只隔一條磚縫）
    (20, [(448, 674), (560, 692), (660, 710), (710, 720)]),
    # 食堂前的石板，過燈柱，接到河邊那條步道
    (16, [(862, 796), (894, 796)]),
    # 洗衣房門口的石板，沿著房子前面接到食堂
    (16, [(1160, 625), (1100, 660), (1040, 700), (960, 724)]),
    # 診所：沿花圃外側走到台階，不橫切花圃
    (18, [(860, 450), (870, 380), (885, 330), (940, 305), (1020, 298), (1120, 300), (1220, 296)]),
    # 車站雨棚東角，接到月台
    (18, [(690, 930), (710, 975), (640, 995), (520, 998)]),
]
# 月台走道（雨棚影子裡，偵測不到整條）
PLATFORM = (8, 984, 600, 26)
SEED = (720, 452)


def _blocked_image():
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    for poly in BUILDINGS:
        d.polygon(poly, fill=255)
    d.polygon(GARDEN, fill=255)
    d.polygon(FENCE, fill=255)
    return np.asarray(img) > 0


def _paint_bridges():
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    for width, pts in BRIDGES:
        d.line(pts, fill=255, width=width, joint="curve")
        r = width / 2.0
        for x, y in (pts[0], pts[-1]):
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    x, y, w, h = PLATFORM
    d.rectangle((x, y, x + w, y + h), fill=255)
    return np.asarray(img) > 0


def build():
    """石板，加上補過的缺口。草地、屋頂、花圃、河對岸不算。"""
    rgb = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    bright = rgb.mean(axis=2)
    red, green, blue = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = uniform_filter(bright, 11)
    var = uniform_filter(bright * bright, 11) - mean * mean
    texture = np.sqrt(np.maximum(var, 0))
    warm = (red + 6 > green) & (green + 8 > blue)
    # 上限放到 236：向陽的石板比屋頂邊緣還亮，屋頂靠上面的多邊形扣掉
    stone = (bright > 140) & (bright < 236) & (texture < 21.0) & warm
    blocked = _blocked_image()
    keep = stone & ~blocked
    keep |= _paint_bridges()
    keep &= ~blocked
    # 只黏合約 8px 以內的裂縫（燈柱、磚縫），不要把花圃兩邊黏在一起
    keep = binary_closing(keep, structure=np.ones((9, 9)), iterations=1) & ~blocked
    keep = binary_dilation(keep, iterations=1) & ~blocked
    lab, _n = ndimage.label(keep)
    seed = lab[SEED[1], SEED[0]]
    if seed == 0:
        raise SystemExit("廣場種子 %s 不在路上" % (SEED,))
    return lab == seed


def main():
    keep = build()
    out = Image.fromarray((keep * 255).astype(np.uint8)).resize((W // 2, H // 2), Image.NEAREST)
    out.save(OUT)
    print("完成", OUT, out.size, "可走比例 %.1f%%" % (keep.mean() * 100))
    if "--preview" in sys.argv:
        p = sys.argv[sys.argv.index("--preview") + 1]
        im = np.asarray(Image.open(SRC).convert("RGB")).astype(float)
        im[keep] = im[keep] * 0.45 + np.array([255, 40, 40]) * 0.55
        Image.fromarray(im.astype(np.uint8)).save(p, quality=82)


if __name__ == "__main__":
    main()
