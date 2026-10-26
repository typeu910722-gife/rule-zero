# 用顯示卡重練畫風 LoRA（rzstyle）：比雲端 CPU 版解析度高（1024）、步數多。
# RTX 3070 Laptop 8GB：實測每步約 4 秒 → 3000 步約 3 小時 20 分（2026-10-27；用約 6.6GB 顯示記憶體）。
# 先跑：tools\art\windows\setup_windows.ps1 -Train
# 用法：powershell -ExecutionPolicy Bypass -File tools\art\windows\train_style_gpu.ps1 [-Steps 3000] [-Res 1024] [-Dim 16]
# 成品：%USERPROFILE%\rz-art\out\rzstyle_gpu\（每 250 步存一次）。挑好的那一步複製成 tools\art\models\rzstyle.safetensors。
# 維度 16 ≈ 85MB（GitHub 單檔上限 100MB，所以不要超過 16）。
param([int]$Steps = 3000, [int]$Res = 1024, [int]$Dim = 16)
$ErrorActionPreference = "Continue"
$Root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Art = if ($env:ART_HOME) { $env:ART_HOME } else { Join-Path $env:USERPROFILE "rz-art" }
$TPy = "$Art\trainenv\Scripts\python.exe"
if (-not (Test-Path $TPy)) { Write-Host "先跑 setup_windows.ps1 -Train" -ForegroundColor Red; exit 1 }

Write-Host "== 整理訓練資料（只用委託的原圖）" -ForegroundColor Cyan
$env:ART_HOME = $Art
py -3.11 "$Root\tools\art\train\make_style_dataset.py" "$Art\datasets\style"
if ($LASTEXITCODE) { Write-Host "整理資料失敗" -ForegroundColor Red; exit 1 }

Write-Host "== 開始訓練（$Steps 步，$Res 解析度）" -ForegroundColor Cyan
$Out = "$Art\out\rzstyle_gpu"
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Push-Location "$Art\sd-scripts"
& $TPy sdxl_train_network.py `
  --pretrained_model_name_or_path "$Art\ComfyUI\models\checkpoints\sd_xl_base_1.0.safetensors" `
  --train_data_dir "$Art\datasets\style" --caption_extension .txt `
  --resolution "$Res,$Res" --enable_bucket --min_bucket_reso 512 --max_bucket_reso 1536 --bucket_reso_steps 64 `
  --network_module networks.lora --network_dim $Dim --network_alpha ([int]($Dim / 2)) `
  --network_train_unet_only --cache_text_encoder_outputs --cache_latents --cache_latents_to_disk `
  --learning_rate 1e-4 --optimizer_type AdamW8bit --lr_scheduler cosine --lr_warmup_steps 150 `
  --max_train_steps $Steps --train_batch_size 1 `
  --mixed_precision bf16 --full_bf16 --no_half_vae --save_precision fp16 `
  --gradient_checkpointing --sdpa `
  --save_every_n_steps 250 --output_dir $Out --output_name rzstyle_gpu --save_model_as safetensors `
  --max_data_loader_n_workers 2 --seed 42 --logging_dir "$Out\logs"
$code = $LASTEXITCODE
Pop-Location
if ($code) { Write-Host "訓練失敗（如果是顯示記憶體不夠，改用 -Res 896 再試）" -ForegroundColor Red; exit 1 }
Write-Host "完成：$Out" -ForegroundColor Green
Write-Host "比較各步數：在 Claude 裡說「比較 rzstyle_gpu 各步數」，或手動用 RZ_STYLE_LORA 環境變數指定檔名出圖。"
