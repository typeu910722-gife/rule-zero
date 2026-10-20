#!/usr/bin/env python3
"""《第零條規則》出圖工具：ComfyUI（SDXL＋本專案畫風 LoRA）。說明：docs/art_pipeline.md

例：
  python3 tools/art/gen.py portrait --char lulu --prompt "holding a letter, worried" --out lulu_letter.png --cutout
  python3 tools/art/gen.py bg_bleach --prompt "empty school library, rows of shelves" --out library.jpg --final 1280x720
  python3 tools/art/gen.py cg --char bu --char fen --prompt "sitting on the train roof at night" --out cg.jpg --final 1280x720
  python3 tools/art/gen.py portrait --char fen --init old.png --denoise 0.5 --out new.png      （以舊圖為底重畫）
  python3 tools/art/gen.py free --prompt "..." --control layout.png --control-type lineart --ref int_lulu.jpg --ref-mode style

需要先跑 tools/art/setup.sh。每張圖都會啟動一個新的 ComfyUI（CPU、記憶體 15GB 時連續出圖會被系統終止）。
"""
import argparse, json, os, shutil, subprocess, sys, time, urllib.request, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
ART_HOME = Path(os.environ.get("ART_HOME", "/tmp/rz-art"))
COMFY = Path(os.environ.get("COMFY_DIR", ART_HOME / "ComfyUI"))
PY = os.environ.get("COMFY_PY", str(ART_HOME / "comfyenv/bin/python"))
PORT = int(os.environ.get("COMFY_PORT", "8188"))
HOST = f"http://127.0.0.1:{PORT}"
STYLE_LORA = os.environ.get("RZ_STYLE_LORA", "rzstyle.safetensors")

STYLE = {
    "plush": "rz_plush, plush toy photography, felt and fur texture, visible stitched seams, soft cinematic lighting",
    "flat": "rz_flat, flat cel illustration, thick dark brown outline, soft pastel colors, simple shading",
    "town": "rz_town, storybook painted background, cotton candy town, pastel fairy tale",
    "memory": "rz_memory, human world memory scene, photorealistic, muted colors, melancholy",
    "bleach": "rz_bleach, bleach town, desaturated grey and white knitted felt world, cold light",
}
# 預設：畫風、構圖詞、尺寸
PRESETS = {
    "portrait":  ("plush", "character portrait, upper body, plain white background", (832, 1216)),
    "fullbody":  ("plush", "character turnaround, full body, plain background, front view", (832, 1216)),
    "flat":      ("flat", "full body standing, plain white background", (832, 1216)),
    "face":      ("flat", "bust portrait, plain white background", (1024, 1024)),
    "sprite":    ("flat", "chibi map sprite, full body, plain white background", (1024, 1024)),
    "bg_town":   ("town", "scene", (1344, 768)),
    "bg_memory": ("memory", "scene", (1344, 768)),
    "bg_bleach": ("bleach", "background, no characters", (1344, 768)),
    "interior":  ("town", "dollhouse room interior, miniature diorama", (1344, 768)),
    "cg":        ("plush", "cinematic event scene", (1344, 768)),
    "item":      ("plush", "single object, prop, plain white background", (1024, 1024)),
    "free":      (None, "", (1024, 1024)),
}
NEG = "blurry, lowres, deformed, extra limbs, extra fingers, text, watermark, logo, signature, jpeg artifacts"
CN_TYPES = {"lineart": "canny/lineart/anime_lineart/mlsd", "canny": "canny/lineart/anime_lineart/mlsd",
            "depth": "depth", "pose": "openpose", "scribble": "hed/pidi/scribble/ted", "tile": "tile"}


def chars():
    return json.load(open(ROOT / "tools/art/characters.json", encoding="utf-8"))


def loras_available():
    d = COMFY / "models/loras"
    return {p.name for p in d.iterdir()} if d.exists() else set()


def build(a):
    style, comp, size = PRESETS[a.preset]
    style = a.style or style
    C = chars()
    parts = ["rzstyle"] if style else []
    if style: parts.append(STYLE[style])
    if comp: parts.append(comp)
    extra_loras = []
    for k in a.char or []:
        if k not in C: sys.exit(f"不認得的角色：{k}（tools/art/characters.json）")
        parts.append(C[k]["外觀"])
        if C[k].get("lora") and not a.no_char_lora:
            extra_loras.append((C[k]["lora"] + ".safetensors", a.char_lora_strength))
    if a.prompt: parts.append(a.prompt)
    prompt = ", ".join(parts)
    w, h = (int(x) for x in a.size.split("x")) if a.size else size

    have = loras_available()
    loras = [("sdxl_lightning_4step_lora.safetensors", 1.0)]
    if not a.no_style and STYLE_LORA in have: loras.append((STYLE_LORA, a.style_strength))
    elif not a.no_style: print(f"（沒有畫風 LoRA {STYLE_LORA}，只用提示詞）")
    for name, s in extra_loras:
        if name in have: loras.append((name, s))
        else: print(f"（沒有角色 LoRA {name}）")

    g = {"1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"}}}
    model, clip = ["1", 0], ["1", 1]
    for i, (name, s) in enumerate(loras):
        nid = f"L{i}"
        g[nid] = {"class_type": "LoraLoader", "inputs": {"model": model, "clip": clip, "lora_name": name,
                                                         "strength_model": s, "strength_clip": s}}
        model, clip = [nid, 0], [nid, 1]
    g["3"] = {"class_type": "CLIPTextEncode", "inputs": {"clip": clip, "text": prompt}}
    g["4"] = {"class_type": "CLIPTextEncode", "inputs": {"clip": clip, "text": NEG + (", " + a.neg if a.neg else "")}}
    pos, neg = ["3", 0], ["4", 0]

    def put(path):
        n = "rz_%s%s" % (uuid.uuid4().hex[:8], Path(path).suffix or ".png")
        (COMFY / "input").mkdir(exist_ok=True)
        shutil.copy(path, COMFY / "input" / n)
        return n

    if a.ref:
        g["20"] = {"class_type": "IPAdapterModelLoader", "inputs": {"ipadapter_file": "ip-adapter-plus_sdxl_vit-h.safetensors"}}
        g["21"] = {"class_type": "CLIPVisionLoader", "inputs": {"clip_name": "CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors"}}
        g["22"] = {"class_type": "LoadImage", "inputs": {"image": put(a.ref)}}
        g["23"] = {"class_type": "IPAdapterAdvanced", "inputs": {"model": model, "ipadapter": ["20", 0], "image": ["22", 0], "clip_vision": ["21", 0],
                   "weight": a.ref_weight, "weight_type": "style transfer" if a.ref_mode == "style" else "linear",
                   "combine_embeds": "concat", "start_at": 0.0, "end_at": 1.0, "embeds_scaling": "V only"}}
        model = ["23", 0]
    if a.control:
        g["30"] = {"class_type": "ControlNetLoader", "inputs": {"control_net_name": "xinsir_union_promax_sdxl.safetensors"}}
        g["31"] = {"class_type": "SetUnionControlNetType", "inputs": {"control_net": ["30", 0], "type": CN_TYPES[a.control_type]}}
        g["32"] = {"class_type": "LoadImage", "inputs": {"image": put(a.control)}}
        g["33"] = {"class_type": "ControlNetApplyAdvanced", "inputs": {"positive": pos, "negative": neg, "control_net": ["31", 0], "image": ["32", 0],
                   "strength": a.control_strength, "start_percent": 0.0, "end_percent": a.control_end, "vae": ["1", 2]}}
        pos, neg = ["33", 0], ["33", 1]
    if a.init:
        g["5"] = {"class_type": "LoadImage", "inputs": {"image": put(a.init)}}
        g["5s"] = {"class_type": "ImageScale", "inputs": {"image": ["5", 0], "upscale_method": "lanczos", "width": w, "height": h, "crop": "center"}}
        g["6"] = {"class_type": "VAEEncode", "inputs": {"pixels": ["5s", 0], "vae": ["1", 2]}}
        steps, den = 6, a.denoise
    else:
        g["6"] = {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}}
        steps, den = 4, 1.0
    g["7"] = {"class_type": "KSampler", "inputs": {"model": model, "positive": pos, "negative": neg, "latent_image": ["6", 0],
              "seed": a.seed, "steps": a.steps or steps, "cfg": 1.0, "sampler_name": "euler", "scheduler": "sgm_uniform", "denoise": den}}
    g["8"] = {"class_type": "VAEDecodeTiled", "inputs": {"samples": ["7", 0], "vae": ["1", 2], "tile_size": 512, "overlap": 64,
              "temporal_size": 64, "temporal_overlap": 8}}
    g["9"] = {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "rz"}}
    heavy = bool(a.ref or a.control)
    return g, prompt, heavy


def start_server(heavy):
    if not Path(PY).exists() or not COMFY.exists():
        sys.exit(f"找不到 ComfyUI（{COMFY}）。先跑 tools/art/setup.sh")
    unet = "--fp8_e4m3fn-unet" if heavy else "--bf16-unet"   # 加了 ControlNet／IP-Adapter 時主模型改 fp8 才不會爆記憶體
    log = open(ART_HOME / "comfy.log", "w") if ART_HOME.exists() else open("/tmp/rz-comfy.log", "w")
    p = subprocess.Popen([PY, "main.py", "--cpu", "--listen", "127.0.0.1", "--port", str(PORT), unet, "--bf16-vae",
                          "--fp16-text-enc", "--disable-auto-launch", "--cache-none"], cwd=COMFY, stdout=log, stderr=subprocess.STDOUT)
    for _ in range(200):
        if p.poll() is not None: sys.exit("ComfyUI 啟動失敗，看 " + log.name)
        try:
            urllib.request.urlopen(HOST + "/system_stats", timeout=2); return p
        except Exception: time.sleep(2)
    p.kill(); sys.exit("ComfyUI 啟動逾時")


def run(graph, out):
    req = urllib.request.Request(HOST + "/prompt", data=json.dumps({"prompt": graph, "client_id": str(uuid.uuid4())}).encode(),
                                 headers={"Content-Type": "application/json"})
    pid = json.loads(urllib.request.urlopen(req).read())["prompt_id"]
    while True:
        h = json.loads(urllib.request.urlopen(HOST + "/history/" + pid).read())
        if pid in h:
            st = h[pid].get("status", {})
            if st.get("status_str") == "error":
                sys.exit("出圖失敗：" + json.dumps(st, ensure_ascii=False)[:1500])
            for node in h[pid]["outputs"].values():
                for img in node.get("images", []):
                    src = COMFY / "output" / img.get("subfolder", "") / img["filename"]
                    shutil.move(str(src), out); return
        time.sleep(2)


def post(path, a):
    from PIL import Image
    im = Image.open(path)
    if a.cutout:
        im = cutout(im.convert("RGB"))
    if a.final:
        fw, fh = (int(x) for x in a.final.split("x"))
        s = max(fw / im.width, fh / im.height)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        l, t = (im.width - fw) // 2, (im.height - fh) // 2
        im = im.crop((l, t, l + fw, t + fh))
    if path.lower().endswith((".jpg", ".jpeg")):
        im.convert("RGB").save(path, quality=90)
    else:
        im.save(path)


def cutout(im, tol=28):
    """白底去背：從四邊往內找接近背景色的區域，邊緣羽化。"""
    import numpy as np
    from PIL import Image, ImageFilter
    from scipy import ndimage
    a = np.asarray(im).astype(int)
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    near = np.sqrt(((a - bg) ** 2).sum(-1)) < tol
    lab, _ = ndimage.label(near)
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    mask = ~np.isin(lab, list(border))
    mask = ndimage.binary_fill_holes(mask)
    al = Image.fromarray((mask * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1.2))
    out = im.convert("RGBA"); out.putalpha(al)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("preset", choices=PRESETS)
    ap.add_argument("--out", required=True, help="輸出檔（.png／.jpg）；--count>1 時自動加 _1、_2…")
    ap.add_argument("--char", action="append", help="角色代號（可多個）：見 tools/art/characters.json")
    ap.add_argument("--prompt", default="", help="額外描述（英文效果最好）")
    ap.add_argument("--neg", default="", help="額外的負面提示")
    ap.add_argument("--style", choices=STYLE, help="改用別的畫風標籤")
    ap.add_argument("--size", help="生成尺寸，例 1344x768（SDXL 建議約 100 萬像素）")
    ap.add_argument("--final", help="輸出前縮放＋置中裁切，例 1280x720")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--count", type=int, default=1, help="換種子連出幾張")
    ap.add_argument("--steps", type=int)
    ap.add_argument("--style-strength", type=float, default=0.8)
    ap.add_argument("--no-style", action="store_true", help="不用畫風 LoRA")
    ap.add_argument("--char-lora-strength", type=float, default=0.8)
    ap.add_argument("--no-char-lora", action="store_true")
    ap.add_argument("--init", help="以這張圖為底重畫（img2img）")
    ap.add_argument("--denoise", type=float, default=0.55)
    ap.add_argument("--ref", help="參考圖（IP-Adapter）")
    ap.add_argument("--ref-mode", choices=["style", "content"], default="style")
    ap.add_argument("--ref-weight", type=float, default=0.7)
    ap.add_argument("--control", help="構圖控制圖（ControlNet）：線稿、深度圖…")
    ap.add_argument("--control-type", choices=CN_TYPES, default="lineart")
    ap.add_argument("--control-strength", type=float, default=0.6)
    ap.add_argument("--control-end", type=float, default=0.8)
    ap.add_argument("--cutout", action="store_true", help="白底去背（立繪、道具）")
    ap.add_argument("--dry", action="store_true", help="只印出提示詞，不出圖")
    a = ap.parse_args()
    for i in range(a.count):
        out = a.out if a.count == 1 else "%s_%d%s" % (os.path.splitext(a.out)[0], i + 1, os.path.splitext(a.out)[1])
        g, prompt, heavy = build(a)
        if i == 0: print("提示詞：", prompt)
        if a.dry: return
        t0 = time.time()
        p = start_server(heavy)
        try:
            run(g, out)
        finally:
            p.kill(); p.wait()
        post(out, a)
        print("完成", out, "%.0f 秒" % (time.time() - t0))
        a.seed += 1


if __name__ == "__main__":
    main()
