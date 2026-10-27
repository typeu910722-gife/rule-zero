# 一次渲染一章（或指定幾間）的地圖房間美術，放進 game/art/rooms/<關卡>/<房間>/
# 用法：powershell -File tools\art\blender\render_rooms.ps1 chapter3 [房間 id ...] [-Samples 64]
param([Parameter(Mandatory)][string]$Level, [string[]]$Rooms, [int]$Samples = 64)
$Root = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$Blender = if ($env:BLENDER) { $env:BLENDER } else { "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" }
$Json = "$Root\game\levels\$Level.json"
$Tmp = if ($env:ART_HOME) { "$env:ART_HOME\rooms\$Level" } else { "$env:USERPROFILE\rz-art\rooms\$Level" }
if (-not $Rooms) { $Rooms = py -3.11 -c "import json,sys;print('\n'.join(json.load(open(sys.argv[1],encoding='utf-8'))['rooms']))" $Json }
foreach ($r in $Rooms) {
  $t = Get-Date
  & $Blender --background --factory-startup --python "$PSScriptRoot\room.py" -- $Json $r $Tmp $Samples *> "$Tmp-$r.log"
  $dst = "$Root\game\art\rooms\$Level\$r"
  if (Test-Path "$Tmp\$r\room.json") {
    New-Item -ItemType Directory -Force $dst | Out-Null
    Copy-Item "$Tmp\$r\*.png", "$Tmp\$r\*.jpg", "$Tmp\$r\room.json" $dst -Force
    Write-Output ("{0,-16} ok  {1:N0}s" -f $r, ((Get-Date) - $t).TotalSeconds)
  } else {
    Write-Output ("{0,-16} 失敗（看 $Tmp-$r.log）" -f $r)
  }
}
Write-Output "ALLDONE"
