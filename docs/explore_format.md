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
| `art` | 有自製背景圖時的路徑（整個房間一張圖，大小＝size），有圖就不畫佔位（舊做法；新的房間美術用下面的「房間美術」） |

### 房間美術（2026-10-27）
不用改 JSON：`game/art/rooms/<關卡檔名>/<房間 id>/room.json` 存在就用（`Explore._room_art`）。由 `tools/art/blender/room.py` 照 JSON 在 Blender 蓋出房間、渲染：
- `bg.jpg`：地板、後牆（門、窗、窗台的鳥）、房間裡的牆、地上的線。文字 decals 照舊由程式畫在上面。
- 每件家具一張去背 PNG（key：`prop:種類@x,y,w,h`、有 kind 的躲藏點 `hide:<id>`、調查點 `spot:<id>`），在遊戲裡照前後順序疊（角色走到櫃子後面會被擋住）。
- 改了家具的位置或大小，key 對不上就自動用舊的程式畫法；重跑 `tools/art/blender/render_rooms.ps1 <關卡> -Rooms <id>` 即可。
- 測試：`tests/rooms_art_test.gd`（每間都有圖、每件家具都對得上）。

### 壓迫感（explore.gd）
- `dread`（預設 0.22）：平常的暗角；暗的房間再 +0.3；巡邏的人越近越重（`threat` 0～1），近到一定程度會有心跳聲、畫面微晃（溫和模式不放心跳、不晃）。
- `auto_ambience`（預設開）：進房間依主題換環境音（`AMB_BY_THEME`：醫院／實驗室／真的醫院＝日光燈嗡嗡、舊病棟／地下／月台＝低鳴、學校／家＝空房間）。章節導演要安靜時關掉。
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

## 3D 段落（`scripts/ch3/chase3d.gd`，class Chase3D）
格子迷宮（`#` 牆、`.` 路、`S` 起點、`E` 出口、`C` 檢查點、`D` 追的人出發點、`W` 地上的白線）。用 Godot 內建形狀，之後可換 Blender 的 .glb。
| 欄位 | 說明 |
|---|---|
| `maze` | 迷宮（內建：`maze` 預設、`MAZE_ROLLCALL`、`MAZE_SCHOOL`、`MAZE_REAL_HALL`） |
| `look` | 配色（`LOOK_SCHOOL`、`LOOK_REAL`；空＝第三章的暗醫院＋手電筒） |
| `has_enemy` | false：沒有追的人 |
| `time_limit` | > 0：限時；超過也走得完，`play()` 回傳 1 |
| `breath` | 呼吸模式：走路會喘，喘到底停 1.5 秒（`breath_stops` 記次數） |
| `title`、`hint`、`start_motif` | 畫面上的字、開始的音效（空字串＝不放） |
測試：`tests/chase3d_test.gd`（每張迷宮都要每一格連得到、模擬按鍵走得到出口）。
