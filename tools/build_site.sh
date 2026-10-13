#!/usr/bin/env bash
# 產生試玩網站：build/web/（入口頁＋各專案）
# 需要 Godot 4.3 與 Web 匯出範本（web_nothreads_release.zip）。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUT="$ROOT/build/web"
mkdir -p "$OUT/rule-zero"
"$GODOT" --headless --path "$ROOT/game" --export-release "Web" "$OUT/rule-zero/index.html"
cp "$ROOT/site/index.html" "$OUT/index.html"
python3 - "$ROOT" "$OUT" <<'PY'
import sys
from PIL import Image
root, out = sys.argv[1], sys.argv[2]
im = Image.open(f"{root}/docs/images/proto_title.png").convert("RGB")
im.thumbnail((640, 360))
im.save(f"{out}/rule-zero-cover.jpg", quality=82)
PY
(cd "$ROOT/build" && rm -f try-site.zip && zip -qr try-site.zip web)
echo "完成：$OUT（壓縮檔 build/try-site.zip）"
