#!/usr/bin/env bash
# 產生試玩網站：public/（入口頁＋各專案），Cloudflare Pages 直接發布這個資料夾。
# 需要 Godot 4.3 與 Web 匯出範本（web_nothreads_release.zip）。
# SITE_URL：要發布的網址（iPhone 描述檔會指向 $SITE_URL/rule-zero/），預設 https://try.yzprojecttw.com
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/public"
rm -rf "$OUT"
mkdir -p "$OUT/rule-zero/boot"
# 開場（Logo 影片＋載入畫面）寫在 game/web/head_include.html，匯出前塞進匯出設定
python3 - "$ROOT" <<'PY'
import re, sys
root = sys.argv[1]
head = open(f"{root}/game/web/head_include.html", encoding="utf-8").read()
cfg_path = f"{root}/game/export_presets.cfg"
cfg = open(cfg_path, encoding="utf-8").read()
esc = head.replace("\\", "\\\\").replace('"', '\\"')
lines = cfg.split("\n")
out, skip = [], False
for ln in lines:
    if ln.startswith('html/head_include="'):
        out.append('html/head_include="' + esc + '"')
        # 舊的值可能跨好幾行：一直跳到結尾的引號
        skip = not (ln.endswith('"') and not ln.endswith('\\"') and len(ln) > len('html/head_include="'))
        continue
    if skip:
        if ln.endswith('"') and not ln.endswith('\\"'):
            skip = False
        continue
    out.append(ln)
open(cfg_path, "w", encoding="utf-8").write("\n".join(out))
PY
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$OUT/rule-zero/index.html"
cp "$ROOT/game/web/intro.mp4" "$OUT/rule-zero/boot/intro.mp4"
cp "$ROOT/game/web/intro.webm" "$OUT/rule-zero/boot/intro.webm"
# 載入畫面的小圖：縮小，才不會跟遊戲本體搶下載
python3 - "$ROOT" "$OUT/rule-zero/boot" <<'PY'
import sys
from PIL import Image
root, out = sys.argv[1], sys.argv[2]
walk = Image.open(f"{root}/game/art/walk_bu.png")
row = walk.crop((0, 192 * 2, 576, 192 * 3)).resize((3 * 128, 128), Image.LANCZOS)   # 朝右跑的那一列
row.save(f"{out}/run_bu.png", optimize=True)
Image.open(f"{root}/game/web/bu_faces.png").resize((6 * 128, 128), Image.LANCZOS).save(f"{out}/bu_faces.png", optimize=True)
m = Image.open(f"{root}/game/art/item_stand_mayor.png")
m.thumbnail((200, 200), Image.LANCZOS)
m.save(f"{out}/mayor.png", optimize=True)
PY
cp "$ROOT/site/index.html" "$OUT/index.html"
cp "$ROOT/site/_headers" "$OUT/_headers"
# iPhone 安裝頁＋描述檔（主畫面圖示）。SITE_URL＝這次要發布到的網址
mkdir -p "$OUT/ios"
cp "$ROOT/site/ios/index.html" "$ROOT/site/ios/icon.png" "$OUT/ios/"
# 同一頁（iPhone＋Android）也放在 /android/ 和 /download/
for d in android download; do mkdir -p "$OUT/$d"; cp "$ROOT/site/ios/index.html" "$OUT/$d/index.html"; done
python3 "$ROOT/tools/make_ios_profile.py" "${SITE_URL:-https://try.yzprojecttw.com}" "$OUT/rule-zero.mobileconfig"
python3 - "$ROOT" "$OUT" <<'PY'
import json, sys
from PIL import Image
root, out = sys.argv[1], sys.argv[2]
im = Image.open(f"{root}/docs/images/proto_title.png").convert("RGB")
im.thumbnail((640, 360))
im.save(f"{out}/rule-zero-cover.jpg", quality=82)
# Cloudflare Pages 單檔上限 25 MiB：引擎 wasm 和遊戲內容 pck 都切成 20 MiB 一塊，
# 頁面載入時再接回來（見 game/web/head_include.html 的第 1 段）。內容再多也只是多幾塊。
import os
size = 20 * 1024 * 1024
for kind in ["wasm", "pck"]:
    path = f"{out}/rule-zero/index.{kind}"
    data = open(path, "rb").read()
    parts = []
    for i in range(0, len(data), size):
        name = f"index.{kind}.part{len(parts)}"
        open(f"{out}/rule-zero/{name}", "wb").write(data[i:i + size])
        parts.append(name)
    json.dump(parts, open(f"{out}/rule-zero/index.{kind}.parts.json", "w"))
    os.remove(path)
    print(f"{kind}：{len(data) / 1048576:.1f} MB，切成 {len(parts)} 塊")
PY
echo "完成：$OUT"
