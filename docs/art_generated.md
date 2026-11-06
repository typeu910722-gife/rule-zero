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
## 追逐戰全身圖 3 套 × 12 張（ChatGPT，2026-11-04）
需求 v2 第 2-4 節。ChatGPT 一套畫一張 4 欄 × 3 列的白底動作表（原圖 `E:\哲\第零條規則\chatgpt_art\chase_h_*.png`，1774×887），
`py -3.11 tools/art/fit_chase_sheet.py <原圖> game/art/human/chase <前綴>` 切成 12 張 512×512 透明 PNG：
12 格同一個縮放比例、腳底 y=488、頭＋上半身的中心 x=256。動作：run_00～07、idle、look_back、stumble、breath。

| 套 | 前綴 | 用在哪裡 |
|---|---|---|
| A 遙（制服） | `h_haruka_chase_uniform` | 目前劇本沒有遙穿制服跑的段落，圖先備著 |
| B 遙（病人服） | `h_haruka_chase_gown` | 第五章終章 A「走出去」（chapter5.gd `_walk_out`）；走路格子是慢慢走 |
| C 芬（制服） | `h_fen_chase_uniform` | 第四章「走廊盡頭」（chapter4.gd `c4_run`） |

遊戲裡的用法：3D 追逐（`scripts/ch3/chase3d.gd`）設 `runner` 後，畫面左下角出現側面全身小人：
往前＝跑步循環（每秒 12 格；終章 A 慢一點），撞牆＝踉蹌 0.6 秒，喘不過氣停下來＝撐膝蓋（輕輕上下動），偶爾＝回頭 0.5 秒。
第三章（玩偶）不設 `runner`，不顯示。測試：`human_art_test.gd`。

## 小玉（布偶）與地圖上的門（ChatGPT，2026-11-04）
**小玉**：第五章壞結局 B 回到棉花糖鎮時有台詞，原本沒有第二章那種布偶立繪；地圖走路圖也還是第一章的 Q 版。
- 立繪 `game/art/ch2/characters/portraits/ch2_tama_portrait_{default,smile_hard,bow}.png`（512×768）：
  原圖 `chatgpt_art\portrait_tama_felt.png`（參考第一章表情圖＋麻糬、波波的立繪，三花貓布偶、黃領巾、墨綠吊帶裙）。
  dialogue.gd `PORTRAITS["小玉"] = "tama"`；chapter5.txt 鞠躬那句 `@face 小玉 bow`、「很好的一天」那句 `@face 小玉 smile_hard`。
- 走路圖 `game/art/walk4/tama.png`（1280×1280，取代第一章原圖做的 640 版）：原圖 `chatgpt_art\walk_tama_felt.png`，
  `py -3.11 tools/art/fit_walk_sheet.py <原圖> game/art/walk4/tama.png --height 286`（和舊圖一樣高）。
  第一章的 `walk_tama.png`、`face_tama.png` 沒有動。

**門**（全遊戲美術清單第 4 節 C，原本是方塊＋字）：4 套 × 4 張，`game/art/doors/door_<套>_<front|side>_<locked|open>.png`。
原圖 `chatgpt_art\door_{school,hospital,real,town}.png`（2×2 白底），`py -3.11 tools/art/fit_door_sheet.py <原圖> game/art/doors <套>`。
| 套 | 用在哪些房間主題（explore_art.gd `DOOR_SETS`） |
|---|---|
| school 木頭教室門 | school、school_dark（調暗）、home |
| hospital 玩偶世界的舊病房門 | hospital、lab、platform、hospital_old（調暗）、basement（更暗） |
| real 現實的白色病房門＋電子鎖 | real |
| town 棉花糖鎮的粉紅拱門 | town |
畫法（explore.gd `_draw_door_art`）：上面牆的門畫正面（腳在門的範圍下緣、不超出房間上緣），名字改寫在門下面；
左右牆、下面牆的門畫俯視的細長門（右牆左右翻、下牆轉 90 度）。鎖著的門有鎖鏈（真實醫院是亮紅燈的電子鎖），開著的門是暗的門洞。
測試：`human_art_test.gd`（小玉立繪／走路圖、每一種有門的房間主題都找得到 4 張門）。

## 第三章小遊戲零件（ChatGPT，2026-11-05）
- 原圖：`E:\哲\第零條規則\chatgpt_art\ch3_mini_props.png`（4×3：心臟、壓扁的心臟、心電圖螢幕、點滴袋、水滴、牌背、空白牌面、溫度計、裂開的布、針、棉花、告示板）、
  `ch3_mini_runner.png`（3×2：推床、點滴架、伸出來的手、小布背影 2 格、輪椅；小布照 `ch2_pip_portrait_default.png` 上傳參考）、
  `ch3_mini_corridor.png`（一點透視的走廊，裁成 1280×720，消失點對齊程式的 (640, 250)）。
- 切圖：`py -3.11 tools/art/fit_parts_sheet.py <原圖> game/art/ch3/mini <欄> <列> <最長邊> 名字…`
  （白底只挖「跟邊緣連通、很白」的地方；名字後面加 `!` 會補洞，棉花這種整塊白的東西要加）。
- 程式：`Ch3Mini.art(名字)` 讀 `game/art/ch3/mini/`，沒有圖就退回原本的色塊。圖一定要快取：只在 `_draw` 裡 `load()` 的話，
  畫完就被釋放，畫面上會是一塊白色（human_art_test 有檢查）。
- 用在：心臟按壓（布心臟會被壓扁、床邊心電圖螢幕）、點滴（袋子＋液面＋水滴）、心臟病（牌背翻成牌面）、
  縫合（布塊、針、掉出來的棉花）、量體溫（玻璃溫度計）、捉迷藏／廣播點名（走廊背景、推床、點滴架、手、輪椅、跑步的小布）、
  醫院守則（字寫在告示板的紙上）。

## 第四、五章小遊戲與演出（ChatGPT，2026-11-05）
- 原圖：`chatgpt_art\ch45_mini_sprites.png`（4×3：鞋子 6 雙、白鴿、芬的剪影站著／被推開、手機、白衣職員走路 2 格；上傳 `h_cg01_speech.jpg` 當畫風參考）、
  `ch4_bg_toilet_door.png`（放學後的廁所門口：門在正中間、右邊窗戶、左下樓梯）、`ch4_bg_podium.png`（從講台看出去，台下都是逆光的影子）、
  `ch5_bg_hospital_side.png`（真實醫院走廊的側面）。背景裁成 1280×720。
- 放在 `game/art/ch4/mini/`，程式用 `Ch3Mini.art4(名字)`（第五章也用這個資料夾）。
- 用在：自我介紹（講台背景、笑聲越大越暗）、群組（手機外框）、擋在門前（廁所門口、窗台上的白鴿、芬的剪影；被撞下樓梯只是剪影滑出畫面）、
  秋歌的手機取景（手機螢幕裡是那扇門）、門縫的鞋子（只看得到鞋子，往上淡掉，看不到人）、
  醒來走路（醫院走廊側面，遙用 `h_haruka_chase_gown_*` 走路／喘氣）、守走廊（白衣職員一步一步走過來）。
- 「那一天」照設定：畫面只有門外、鞋子、聲音，門裡面什麼都不畫。

## 地圖小道具與條碼的走路圖（ChatGPT，2026-11-05）
- 原圖：`chatgpt_art\misc_props_tiaoma.png`（4×3：條碼正面／右／背面／左、糖果粉綠黃、紙條、信箱、枕頭；上傳小布的搶椅子走路格＋條碼站姿當參考）。
- 條碼：`game/art/ch2/minigames/chairs/ch2_chairs_tiaoma_walk_01～04.png`（80×80，跟小布一樣腳底在 y=75、高 70），搶椅子改用走路圖。
- 道具：`game/art/props/`（candy_0～2、note、mailbox、pillow），`Interactable.prop_tex()` 讀（有快取），沒有圖退回原本的形狀。

## 第二～五章的對話框、名牌、密碼鎖、狀態列（2026-11-05）
- 對話框與名牌：第二章接上外包的 `ch2_ui_01_dialogue.png`／`ch2_ui_01_nameplate.png`（原本是程式畫的灰框）；
  第三章 `game/art/ch3/ui/`（醫院毛氈，原圖 `chatgpt_art\ui_ch3_dialog.png`）；第四、五章 `game/art/human/ui/`（筆記本紙＋深藍名牌，`ui_human_dialog.png`）。
  `Dialogue.CHAPTER_SKINS` 設定每章的圖和九宮格邊距；名牌只包住名字，旁白時不顯示（高度不變）。
- 密碼鎖：`kp3_*`（毛氈，第三章）、`kp5_*`（金屬，第五章）；狀態列底條：`hud3_bar`（毛氈）、`hud4_bar`（筆記本紙），都在 `game/art/ch3/mini/`
  （原圖 `ui_keypad_hud.png`）。狀態列底條高 60px，九宮格邊才不會比狀態列高。
- 切圖：很寬的東西（對話框）或格子不平均的零件表用 `tools/art/fit_ui_pieces.py`（找連在一起的幾塊；`--pos` 照位置排）。

## 章末卡片背景、3D 走廊的門／逃生燈牌／天花板燈（2026-11-05）
- 章末卡片：`game/art/ch3/bg/ch3_end_card.jpg`（玩偶醫院夜裡空的病床，原圖 `chatgpt_art\ch3_end_card.png`）、
  `game/art/ch4/bg/ch4_end_card.jpg`（夜裡空的三年二班，`ch4_end_card.png`）。很暗、慢慢浮出來，字疊在上面。
- 3D 走廊的門：直接用地圖那套門圖（`door_<hospital|school|real>_front_locked.png`），不另外畫。
- `game/art/3d/tex/exit_sign.png`（發光的逃生燈牌，學校與真實醫院）、`exit_sign_felt.png`（毛氈的，玩偶醫院）、
  `ceiling_lamp.png`（天花板燈具）；原圖 `chatgpt_art\3d_exit_lamp.png`。燈牌朝向走過來的那一格。
- 還沒做：3D 走廊的桌椅、置物櫃、長椅等模型（ChatGPT 只能出平面圖）。

## 第五章事件 CG 3 張（ChatGPT，2026-11-05）
- `h_cg11_director`（理事帶著老鷹走進實驗室；玩偶世界的真人，臉是一片陰影；上傳 `ch2_director_portrait_default.png` 當參考）、
  `h_cg12_vest`（白面的背心蓋在芬的手上，只畫手）、`h_cg13_vest_note`（壞結局：空床上摺好的背心和看不清楚的紙條）。
- 原圖 `chatgpt_art\cg_h_cg11_director.png` 等，裁 16:9、放大到 2560×1440，放在 `game/art/human/cg/`。
- 劇本：`c5_director`（老鷹那句之後顯示，接著回到 `c5_lab`）、`c5_a_baimian`、`c5_b3_fen`。

## 學校、真實醫院 3D 走廊的擺設（Blender 命令列，2026-11-05）
- `tools/art/make_props_3d.py` 用 Blender 5.2 不開視窗產生低面數 glb：`school_desk`（課桌＋倒放的椅子）、`locker`（三格置物櫃）、
  `bench`（候診長椅）、`cart`（推車），放在 `game/art/3d/`。
- `chase3d.gd` 的 `PROPS`：死巷裡放第一組、直走廊每隔幾格靠牆放第二組（正面朝走廊）。

## 第二章結局車廂的 Fen 分層（ChatGPT，2026-11-05）
- 原圖 `chatgpt_art\ch2_cg20_fen_src.png`（上傳 `ch2_fen_portrait_a_default.png`，畫坐著的 Fen），去背後縮到 140px 高、稍微調暗，
  放在右邊第二排靠走道（中心 x=748、頭頂 y=292），存成 `game/art/ch2/cg/ending_layers/ch2_cg20_fen.png`（1280×720 透明）。
- chapter2.gd 的疊圖順序：Fen 在車掌和前排之前畫。

## 選項按鈕三套（ChatGPT，2026-11-05）
- 原圖 `chatgpt_art\choice_buttons.png`（3×3：漂白宿舍／毛氈醫院／筆記本紙 × 一般／選到／不能選），
  `py -3.11 tools/art/fit_ui_pieces.py … --pos` 切成 `game/art/ui_choices/ch{2,3,4}_{normal,focus,off}.png`（寬 360）。
- `dialogue.gd` 的 `CHOICE_SKIN`：第二章 ch2、第三章 ch3、第四五章 ch4；九宮格左邊留 80px（十字貼布、紙膠帶不會被拉長）。

## 第三章「舉槍、上膛」特寫、終章 A 門口排隊的孩子（ChatGPT，2026-11-05）
- `ch3_bg_cg_gun.jpg`（1280×720）：和平鴿（白色鳥面具、白手套）拉開左輪的擊鎚，背景是被綁在椅子上的車掌、掉在地上的帽子；
  沒有血。上傳第三章結尾 CG、和平鴿、車掌立繪當參考。`chapter3.gd` 的 `_gunshot()` 先切到這張，再上膛、黑屏、槍聲。
- `h_cg14_queue.jpg`（2560×1440）：醫院大門，一列穿制服的孩子走進去，最後一個回頭、手裡一顆白色糖果；
  上傳 `h_cg10_outside.jpg` 當參考，招牌是空白的（字由劇本說）。劇本 `c5_a_outside` 的「隊伍的最後一個孩子回過頭」前。

## 第四、五章配樂（程式合成，2026-11-05）
- `tools/make_ch45_bgm.py`：鋼琴＋弦樂墊，旋律是全作的動機。輸出 `game/audio/ch45/bgm/` 7 首（可循環）。
  第四章：school（回憶）、after_school（傍晚）、night（夜晚）、unease（芬的段落，動機降半音）；
  第五章：lesson（最後一堂課）、waking（終章 A，最後一個音落回主音）、hollow（B-2、B-3，遠處的心電監護儀）。
  組織的段落、理事的實驗室沿用第二章〈涅槃〉，B-1（留在玩偶世界）沿用〈夢〉。
  「那一天」和第五章開場刻意沒有音樂。
- 執行：`uv run --no-project --python 3.12 --with numpy --with scipy python tools/make_ch45_bgm.py`（這台電腦的 Python 3.11 scipy 壞了一部分）。
- 烏鴉叫聲試著合成，聽起來像錯誤提示音，所以沒有用；第三章窗台的烏鴉改用外包的 `bird_peck`（啄窗聲）。

## 第三章：小布跑步 4 格、病房門突然打開、結尾的破爛玩偶（2026-11-05）
- `run_bu_03.png`、`run_bu_04.png`：ChatGPT 畫的兩格「經過」動作（上傳原本的 01、02 當參考，原圖 `chatgpt_art
un_bu_passing.png`），
  `fit_parts_sheet.py … 2 1 220` 切成高 220。`runner.gd` 的 `BU_CYCLE` = 01 → 03 → 02 → 04（背包左右甩）。
- 3D 追逐（玩偶醫院）：每 10 面牆裡的一扇病房門會在玩家走到 1.6 公尺內時突然打開——換成 `door_hospital_front_open.png`、
  `door_thud` 聲、畫面閃白、腳步慢 0.8 秒；起點附近不會開。不用新圖。
- 結尾 `@event c3_tatters`（和平鴿看見大家時）：用第二章立繪排一列，依 `c3_cotton_<id>` 合成——棉花越少越灰、
  裂開的縫線越長、從縫線冒出來的棉花（`sew_cotton.png`）越多；疊在背景 CG 上、對話框下，舉槍時拿掉。

## 第三章醫療小遊戲的音效（程式合成，2026-11-05）
- `tools/make_ch3_sfx.py` 加了 `drip`（點滴落進滴壺，滴得越快越密）、`compress`（心臟按壓時壓在布偶胸口的悶響）、
  `thermo_beep`（電子體溫計量好的嗶嗶）。用 earshot 聽過：drip 像水泡破掉、thermo_beep 像電子嗶聲；
  compress 聽起來像很悶的大鼓，節奏遊戲裡當「壓下去」的回饋可以接受。
- 點滴小遊戲的腳步聲 `dove_step` 是和平鴿走近的提示（聽到要停手），不是借錯的音效，維持原樣。
- 只重做幾個：`uv run --no-project --python 3.12 --with numpy --with scipy python tools/make_ch3_sfx.py drip compress thermo_beep`

## 畫面總檢查（自動截圖，2026-11-05）
- 跑了第二章（13）、第二章小遊戲（12）、第三章地圖（22）、第三章小遊戲（7）、第四、五章地圖（11）、第四、五章小遊戲與背景（7）、標題（2）的截圖，逐張看過。
- 修正：終章「守住走廊」牆上的心電監視器原本是四個深綠色方塊 → ChatGPT 畫的壁掛監視器 `game/art/ch4/mini/wall_monitor.png`
  （原圖 `chatgpt_art\ch5_wall_monitor.png`，260×104，螢幕在 (20, 32) 起 220×52，波形畫在螢幕裡）；
  第三章「心臟病」的「值班護士：一、二、三～」往上移，不再壓到心電圖。
- `tests/screenshots_ch3.gd`、`screenshots_ch45.gd` 還在讀舊的房間表（已經改成探索地圖），改成只拍還存在的；房間畫面看 `screenshots_ch*_map.gd`。
- 看起來是「空房間」的第四章校門、玄關：背景圖上的黑色方塊是家具的位置，遊戲裡會疊上家具圖，不是缺圖。
- 同一天再跑第一章（9）、第一章追逐（6）、3D 追逐（3）、結局（7）、手機版面（5）、探索（2）的截圖：沒有發現缺圖或擋字。

## 人類時期斜向走路圖 13 張（2026-11-06，ChatGPT）
使用者回饋：第四章走路沒有左上、右上、左下、右下。同一個 ChatGPT 對話「繪製對角行走精靈圖」，每次附上原本的四方向走路圖，請它畫同一個角色的 4×4 斜向走路圖。
- 原圖：`E:\哲\第零條規則\chatgpt_art\walk_<id>_diag.png`
- 進遊戲：`py -3.11 tools/art/fit_diag_sheet.py <原圖> <id>` → `game/art/walk4/<id>_diag.png`。只用第 1 列（左下）、第 2 列（左上），右下、右上是左右翻過來的（ChatGPT 畫右邊常常轉錯方向）；高度照同一角色四方向圖最高的那格；頭髮之間包住的白底另外挖掉。
- 列的順序：0 左下、1 左上、2 右下、3 右上（`explore_art.gd` `draw_walk` 的 row 4～7）。沒有斜向圖的角色（玩偶小布等）斜著走時用左右那一列。
- 角色：h_haruka、h_xiaoman、h_tiwen、h_hilufei、h_xinhe、h_mingyue、h_teacher、h_fen、h_haruka_dress、h_duty、h_lien、h_haruka_gown；h_shadow_diag 用遙的斜向圖照 `make_crowd_shadow.py` 的方法做成人影（`tools/art/make_shadow_diag.py`）。
- 測試：`tests/walk8_test.gd`（方向對到哪一列、第四、五章能操作的人都有斜向圖、16 格都有人且腳底對齊）。

## 第三章抵達月台的 CG 重畫（2026-11-06，ChatGPT）
使用者回饋：倒掛的和平鴿很怪（飄在半空、臉不是鴿子面具，右邊又站一個和平鴿立繪）。
- 照劇本「車窗的上緣，倒掛著一張白色的臉」：和平鴿趴在左邊火車的車頂，白色鳥嘴面具從車窗上緣倒掛下來，白手套抓著車頂邊緣。其他（車掌、五個玩偶、月台）照舊。原圖 `chatgpt_art\c3_cg_arrival_v2.png` → `game/art/ch3/bg/ch3_bg_cg_arrival.jpg`（1280×720）。
- `dialogue.gd`：第三章的 CG（`c3_cg_*`）上不再疊立繪（以前只有第四、五章和一般 CG 有這條規則）。測試在 `human_art_test`。

## 地圖房間用 ChatGPT 重畫（2026-11-06 起，進行中）
使用者回饋：地圖很奇怪（Blender 算的俯視圖：空、柱子是深色長條、站名寫在地上、月台沒有火車）。使用者選擇：每個房間用 ChatGPT 重畫一張完整的背景，先做第三章。
1. `py -3.11 tools/art/room_guide.py chapter3 <房間> <輸出.png>`：用現有的背景＋家具合成「版型參考圖」（縮到寬 1536、上下補黑邊成 1536×1024），並印出家具、調查點、門在參考圖上的座標。
2. ChatGPT（對話「Repaint Room Map」）：附上參考圖＋風格參考（第三章抵達月台的 CG），要求同樣的鏡頭角度、每件家具同樣的位置大小、不寫字、不畫人、黑邊保持黑色。
3. `py -3.11 tools/art/room_repaint.py chapter3 <房間> <ChatGPT 原圖>`：切出房間那一條縮放成房間大小（`bg_paint.jpg`）；家具用舊家具圖的形狀從新背景切出來（`prop_paint_*.png`，角色走到後面一樣會被擋住）；`room.json` 加 `"painted": true`，舊的存成 `room.blender.json`（`--undo` 退回）。
4. 重畫過的房間不再把地上的字（站名等）畫出來，招牌畫在圖裡、沒有字。
| 房間 | 原圖 | 說明 |
|---|---|---|
| 第三章 platform 地下月台 | `chatgpt_art\rooms\paint_ch3_platform.png` | 上面一排是停著的夜車；空白的站名牌、時刻表；正常的磁磚柱子 |
| 第三章其他 21 間 | `chatgpt_art\rooms\paint_ch3_<房間>.png` | 一樓（大廳、候診室、走廊、診間、藥局）、二樓（走廊、涅槃計畫區、護理站、被服室、病歷室、理事室）、舊病棟（走廊、交誼廳、兒童病房、倉庫、盡頭）、地下二樓（走廊、置物間、病房、特別病房、監控室）。同一個 ChatGPT 對話「Repaint Room Map」接著畫；地下二樓走廊在新對話「Repaint Game Map」重畫（`_v4`） |

經驗（第五、四章照做）：
- 每次都附參考圖、寫「SAME 3:2 canvas, black bars black, trace the guide layout exactly」，並寫出牆只到哪裡（`room_prompt.py` 會算：「The back wall is ONLY a thin band…」），不然 ChatGPT 會把牆畫成半個房間高。
- 對位檢查：`room_repaint.py` 會存 `E:/rzw/check_<房間>.jpg`（紅框＝家具碰撞、藍圈＝調查點、綠框＝門）。藥局第一次架子畫錯邊、地下二樓走廊兩次東西往下滑，都是看這張圖發現的，重畫到對齊為止。
- ChatGPT 偶爾換畫布比例（例如 2:1），工具會改用「不是黑邊的範圍」切；畫布一樣是 3:2 時照參考圖座標切。
- 同一個對話裡重畫同一間，ChatGPT 容易沿用上一張的構圖；開新對話（附參考圖＋一張已經畫好的同區房間當風格參考）比較準。
- 已知小問題（之後再修）：大廳候診椅上多了一隻布偶兔子；有些房間 ChatGPT 自己畫了門，和遊戲畫的門位置不同。
| 第五章 19 間 | `chatgpt_art\rooms\paint_ch5_<房間>.png` | 玩偶世界的醫院（實驗室、走廊、檔案室、監視室、教官室、理事室、晚上的走廊）用第三章畫好的房間當風格參考；真實世界的醫院（病房、走廊、白線的另一邊、大廳、三床病房、很長的走廊、芬的病房）用人類時期 CG〈醒來〉當風格參考；校門口用 CG〈郵筒〉；棉花糖鎮（廣場、鎮長公館、修理室）用第一章的背景當參考，畫成褪色的樣子。ChatGPT 對話「Repaint Game Map」 |
- 第五章已知小問題：床的碰撞範圍是床頭那一段，ChatGPT 畫的床往下延伸，可以走到床尾上面一點；校門的柱子、郵筒碰撞稍微偏右。
- 2026-11-06 畫到修理室時 ChatGPT 出現「Unusual activity has been detected」，停了幾分鐘後恢復，月台補畫完成（第一章月台背景當參考，夜晚）。

## 希露飛（人類時期）使用者提供的圖（2026-11-06）
- CG02 鏡子碎片：換成使用者給的版本（原檔 `chatgpt_art\cg_h_cg02_mirror_user_v2.png`）→ `game/art/human/cg/h_cg02_mirror.jpg`（裁 16:9、2560×1440）。
- 走路圖：使用者給的 4×4（原檔 `chatgpt_art\walk_h_hilufei_user_v2.jpg`）方向混在一起，重新排成遊戲的順序後轉檔：下＝正面那幾格、左＝側面兩格輪流、右＝左的翻轉、上＝背面三格；斜向用 3/4 正面、3/4 背面那幾格（`h_hilufei_diag.png`）。每格上緣 30px 塗成底色，避免上一格的鞋子跑進來。
- 對話立繪沒有換（維持原本 6 張）。
- 2026-11-06 對話立繪 6 張換成使用者提供、已經調整過比例的版本（原檔 `chatgpt_art\portrait_h_hilufei_user_v3.jpg`，一張 6 格）。去背：從邊緣連通的底色＋夾在頭髮之間、靠兩側的小塊底色（不動中間的臉和手、白襯衫），再用 `fit_human_portrait.py` 轉 512×768。注意：「gown」兩張畫的是灰色毛衣，不是病人服。
| 第四章 13 間 | `chatgpt_art\rooms\paint_ch4_<房間>.png` | 學校（校門、玄關、一樓走廊、三年二班、教師辦公室、樓梯口、樓下、校長室）用第五章校門口和 CG〈自我介紹〉當風格參考，白天畫（遊戲裡會依時段調色）；薙文、希露飛的房間；很多年以前的醫院、白色的月台、慈愛組織的大病房（中間一條白線）。樓梯口只畫普通的走廊和關著的門。 |
- 第三、四、五章 54 間全部重畫完成（`walk8_test` 檢查每間都用重畫的圖）。
- 已知小問題（之後再修）：床的碰撞範圍和畫面上的床有時差一點（第五章床往下畫、第四章醫院床往上畫）；第三章大廳椅子上的布偶兔子；有些房間 ChatGPT 自己畫了門。
- 2026-11-06 修正：床的碰撞範圍對齊重畫的畫面（第五章 a_ward5、a_other5、b3_ward5、lab5，第四章 hospital4；`tools/art/fit_prop_rect.py`，記在 `tools/levels/prop_rect_fixes.json`，兩支關卡產生器會套用）；hospital4 兩個調查點往上移到床邊。第三章大廳椅子上的布偶兔子用旁邊空的座位蓋掉（原圖留在 `paint_ch3_lobby_with_bunny.png`）。
- 2026-11-06 CG01 自我介紹：照「棉花糖鎮的孩子沒有參與霸凌」重修，後排三個人改成低著頭、沒有笑（ChatGPT 改圖，原檔 `chatgpt_art\cg_h_cg01_speech_v2.png`）。

## 希露飛走路圖重畫、畢業生（2026-11-06，ChatGPT）
- 希露飛四方向＋斜向走路圖：使用者回饋「走路太奇怪」（舊圖腳幾乎不動、比例和其他同學不一樣）→ 用遙的走路圖當格式參考、希露飛的立繪當造型參考重畫。原圖 `chatgpt_art/walk_hilufei_v2.png`、`walk_hilufei_diag_v2.png`；`fit_walk_sheet.py`／`fit_diag_sheet.py` 之後再跑 `tools/art/remove_white_outline.py` 去掉貼紙白邊。舊圖留在 `chatgpt_art/h_hilufei_walk_old.png`、`h_hilufei_diag_old.png`。
- 畢業生（第三章）：照職員的毛氈玩偶畫法（成人比例、布料、臉不畫五官）。
  - 可以對話的＝被壓榨、聽話：燙平的病人服、縫上去的笑、額頭磨亮、駝背。走路圖 `walk4/graduate.png`，立繪 `ch2_graduate_portrait_default.png`。
  - 追人的＝神志不清、失控：破病人服、跑出棉花（不畫血）、長毛線頭髮蓋住臉、赤腳、手伸出來抓。走路圖 `walk4/graduate_wild.png`（關卡的 patrols 用這張），立繪 `ch2_graduate_portrait_wild.png`（`@face 畢業生 wild`）。
  - CG `ch3_bg_cg_graduates.jpg`：舊病棟走廊兩邊面壁的畢業生同時轉頭、中間病床睡著抱玩偶的人（`c3_wild_intro`）。
  - 原圖 `chatgpt_art/graduates_pair.png`、`walk_graduate.png`、`walk_graduate_wild.png`、`c3_cg_graduates.png`；舊的 Blender 走路圖留在 `graduate_walk_blender_old.png`。
