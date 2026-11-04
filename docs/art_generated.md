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

| `game/art/walk4/graduate.png` | 第三章失控區的畢業生（地圖 NPC、巡邏） | `chase_assets.py` 的畢業生模型 → `glb_views.py` 四個方向 → `make_walk_sheet.py --right`（點滴架在右手，左右不對稱）。16 格逐格檢查：正面頭髮蓋住臉、背面沒有臉、點滴架一直在右手 |
| `game/art/walk4/human_nurse.png` | 第三章的人類護理師（二樓巡邏） | 複製 `h_nurse.png`（同一個組織的護理師），在玩偶世界放大（`WALK_SCALE` 0.85） |

| `game/art/walk4/h_duty.png` | 第四章「那一天」② 值日生（小狗居民的人類時期） | `gen.py free --no-style` 出正面（白襯衫、灰長褲）→ 頭髮改淺褐色（呼應米色小狗）、胸前口袋畫一條黃抹布（呼應黃圍巾、他在擦窗戶）→ rembg → Zero123++ 90°／210° → `make_walk_sheet.py --match-color --right`（朝右時抹布在另一邊，要拿掉，不能直接翻轉）。16 格逐格檢查 |
| `game/art/walk4/h_crowd.png` | 第四章的群眾：同學們、圍過來的人、學生們 | 三個沒有名字的同學（兩男一女，`gen.py` 出正面 → Zero123++ → 走路圖，各自逐格檢查）→ `tools/art/make_crowd_shadow.py` 疊成一小群（每格三個人，`WALK_SCALE` 0.69）。正面有臉、背面沒有臉、側面整群同一個方向 |
| `game/art/walk4/h_shadow.png` | 第四章「那一天之後」「第一個晚上」的主角：「你像一個影子一樣，走過那些地方。沒有人看得到你。」 | `make_crowd_shadow.py`：一個同學的輪廓 → 半透明的暗藍灰色人影（看不到臉、衣服） |

## 地圖房間、3D 追逐（2026-10-27，Blender 5.2＋程式）
| 檔案 | 用途 | 做法 |
|---|---|---|
| `game/art/rooms/chapter{3,4,5}/<房間>/`（54 間） | 第三～五章地圖房間的背景＋家具 | `tools/art/blender/room.py`（見 `docs/art_pipeline.md` 第 8 節）。每章逐間檢查：家具落在碰撞框上、窗台的鳥照設定 |
| `game/art/3d/graduate.glb`、`gurney.glb`、`ivpole.glb`、`wheelchair.glb` | 3D 追逐的追兵、障礙物 | `tools/art/blender/chase_assets.py` |
| `game/art/3d/tex/*.png` | 3D 追逐的牆、地板、天花板 | `tools/art/make_chase_textures.py`（程式畫的） |
| `game/audio/amb_hum.ogg`、`amb_drone.ogg`、`amb_room.ogg`、`sfx_ivdrag.ogg` | 環境音、追兵的聲音 | `tools/audio/make_ambience.py`、`make_chase_sfx.py`（程式合成，不是錄音） |

## 試過但不能用的
| 項目 | 結果 | 缺少的工具 |
|---|---|---|
| 第一章鏡之屋室內（第一輪） | 蓋布的鏡子變成門、畫風不一致 | 已用 ControlNet＋IP-Adapter 解決（見上表） |

## 合併 cursor/ch2-mid-no-hold-skip-6513（2026-10-27）
那個分支的第三章整張地圖 `game/art/ch3/maps/` 留著當備用；遊戲裡第三章用 Blender 做的房間（有家具前後遮擋）。巡邏的護士、畢業生用 `human_nurse`（＝ `h_nurse` 放大）、`graduate`（Blender 模型，跟 3D 追逐同一個人）；那個分支的 `h_graduate.png` 也留著。

## 人類時期立繪全部重畫（2026-11-03，ChatGPT）
外包第一批（程式化向量初版）品質不夠，使用者指定的標準是 ChatGPT／Codex 的日漫風。
- 用 ChatGPT（使用者的 ChatGPT Classic 桌面版）照 `docs/vendor/human_era_characters_request_v2.txt` 第 3 節與身高比較設計稿（D1），在同一個對話裡一張一張畫：先畫每個人的第一張，之後「同一個人、同樣構圖，只換表情」。
- 共 79 張：三年二班 13 人的 78 張（表情對照表 `docs/vendor/expression_dictionary.csv` 全部）＋校長 1 張（新角色立繪）。銘越的病人服 2 張是第一次有。
- 原圖（約 1086×1448 透明 PNG）留在使用者電腦 `E:\哲\第零條規則\chatgpt_art\`（不進 Git）；外包第一批的舊圖備份在 `E:\哲\第零條規則\vendor_v1_portraits\`。
- 進遊戲：`py -3.11 tools/art/fit_human_portrait.py <原圖> game/art/human/portraits/<檔名>`（512×768、頭頂離上緣 9%、身體貼齊下緣、左右置中）。
- AI 生成，上架要揭露。

## 人類時期 Q 版走路圖全部重畫（2026-11-03，ChatGPT）
外包的向量小人跟新立繪不搭，同一個 ChatGPT 對話接著畫 Q 版走路圖（每次寫清楚該角色的髮型與服裝，否則 ChatGPT 會畫錯人）。
- 17 張：遙（制服／喜歡的衣服／病人服）、芬（制服／病人服）、導師、希露飛、銘越、小滿、班長、值日生、辛禾、薙文、郡主、秋歌、李恩，加上辛禾的病人服。
- 原圖（約 1254×1254，4×4）在 `E:\哲\第零條規則\chatgpt_art\walk_<id>.png`；總覽 `E:\哲\第零條規則\walk_overview.jpg`。
- 進遊戲：`py -3.11 tools/art/fit_walk_sheet.py <原圖> game/art/walk4/<id>.png`（每格各自找人、同一比例縮放、x=160 置中、腳底 y=304；ChatGPT 偶爾給半透明白底，工具會挖掉）。
- Q 版頭比外包的寬，`human_art_test` 的格子範圍放寬為 x 50～270。
- 2026-11-04 補畫郡主、秋歌、李恩的病人服（`h_junzhu_gown`、`h_qiuge_gown`、`h_lien_gown`）；第五章病房的辛禾、郡主、秋歌、李恩改用 `*_gown`（`tools/levels/build_ch5_level.py` 和 `chapter5.json` 一起改）。人類時期走路圖共 20 張，外包需求列的 20 套都有了。
## 大人的對話立繪（2026-11-04，ChatGPT）
同一個 ChatGPT 對話接著畫，原圖在 `E:\哲\第零條規則\chatgpt_art\portrait_*.png`。
- 人類時期（日漫風、半身，和校長同一套）：`py -3.11 tools/art/fit_human_portrait.py` 轉成 512×768。
  - 穿白大衣的人（第四章，組織的研究員）：白口罩、細框眼鏡、白手套、胸前小小的白鴿徽章，眼睛彎彎的客氣 → `h_whitecoat_portrait_teacher_polite.png`
  - 芬的父親（第四章）：深橘棕色往後梳、深藍三件式西裝、伸手要握手、嚴厲 → `h_fen_father_portrait_teacher_stern.png`
  - 護理師（第五章醒來之後）：淺藍制服、護士帽、寫字板、名牌字看不清楚、很標準的微笑 → `h_nurse_portrait_teacher_smile.png`
  - 服裝代號照校長用 `teacher`（第五章的病人服狀態會退回這一套）；已加進 `expression_dictionary.csv`（82 張）。
- 理事（第五章實驗室，玩偶世界的真人，CLAUDE.md 1-5）：改用羊毛氈／布偶 3D 質感，和車掌、和平鴿同一個世界；白色長大衣、白手套、左肩一隻布做的老鷹，**臉是光滑的白布、沒有五官**。全身圖，比照和平鴿立繪的位置（512×768、頭頂 y≈11、腳底 y≈757）→ `game/art/ch2/characters/portraits/ch2_director_portrait_default.png`，`dialogue.gd` 的 `PORTRAITS["理事"]`。
## 人類時期 CG 10 張（2026-11-04，ChatGPT）
照 `docs/vendor/human_era_characters_request_v2.txt` 第 4 節的 CG 清單，同一個 ChatGPT 對話畫（日漫風、和立繪同一套角色設計）。每張都把角色的髮型、服裝寫清楚，並要求「不畫血、傷口、暴力」「畫面上方 2/3 放重點」「沒有字」。
- 原圖：`E:\哲\第零條規則\chatgpt_art\cg_h_cgXX_*.png`（約 1672×941）。進遊戲：`py -3.11 tools/art/fit_cg.py <原圖> game/art/human/cg/h_cgXX_*.jpg --top 0.4`（裁成 16:9、放大到 2560×1440）。
- 劇本用 `@bg c4_cgXX_*`／`@bg c5_cgXX_*`（`dialogue.gd` 的 `HUMAN_CG`，顯示時不疊立繪）：
  | CG | 位置 |
  |---|---|
  | 01 自我介紹 | `c4_haruka_speech`（走上講台之後） |
  | 02 鏡子碎片 | `c4_l_shard1`（希露飛的地圖，第一片碎片） |
  | 03 郵筒前 | `c4_xinhe_leave`（選「不拿」，手停在投信口前） |
  | 04 留到晚上的導師 | `c4_teacher_rules` |
  | 05 練習要說的話 | `c4_d1_practice`（「那一天」①，畫得溫柔明亮；廁所只有遠遠的標示） |
  | 06 樓梯口的白鴿 | `c4_day_6_fall`、`c4_day_6b_window`（停在白鴿飛進來的一刻，下一句切回樓梯背景） |
  | 07 遺留物 | `c4_org_hospital` |
  | 08 第一個晚上 | `c4_n_end`（門開了 → 電閘；床上的人看不清楚、沒有綁的細節） |
  | 09 醒來 | `c5_a_intro`（舉起手 → 遺留物；之後回 `c5_real_ward`） |
  | 10 走出大門 | `c5_a_outside`（9 個人的背影＋遠處排隊進醫院、拿白色糖果的孩子） |
- `human_art_test` 檢查 10 張都在、2560×1440、劇本有用到、CG 上不疊立繪。