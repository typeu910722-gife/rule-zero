#!/usr/bin/env python3
"""把 Noto Sans CJK TC 縮減成只包含遊戲用到的字，打包進 game/fonts/。

用法：python3 tools/subset_font.py <NotoSansCJK-Regular.ttc>
（Debian/Ubuntu：fonts-noto-cjk 套件；授權 SIL OFL 1.1）
對話或程式新增文字後，重新執行一次即可。
"""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
OUT = GAME / "fonts" / "NotoSansTC-Game.otf"
TC_INDEX = 3  # NotoSansCJK-Regular.ttc 裡的第 4 個字型是 Noto Sans CJK TC

chars = set(chr(c) for c in range(0x20, 0x7F))
chars |= set("，。、！？：；「」『』（）《》〈〉—…～·・★☆♪♥※→←↑↓／｜＿　０１２３４５６７８９")
for path in list(GAME.rglob("*.gd")) + list(GAME.rglob("*.txt")):
    chars |= set(path.read_text(encoding="utf-8"))
chars = {c for c in chars if c.isprintable() or c == "　"}

text_file = ROOT / "tools" / ".subset_chars.txt"
text_file.write_text("".join(sorted(chars)), encoding="utf-8")
subprocess.run([
    sys.executable, "-m", "fontTools.subset", sys.argv[1],
    f"--font-number={TC_INDEX}", f"--text-file={text_file}",
    f"--output-file={OUT}", "--layout-features=*", "--no-hinting",
], check=True)
text_file.unlink()
print(f"{OUT.relative_to(ROOT)}: {len(chars)} 字, {OUT.stat().st_size // 1024} KB")
