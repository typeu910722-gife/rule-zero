#!/usr/bin/env python3
"""第二章漂白鎮：「可以走的地方」遮罩 game/art/ch2/walk_mask_ch2.png（跟第一章一樣只能走在路上）

屋頂和石板幾乎同色，用亮度抓會把屋頂、草地也算成路，所以只留手描的路：
每條路是一串中心點＋路寬，廣場是圓環。最後扣掉建築物、高台、公告欄、鐵絲網另一邊。
遮罩是原圖的一半解析度：白＝可以走。

用法：python3 tools/build_walk_mask_ch2.py [--preview 預覽.jpg]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

SRC = "game/art/ch2/backgrounds/ch2_bg_town_day.jpg"
OUT = "game/art/ch2/walk_mask_ch2.png"
W, H = 1600, 1150

# 地圖座標（1600×1150）：(路寬, [中心點…])
# 中心點沿著畫面上的石板路走，不抄近路穿過草地或屋頂。廣場是圓環，不是填滿的橢圓。
ROADS = [
    (48, [(30, 300), (160, 318), (300, 318), (430, 308), (530, 300)]),          # 宿舍門口前
    (46, [(530, 300), (610, 345), (670, 400), (700, 440)]),                      # 宿舍 → 廣場環
    (44, [(640, 275), (760, 285), (880, 275), (960, 310)]),                      # 廣播塔南側的路
    (42, [(760, 285), (750, 360), (730, 420)]),                                  # 塔 → 廣場環北側
    (42, [(920, 310), (900, 370), (860, 430)]),                                  # 塔右 → 廣場環
    # 診所：從廣場東側往北，貼著洗衣房屋頂的北緣走到台階（不穿進建築）
    (50, [(860, 430), (960, 380), (1030, 340), (1140, 318), (1280, 312)]),
    # 洗衣房門口：沿食堂前的路往東，貼著台階南側，不橫切前院
    (40, [(1000, 705), (1120, 670), (1240, 650), (1340, 665)]),
    # 教室：沿南側石板，再從食堂西側繞進廣場
    (44, [(20, 680), (240, 698), (460, 690), (560, 640), (580, 530), (660, 470)]),
    (48, [(430, 718), (620, 726), (820, 724), (980, 708)]),                      # 食堂台階前
    # 鐵絲網這一側，貼著網子走到月台右端，不斜穿中間的樹叢
    (34, [(980, 710), (930, 745), (880, 778), (830, 820), (770, 868), (700, 945), (620, 990)]),
]
RECTS = [
    (0, 970, 740, 44),       # 月台走道（車站屋頂在 y<956，鐵軌在 y>1016）
]
# 點名廣場的石板圓環：中心、外徑、線寬（等角所以是扁的）
RING = (792, 452, 172, 64, 56)
BLOCK = [
    (748, 400, 100, 70),     # 廣場中間的白色高台（不能站上去）
    (748, 318, 100, 82),     # 公告欄本體
]
# 鐵絲網的另一邊：跟 game/scripts/world/bleach_town.gd 的 BLOCKED 相同
FENCE = [(640, 1150), (668, 1010), (800, 872), (880, 808), (1000, 748), (1250, 658), (1600, 626), (1600, 1150)]


# 建築物、屋頂、高塔、焚化爐、車站屋頂、鐵軌：一律走不進去（屋頂顏色跟石板很像，所以要手動扣掉）
BUILDINGS = [
    [(40, 20), (605, 20), (605, 245), (470, 268), (440, 288), (200, 288), (150, 270), (40, 250)],  # 宿舍
    [(40, 185), (185, 185), (185, 275), (40, 275)],                                                 # 宿舍旁的箱子
    [(20, 415), (130, 350), (562, 350), (562, 548), (470, 590), (20, 590)],                         # 教室
    [(640, 555), (990, 555), (990, 695), (640, 695)],                                               # 食堂（西側、北側的石板要留著）
    [(690, 0), (912, 0), (912, 238), (690, 238)],                                                   # 廣播塔
    [(985, 0), (1525, 0), (1525, 278), (1200, 290), (1040, 290), (985, 268)],                      # 診所（治療室）
    [(1392, 0), (1600, 0), (1600, 640), (1392, 640)],                                               # 焚化爐
    [(1050, 330), (1392, 330), (1392, 640), (1300, 640), (1300, 545), (1050, 545)],                # 洗衣房
    [(0, 812), (655, 812), (655, 956), (0, 956)],                                                   # 車站屋頂
    [(0, 1016), (1600, 1016), (1600, 1150), (0, 1150)],                                             # 鐵軌
]
SEED = (700, 452)   # 廣場圓環左側，從這裡連得到的才算


def build_v1():
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    for width, pts in ROADS:
        d.line(pts, fill=255, width=width, joint="curve")
        r = width / 2
        for x, y in (pts[0], pts[-1]):
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    cx, cy, rx, ry, rw = RING
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), outline=255, width=rw)
    return np.asarray(img) > 0


def build():
    """只留手描的石板路（跟廣場圓環連在一起）。亮度自動抓會把屋頂和草地也算進去。"""
    from scipy import ndimage
    keep = build_v1()
    block = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(block)
    for poly in BUILDINGS:
        d.polygon(poly, fill=255)
    for x, y, w, h in BLOCK:
        d.rectangle((x, y, x + w, y + h), fill=255)
    d.polygon(FENCE, fill=255)
    keep = keep & (np.asarray(block) == 0)
    for x, y, w, h in RECTS:   # 月台走道：屋頂遮罩扣掉之後再加回來
        keep[y:y + h, x:x + w] = True
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
