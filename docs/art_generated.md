# 自行生成的替代美術

外包正式圖到位前的替代圖。全部是 AI 生成，**上架 Steam 需要揭露**（同第二章外包素材）。

| 檔案 | 用途 | 做法 |
|---|---|---|
| `game/art/ch2/characters/portraits/ch2_fen_portrait_a_default.png` | 第二章 Fen 立繪（預設：皺眉） | 白面立繪 `ch2_baimian_portrait_a_still.png` 依亮度換成 Fen 的配色 → ComfyUI img2img（強度 0.45）加上布偶質感與補丁 → 用白面的輪廓去背 |
| `game/art/ch2/characters/portraits/ch2_fen_portrait_a_away.png` | 第二章 Fen 立繪（看向別處；結尾火車 `@face Fen away`） | 同上，底圖 `ch2_baimian_portrait_a_faraway.png`（強度 0.42） |
| `game/art/ch2/characters/sprites/ch2_fen_sprite_stand_sheet.png` | 第二章河對岸的 Fen 地圖小人 | 白面站姿小人換色（沒有用 AI 重繪；**沒有尾巴**，因為底圖是白面） |
| `game/art/int_mirror.jpg` | 第一章鏡之屋室內（1280×720） | 依熱點位置畫的線稿（三面蓋布的鏡子改畫成「布垂下來」的形狀，避免變成門）→ ControlNet（union, lineart）鎖構圖＋ IP-Adapter（style transfer）參考 `int_lulu.jpg` 的畫風 → 縫死的鏡子手工補縫線 → 投信口的籃子、書桌上那疊很高的紙用局部重畫（inpaint）對齊劇本 |

另外修正：`game/art/walk_puppy.png` 第 2、3 列（朝左、朝右）的第三格朝向畫反了，兩格對調（原圖在 Git 歷史裡）。

設定依據：白面是從 Fen 身上剝離出來的那一半，兩隻狐狸是同一個身體（`docs/script/chapter2.md` 2.1），所以用白面的圖當底。

## 工具與授權
- ComfyUI 0.42（GPL-3.0；只用來產圖，產出的圖不受 GPL 約束）
- comfyui_controlnet_aux（Apache-2.0）、comfyui-ipadapter（Comfy Org 分支，GPL-3.0；同上，只是工具）
- 模型：Stable Diffusion XL 1.0 base（CreativeML Open RAIL++-M，可商用）＋ SDXL-Lightning 4 步 LoRA（ByteDance，OpenRAIL++，可商用）
- ControlNet：xinsir/controlnet-union-sdxl-1.0（promax，Apache-2.0）
- IP-Adapter：h94/IP-Adapter `ip-adapter-plus_sdxl_vit-h` ＋ ViT-H 影像編碼器（Apache-2.0）
- 在雲端 CPU 上執行（沒有 GPU），每張約 4 分鐘；SDXL＋ControlNet＋IP-Adapter 一起跑超過 15GB 記憶體，要把主模型存成 fp8 才跑得動

## 試過但不能用的
| 項目 | 結果 | 缺少的工具 |
|---|---|---|
| 第一章貓居民的走路圖（12 格） | 第一輪：img2img 耳朵一直是狗的垂耳。第二輪（有 ControlNet＋IP-Adapter）：小狗圖換色、手畫尖耳和長尾巴當底，逐列重畫——正面勉強像貓，但側面耳朵像角、筆觸髒，背面被 IP-Adapter 畫上了臉。達不到委託圖的品質，**沒有放進遊戲**（貓居民目前也不在地圖上） | 用委託的行走圖訓練的角色／畫風 LoRA（需要 GPU）；或請繪師畫。SDXL 在 192px 小格子上本來就弱 |
| 第一章鏡之屋室內（第一輪） | 蓋布的鏡子變成門、畫風不一致 | 已用 ControlNet＋IP-Adapter 解決（見上表） |
