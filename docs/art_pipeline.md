# 美術自製流程（不外包）

2026-10-20 起，新角色、背景、CG、道具一律用本專案的出圖工具自己做（使用者決定）。
工具在 `tools/art/`，畫風 LoRA 用委託的原圖訓練，能叫出跟現有美術一致的畫風。

> **有 NVIDIA 顯示卡的 Windows 電腦**（快幾十倍、可以做 3D）：見 `docs/windows_gpu_setup.md`，一鍵安裝 `tools/art/windows/setup_windows.ps1`。`gen.py` 偵測到顯示卡會自動用。

## 1. 第一次使用（新的雲端工作階段）

```bash
tools/art/setup.sh            # 裝 ComfyUI＋模型＋本專案 LoRA 到 /tmp/rz-art（約 14GB，下載幾分鐘）
tools/art/setup.sh --train    # 要重新訓練 LoRA 時才需要
```

## 2. 出圖

```bash
python3 tools/art/gen.py <預設> --out <檔名> [--char 角色] [--prompt "英文描述"] [其他選項]
```

| 預設 | 畫風 | 用途 | 生成尺寸 |
|---|---|---|---|
| `portrait` | 布偶寫實 | 立繪（第二章風格），白底；加 `--cutout` 去背 | 832×1216 |
| `fullbody` | 布偶寫實 | 全身正面（三視圖風格） | 832×1216 |
| `flat` | 扁平插畫 | 第一章風格的全身立繪 | 832×1216 |
| `face` | 扁平插畫 | 第一章風格的表情頭像 | 1024² |
| `sprite` | 扁平插畫 | 地圖小人（之後縮成 192px 一格） | 1024² |
| `bg_town` | 童話小鎮 | 第一章場景 | 1344×768 |
| `bg_memory` | 人類世界回憶 | 夢境、回憶（寫實、低彩度） | 1344×768 |
| `bg_bleach` | 漂白鎮 | 第二章灰白毛線世界 | 1344×768 |
| `interior` | 娃娃屋 | 小屋室內 | 1344×768 |
| `cg` | 布偶寫實 | 事件 CG | 1344×768 |
| `item` | 布偶寫實 | 道具，白底 | 1024² |
| `free` | 不加 | 完全自己寫提示詞 | 1024² |

常用選項：
- `--char lulu --char bu`：帶入角色外觀（`tools/art/characters.json`）。Fen 會自動加上 Fen 的角色 LoRA。
- `--final 1280x720`：輸出前縮放＋裁切成遊戲用的尺寸。
- `--count 4`：換種子連出 4 張挑選。
- `--init 舊圖.png --denoise 0.5`：以舊圖為底重畫（改表情、換配色、補細節）。數字越大改越多。
- `--control 線稿.png --control-type lineart`：鎖定構圖（ControlNet）。也可用 `depth`、`pose`、`scribble`。
- `--ref 參考.jpg --ref-mode style`：參考某張圖的畫風（IP-Adapter）；`content` 參考內容。
- `--style memory`：換畫風標籤。`--style-strength 0.6`：畫風 LoRA 強度（預設 0.8）。

例：
```bash
# 第二章新角色立繪（先多出幾張挑）
python3 tools/art/gen.py portrait --prompt "new character, small grey mouse plush, torn ear, oversized school blazer" --count 4 --out mouse.png --cutout
# 漂白鎮的新場景
python3 tools/art/gen.py bg_bleach --prompt "empty library, tall shelves, dust in the light" --out ch2_bg_library.jpg --final 1280x720
# 事件 CG（兩個角色）
python3 tools/art/gen.py cg --char bu --char lulu --prompt "sitting together on the night train, looking out the window" --out cg.jpg --final 1280x720
# 依熱點位置畫好的線稿 → 室內（鏡之屋就是這樣做的）
python3 tools/art/gen.py interior --control layout_lines.png --ref game/art/int_lulu.jpg --prompt "..." --out int_x.jpg --final 1280x720
```

CPU 上每張約 3–6 分鐘（加了 ControlNet／IP-Adapter 會久一點）。每張圖都會重開一次 ComfyUI，避免記憶體不足。

## 3. 畫風標籤（訓練時用的觸發詞）

| 標籤 | 對應的委託原圖 |
|---|---|
| `rzstyle` | 全部（共通的觸發詞） |
| `rz_plush` | 角色設定圖、第二章立繪與 CG、標題的小布、驚嚇特寫、夜車 CG |
| `rz_flat` | 第一章表情圖、立繪、行走圖 |
| `rz_town` | 第一章小鎮場景、小屋室內 |
| `rz_memory` | 人類世界的回憶、醫院走廊（鉛筆素描） |
| `rz_bleach` | 第二章漂白鎮場景 |

`gen.py` 會依預設自動加上，平常不用自己寫。

## 4. 模型與授權（全部可商用）

| 項目 | 授權 |
|---|---|
| Stable Diffusion XL 1.0 base | CreativeML Open RAIL++-M |
| SDXL-Lightning 4 步 LoRA（ByteDance） | OpenRAIL++ |
| ControlNet union SDXL（xinsir） | Apache-2.0 |
| IP-Adapter SDXL＋ViT-H 影像編碼器（h94） | Apache-2.0 |
| ComfyUI、comfyui-ipadapter | GPL-3.0（工具本身；產出的圖不受 GPL 約束） |
| comfyui_controlnet_aux、kohya-ss/sd-scripts | Apache-2.0 |
| 本專案 LoRA（`tools/art/models/`） | 用本專案委託的原圖訓練，歸本專案 |

上架（Steam 等）要揭露使用 AI 生成內容。

## 5. 本專案的 LoRA

| 檔案 | 內容 | 訓練資料 |
|---|---|---|
| `tools/art/models/rzfen.safetensors` | Fen 角色 | Fen 的委託圖 21 張（`tools/art/train/make_fen_dataset.py`） |
| `tools/art/models/rzstyle.safetensors` | 全作畫風＋各角色 | 委託原圖 207 張（`tools/art/train/make_style_dataset.py`） |

`rzstyle.safetensors` 的訓練紀錄（2026-10-21 完成）：SDXL base、LoRA dim 16／alpha 8、只練 UNet、768 解析度、學習率 1e-4、共 2400 步（CPU，每步約 15 秒，存檔每 50 步、可以接著練）。
比較 0（不用）／1000／1500／2000／2400 步（同種子；`docs/lora_compare.png`）：不用 LoRA 時露露會變成綠頭髮的娃娃；1000 步起就是本作的布偶兔子；2400 步最穩定（布料、縫線、服裝最一致），背景沒有過度擬合，所以採用 2400 步。
用法：不用設定，`gen.py` 預設就會載入（強度 `--style-strength`，預設 0.8；要比較別的存檔可設環境變數 `RZ_STYLE_LORA`）。

自己生成的替代圖（`docs/art_generated.md` 列的那些）**不放進訓練資料**，以免越練越偏。

重新訓練或加新角色：
1. 改 `tools/art/train/make_style_dataset.py`（加圖、改說明文字），或新增一個角色的資料集腳本。
2. `python3 tools/art/train/make_style_dataset.py /tmp/rz-art/datasets/style`
3. `tools/art/train/train_lora.sh /tmp/rz-art/datasets/style /tmp/rz-art/out rzstyle 2400`
4. 用 `gen.py` 比較各步數的存檔，挑最好的複製到 `tools/art/models/`。

## 7. 四方向走路圖（2026-10-22）
只靠文字出圖做不出同一個角色的側面、背面（會把背面畫成正臉、配件跑掉），所以改用「從正面推算」：
1. 正面：有第二章原始立繪就直接用；沒有的先用 `gen.py free --no-style`（人類時期，寫實）出正面設計，人工確認合設定。
2. `tools/art/zero123_views.py 正面.png 輸出前綴`（Zero123++ v1.2，CPU 約 9 分鐘）：輸出 6 個角度，用 90°（側面、朝左）和 210°（背面）。
3. rembg（`isnet-general-use`）去背。
4. `python3 tools/art/make_walk_sheet.py 正面 側面 背面 輸出.png --match-color`（側面、背面的色調對齊正面）。
5. **逐格放大檢查**：往左那列朝左、往右那列朝右、背面沒有臉、配件和原設計一樣。不合格就重算（Zero123++ 每次結果不同）或換正面圖。
6. 放到 `game/art/walk4/<id>.png`。人類時期用 `h_<id>`。
模型：`sudo-ai/zero123plus-v1.2`（約 5.6GB，放 /tmp/claude-0/z123，不進 Git）。

**另一條路：Blender 3D 模型（2026-10-27，Windows 電腦）**——推算不出來、或左右不對稱的角色（例：理事肩上的老鷹）用這個，四個角度保證是同一個角色：
1. 寫建模腳本 `tools/art/blender/<id>.py`（範例：`director.py`，用基本形狀＋布料材質，照車掌、和平鴿的公仔質感）。
2. `blender --background --factory-startup --python tools/art/blender/<id>.py -- <輸出資料夾>`：輸出去背的 front／left／right／back.png 和 .blend（Cycles CPU，約 1 分鐘，不搶訓練中的顯示卡）。
3. `make_walk_sheet.py 正面 左 背面 輸出.png --right 右`：左右不對稱就一定要給 `--right`，不要用翻轉。
4. 一樣逐格檢查。

## 6. 注意

- 設定（`CLAUDE.md`）優先：人類時期的場景用人類本名；遙的隱藏設定只能用細節暗示；遊戲文字不出現歧視用語。
- 生成的圖要記在 `docs/art_generated.md`（檔名、用途、做法）。
- 小格子的行走圖（192px）是 SDXL 的弱項：先用 `sprite` 出大圖，再縮小、手修。
