#!/usr/bin/env bash
# 匯出 Windows／Android 版到 build/（build/ 不進 Git）。
# 需要：Godot 4.3 與匯出範本（Godot 編輯器 → 編輯器 → 管理匯出範本）。
# Android 另外需要：JDK 17、Android SDK（platform-tools、build-tools）、debug keystore，
#   在 Godot 編輯器設定 → 匯出 → Android 填好路徑（或 ~/.config/godot/editor_settings-4.3.tres）。
# iOS：需要 macOS＋Xcode＋Apple 開發者帳號，見 docs/platform_plan.md 第 9 節。
#
# 用法：GODOT=/path/to/godot tools/build_platforms.sh [windows] [android]（不寫＝兩個都做）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
TARGETS="${*:-windows android}"
cd "$ROOT/game"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
for t in $TARGETS; do
  case "$t" in
    windows)
      mkdir -p "$ROOT/build/windows"
      "$GODOT" --headless --path . --export-release "Windows Desktop" "$ROOT/build/windows/RuleZero.exe"
      echo "完成：build/windows/RuleZero.exe（資源已內嵌，單一執行檔）";;
    android)
      mkdir -p "$ROOT/build/android"
      "$GODOT" --headless --path . --export-debug "Android" "$ROOT/build/android/RuleZero-debug.apk"
      echo "完成：build/android/RuleZero-debug.apk（debug 簽章，只能側載測試，不能上架）";;
    *) echo "不認得的平台：$t（可用：windows、android）"; exit 1;;
  esac
done
