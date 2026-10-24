# 對話腳本語法

檔案：`game/dialogue/chapter1.txt` … `chapter6.txt`（UTF-8）。所有檔案共用同一個標籤空間。第二章標籤以 `c2_` 開頭，其後各章以 `c3_` … `c6_` 開頭。設計目標是讓**寫劇本的人不用碰程式**。

| 語法 | 意思 |
|---|---|
| `=== 標籤` | 一段對話的開始（也是一個可跳轉的標籤）。遇到下一個 `===` 就結束。 |
| `# 標籤` | 段落內的跳轉點 |
| `角色：台詞` | 角色說話（全形冒號） |
| `> 文字` | 旁白／描述 |
| `* 選項文字 -> 標籤` | 選項（連續幾行組成一組） |
| `* 選項文字 -> 標籤 $1` | 違反守則的選項，消耗 1 點膽量；膽量不足時會顯示為灰色 |
| `[條件] 任何一行` | 條件成立才執行這一行。條件：`flag`、`!flag`、`sus>=40`、`courage>=1`、`day==2`、`conduct>=60`；多個條件用 `&` 串接（例：`!a&!b`） |
| `@set 旗標` / `@unset 旗標` | 設定／清除旗標（秘密也是旗標，見 `game_state.gd` 的 `SECRETS`） |
| `@sus 10` | 懷疑值 +10（玩家看不到，F3 可顯示） |
| `@conduct -10` | 第二章：操行成績 −10（玩家看得到） |
| `@sfx whistle_short` | 播放音效（`scripts/audio/sfx.gd` 的名稱：text、whistle_short、whistle_long、shock_short／medium／long） |
| `@goto 標籤` | 跳轉 |
| `@if 條件 標籤` | 條件成立就跳轉 |
| `@end` | 結束這段對話 |
| `@bg black / train / grey_train / white / dream / none` | 全螢幕背景（序章、夢境用） |
| `@event 名稱` | 交給程式處理的事件：`candy`、`board`、`mirror_stare`、`to_plaza` |
| `{name}` | 替換成玩家目前的名字（拆下名牌時會變成「新朋友」） |
| `// 註解` | 註解 |

## 互動對應規則
玩家對某個角色／物件（id）按 E 時，依序找第一個存在的標籤：

1. `<id>_<phase>`（例：`mirror_day1_night`、`lulu_night_out`）
2. 夜晚的預設標籤（`night_resident`、`late`）
3. `<id>_d<天數>`（例：`lulu_d2`）
4. `<id>`

## 檢查
```
godot --headless --path game -s tests/lint_dialogue.gd
```
會檢查所有跳轉目標、事件名稱、背景名稱是否存在。
