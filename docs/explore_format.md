# 室內探索關卡格式（第三～五章）

程式：`game/scripts/explore/`（`explore.gd` 主體、`explore_player.gd` 小布、`patrol.gd` 巡邏、`keypad.gd` 密碼鎖、`explore_art.gd` 佔位美術）。
關卡：每章一個 JSON（`game/levels/chapterN.json`）。座標是房間座標（像素），房間可以比畫面大，鏡頭會跟著小布。
測試：`tests/explore_test.gd`（範例關卡 `tests/fixtures/explore_test.json`）。

## 最上層
| 欄位 | 說明 |
|---|---|
| `rooms` | 房間表：`{"房間id": {...}}` |
| `items` | 會顯示在「持有：」的東西：`{"旗標": "名字"}`（旗標成立就算拿著） |
| `keypads` | 密碼鎖：`{"事件名": {"title", "code", "flag"(對了設定), "hint", "fail_flag"}}`。劇本裡寫 `@event 事件名` 就會打開 |

## 房間
| 欄位 | 說明 |
|---|---|
| `name` | 房間名（狀態列顯示） |
| `size` | `[寬, 高]` |
| `theme` | 佔位配色：hospital、hospital_old、basement、lab、platform、school、school_dark、home、real、town |
| `art` | 有自製背景圖時的路徑（整個房間一張圖，大小＝size），有圖就不畫佔位 |
| `wall_h` | 上面那面牆的高度（預設 90，走不進去） |
| `dark` | `true`：只有小布身邊一圈亮（手電筒） |
| `spawns` | 出生點：`{"名字": [x, y]}`，門的 `spawn` 指到這裡 |
| `walls` | 牆、柱子：`[[x, y, w, h], …]`（走不過去） |
| `props` | 家具：`{"kind", "rect": [x,y,w,h], "solid"(預設 true), "label"}`。kind：bed、desk、table、cabinet、locker、shelf、chair、plant、machine、window、rug、blackboard、sink、crate、pillar |
| `decals` | 地上的線與字：`{"kind": "line", "points", "color", "width"}`、`{"kind": "text", "pos", "text", "w", "size", "color"}`、`{"kind": "rect", "rect", "color"}` |
| `spots` | 調查點：`{"id", "name", "pos", "label"(預設＝id), "set"(調查後設定的旗標), "when"(出現條件), "once"(調查過就消失), "reach", "kind"/"size"(畫成家具), "auto_skip"(自動測試不要點)}` |
| `npcs` | 人物：同 spots，加上 `"char"`（ExploreArt.CHARS 的 id，或 `human:#顏色`）、`"flip"` |
| `doors` | 門：`{"id", "name", "pos", "size", "to"(房間), "spawn", "open"(打得開的條件；空＝一直開), "locked_label"(打不開時的對話), "locked_text"}` |
| `hides` | 躲藏點：`{"id", "name", "pos", "kind", "size"}`；躲著時巡邏看不到，按互動鍵出來 |
| `patrols` | 巡邏：`{"id", "char", "path": [[x,y]…], "speed", "view"(視野長), "fov"(半角弧度), "pause", "when", "catch"(被抓時的對話)}`；被看到 0.35 秒就算被抓，回到這個房間的入口 |
| `on_enter` | 第一次進這個房間時跑的對話標籤 |

條件（`when`、`open`）用 `GameState.check` 的語法：`flag`、`!flag`、`a&b`、`a|b`。

## 導演怎麼用
```gdscript
explore = Explore.new()
explore.load_level("res://levels/chapter3.json")
explore.party = ["lulu", "mochi", "popo", "fen", "baimian"]
add_child(explore)
await explore.enter("hall", "start")
await explore.until("c3_heart_done")   # 自由探索，直到條件成立
explore.save_state()                     # 檢查點：記住房間與位置；讀檔用 restore_or()
```
劇本的 `@event` 先給 `explore.handle_event(name)`（密碼鎖），回傳 false 再由導演處理。
