# 開著 ComfyUI，讓 gen.py 每張圖不用重新載入模型（第一張約 1 分鐘，之後每張幾秒）。
# 用法：powershell -ExecutionPolicy Bypass -File tools\art\windows\comfy_server.ps1
# 要關掉：在這個視窗按 Ctrl+C。瀏覽器開 http://127.0.0.1:8188 也能直接用 ComfyUI 介面。
$Art = if ($env:ART_HOME) { $env:ART_HOME } else { Join-Path $env:USERPROFILE "rz-art" }
$Port = if ($env:COMFY_PORT) { $env:COMFY_PORT } else { "8188" }
Set-Location "$Art\ComfyUI"
& "$Art\comfyenv\Scripts\python.exe" main.py --listen 127.0.0.1 --port $Port --disable-auto-launch
