#!/usr/bin/env bash
# 畫風 LoRA：從最新的存檔接著練（工作階段重啟後重跑這支就好）。目標總步數 2400。
set -e
CK=/tmp/claude-0/lora/style_ckpt
last=$(ls $CK/rzstyle-total*.safetensors | sort | tail -1)
done_steps=$(basename $last .safetensors | sed 's/rzstyle-total0*//')
left=$((2400 - done_steps))
[ $left -le 0 ] && { echo "已完成 $done_steps 步"; exit 0; }
OUT=/tmp/claude-0/lora/style_seg; rm -rf $OUT; mkdir -p $OUT
echo "從 $done_steps 步接著練，剩 $left 步" > /tmp/claude-0/lora/resume.log
cd /tmp/rz-art/sd-scripts
/tmp/rz-art/trainenv/bin/python sdxl_train_network.py --pretrained_model_name_or_path /tmp/rz-art/ComfyUI/models/checkpoints/sd_xl_base_1.0.safetensors --train_data_dir /tmp/claude-0/lora/style/img --caption_extension .txt --resolution 768,768 --enable_bucket --min_bucket_reso 448 --max_bucket_reso 1024 --bucket_reso_steps 64 --network_module networks.lora --network_dim 16 --network_alpha 8 --network_weights $last --network_train_unet_only --cache_text_encoder_outputs --cache_latents --cache_latents_to_disk --learning_rate 1e-4 --optimizer_type AdamW --lr_scheduler constant --max_train_steps $left --train_batch_size 1 --mixed_precision bf16 --full_bf16 --no_half_vae --save_precision fp16 --gradient_checkpointing --sdpa --save_every_n_steps 50 --output_dir $OUT --output_name seg --save_model_as safetensors --max_data_loader_n_workers 0 --seed $((42 + done_steps)) >> /tmp/claude-0/lora/resume.log 2>&1 &
TP=$!
# 每存一個段落檔，就換算成總步數搬到 style_ckpt
while kill -0 $TP 2>/dev/null; do
  for f in $OUT/seg-step*.safetensors; do
    [ -e "$f" ] || continue
    s=$(basename $f .safetensors | sed 's/seg-step0*//')
    mv "$f" $CK/rzstyle-total$(printf %05d $((done_steps + s))).safetensors
  done
  sleep 20
done
[ -f $OUT/seg.safetensors ] && mv $OUT/seg.safetensors $CK/rzstyle-total02400.safetensors
echo "結束" >> /tmp/claude-0/lora/resume.log
