"""全遊戲美術清單：game/art 底下每一個可以換掉的圖（給外包用）。
py -P tools/art/make_art_inventory.py <輸出.csv>
換圖規則：同檔名、同尺寸（或同比例放大，見需求文件）、同樣的透明／不透明。"""
import csv, json, os, re, sys
from PIL import Image

GAME = os.path.join(os.path.dirname(__file__), "..", "..", "game")
ART = os.path.join(GAME, "art")

# 第一章（art 根目錄）各檔的中文用途
ROOT = {
    "bg_bakery": "麵包店（麻糬）", "bg_classroom": "記憶：教室", "bg_clocktower": "鐘塔", "bg_glove": "手套事件",
    "bg_hospital_child": "記憶：醫院（孩子）", "bg_hospital_empty": "記憶：空的病房", "bg_hospital_haruka": "記憶：遙的病床",
    "bg_mayor_broken": "壞掉的鎮長", "bg_mem_class": "記憶：班上", "bg_mem_hospital": "記憶：醫院", "bg_mem_sea": "記憶：海",
    "bg_mem_toilet": "記憶：那一天（廁所外，不畫人）", "bg_nt_dog": "夜晚：小狗居民家", "bg_nt_lulu": "夜晚：露露家",
    "bg_nt_mochi": "夜晚：麻糬家", "bg_nt_popo": "夜晚：波波家", "bg_nt_tama": "夜晚：小玉家", "bg_platform": "月台",
    "bg_plaza": "廣場", "bg_repair": "修理鋪", "bg_room_night": "小布的房間（夜）", "bg_town2": "小鎮", "bg_train": "火車車廂",
    "bg_train_night": "火車車廂（夜）", "room": "小布的房間（探索）", "title_platform": "標題畫面背景（月台）",
    "boot_splash": "開機畫面", "ui_chapter_end_bg": "章節結束畫面背景", "ui_ending_bg": "結局畫面背景",
    "town_map": "小鎮大地圖（探索，俯視）", "forest_map": "森林地圖（探索，俯視）", "fen_treehouse": "Fen 的樹屋（地圖上的建築）",
    "mirror_states": "鏡子 4 種狀態（4 格橫排，每格 256×256）",
    "ui_button": "按鈕", "ui_button_focus": "按鈕（選取中）", "ui_choice": "選項", "ui_choice_focus": "選項（選取中）",
    "ui_choice_off": "選項（不能選）", "ui_dialog": "對話框（九宮格拉伸）", "ui_diary": "日記本", "ui_rules_board": "鎮規告示板",
}
NAMES = {"bu": "小布", "mayor": "熊熊鎮長", "lulu": "露露", "fen": "Fen", "popo": "波波", "mochi": "麻糬", "tama": "小玉",
         "conductor": "車掌", "puppy": "小狗居民", "mirror": "鏡子", "dove": "和平鴿", "nurse": "護理師",
         "baimian": "白面", "xiaoji": "小棘", "tiaoma": "條碼", "gaga": "嘎嘎", "zhongzhong": "重重", "youyou": "鼬鼬",
         "staff": "工作人員", "director": "理事", "graduate": "畢業生", "pip": "小布",
         "h_crowd": "人類：路人學生", "h_fen_father": "人類：芬的爸爸", "h_graduate": "人類：畢業生", "h_nurse": "人類：護理師",
         "h_principal": "人類：校長", "h_shadow": "人類：影子", "h_whitecoat": "人類：白袍研究員", "human_nurse": "人類：護理師（舊）"}
MINI = {"apology": "道歉", "chairs": "搶椅子", "confession": "告解卡", "find_odd": "找不同", "hold_endure": "忍耐",
        "restuff": "重新塞棉花", "scrub": "刷洗", "sneak": "偷偷走", "trim": "修剪"}
KIND = {"bed": "床", "desk": "桌子", "chair": "椅子", "cabinet": "櫃子", "shelf": "架子", "machine": "機器", "plant": "盆栽",
        "crate": "箱子", "table": "桌子", "sink": "洗手台", "locker": "置物櫃", "pillar": "柱子", "box": "箱子"}


def room_names():
    out = {}
    for c in (3, 4, 5):
        with open(os.path.join(GAME, "levels", f"chapter{c}.json"), encoding="utf-8") as f:
            for rid, r in json.load(f)["rooms"].items():
                out[(c, rid)] = r.get("name", rid)
    return out


def classify(rel, stem, size, rooms):
    """回傳（章節, 分類, 用途, 規格注意, 優先度）。優先度：A 角色臉／立繪／CG、B 背景地圖、C 物件 UI、D 不建議外包"""
    p = rel.split("/")
    if p[0] == "human":
        return "第四、五章", "人類時期立繪", stem, "已在《人類時期角色需求 v2.1》裡，照那份做", "A（已發包）"
    if p[0] == "walk4":
        if stem.startswith("h_") and size[0] == 1280:
            return "第四、五章", "人類時期走路圖（Q 版）", stem, "已在《人類時期角色需求 v2.1》裡，照那份做", "A（已發包）"
        who = NAMES.get(stem, NAMES.get(stem.removeprefix("h_"), stem))
        ch = "第四、五章" if stem.startswith(("h_", "human_")) else "第二～五章"
        return ch, "四方向走路圖", who, "4×4 格（下、左、右、上 × 走路 4 格），可以做成每格 160 或 320（整張 640 或 1280）", "A"
    if p[0] == "ch2":
        if len(p) == 2:
            return "第二章", "可走範圍遮罩", "地圖哪裡可以走（黑白）", "不是給玩家看的圖；換地圖時我們自己改", "D"
        if p[1] == "backgrounds":
            return "第二章", "背景", stem.removeprefix("ch2_bg_"), "_overlay / 透明 PNG 是疊在背景上的圖層，要和底圖對齊", "B"
        if p[1] == "cg":
            lay = "（結局 CG 的分層，每層一個角色，要能疊在一起）" if "ending_layers" in p else ""
            note = "_text_overlay 是字的圖層、_blank 是沒有字的版本、_stitch_01～04 是逐步縫上的動畫格" if "_" in stem else ""
            return "第二章", "CG", stem.removeprefix("ch2_") + lay, note, "A"
        if p[2:3] == ["portraits"]:
            return "第二章", "對話立繪（玩偶）", stem.removeprefix("ch2_"), "512×768 透明，半身，同一角色每個表情位置對齊", "A"
        if p[2:3] == ["sprites"]:
            return "第二章", "角色動作圖（sheet）", stem.removeprefix("ch2_"), "格子排法照原圖（每格大小＝原圖寬÷欄數），只換內容", "A"
        if p[1] == "minigames":
            return "第二章", f"小遊戲：{MINI.get(p[2], p[2])}", stem.removeprefix(f"ch2_{p[2]}_"), "_01～ 是動畫格；_normal/_hover/_pressed 是按鈕三態", "C"
        if p[1] == "ui":
            return "第二章", "UI", stem.removeprefix("ch2_ui_"), "", "C"
    if p[0] in ("ch3", "ch4", "ch5"):
        ch = {"ch3": "第三章", "ch4": "第四章", "ch5": "第五章"}[p[0]]
        if p[1] == "maps":
            return ch, "舊版整張地圖（目前沒用到）", stem.removeprefix("ch3_map_"), "已被「探索房間」＋「探索家具」取代，不用做", "D"
        kind = "CG" if "_cg_" in stem else "背景"
        return ch, kind, re.sub(r"^ch\d_bg_(cg_)?", "", stem), "1280×720 不透明（可交 2560×1440）", "A" if kind == "CG" else "B"
    if p[0] == "rooms":
        c = int(p[1][-1])
        rname = rooms.get((c, p[2]), p[2])
        ch = f"第{'三四五'[c - 3]}章"
        if stem == "bg":
            return ch, "探索房間（地板、牆，俯視）", rname, "不透明；家具另外是透明 PNG 疊上去，這張不要畫家具", "B"
        m = re.match(r"(prop|hide)_(?:c\d_hide_)?([a-z0-9]+)(?:_(\d+)_(\d+)_(\d+)_(\d+))?", stem)
        k = KIND.get(m.group(2), m.group(2)) if m else stem
        if m and m.group(1) == "hide":
            return ch, "可躲藏的家具", f"{rname}：{k}", "透明 PNG；玩家會躲在後面，要有遮得住人的高度", "C"
        pos = f"（房間座標 x{m.group(3)} y{m.group(4)}，底面 {m.group(5)}×{m.group(6)}）" if m and m.group(3) else ""
        return ch, "探索家具", f"{rname}：{k}{pos}", "透明 PNG，俯視角度要和房間一致；腳底面積不能變（碰撞是照這個算的）", "C"
    if p[0] == "chase2d":
        who = "小布" if stem.startswith("bu") else "熊熊鎮長" if stem.startswith("mayor") else ""
        return "第一章", "追逐戰", f"{who} {stem}".strip(), "_run_00～03 是跑步循環；角色透明 PNG", "A" if who else "C"
    if p[0] == "scissors":
        return "第一章", "剪刀事件（連續畫面）", f"鎮長 第 {stem[-1]} 張", "1280×720 不透明，7 張依序播放", "A"
    if p[0] == "3d":
        if p[1:2] == ["tex"]:
            return "第三～五章", "3D 貼圖", stem, "要能無縫重複（上下左右接起來看不出接縫）", "C"
        return "第三～五章", "3D 模型", stem, "glb，Godot 4 可讀；面數低（手機要跑）", "C"
    if p[0] == "branding":
        return "全遊戲", "圖示／Logo", stem, "Android 圖示前景要留安全邊距（中間 66%）", "B"
    # art 根目錄＝第一章
    if stem.startswith("face_"):
        return "第一章", "對話表情頭像", NAMES.get(stem[5:], stem[5:]), "4 欄 × 2 列，每格 256×256，8 個表情（照原圖順序）", "A"
    if stem.startswith("walk_") and size == (576, 768):
        return "第一章", "走路圖", NAMES.get(stem[5:], stem[5:]), "3 欄（步伐）× 4 列（下、左、右、上），每格 192×192，腳底在格子底部", "A"
    if stem.endswith("_mask"):
        return "第一章", "可走範圍遮罩", stem, "不是給玩家看的圖；換地圖時我們自己改", "D"
    if stem.startswith("int_"):
        return "第一章", "室內畫面（進屋）", NAMES.get(stem[4:], stem[4:]) + ("" if stem[4:] == "station" else " 的家"), "1280×720 不透明", "B"
    if stem.startswith("item_stand_"):
        return "第一章", "角色站姿（事件用）", NAMES.get(stem[11:].replace("_broken", ""), stem[11:]) + ("（壞掉）" if "broken" in stem else ""), "透明 PNG 全身", "A"
    if stem.startswith("item_"):
        return "第一章", "調查物品特寫", stem[5:], "透明 PNG", "C"
    if stem.startswith("scare_"):
        return "第一章～三章", "嚇人畫面（全螢幕的臉）", NAMES.get(stem[6:], stem[6:]), "透明 PNG 正方形，臉塞滿畫面", "A"
    if stem.startswith("title_bu_"):
        return "全遊戲", "標題畫面小布", f"姿勢 {stem[-1]}", "512×512 透明", "A"
    if stem.startswith(("bg_", "ui_", "title_", "boot_", "room")) or stem in ROOT:
        kind = "UI" if stem.startswith("ui_") and not stem.endswith("_bg") else "物件" if stem in ("mirror_states", "fen_treehouse") else "背景"
        return "第一章", kind, ROOT.get(stem, stem), "", "B" if kind != "UI" else "C"
    return "?", "其他", stem, "", "C"


def main(out):
    rooms = room_names()
    rows = []
    for root, _, files in os.walk(ART):
        for f in sorted(files):
            ext = f.rsplit(".", 1)[-1].lower()
            if ext not in ("png", "jpg", "jpeg", "webp", "glb"):
                continue
            full = os.path.join(root, f)
            rel = os.path.relpath(full, ART).replace(os.sep, "/")
            if ext == "glb":
                size, alpha = (0, 0), "—"
            else:
                im = Image.open(full)
                size, alpha = im.size, "透明" if im.mode in ("RGBA", "LA", "P") and ext == "png" else "不透明"
            stem = f.rsplit(".", 1)[0]
            ch, cat, use, note, pri = classify(rel, stem, size, rooms)
            rows.append([ch, cat, use, "game/art/" + rel, f"{size[0]}×{size[1]}" if size[0] else "3D", alpha, ext, note, pri])
    order = ["全遊戲", "第一章", "第一章～三章", "第二章", "第二～五章", "第三章", "第三～五章", "第四章", "第四、五章", "第五章", "?"]
    rows.sort(key=lambda r: (order.index(r[0]) if r[0] in order else 99, r[1], r[3]))
    with open(out, "w", newline="", encoding="utf-8-sig") as fh:
        w = csv.writer(fh)
        w.writerow(["編號", "章節", "分類", "內容", "遊戲裡的檔案（交件請用同一個檔名）", "目前尺寸", "背景", "格式", "規格／注意", "優先度"])
        for i, r in enumerate(rows, 1):
            w.writerow([i] + r)
    return rows


if __name__ == "__main__":
    rows = main(sys.argv[1])
    import collections
    print(len(rows), "files")
    for k, v in sorted(collections.Counter((r[0], r[1]) for r in rows).items()):
        print(f"{k[0]}\t{k[1]}\t{v}")
    print(collections.Counter(r[8] for r in rows))
