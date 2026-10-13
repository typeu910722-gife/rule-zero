# Rule Zero — Godot 原型

第一章「歡迎回來」**第一～二天**的可玩原型（約 20–30 分鐘）。
用來驗證：守則與膽量系統、對話節奏、「可愛 → 一點點怪」的氛圍。

![廣場](../docs/images/proto_plaza.png)

## 執行
1. 安裝 [Godot 4.3](https://godotengine.org/download)（標準版即可，不需要 .NET）。
2. Godot → 匯入 → 選擇本資料夾的 `project.godot` → 按 F5。

## 操作
| 按鍵 | 功能 |
|---|---|
| WASD / 方向鍵 | 移動 |
| E / 空白鍵 / Enter | 互動、下一句 |
| Tab / Esc | 日記（守則、發現的事情、拆下名牌） |
| F3 | 除錯：顯示隱藏的懷疑值 |

## 已實作
- 依概念地圖（`docs/art/00_town_map.jpg`）配置的小鎮：守則廣場、鐘塔、鎮長公館、修理室、鏡之屋、森林小徑、河流與石橋、居民小屋、火車站
- 角色外觀依設定圖簡化：露露薄荷綠蝴蝶結、鎮長高禮帽、小布綠斗篷、麻糬（倉鼠）的空白名牌、小玉（三花貓）
- 序章火車 → 歡迎會 → 接糖果小遊戲（含灰色鈕扣異常）→ 守則教學
- 第一天自由探索（7 個地點，拜訪 2 個進入傍晚）、露露叫錯名字、鏡子凝視 10 秒
- 夢境 1、第二天公告欄異常（第 9 條「回來」變粗）、鐘塔指針停在三點
- 膽量系統：問「以前」、拆名牌、晚上偷溜出門，膽量不足時選項變灰
- 夜晚的小鎮：居民面朝鐘塔，鈕扣眼睛跟著你轉；Fen 的對話
- 結算畫面（秘密數、線頭數、懷疑值）

## 尚未實作（下一步）
- 第三天：森林、下午三點的鐘聲、修理、第二章自動開場
- 揉麵團節奏小遊戲（「露露哼的另一首歌」秘密）
- 存檔、音效與音樂、正式美術（目前角色與地圖都是程式繪製的佔位圖）
- 牆壁碰撞（目前只限制地圖邊界）

## 專案結構
```
game/
├── project.godot
├── scenes/main.tscn            # 進入點
├── dialogue/chapter1.txt       # 全部對話（語法：docs/dialogue-format.md）
├── scripts/
│   ├── main.gd                 # 章節流程、場景配置、互動分派
│   ├── autoload/
│   │   ├── game_state.gd       # 天數、膽量、懷疑值、旗標、秘密
│   │   ├── dialogue.gd         # 對話 UI 與執行
│   │   └── dialogue_parser.gd  # 對話腳本解析與檢查
│   ├── world/                  # 小鎮、玩家、角色繪製
│   ├── ui/                     # 公告欄、HUD／日記、結算
│   └── minigames/              # 接糖果、鏡子凝視
└── tests/
    ├── lint_dialogue.gd        # 檢查對話腳本
    ├── smoke_test.gd           # 自動跑完兩條主要路線
    └── screenshots.gd          # 產生截圖（需要顯示環境）
```

## 測試
```
godot --headless --path . -s tests/lint_dialogue.gd
godot --headless --path . -s tests/smoke_test.gd
```

## 字型
原型使用系統的中文字型（Windows：微軟正黑體；macOS：蘋方）。
正式版需要打包可商用授權的字型（例如 Noto Sans TC 或圓體），再上架 Steam。
