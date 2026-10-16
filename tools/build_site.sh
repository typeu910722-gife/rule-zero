#!/usr/bin/env bash
# 產生試玩網站：public/（入口頁＋各專案），Cloudflare Pages 直接發布這個資料夾。
# 需要 Godot 4.3 與 Web 匯出範本（web_nothreads_release.zip）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/public"
rm -rf "$OUT"
mkdir -p "$OUT/rule-zero"
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$OUT/rule-zero/index.html"
cp "$ROOT/site/index.html" "$OUT/index.html"
cp "$ROOT/site/_headers" "$OUT/_headers"
python3 - "$ROOT" "$OUT" <<'PY'
import json, sys
from PIL import Image
root, out = sys.argv[1], sys.argv[2]
im = Image.open(f"{root}/docs/images/proto_title.png").convert("RGB")
im.thumbnail((640, 360))
im.save(f"{out}/rule-zero-cover.jpg", quality=82)
# Cloudflare Pages 單檔上限 25 MiB：把引擎 wasm 與資源包 pck 切塊，頁面載入時再接回來（見 export_presets.cfg 的 head_include）
import os
for ext in ("wasm", "pck"):
    path = f"{out}/rule-zero/index.{ext}"
    data = open(path, "rb").read()
    size = 20 * 1024 * 1024
    parts = []
    for i in range(0, len(data), size):
        name = f"index.{ext}.part{len(parts)}"
        open(f"{out}/rule-zero/{name}", "wb").write(data[i:i + size])
        parts.append(name)
    json.dump(parts, open(f"{out}/rule-zero/index.{ext}.parts.json", "w"))
    os.remove(path)
    print(ext, "切成", len(parts), "塊")
PY
echo "完成：$OUT"
