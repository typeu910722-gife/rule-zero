"""Zero123++：一張正面 → 同一個角色 6 個角度（方位角 30、90、150、210、270、330 度）。
用法：python run.py 輸入.png 輸出前綴 [步數]"""
import os, sys, torch
from PIL import Image
from diffusers import DiffusionPipeline, EulerAncestralDiscreteScheduler
src, out = sys.argv[1], sys.argv[2]
steps = int(sys.argv[3]) if len(sys.argv) > 3 else 28
# 模型位置：Z123_HOME（預設 ART_HOME/z123）；裡面要有 model/ 和 pipeline/（見 docs/art_pipeline.md 第 7 節）
H = os.environ.get("Z123_HOME") or os.path.join(os.environ.get("ART_HOME", os.path.expanduser("~/rz-art") if os.name == "nt" else "/tmp/claude-0"), "z123")
gpu = torch.cuda.is_available()
torch.set_num_threads(os.cpu_count() or 4)
pipe = DiffusionPipeline.from_pretrained(os.path.join(H, "model"), custom_pipeline=os.path.join(H, "pipeline"),
                                         torch_dtype=torch.float16 if gpu else torch.float32, trust_remote_code=True)
if gpu:
    pipe.to("cuda")
pipe.scheduler = EulerAncestralDiscreteScheduler.from_config(pipe.scheduler.config, timestep_spacing="trailing")
im = Image.open(src).convert("RGBA")
# 置中放進正方形、灰底（Zero123++ 要的格式）
bb = im.getchannel("A").getbbox(); im = im.crop(bb)
side = int(max(im.size) * 1.15)
sq = Image.new("RGBA", (side, side), (128, 128, 128, 255))
sq.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
sq = sq.convert("RGB").resize((320, 320), Image.LANCZOS)
res = pipe(sq, num_inference_steps=steps).images[0]
res.save(out + "_grid.png")
W, H = res.size; cw, ch = W // 2, H // 3
for i in range(6):
    r, c = divmod(i, 2)
    res.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)).save(f"{out}_{[30,90,150,210,270,330][i]}.png")
print("完成", out, res.size)
