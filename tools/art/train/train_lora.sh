#!/usr/bin/env bash
# 訓練 SDXL LoRA（CPU 也可以，約 13 秒一步；有 GPU 會快幾十倍）
# 用法：train_lora.sh <資料集資料夾（裡面是 N_名字/ 子資料夾）> <輸出資料夾> <LoRA 名字> <步數> [維度=16（約 85MB；GitHub 單檔上限 100MB）] [解析度=768]
# 例：  python3 tools/art/train/make_style_dataset.py /tmp/rz-art/datasets/style
#       tools/art/train/train_lora.sh /tmp/rz-art/datasets/style /tmp/rz-art/out rzstyle 2400
# 訓練完把要用的那一步複製到 tools/art/models/<名字>.safetensors（fp16，約 40–90MB）。
set -euo pipefail
ART_HOME="${ART_HOME:-/tmp/rz-art}"
DATA=$1; OUT=$2; NAME=$3; STEPS=$4; DIM=${5:-16}; RES=${6:-768}
mkdir -p "$OUT"
cd "$ART_HOME/sd-scripts"
exec "$ART_HOME/trainenv/bin/python" sdxl_train_network.py \
  --pretrained_model_name_or_path "$ART_HOME/ComfyUI/models/checkpoints/sd_xl_base_1.0.safetensors" \
  --train_data_dir "$DATA" --caption_extension .txt \
  --resolution $RES,$RES --enable_bucket --min_bucket_reso 448 --max_bucket_reso 1024 --bucket_reso_steps 64 \
  --network_module networks.lora --network_dim $DIM --network_alpha $((DIM / 2)) \
  --network_train_unet_only --cache_text_encoder_outputs --cache_latents \
  --learning_rate 1e-4 --optimizer_type AdamW --lr_scheduler cosine --lr_warmup_steps 100 \
  --max_train_steps $STEPS --train_batch_size 1 \
  --mixed_precision bf16 --full_bf16 --no_half_vae --save_precision fp16 \
  --gradient_checkpointing --sdpa \
  --save_every_n_steps 400 --output_dir "$OUT" --output_name "$NAME" --save_model_as safetensors \
  --max_data_loader_n_workers 0 --seed 42 --logging_dir "$OUT/logs"
