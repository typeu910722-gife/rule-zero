"""產生給畫師的表情對照表（立繪 78 張的檔名、表情說明、交件批次）。
py -P tools/art/make_expression_csv.py <輸出.csv>"""
import csv, sys

# (角色代號, 角色, 服裝代號, 服裝, 批次, [(表情代號, 說明, 預設?)])
ROWS = [
 ("haruka", "遙", "uniform", "制服（袖子太長）", 1, [
   ("nervous", "緊張的平常臉", 1), ("smile_small", "小小的笑", 0), ("afraid", "害怕", 0),
   ("quiet_cry", "安靜地掉眼淚", 0), ("resolved", "下定決心", 0), ("daydream", "放空", 0)]),
 ("haruka", "遙", "dress", "「那一天」的衣服（裙子）", 3, [
   ("practicing", "練習說話（害羞）", 0), ("nervous", "緊張", 1), ("startled", "害怕（有人從後面叫他的名字）", 0)]),
 ("haruka", "遙", "gown", "病人服", 3, [
   ("waking", "剛醒來的放空", 0), ("cry", "哭", 0), ("smile_soft", "淡淡的笑", 0), ("default", "平常", 1)]),
 ("fen", "芬", "uniform", "制服", 1, [
   ("annoyed", "不耐煩", 1), ("blushing_away", "看向別處（耳朵紅）", 0), ("panic", "慌張", 0),
   ("angry", "生氣", 0), ("regret", "後悔、忍著快哭", 0), ("tiny_smile", "很淡很淡的笑（只用一次）", 0)]),
 ("fen", "芬", "gown", "病人服（頭上有紗布）", 3, [
   ("eyes_closed", "閉著眼睛", 0), ("waking", "剛醒來", 1), ("smile_soft", "淡淡的笑", 0)]),
 ("teacher", "導師", "teacher", "上課的樣子（綠背心）", 2, [
   ("forced_smile", "勉強的溫和微笑", 1), ("tired", "疲倦", 0), ("uneasy", "不安、手在抖", 0),
   ("stunned", "愣住", 0), ("vacant", "崩潰（眼神空掉，不誇張）", 0)]),
 ("hilufei", "希露飛", "uniform", "制服", 2, [
   ("happy", "開心的笑（眼睛瞇成線）", 1), ("bashful", "說到銘越時害羞", 0),
   ("embarrassed", "難堪、低頭", 0), ("cry", "哭", 0)]),
 ("hilufei", "希露飛", "gown", "病人服", 3, [("default", "平常", 1), ("smile_soft", "淡淡的笑", 0)]),
 ("mingyue", "銘越", "uniform", "制服", 2, [
   ("laugh", "爽朗大笑", 1), ("proud", "得意", 0), ("awkward", "被圍著笑時僵住的臉", 0), ("disappointed", "失落（信箱是空的）", 0)]),
 ("mingyue", "銘越", "gown", "病人服", 3, [("default", "平常（剛醒來）", 1), ("smile_soft", "淡淡的笑", 0)]),
 ("xiaoman", "小滿", "uniform", "制服＋燕麥色大毛衣", 2, [
   ("looking_down", "低著頭", 1), ("whisper", "小聲說話", 0), ("brave_smile", "很努力的笑", 0), ("cry", "哭", 0)]),
 ("xiaoman", "小滿", "gown", "病人服", 3, [("default", "平常", 1), ("smile_small", "小小的笑", 0)]),
 ("classrep", "班長", "uniform", "制服＋班長臂章", 2, [
   ("standard_smile", "標準的微笑", 1), ("nervous", "緊張", 0), ("vacant", "放空", 0), ("true_smile", "真心的小小的笑", 0)]),
 ("duty", "值日生", "uniform", "制服（袖子捲起、拿黃抹布）", 2, [
   ("default", "平常", 1), ("witness", "看到了（愣住）", 0), ("sorry", "低頭說「對不起」", 0)]),
 ("xinhe", "辛禾", "uniform", "制服", 2, [
   ("hostile", "兇（看什麼看）", 1), ("fake_smile", "標準的假笑", 0), ("guilty", "心虛", 0), ("cry", "哭", 0)]),
 ("xinhe", "辛禾", "gown", "病人服", 3, [("vacant", "沒有表情（空空的）", 0), ("default", "平常", 1)]),
 ("tiwen", "薙文", "uniform", "制服（拿手機）", 2, [
   ("phone_blank", "低頭滑手機（沒有表情）", 1), ("side_glance", "抬眼一瞥", 0), ("stunned", "愣住（第一次像個真的孩子）", 0)]),
 ("junzhu", "郡主", "uniform", "制服＋灰色連帽外套", 2, [
   ("silent", "沉默", 1), ("hide_hand", "把手縮起來（躲）", 0), ("angry", "生氣", 0), ("protest", "喊冤（我沒有推他！）", 0)]),
 ("junzhu", "郡主", "gown", "病人服", 3, [("default", "平常", 1), ("whisper", "小聲說話", 0)]),
 ("qiuge", "秋歌", "uniform", "制服（拿手機或相機）", 2, [
   ("focused", "拍照（專注）", 1), ("unreadable", "淡淡的、看不出在想什麼", 0), ("trembling", "害怕、手在抖", 0)]),
 ("qiuge", "秋歌", "gown", "病人服", 3, [("default", "平常", 1), ("looking_down", "低頭", 0)]),
 ("lien", "李恩", "uniform", "制服＋灰背心＋紅圍巾", 2, [
   ("sly_grin", "賊賊的笑", 1), ("whisper", "壓低聲音講悄悄話", 0), ("serious", "認真（打電話求救）", 0), ("panic", "慌張", 0)]),
 ("lien", "李恩", "gown", "病人服＋脖子上的紅繩", 3, [("default", "平常", 1), ("sly_grin", "賊賊的笑", 0)]),
]

def rows():
    n = 0
    for cid, name, oid, outfit, batch, faces in ROWS:
        for fid, desc, default in faces:
            n += 1
            yield [n, name, cid, outfit, oid, fid, desc, "★" if default else "",
                   f"h_{cid}_portrait_{oid}_{fid}.png", f"第 {batch} 批"]

if __name__ == "__main__":
    out = list(rows())
    assert len(out) == 78, len(out)
    assert len({(r[2], r[4]) for r in out}) == 23
    with open(sys.argv[1], "w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["編號", "角色", "角色代號", "服裝", "服裝代號", "表情代號", "表情說明", "預設表情", "檔名", "交件批次"])
        w.writerows(out)
    print(len(out), "rows")
