"""內建字型（NotoSansTC-Game.otf）缺的字，從 Windows 的 Noto Sans TC 可變字型補一個小字型 NotoSansTC-Extra.ttf。
遊戲裡設成內建字型的第一個後備字型（game_state.gd _setup_font），網頁版、Android 沒有系統字型也看得到。
Noto Sans TC 和 Noto Sans CJK TC 是同一套字（思源黑體），字形一樣。
用法：py -3.11 tools/subset_font_extra.py [可變字型路徑，預設 C:/Windows/Fonts/NotoSansTC-VF.ttf]
新增文字後：能重做主字型（tools/subset_font.py）就重做；不能的話跑這支補缺字。
"""
import pathlib
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
VF = sys.argv[1] if len(sys.argv) > 1 else "C:/Windows/Fonts/NotoSansTC-VF.ttf"
OUT = GAME / "fonts" / "NotoSansTC-Extra.ttf"

main = TTFont(GAME / "fonts" / "NotoSansTC-Game.otf").getBestCmap()
chars = set()
for path in list(GAME.rglob("*.gd")) + list(GAME.rglob("*.txt")) + list((GAME / "levels").glob("*.json")):
    chars |= set(path.read_text(encoding="utf-8"))
missing = sorted(c for c in chars if ord(c) > 0x2000 and c.isprintable() and ord(c) not in main)
vf = TTFont(VF)
inst = instancer.instantiateVariableFont(vf, {"wght": 400})
have = inst.getBestCmap()
missing = [c for c in missing if ord(c) in have]
opts = subset.Options()
opts.layout_features = ["*"]
opts.hinting = False
sub = subset.Subsetter(opts)
sub.populate(text="".join(missing))
sub.subset(inst)
inst.save(OUT)
print(f"{OUT.relative_to(ROOT)}: {len(missing)} 字（{''.join(missing)}），{OUT.stat().st_size // 1024} KB")
