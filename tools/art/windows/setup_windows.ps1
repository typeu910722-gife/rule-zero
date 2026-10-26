# 《第零條規則》美術環境：Windows＋NVIDIA 顯示卡版（RTX 3070 Laptop 8GB 測試目標）
# 說明：docs/windows_gpu_setup.md
#
# 用法（在專案資料夾，用 PowerShell 執行）：
#   powershell -ExecutionPolicy Bypass -File tools\art\windows\setup_windows.ps1            # 出圖環境（ComfyUI＋模型＋本專案 LoRA）
#   powershell -ExecutionPolicy Bypass -File tools\art\windows\setup_windows.ps1 -Train     # 另外裝 LoRA 訓練工具
#   powershell -ExecutionPolicy Bypass -File tools\art\windows\setup_windows.ps1 -Views     # 另外裝 Zero123++（四方向走路圖用）
#   powershell -ExecutionPolicy Bypass -File tools\art\windows\setup_windows.ps1 -Blender   # 另外裝 Blender＋Blender MCP（3D）
#   全部：加上 -Train -Views -Blender
# 預設裝在 %USERPROFILE%\rz-art（約 20GB；加 -Train -Views 約 30GB）。
param([switch]$Train, [switch]$Views, [switch]$Blender)
$ErrorActionPreference = "Continue"   # 外部程式（git、uv）會把進度寫到 stderr；錯誤一律看 $LASTEXITCODE
$Root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Art = if ($env:ART_HOME) { $env:ART_HOME } else { Join-Path $env:USERPROFILE "rz-art" }
New-Item -ItemType Directory -Force -Path $Art | Out-Null
Set-Location $Art

function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Fail($t) { Write-Host "失敗：$t" -ForegroundColor Red; exit 1 }
function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

# 版本固定（和雲端實際用過的一樣）
$COMFY_REV = "e3bee7ffcb7d6547ed0bcd15221792f3b8646b17"
$CNAUX_REV = "a587a4c1594524c1d2de5cd1a86cd868ff448e1c"
$SDS_REV   = "04ca541746b7667b27eab230db067579f682895e"

Step "檢查顯示卡與驅動程式"
if (-not (Have "nvidia-smi")) { Fail "找不到 nvidia-smi。請先安裝 NVIDIA 最新驅動程式（NVIDIA App 或 nvidia.com/drivers）。" }
$drv = (& nvidia-smi --query-gpu=driver_version,name,memory.total --format=csv,noheader) -split ","
Write-Host ("顯示卡：{0}　顯示記憶體：{1}　驅動：{2}" -f $drv[1].Trim(), $drv[2].Trim(), $drv[0].Trim())
if ([double]($drv[0].Trim().Split(".")[0]) -lt 551) {
  Fail ("驅動程式版本 {0} 太舊（需要 551 以上才能用 CUDA 12.4）。請先用 NVIDIA App 更新驅動，重開機後再跑一次。" -f $drv[0].Trim())
}

Step "安裝基本工具（Git、Python 3.11、uv）"
if (-not (Have "git")) { winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements }
if (-not (Have "py")) { winget install --id Python.Python.3.11 -e --silent --accept-package-agreements --accept-source-agreements }
if (-not (Have "uv")) { winget install --id astral-sh.uv -e --silent --accept-package-agreements --accept-source-agreements }
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
foreach ($c in "git", "uv") { if (-not (Have $c)) { Fail "$c 裝好了但還找不到。請關掉這個視窗、開一個新的 PowerShell 再跑一次。" } }

function Clone($url, $dir, $rev) {
  if (-not (Test-Path "$dir\.git")) { git clone -q $url $dir; if ($LASTEXITCODE) { Fail "下載 $url" } }
  git -C $dir fetch -q --depth 1 origin $rev 2>$null
  git -C $dir checkout -q $rev; if ($LASTEXITCODE) { Fail "切換 $dir 到 $rev" }
}
$Torch = "--index-url", "https://download.pytorch.org/whl/cu124"

Step "ComfyUI（出圖引擎）"
Clone "https://github.com/Comfy-Org/ComfyUI" "ComfyUI" $COMFY_REV
Clone "https://github.com/Fannovel16/comfyui_controlnet_aux" "ComfyUI\custom_nodes\comfyui_controlnet_aux" $CNAUX_REV
$Py = "$Art\comfyenv\Scripts\python.exe"
if (-not (Test-Path $Py)) {
  uv venv -q --python 3.11 comfyenv
  uv pip install -q --python $Py torch torchvision torchaudio @Torch
  uv pip install -q --python $Py -r ComfyUI\requirements.txt
  uv pip install -q --python $Py -r ComfyUI\custom_nodes\comfyui_controlnet_aux\requirements.txt
  uv pip install -q --python $Py pillow scipy opencv-python-headless
}
& $Py -c "import torch,sys; ok=torch.cuda.is_available(); print('CUDA 可用：', ok, torch.cuda.get_device_name(0) if ok else ''); sys.exit(0 if ok else 1)"
if ($LASTEXITCODE) { Fail "PyTorch 看不到顯示卡（多半是驅動太舊）。更新驅動後重開機再跑。" }

Step "出圖工具用的 Python 套件（去背 rembg 等）"
py -3.11 -m pip install -q --user scipy numpy pillow "rembg[cpu]"

Step "模型（Hugging Face，約 12GB，第一次要等一陣子）"
$M = "ComfyUI\models"
function Get-File($url, $dst) {
  if ((Test-Path $dst) -and ((Get-Item $dst).Length -gt 0)) { return }
  New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
  curl.exe -sSL --retry 4 -o "$dst.part" $url
  if ($LASTEXITCODE) { Fail "下載 $url" }
  Move-Item -Force "$dst.part" $dst
  Write-Host ("  下載完成 " + (Split-Path $dst -Leaf))
}
$HF = "https://huggingface.co"
Get-File "$HF/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" "$M\checkpoints\sd_xl_base_1.0.safetensors"
Get-File "$HF/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_lora.safetensors" "$M\loras\sdxl_lightning_4step_lora.safetensors"
Get-File "$HF/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors" "$M\controlnet\xinsir_union_promax_sdxl.safetensors"

Step "本專案的 LoRA（tools\art\models\）"
Get-ChildItem "$Root\tools\art\models\*.safetensors" | ForEach-Object {
  Copy-Item -Force $_.FullName "$M\loras\$($_.Name)"; Write-Host "  $($_.Name)"
}

if ($Train) {
  Step "LoRA 訓練工具（kohya-ss/sd-scripts）"
  Clone "https://github.com/kohya-ss/sd-scripts" "sd-scripts" $SDS_REV
  $TPy = "$Art\trainenv\Scripts\python.exe"
  if (-not (Test-Path $TPy)) {
    uv venv -q --python 3.11 trainenv
    uv pip install -q --python $TPy torch torchvision @Torch
    Push-Location sd-scripts
    (Get-Content requirements.txt) | Where-Object { $_ -notmatch "^-e" } | Set-Content "$Art\train-req.txt"
    uv pip install -q --python $TPy -r "$Art\train-req.txt" bitsandbytes
    uv pip install -q --python $TPy -e .
    Pop-Location
  }
}

if ($Views) {
  Step "Zero123++（從正面推算側面、背面；約 5.6GB）"
  uv pip install -q --python $Py diffusers "rembg[cpu]"
  & $Py -c "from huggingface_hub import snapshot_download as s; s('sudo-ai/zero123plus-v1.2', local_dir=r'$Art\z123\model'); s('sudo-ai/zero123plus-pipeline', local_dir=r'$Art\z123\pipeline')"
  if ($LASTEXITCODE) { Fail "下載 Zero123++" }
}

if ($Blender) {
  Step "Blender＋Blender MCP（讓 Claude 直接在 Blender 裡做 3D）"
  if (-not (Test-Path "$env:ProgramFiles\Blender Foundation")) {
    winget install --id BlenderFoundation.Blender -e --silent --accept-package-agreements --accept-source-agreements
  }
  curl.exe -sSL -o "$Art\blender_mcp_addon.py" "https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py"
  if ($LASTEXITCODE) { Fail "下載 Blender MCP 外掛" }
  Write-Host "  外掛檔：$Art\blender_mcp_addon.py"
  Write-Host "  接下來（只要做一次）："
  Write-Host "   1. 開 Blender → Edit → Preferences → Add-ons → 右上角 ▼ → Install from Disk → 選上面那個檔 → 打勾啟用"
  Write-Host "   2. Blender 畫面按 N → 右邊 BlenderMCP 分頁 → Connect to Claude"
  Write-Host "   3. 在專案資料夾執行：claude mcp add blender -- uvx blender-mcp"
}

Write-Host ""
Write-Host "完成：$Art" -ForegroundColor Green
Write-Host "試出一張圖：py -3.11 tools\art\gen.py portrait --char lulu --out test.png"
