# 跨平台製作計畫（Windows／Android／iOS）

> 2026-10-19 第一階段檢查結果。素材逐檔清單見 `docs/asset_inventory.md`。
> 本文件只整理現況與計畫，**不改動任何劇本、角色設定或素材**。

---

## 0. 結論先講

1. **專案本來就是 Godot 4.3**（GDScript、GL Compatibility 渲染），不需要「從別的引擎移植」。工作重點改成三件事：
   - 把第一章從「程式畫的佔位圖」換成正式美術與音訊（第一章目前**沒有任何**正式圖、配樂、音效）。
   - 補齊跨平台需要的部分：手把、手機版面、Windows／Android／iOS 匯出設定。
   - 依需要把一部分架構改成 Godot 標準節點（見第 2 節），但不一次重寫。
2. **現有程式能正常運作**：在 Godot 4.3 headless 實際執行四個測試，全部通過（見第 1.3 節）。
3. **第二章外包素材已全部交件**，但約 82 張圖、4 首配樂、35 種音效還沒接進遊戲。

---

## 1. 原始專案檢查

### 1.1 技術現況

| 項目 | 現況 | 位置 |
|---|---|---|
| 引擎 | Godot 4.3 stable，GL Compatibility（桌機、手機、網頁都用同一個渲染器） | `game/project.godot` |
| 語言 | 全部 GDScript，約 7,600 行程式＋2,066 行對話腳本 | `game/scripts/`、`game/dialogue/` |
| 場景管理 | 兩個場景：`main.tscn`（標題＋第一章）、`chapter2.tscn`；用 `change_scene_to_file` 切換。章內的地點（小鎮、森林、室內）由程式產生節點、用 `_layout()` 切換 | `scripts/main.gd`、`scripts/chapter2.gd` |
| 角色控制 | `Node2D` 手動移動＋地圖邊界限制＋多邊形禁區（沒有用 `CharacterBody2D`，沒有牆壁碰撞） | `scripts/world/player.gd` |
| 角色繪製 | 第一章：程式 `_draw()` 畫出來的佔位角色；第二章：外包 sprite sheet，缺圖時退回程式繪圖 | `scripts/world/critter.gd` |
| 動畫 | 程式控制（`_process` + `_draw`、少量 `create_tween`）；沒有 `AnimationPlayer`／`AnimatedSprite2D` | — |
| 對話 | 自建系統：純文字腳本（`=== 標籤`、選項、條件、`@指令`），有語法檢查器；寫劇本的人不用碰程式 | `autoload/dialogue.gd`、`dialogue_parser.gd`、`docs/dialogue-format.md` |
| 遊戲狀態 | Autoload `GameState`：天數、膽量、懷疑值、操行、旗標、秘密 | `autoload/game_state.gd` |
| 存檔 | JSON：`user://save.json`（當章，每天早上自動存）＋`user://meta.json`（跨周目）；有 `version` 欄位 | `game_state.gd` |
| 輸入 | 程式內建鍵盤綁定（WASD／方向鍵、E／空白／Enter、Tab／Esc）；手機有虛擬搖桿＋「互動」「日記」按鈕。**沒有手把** | `game_state.gd::_setup_input`、`ui/touch_controls.gd` |
| 解析度 | 1280×720，`canvas_items` 縮放、`keep` 比例（手機會有黑邊）；UI 座標多為固定值 | `project.godot` |
| 音訊 | 第二章：`AudioStreamPlayer` 播 ogg；第一章：只有揉麵團的程式合成音 | `chapter2.gd`、`audio/sfx.gd`、`audio/tones.gd` |
| 特效 | 一個 canvas shader（重新塞棉花的漂白光）、`CanvasModulate` 做時段色調 | `minigames/restuff.gd`、`main.gd` |
| 字型 | 內建 Noto Sans TC 子集（SIL OFL 1.1，可商用） | `game/fonts/` |
| 匯出 | 只有 Web 一個 preset（已上線為網頁試玩）；**沒有 Windows／Android／iOS preset** | `game/export_presets.cfg` |
| 外掛 | 無（GDD 提到的 Dialogic、GodotSteam 都還沒裝） | — |

### 1.2 劇情與內容現況

| 章節 | 劇本 | 可玩程度 | 美術 | 音訊 |
|---|---|---|---|---|
| 第一章「歡迎回來」 | `docs/script/chapter1.md` | 三天完整可玩（火車序章、歡迎會、接糖果、守則、鏡子凝視、夢境 1／2（醫院走廊）、公告欄異常、Fen、森林零件堆、修理室） | **全部是程式佔位圖**；只有 `docs/art/` 9 張概念圖 | **無**（揉麵團合成音除外；八點鐘聲沒有聲音） |
| 第二章「漂白鎮」 | `docs/script/chapter2.md` | 完整可玩（序章、三天、畢業典禮、結尾、壞結局、9 個小遊戲） | 外包全部交件（AI 生成，Steam 需揭露） | 配樂 17 檔、音效 61 種，部分未接 |
| 第三章「慈愛綜合醫院」 | 待設計 | — | — | — |

### 1.3 實際執行的測試（2026-10-19，Godot 4.3 stable，Linux headless）

| 測試 | 結果 |
|---|---|
| `tests/lint_dialogue.gd` | 通過：238 個標籤、1,780 個指令、0 個錯誤 |
| `tests/rhythm_test.gd` | 通過：準時／偏掉兩種情況 |
| `tests/smoke_test.gd` | 通過（0 個失敗）：第一章兩條路線＋第二章開場、存檔讀檔、揉麵團秘密 |
| `tests/chapter2_test.gd` | 通過（0 個失敗）：第二章四條路線（含刺向面具、壞結局）、存檔讀檔 |

結束時有 `ObjectDB instances leaked` 警告，不影響結果，之後順手清。
**沒有執行**：任何平台匯出、實機（手機、Windows）測試、截圖測試（需要顯示環境）。

### 1.4 素材盤點摘要（詳見 `docs/asset_inventory.md`）

- 遊戲素材 609 檔（圖 407、音 200、字型 2），全部有 `.import`；程式引用但不存在的檔案：**0**。
- 第二章：需求單所有項目都有檔案。未接入：約 82 張圖（含嘎嘎 7 張立繪、對話框／日記 UI、BG-09／BG-10、cg01 繡字漸進）、4 首配樂（03、06、07、07_stop）、35 種音效（所有小遊戲與 UI 音效）。
- 外包交件裡有完全相同的檔案，可能是交件錯誤：`confession_card_back` = `card_front`、`cg08_diary_blank` = `cg08_diary`。
- 第一章缺：角色（小布、熊熊鎮長、露露、Fen、麻糬、小玉、波波、鏡中的孩子、車掌的影子、居民）、棉花糖鎮地圖、火車車廂、小布的家、森林、修理室、夢境、3 個小遊戲、全部 UI、全部配樂音效。
- `docs/vendor/ch2_batch2_feedback.txt` 寫「配樂與音效全部已接入」，和程式現況不符；`game/README.md` 的「尚未實作」一節也過期。

---

## 2. Godot 架構：現況 vs 目標

原則：**能用就不重寫**。只在「做垂直切片時會碰到、而且改了明顯更好」的地方改。

| 需求 | 現況 | 建議 | 時機 |
|---|---|---|---|
| SceneTree 場景管理 | 2 個大場景，章內地點由程式產生 | 第一章正式美術進來時，把每個地點拆成獨立 `.tscn`（美術可以在編輯器裡擺）；加一個 `SceneRouter` autoload 負責淡入淡出與載入 | 垂直切片 |
| 角色控制 | `Node2D` 手動移動、只有邊界 | 改 `CharacterBody2D` ＋ `CollisionShape2D`，地圖用碰撞多邊形（README 列的「牆壁碰撞」也一起解決） | 垂直切片 |
| AnimationPlayer／AnimatedSprite2D | 程式畫格 | 角色走路用 `AnimatedSprite2D`（`SpriteFrames`）；演出（鐘聲、縫合、崩潰）用 `AnimationPlayer` | 垂直切片 |
| AudioStreamPlayer | 第二章已用 | 抽成 `AudioManager` autoload（BGM 淡入淡出、SE 隨機變化、音量設定），兩章共用；加 Audio Bus（Music／SFX／Voice） | 垂直切片 |
| CanvasLayer UI | 已用（HUD、對話、日記） | 保留；加手機版面（第 4 節） | 跨平台 |
| 對話系統 | 自建、資料驅動、有 lint | **保留**，不換 Dialogic／Dialogue Manager：現有 2,000 行劇本、旗標、條件、測試都綁在這套語法上，換掉風險大、收益小 | — |
| JSON／Resource 劇情資料 | 對話是純文字；角色表、物件表寫在 `.gd` 常數 | 把 `ACTORS`、`OBJECTS`、秘密定義搬到 JSON 或 `.tres`，方便非程式人員改 | 之後 |
| 存檔讀檔 | JSON＋版本號 | 改成「先寫暫存檔再改名」避免手機被強制關閉時存壞；加多存檔欄位（可選）；Steam 雲端時一起處理 | 跨平台 |
| 多解析度 | 1280×720 固定比例＋黑邊 | 改 `expand` 比例，UI 用錨點；處理手機瀏海與圓角（`DisplayServer.get_display_safe_area()`） | 跨平台 |
| 手機觸控 | 已有搖桿與按鈕 | 搖桿改為「按哪裡出現在哪裡」、按鈕放大到至少 9mm、對話字級手機版加大 | 跨平台 |

---

## 3. 核心體驗（第三階段）對照

| 項目 | 現在有沒有 | 要補的 |
|---|---|---|
| 火車序章 | 有（純色背景＋文字） | 車廂背景、窗外視差、火車音效 |
| 角色探索 | 有 | 正式地圖、碰撞、走路動畫 |
| 劇情對話 | 有 | 第一章立繪、對話框美術（粉紅「縫在布上的標籤」） |
| 道具與線索 | 有（日記「記下的事」） | 道具特寫圖 |
| 夢境切換 | 有（夢境 1、2：醫院走廊） | 夢境畫面、轉場 shader（鉛筆線稿、去飽和） |
| 鏡子異常 | 有（凝視 10 秒） | 鏡中孩子的畫面與遮罩效果 |
| 恐怖閃字與畫面干擾 | 部分（公告欄字變粗、紅線） | 通用的 `AnomalyFX`：閃字、雜訊、色差、去飽和 shader（GDD 5.5：異常不配提示音、不解釋） |
| 角色動畫（含崩潰、破敗） | 程式繪圖 | 需要美術提供分件或逐格圖（紙偶動畫：分件用 `Skeleton2D` 或 `AnimationPlayer` 擺動） |
| 分支與事件 | 有（旗標、條件、`@event`） | — |
| 存檔與進度 | 有 | 原子寫入、設定選單（音量、字級） |

---

## 4. 跨平台（第四階段）

| 平台 | 需要什麼 | 能在這個雲端環境驗證嗎 |
|---|---|---|
| Windows | 4.3 匯出範本；手把綁定（`InputEventJoypadButton`／`JoypadMotion`）；滑鼠點擊互動；可選 rcedit 改圖示 | 可以匯出 `.exe`；**不能**實機執行（Linux 環境），需要你在 Windows 上跑 |
| Android | 匯出範本、JDK 17、Android SDK、keystore；觸控與效能測試 | 可以產生 debug `.apk`（要下載 SDK，約數 GB）；**不能**實機測試，需要你的手機或模擬器。上架前要確認 Google Play 當時要求的 target API 等級，以及 Godot 4.3 是否符合（較新版本可能需要升級 Godot） |
| iOS | **macOS＋Xcode＋Apple Developer 帳號（年費）**；Godot 匯出的是 Xcode 專案，在 Xcode 簽署後安裝 | **不能**。必須在 Mac 上做 |
| 網頁 | 已上線 | 已有 `tools/build_site.sh` |

手機 UI 不是把電腦畫面縮小：
- 對話框：手機版字級 ≥ 32（以 720p 畫布計）、行數減少、點任何地方前進。
- 選項：改成大按鈕直排，間距加大。
- 日記與公告欄：全螢幕分頁，可滑動。
- HUD：避開瀏海與圓角安全區。
- 小遊戲：逐一檢查（拖曳刷子、按住撐住、節奏判定在觸控上的延遲）。

---

## 5. Claude 工具整合

### 5.1 搜尋結果（2026-10-19，只讀資訊，**沒有安裝任何東西**）

| 工具 | 用途 | 授權 | Godot 版本 | 安全性備註 |
|---|---|---|---|---|
| [Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp) | MCP：開編輯器、執行專案、讀錯誤輸出、建立場景／加節點、存場景 | MIT（已讀 LICENSE） | 4.x（UID 功能需 4.4+） | Node.js；依賴只有 `@modelcontextprotocol/sdk`、`axios`、`fs-extra`。2026-04 合併了「任意腳本實例化 RCE」修正（PR #99），**只能用此修正之後的版本**，而且只在本機使用 |
| [jame581/GodotPrompter](https://github.com/jame581/GodotPrompter) | Claude Code skills（約 40+ 個：架構、2D、UI、shader、手機部署等） | MIT（已讀 LICENSE） | 4.3+ | 純文字指引、不執行程式，風險低；內容針對 4.5／4.6 的部分要注意相容 |
| fenixnix/Godot-Skills | GDScript、TSCN 格式等 skills | 未確認 | — | README 主要是中文；安裝指令有佔位字，未驗證 |

### 5.2 建議工作流程

- **雲端（現在這個環境）**：不需要 MCP。直接下載官方 Godot 4.3 執行檔，用 headless 模式跑測試、匯出、截圖（本次檢查就是這樣做的）。
- **你的電腦（Claude Desktop）**：如果要讓 Claude 開編輯器、看即時畫面，可以裝 godot-mcp（MIT，需 Node.js）。安裝前先確認版本包含 PR #99。Desktop 不能直接操作 Godot 時，替代做法：Claude 改檔、跑 headless 測試與截圖 → 推到 Git → 你在本機 Godot 開啟確認。
- **iOS 一律在 Mac 上做**，Claude 能做的是準備匯出設定與檢查清單。

---

## 6. 階段計畫與可驗證成果

| 階段 | 內容 | 可驗證成果（怎麼證明做完） |
|---|---|---|
| A. 基礎整理 | 手把綁定；存檔原子寫入；`AudioManager`；更新過期的 README；清掉測試結束的資源洩漏警告 | 既有 4 個測試仍全過；新增存檔測試；手把需你實機確認 |
| B. 垂直切片（第一章開頭） | 火車序章 → 抵達廣場 → 歡迎會 → 第一天探索（2–3 個地點）→ 鏡子凝視 → 夢境 1（醫院走廊）。正式美術、地點拆成獨立場景、`CharacterBody2D`、`AnimatedSprite2D`、配樂音效、異常效果 shader | headless 測試跑完整段；截圖；Windows `.exe` 給你實機試玩 |
| C. 手機版 | 手機版面、安全區、觸控改良、效能（材質壓縮、記憶體） | Android debug `.apk`（你在手機上試）；iOS 匯出設定＋檢查清單（你在 Mac 上建置） |
| D. 全面套用 | 第一章其餘部分換正式素材；第二章未接的素材接上；第三章 | 每章路線測試全過 |

**垂直切片卡在美術**：第一章目前沒有任何可以放進遊戲的正式圖（`docs/art/` 是概念圖，README 也列了待修的地方）。可行的方向：

1. 依第二章需求單的格式，先寫「第一章垂直切片素材需求單」交給外包（角色設定、隱藏設定照 `CLAUDE.md` 附上）。
2. 等素材期間，先用現有程式佔位圖把**架構**改好（場景拆分、碰撞、動畫節點、音訊、效果），素材到了直接替換。

---

## 7. 風險

| 風險 | 影響 | 對策 |
|---|---|---|
| 第一章沒有正式素材 | 垂直切片的「美術品質」無法驗證 | 先做架構、同時發需求單 |
| iOS 需要 Mac 與付費開發者帳號 | 雲端無法建置 | 你準備 Mac；Claude 準備設定與步驟 |
| 雲端無法實機測試 | 觸控手感、效能、手把只能由你確認 | 每階段給你可安裝的檔案和測試清單 |
| Godot 4.3 版本 | 新版手機商店要求可能需要升級 | 垂直切片完成後再評估升級到較新的 4.x，升級前後都跑完整測試 |
| 素材為 AI 生成 | Steam 需揭露 | 商店頁準備揭露文字 |
| 外包缺分層原始檔 | 紙偶動畫需要分件 | 第一章需求單要求附分層檔 |
| 大量程式產生節點 | 美術不好在編輯器裡擺 | 階段 B 逐步拆成 `.tscn`，不一次重寫 |

---

## 8. 進度紀錄

| 輪次 | 日期 | 做了什麼 | 驗證 |
|---|---|---|---|
| 1 | 2026-10-19 | 手把綁定（左搖桿／十字鍵、A、START／BACK）；互動提示依最後使用的裝置顯示 E／A／互動；存檔改成「.tmp → 讀回確認 → 換上，舊檔留 .bak」，主檔壞掉時讀 .bak；新增 `tests/save_test.gd`；README 過期段落更新 | 5 個測試在 Godot 4.3 headless 全過；**手把沒有實機測試** |
