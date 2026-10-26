# 自行生成的替代美術

外包正式圖到位前的替代圖。全部是 AI 生成，**上架 Steam 需要揭露**（同第二章外包素材）。

| 檔案 | 用途 | 做法 |
|---|---|---|
| `game/art/ch2/characters/portraits/ch2_fen_portrait_a_default.png` | 第二章 Fen 立繪（預設：皺眉） | 白面立繪 `ch2_baimian_portrait_a_still.png` 依亮度換成 Fen 的配色 → ComfyUI img2img（強度 0.45）加上布偶質感與補丁 → 用白面的輪廓去背 → **補上尾巴**（見下） |
| `game/art/ch2/characters/portraits/ch2_fen_portrait_a_away.png` | 第二章 Fen 立繪（看向別處；結尾火車 `@face Fen away`） | 同上，底圖 `ch2_baimian_portrait_a_faraway.png`（強度 0.42）→ 補上尾巴 |
| `game/art/ch2/characters/sprites/ch2_fen_sprite_stand_sheet.png` | 第二章河對岸的 Fen 地圖小人 | 白面站姿小人換色 → 補上尾巴（蓋住屁股那圈縫線） |
| `game/art/int_mirror.jpg` | 第一章鏡之屋室內（1280×720） | 依熱點位置畫的線稿（三面蓋布的鏡子改畫成「布垂下來」的形狀，避免變成門）→ ControlNet（union, lineart）鎖構圖＋ IP-Adapter（style transfer）參考 `int_lulu.jpg` 的畫風 → 縫死的鏡子手工補縫線 → 投信口的籃子、書桌上那疊很高的紙用局部重畫（inpaint）對齊劇本 |

貓居民已廢案（2026-10-20 使用者決定），表情圖 `face_cat.png` 與程式裡的貓居民一併刪除。

另外修正：`game/art/walk_puppy.png` 第 2、3 列（朝左、朝右）的第三格朝向畫反了，兩格對調（原圖在 Git 歷史裡）。

設定依據：白面是從 Fen 身上剝離出來的那一半，兩隻狐狸是同一個身體（`docs/script/chapter2.md` 2.1），所以用白面的圖當底。

### Fen 的尾巴（2026-10-20 修正）
底圖是白面（白面**沒有**尾巴），換色後 Fen 也跟著沒了尾巴，屁股上還留著白面的縫線。設定：**Fen 有尾巴、白面沒有**。
做法：SDXL＋IP-Adapter（參考 Fen 立繪）生一條狐狸尾巴、裁出來 → `tools/art/fix/fen_tail_ch2.py` 疊上（立繪放在身體後面、小人蓋在屁股上）→ 立繪再整張 img2img（強度 0.38），只把尾巴那塊換回來，讓真毛變成毛氈質感，臉不動。
**以後用白面的圖做 Fen（或反過來）時，記得尾巴要加／要拿掉。**

## 工具與授權
- ComfyUI 0.42（GPL-3.0；只用來產圖，產出的圖不受 GPL 約束）
- comfyui_controlnet_aux（Apache-2.0）、comfyui-ipadapter（Comfy Org 分支，GPL-3.0；同上，只是工具）
- 模型：Stable Diffusion XL 1.0 base（CreativeML Open RAIL++-M，可商用）＋ SDXL-Lightning 4 步 LoRA（ByteDance，OpenRAIL++，可商用）
- ControlNet：xinsir/controlnet-union-sdxl-1.0（promax，Apache-2.0）
- IP-Adapter：h94/IP-Adapter `ip-adapter-plus_sdxl_vit-h` ＋ ViT-H 影像編碼器（Apache-2.0）
- 在雲端 CPU 上執行（沒有 GPU），每張約 4 分鐘；SDXL＋ControlNet＋IP-Adapter 一起跑超過 15GB 記憶體，要把主模型存成 fp8 才跑得動

## 第三～五章劇情背景（2026-10-21，畫風 LoRA 2400 步）
腳本：`gen.py`，`--final 1280x720`，負面提示加上人物、文字（第三章另加玩偶，避免背景裡多出不存在的角色）。
| 檔案 | 用途 | 做法 |
|---|---|---|
| `game/art/ch3/bg/ch3_bg_platform.jpg` | 醫院地下的月台 | free＋plush，畫風強度 0.45（強度高時會變成車廂內、多出布偶） |
| `game/art/ch3/bg/ch3_bg_b2.jpg` | B2 走廊 | free＋plush，強度 0.45 |
| `game/art/ch3/bg/ch3_bg_monitor.jpg`、`ch3_bg_lab.jpg`、`ch3_bg_wild.jpg` | 監視室、實驗室、失控區 | free＋plush |
| `game/art/ch4/bg/ch4_bg_{hallway,gate,stairs,toilet_door,mailbox,phone,ward_dark}.jpg` | 第四章（人類時期） | bg_memory；廁所只畫走廊盡頭一扇關著的門 |
| `game/art/ch5/bg/ch5_bg_{lab,real_ward,real_hall,outside,school_gate}.jpg` | 第五章實驗室、真實世界 | free＋plush（實驗室）／bg_memory |
| `game/art/ch5/bg/ch5_bg_{town,town_office}.jpg` | 終章 B-1 棉花糖鎮 | bg_town／interior |

## 3D 模型做的走路圖（2026-10-27，Windows＋Blender 5.2）
| 檔案 | 用途 | 做法 |
|---|---|---|
| `game/art/walk4/director.png` | 理事（第五章地圖） | `tools/art/blender/director.py` 在 Blender 建模（白色大衣、白手套、左肩老鷹、臉在白色大簷帽的黑影裡，照車掌的做法），轉 4 個角度用 Cycles 去背渲染 → `make_walk_sheet.py --right`（老鷹只在一邊肩上，右側要另外渲染、不能翻轉）。16 格逐格檢查：方向對、背面沒有臉、老鷹在左肩。 |

## 試過但不能用的
| 項目 | 結果 | 缺少的工具 |
|---|---|---|
| 第一章鏡之屋室內（第一輪） | 蓋布的鏡子變成門、畫風不一致 | 已用 ControlNet＋IP-Adapter 解決（見上表） |
