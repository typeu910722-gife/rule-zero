"""人類時期的孩子躺在病床上的圖（第四章「第一個晚上」、第五章醒來的病房）。
從走路圖正面第一格切出頭和肩膀，放在枕頭上；身體蓋棉被。
asleep：閉著眼睛（被打了針、還沒醒）　asleep_tied：睡著、也綁著　tied：醒著被綁（掙扎的動作在遊戲裡做）　awake：醒著
輸出 game/art/beds/<id>_<state>.png（216×192，跟病床圖同一個座標：枕頭在上面中間）
用法：py -3.11 tools/art/make_bed_sleepers.py"""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "game")
WALK = os.path.join(ROOT, "art", "walk4")
OUT = os.path.join(ROOT, "art", "beds")
W, H = 216, 192
HEAD_W = 92          # 頭（含頭髮）在床上的寬度
PILLOW = (108, 64)   # 頭的中心


def head_crop(cid):
    im = Image.open(os.path.join(WALK, cid + ".png")).convert("RGBA")
    c = im.width // 4
    f = im.crop((0, 0, c, c)).resize((320, 320), Image.LANCZOS)
    return f.crop((40, 10, 280, 190))   # 頭髮到肩膀


def close_eyes(img):
    """把眼睛塗成膚色，再畫兩條往下彎的線（Q 版的臉：眼睛在切圖的 y 106–146）。
    只塗眼睛附近一個橢圓裡「不像皮膚、也不像頭髮」的點，瀏海留著"""
    a = np.array(img).astype(np.float32)
    rgb, al = a[:, :, :3], a[:, :, 3]
    face = rgb[140:156, 96:144].reshape(-1, 3)
    lum = face.mean(1)
    skin = np.median(face[lum >= np.percentile(lum, 60)], axis=0)
    hair = np.median(rgb[36:62, 96:144].reshape(-1, 3), axis=0)
    d_skin = np.abs(rgb - skin).sum(2)
    d_hair = np.abs(rgb - hair).sum(2)
    yy, xx = np.mgrid[0:a.shape[0], 0:a.shape[1]]
    out = a.copy()
    centers = []
    for x0, x1 in ((62, 119), (121, 178)):
        y0, y1 = 106, 146
        m = (d_skin[y0:y1, x0:x1] > 50) & (d_hair[y0:y1, x0:x1] > 70) & (al[y0:y1, x0:x1] > 200)
        ys, xs = np.where(m)
        cx, cy = ((x0 + int(np.median(xs)), y0 + int(np.median(ys))) if len(ys) > 30 else ((x0 + x1) // 2, 126))
        centers.append((cx, cy))
        ell = ((xx - cx) / 19.0) ** 2 + ((yy - cy) / 14.0) ** 2 <= 1.0
        fill = ell & (d_skin > 28) & (d_hair > 70) & (al > 200)
        out[fill, 0:3] = skin
    res = Image.fromarray(out.astype(np.uint8))
    d = ImageDraw.Draw(res)
    for cx, cy in centers:
        d.arc((cx - 13, cy - 6, cx + 13, cy + 8), 15, 165, fill=(74, 48, 46, 255), width=3)
    return res


def blanket(w, h):
    """棉被：淡淡的灰藍白，上緣反折，中間有身體的起伏（房間的色調在遊戲裡再蓋上去）"""
    b = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle((0, 6, w - 1, h - 1), 16, fill=(226, 230, 238, 255), outline=(150, 158, 176, 255), width=2)
    # 陰影：兩邊暗一點
    sh = Image.new("L", (w, h), 0)
    sd = ImageDraw.Draw(sh)
    sd.rectangle((0, 0, 14, h), fill=60)
    sd.rectangle((w - 14, 0, w, h), fill=60)
    sh = sh.filter(ImageFilter.GaussianBlur(8))
    dark = Image.new("RGBA", (w, h), (120, 128, 150, 255))
    mask = Image.fromarray((np.array(sh) * (np.array(b)[:, :, 3] > 0)).astype(np.uint8))
    b.paste(dark, (0, 0), mask)
    d = ImageDraw.Draw(b)
    # 身體的起伏：兩條淡淡的皺褶
    d.line((w // 2 - 22, 34, w // 2 - 30, h - 14), fill=(196, 202, 216, 255), width=2)
    d.line((w // 2 + 22, 34, w // 2 + 30, h - 14), fill=(196, 202, 216, 255), width=2)
    # 反折
    d.rounded_rectangle((0, 0, w - 1, 18), 9, fill=(246, 247, 250, 255), outline=(150, 158, 176, 255), width=2)
    return b


def straps(img, top):
    d = ImageDraw.Draw(img)
    for y in (top + 30, top + 66):
        d.rectangle((34, y, W - 34, y + 9), fill=(112, 84, 62, 255), outline=(60, 44, 34, 255))
        d.rectangle((W // 2 - 7, y - 2, W // 2 + 7, y + 11), outline=(196, 186, 150, 255), width=2)
    return img


def build(cid, state):
    """只有頭（和一點點肩膀）放在枕頭上；身體在遊戲裡用床本身的畫蓋回去（像蓋著被子）"""
    head = head_crop(cid)
    if state.startswith("asleep"):
        head = close_eyes(head)
    s = HEAD_W / 160.0
    head = head.resize((int(head.width * s), int(head.height * s)), Image.LANCZOS)
    img = Image.new("RGBA", (W, H))
    # 臉的中心（切圖裡 x=120, y=125）放在枕頭上
    img.alpha_composite(head, (int(PILLOW[0] - 120 * s), int(PILLOW[1] - 125 * s)))
    return img


def main(ids):
    os.makedirs(OUT, exist_ok=True)
    for spec in ids:
        cid, state = spec.split(":")
        build(cid, state).save(os.path.join(OUT, "%s_%s.png" % (cid, state)))
        print("ok", cid, state)


if __name__ == "__main__":
    # 沒給參數：重新產生關卡裡用到的全部（levels/*.json 的 sleepers）
    import json, glob
    need = set()
    for lv in glob.glob(os.path.join(ROOT, "levels", "*.json")):
        for r in json.load(open(lv, encoding="utf-8"))["rooms"].values():
            for sl in r.get("sleepers", []):
                need.add("%s:%s" % (sl["char"], sl.get("state", "asleep")))
    main(sys.argv[1:] or sorted(need))
