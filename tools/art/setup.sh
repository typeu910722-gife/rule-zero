#!/usr/bin/env bash
# 安裝「第零條規則」的出圖環境（ComfyUI＋模型＋本專案訓練的 LoRA）。
# 新的雲端工作階段先跑一次，之後用 tools/art/gen.py 出圖。說明：docs/art_pipeline.md
#
# 用法：tools/art/setup.sh            （預設裝到 /tmp/rz-art，約 14GB）
#       ART_HOME=/某處 tools/art/setup.sh
#       tools/art/setup.sh --train    （另外安裝 LoRA 訓練工具 sd-scripts）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ART_HOME="${ART_HOME:-/tmp/rz-art}"
UV="${UV:-$(command -v uv || echo "$HOME/.local/bin/uv")}"
mkdir -p "$ART_HOME"
cd "$ART_HOME"

# 版本固定（2026-10-20 實際用過的版本）
COMFY_REV=e3bee7ffcb7d6547ed0bcd15221792f3b8646b17
CNAUX_REV=a587a4c1594524c1d2de5cd1a86cd868ff448e1c
IPA_REV=b188a6cb39b512a9c6da7235b880af42c78ccd0d
SDS_REV=04ca541746b7667b27eab230db067579f682895e

clone() {  # clone <網址> <資料夾> <commit>
  [ -d "$2/.git" ] || git clone -q "$1" "$2"
  git -C "$2" fetch -q --depth 1 origin "$3" 2>/dev/null || true
  git -C "$2" checkout -q "$3"
}

[ -x "$UV" ] || { curl -LsSf https://astral.sh/uv/install.sh | sh; UV="$HOME/.local/bin/uv"; }

echo "== ComfyUI 與節點"
clone https://github.com/Comfy-Org/ComfyUI ComfyUI $COMFY_REV
clone https://github.com/Fannovel16/comfyui_controlnet_aux ComfyUI/custom_nodes/comfyui_controlnet_aux $CNAUX_REV
clone https://github.com/comfyorg/comfyui-ipadapter ComfyUI/custom_nodes/comfyui-ipadapter $IPA_REV
if [ ! -x comfyenv/bin/python ]; then
  "$UV" venv -q --python 3.13 comfyenv
  "$UV" pip install -q --python comfyenv/bin/python torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
  "$UV" pip install -q --python comfyenv/bin/python -r ComfyUI/requirements.txt
  "$UV" pip install -q --python comfyenv/bin/python -r ComfyUI/custom_nodes/comfyui_controlnet_aux/requirements.txt || true
  "$UV" pip install -q --python comfyenv/bin/python pillow scipy opencv-python-headless
fi

echo "== 模型（Hugging Face，全部可商用：見 docs/art_pipeline.md）"
M=ComfyUI/models
get() {  # get <網址> <存檔>
  [ -s "$2" ] && return 0
  mkdir -p "$(dirname "$2")"
  curl -sSL --retry 4 -o "$2.part" "$1" && mv "$2.part" "$2"
  echo "  下載完成 $(basename "$2")"
}
HF=https://huggingface.co
get $HF/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors $M/checkpoints/sd_xl_base_1.0.safetensors
get $HF/ByteDance/SDXL-Lightning/resolve/main/sdxl_lightning_4step_lora.safetensors $M/loras/sdxl_lightning_4step_lora.safetensors
get $HF/xinsir/controlnet-union-sdxl-1.0/resolve/main/diffusion_pytorch_model_promax.safetensors $M/controlnet/xinsir_union_promax_sdxl.safetensors
get $HF/h94/IP-Adapter/resolve/main/sdxl_models/ip-adapter-plus_sdxl_vit-h.safetensors $M/ipadapter/ip-adapter-plus_sdxl_vit-h.safetensors
get $HF/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors $M/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors

echo "== 本專案的 LoRA（tools/art/models/）"
for f in "$ROOT"/tools/art/models/*.safetensors; do
  [ -e "$f" ] && ln -sf "$f" "$M/loras/$(basename "$f")" && echo "  $(basename "$f")"
done

if [ "${1:-}" = "--train" ]; then
  echo "== LoRA 訓練工具（kohya-ss/sd-scripts）"
  clone https://github.com/kohya-ss/sd-scripts sd-scripts $SDS_REV
  if [ ! -x trainenv/bin/python ]; then
    "$UV" venv -q --python 3.11 trainenv
    "$UV" pip install -q --python trainenv/bin/python torch torchvision --index-url https://download.pytorch.org/whl/cpu
    grep -v "bitsandbytes\|^-e" sd-scripts/requirements.txt > /tmp/rz-train-req.txt
    (cd sd-scripts && "$UV" pip install -q --python ../trainenv/bin/python -r /tmp/rz-train-req.txt -e .)
  fi
fi
echo "完成：$ART_HOME（出圖：python3 tools/art/gen.py --help）"
