# 在自己的 Windows 電腦上做美術（顯示卡版）

目標電腦（使用者，2026-10-26）：Acer Predator PH317-55、Windows 11 家用版、i7-11800H、32GB 記憶體、**RTX 3070 Laptop 8GB**。
雲端的 Claude 工作階段沒有顯示卡（4 核 CPU），也連不到這台電腦；要用顯示卡，得在這台電腦上開 Claude。

| 工作 | 雲端（CPU） | 這台電腦（RTX 3070） |
|---|---|---|
| 出一張圖（SDXL＋畫風 LoRA） | 3～4 分鐘 | **約 4 秒**（實測；每次執行的第一張要多約 70 秒載入模型） |
| 重練畫風 LoRA | 2400 步、768 解析度、約 8 小時 | 3000 步、1024 解析度、**約 1 小時 25 分**（實測每步約 1.7 秒；開頭幾十步在快取資料，看起來比較慢） |
| Zero123++ 推算側面、背面 | 約 9 分鐘 | 約 20～40 秒（估計，還沒實測） |
| 3D（Blender） | 不能 | 可以：背景模式跑建模腳本（`tools/art/blender/`），或開 Blender 用 Blender MCP |

實測：2026-10-27，驅動 621.01、PyTorch 2.11（cu128，出圖）／2.6（cu124，訓練）。

## 1. 更新顯示卡驅動程式（一定要先做）
目前的驅動版本是 27.21.14.6262（＝ NVIDIA 462.62，2021 年），太舊，PyTorch 的 CUDA 12 用不了。
1. 裝「NVIDIA App」（nvidia.com/zh-tw/software/nvidia-app/）→ 驅動程式 → 下載最新的 **Studio** 或 Game Ready 驅動。
2. 裝完重開機。在 PowerShell 打 `nvidia-smi`，右上角的 Driver Version 要 **570 以上**。

## 2. 裝 Claude Code（讓 Claude 在這台電腦上工作）
在「開始」搜尋 PowerShell → 開啟，貼上：
```powershell
winget install --id Git.Git -e
irm https://claude.ai/install.ps1 | iex
```
關掉 PowerShell、重開一個，打 `claude --version` 確認裝好了。

## 3. 下載專案
```powershell
cd $env:USERPROFILE
git clone https://github.com/typeu910722-gife/rule-zero
cd rule-zero
git checkout claude/confident-bohr-fchdn2
```

## 4. 一鍵安裝美術環境
```powershell
powershell -ExecutionPolicy Bypass -File tools\art\windows\setup_windows.ps1 -Train -Views -Blender
```
- 會裝：Git、Python 3.11、uv、ComfyUI（出圖）、模型約 12GB、LoRA 訓練工具、Zero123++、Blender＋Blender MCP 外掛。
- 全部約 30GB，第一次要等一陣子（看網路速度）。
- 每一步失敗都會停下來，用紅字說是哪一步、怎麼處理。
- 最後照畫面上的三個步驟，在 Blender 裡啟用 Blender MCP（只要做一次）。

## 5. 讓雲端的對話接上這台電腦
在專案資料夾：
```powershell
claude
```
第一次會要登入（用同一個 Claude 帳號）。之後可以直接在這裡跟 Claude 說話；
或執行 `claude remote-control`，這個工作階段就會出現在手機／桌面的 Claude Code App 裡，從哪裡都能指揮。

## 6. 之後可以叫 Claude 做的事
- **重練畫風 LoRA**：`tools\art\windows\train_style_gpu.ps1`（1024 解析度、3000 步）。練完 Claude 會比較各步數、挑最好的放回 `tools\art\models\rzstyle.safetensors`（2026-10-27 第一次重練的結果比不上舊版，沒換；見 `docs/art_pipeline.md` 第 5 節）。
- **出圖**：`py -3.11 tools\art\gen.py …`（偵測到 NVIDIA 顯示卡會自動用顯示卡）。每次執行第一張約 70 秒（載入模型），同一次的後續每張約 4 秒；要一直快，先在另一個視窗開著 `tools\art\windows\comfy_server.ps1`，gen.py 會直接用它。
- **四方向走路圖**：`docs/art_pipeline.md` 第 7 節（Zero123++ 在顯示卡上快很多）。
- **3D**：Claude 直接在 Blender 裡建角色、場景，匯出 `.glb` 放進遊戲（第三章的 3D 追逐、第四、五章的 3D 段落可以換成正式模型）；四方向走路圖也可以從 3D 模型直接轉四個角度渲染，比推算更準（理事這種難做的角色先從這裡解決）。

## 注意
- 8GB 顯示記憶體：出圖、訓練（AdamW8bit、只練 UNet、快取 latent）都夠用。訓練如果出現 out of memory，改 `-Res 896`。
- 筆電請插電，電源模式選「最佳效能」；訓練時風扇會很大聲，正常。
- 模型、訓練輸出放在 `%USERPROFILE%\rz-art`，不進 Git；只有挑好的 LoRA（約 85MB）會放進專案。
