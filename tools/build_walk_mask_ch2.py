#!/usr/bin/env python3
"""第二章漂白鎮（v2：手描道路＋自動抓石板地）：「可以走的地方」遮罩 game/art/ch2/walk_mask_ch2.png（跟第一章一樣只能走在路上）

漂白鎮的屋頂顏色跟石板路幾乎一樣，用顏色自動抓會把屋頂當成路，所以道路是照地圖手動描的：
每條路是一串中心點＋路寬。廣場是一個橢圓。最後扣掉高台、公告欄、鐵絲網另一邊。
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
ROADS = [
    (46, [(40, 245), (170, 295), (300, 335)]),                       # 宿舍左邊的小路
    (34, [(300, 335), (380, 318), (470, 290)]),                      # → 宿舍門口
    (52, [(470, 285), (560, 305), (602, 345), (622, 405)]),          # 宿舍門口 → 廣場
    (44, [(600, 335), (640, 285), (700, 268)]),                      # 廣場 → 廣播塔（左）
    (44, [(880, 268), (945, 285), (990, 335)]),                      # 廣播塔（右）→ 廣場
    (40, [(700, 268), (880, 268)]),                                  # 廣播塔腳下
    (46, [(960, 345), (1010, 308), (1120, 302), (1380, 305)]),       # 廣場 → 診所門前
    (56, [(970, 470), (1005, 530), (1025, 610), (1040, 650)]),       # 廣場 → 洗衣房那條路
    (50, [(1040, 640), (1150, 622), (1270, 632)]),                   # 洗衣房門前
    (60, [(640, 495), (575, 555), (480, 598), (380, 640), (240, 660), (110, 645), (20, 625)]),  # 廣場 → 教室前
    (60, [(415, 640), (400, 720), (372, 790)]),                      # 教室前 → 南邊
    (52, [(340, 805), (500, 815), (650, 820), (785, 835)]),          # 車站屋頂後面的路
    (58, [(700, 822), (688, 880), (668, 940), (640, 990)]),          # → 月台右端
    (46, [(600, 722), (800, 726), (985, 712)]),                      # 食堂門前
    (50, [(985, 712), (925, 770), (862, 800), (785, 835)]),          # 沿著鐵絲網
    (40, [(1040, 650), (1000, 700), (985, 712)]),                    # 洗衣房 → 食堂門前
]
RECTS = [
    (0, 975, 650, 38),       # 月台（屋頂下面）
    (1050, 545, 210, 55),    # 洗衣房的走廊
]
PLAZA = (792, 432, 192, 90)  # 廣場：中心、半徑（橢圓）
BLOCK = [
    (725, 388, 132, 74),     # 廣場中間的白色高台
    (725, 300, 132, 88),     # 公告欄
]
# 鐵絲網的另一邊：跟 game/scripts/world/bleach_town.gd 的 BLOCKED 相同
FENCE = [(640, 1150), (668, 1010), (800, 872), (880, 808), (1000, 748), (1250, 658), (1600, 626), (1600, 1150)]


# 建築物、屋頂、高塔、焚化爐、車站屋頂、鐵軌：一律走不進去（屋頂顏色跟石板很像，所以要手動扣掉）
BUILDINGS = [
    [(40, 20), (605, 20), (605, 245), (470, 268), (440, 288), (200, 288), (150, 270), (40, 250)],  # 宿舍
    [(40, 185), (185, 185), (185, 275), (40, 275)],                                                 # 宿舍旁的箱子
    [(20, 415), (130, 350), (562, 350), (562, 548), (470, 590), (20, 590)],                         # 教室
    [(575, 522), (1002, 522), (1002, 682), (575, 682)],                                             # 食堂
    [(690, 0), (912, 0), (912, 238), (690, 238)],                                                   # 廣播塔
    [(985, 0), (1525, 0), (1525, 278), (1200, 290), (1040, 290), (985, 268)],                      # 診所（治療室）
    [(1392, 0), (1600, 0), (1600, 640), (1392, 640)],                                               # 焚化爐
    [(1050, 330), (1392, 330), (1392, 640), (1300, 640), (1300, 545), (1050, 545)],                # 洗衣房
    [(0, 812), (655, 812), (655, 956), (0, 956)],                                                   # 車站屋頂
    [(0, 1016), (1600, 1016), (1600, 1150), (0, 1150)],                                             # 鐵軌
]
SEED = (790, 500)   # 從廣場連得到的才算


def build_v1():
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    for width, pts in ROADS:
        d.line(pts, fill=255, width=width, joint="curve")
        r = width / 2
        for x, y in (pts[0], pts[-1]):
            d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    for x, y, w, h in RECTS:
        d.rectangle((x, y, x + w, y + h), fill=255)
    cx, cy, rx, ry = PLAZA
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
    for x, y, w, h in BLOCK:
        d.rectangle((x, y, x + w, y + h), fill=0)
    d.polygon(FENCE, fill=0)
    return np.asarray(img) > 0


def build():
    """石板地：亮度夠、跟廣場連在一起；再加上原本手描的路（保證主要路線一定通）。"""
    import cv2
    im = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float32)
    lum = cv2.GaussianBlur(im.mean(axis=2), (0, 0), 6)
    ground = (lum > 150).astype(np.uint8)
    ground = cv2.morphologyEx(ground, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (11, 11)))
    ground = cv2.morphologyEx(ground, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (19, 19)))
    ground = ground > 0
    ground |= build_v1()
    block = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(block)
    for poly in BUILDINGS:
        d.polygon(poly, fill=255)
    for x, y, w, h in BLOCK:
        d.rectangle((x, y, x + w, y + h), fill=255)
    d.polygon(FENCE, fill=255)
    keep = ground & (np.asarray(block) == 0)
    for x, y, w, h in RECTS:   # 月台、洗衣房走廊：就算在屋頂下面也能走
        keep[y:y + h, x:x + w] = True
    n, lab = cv2.connectedComponents(keep.astype(np.uint8))
    return lab == lab[SEED[1], SEED[0]]


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
