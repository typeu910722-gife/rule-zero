#!/usr/bin/env bash
# 產生試玩網站：public/（入口頁＋各專案），Cloudflare Pages 直接發布這個資料夾。
# 需要 Godot 4.3 與 Web 匯出範本（web_nothreads_release.zip）。
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
cp "$ROOT/game/art/walk_bu.png" "$OUT/rule-zero/boot/walk_bu.png"
cp "$ROOT/game/web/intro.webm" "$OUT/rule-zero/boot/intro.webm"
cp "$ROOT/game/web/bu_faces.png" "$OUT/rule-zero/boot/bu_faces.png"
cp "$ROOT/game/art/item_stand_mayor.png" "$OUT/rule-zero/boot/mayor.png"
cp "$ROOT/site/index.html" "$OUT/index.html"
cp "$ROOT/site/_headers" "$OUT/_headers"
python3 - "$ROOT" "$OUT" <<'PY'
import json, sys
from PIL import Image
root, out = sys.argv[1], sys.argv[2]
im = Image.open(f"{root}/docs/images/proto_title.png").convert("RGB")
im.thumbnail((640, 360))
im.save(f"{out}/rule-zero-cover.jpg", quality=82)
# Cloudflare Pages 單檔上限 25 MiB：把引擎 wasm 切塊，頁面載入時再接回來（見 export_presets.cfg 的 head_include）
wasm = f"{out}/rule-zero/index.wasm"
data = open(wasm, "rb").read()
size = 20 * 1024 * 1024
parts = []
for i in range(0, len(data), size):
    name = f"index.wasm.part{len(parts)}"
    open(f"{out}/rule-zero/{name}", "wb").write(data[i:i + size])
    parts.append(name)
json.dump(parts, open(f"{out}/rule-zero/index.wasm.parts.json", "w"))
import os
os.remove(wasm)
print("wasm 切成", len(parts), "塊")
PY
echo "完成：$OUT"
