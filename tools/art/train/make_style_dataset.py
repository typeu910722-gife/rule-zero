# 第零條規則畫風 LoRA 的資料集：只用委託的原圖（不含自己生成的替代圖）
import os, re, glob, json
from PIL import Image, ImageFilter
R = os.path.dirname(os.path.abspath(__file__)) + '/../../../'
A = R + 'game/art/'
import sys
OUT = (sys.argv[1] if len(sys.argv) > 1 else '/tmp/rz-art/datasets/style') + '/8_rzstyle/'
os.makedirs(OUT, exist_ok=True)
for f in glob.glob(OUT + '*'): os.remove(f)

CH = {  # 角色描述（英文，給模型看）
 'bu': 'pip, cream curly wool sheep plush, green hooded cloak, brown leather satchel',
 'pip': 'pip, cream curly wool sheep plush, green hooded cloak, brown leather satchel',
 'lulu': 'lulu, pink long-eared rabbit plush, mint green bow, pink dress with heart patch',
 'mayor': 'bear mayor, brown teddy bear plush, black top hat',
 'fen': 'fen, red fox plush, dark grey patched hooded vest, leather satchel',
 'popo': 'popo, navy blue penguin plush, mail carrier',
 'mochi': 'mochi, white hamster plush, blank name tag',
 'tama': 'tama, calico cat plush, blue dress, pearl buttons',
 'conductor': 'conductor, dark train conductor plush, uniform cap',
 'puppy': 'puppy resident, tan puppy plush, blue vest, yellow scarf',
 'mirror_child': 'mirror child, small human child',
 'baimian': 'baimian, pale white fox plush, grey hood',
 'xiaoji': 'xiaoji, black hedgehog plush',
 'tiaoma': 'tiaoma, zebra plush',
 'gaga': 'gaga, black crow plush',
 'zhongzhong': 'zhongzhong, grey hippo plush',
 'youyou': 'youyou, grey weasel plush, red scarf',
 'dove': 'peace dove, principal, tall white figure with white bird beak mask, white doctor coat, stethoscope',
 'mechbird': 'mechanical bird, wind-up metal bird',
 'staff': 'bleach town staff plush',
}
ST = {
 'plush': 'rz_plush, plush toy photography, felt and fur texture, visible stitched seams, soft cinematic lighting',
 'flat': 'rz_flat, flat cel illustration, thick dark brown outline, soft pastel colors, simple shading',
 'town': 'rz_town, storybook painted background, cotton candy town, pastel fairy tale',
 'memory': 'rz_memory, human world memory scene, photorealistic, muted colors, melancholy',
 'bleach': 'rz_bleach, bleach town, desaturated grey and white knitted felt world, cold light',
}
items = []
def chars_in(name):
    found = [k for k in CH if re.search(r'(^|_)' + k + r'(_|\.|$)', name)]
    if 'mirror' in name and 'child' in name: found.append('mirror_child')
    return [CH[k] for k in dict.fromkeys(found)]
def words(name):
    n = re.sub(r'^(ch2_)?(bg|cg\d+|int|item|face|walk|scare|title|item_stand)_?', '', os.path.splitext(os.path.basename(name))[0])
    n = re.sub(r'\d+', '', n)
    return ' '.join(w for w in n.split('_') if w and w not in CH and w not in ('portrait', 'default', 'a', 'b', 's'))
def add(im, style, subj, tag):
    if im.mode in ('RGBA', 'LA', 'P'):
        im = im.convert('RGBA'); bg = Image.new('RGBA', im.size, (255, 255, 255, 255)); bg.alpha_composite(im); im = bg
    im = im.convert('RGB')
    w, h = im.size; s = 1024 / max(w, h)
    if s < 1: im = im.resize((round(w * s), round(h * s)), Image.LANCZOS)
    elif max(w, h) < 512: im = im.resize((round(w * 512 / max(w, h)), round(h * 512 / max(w, h))), Image.LANCZOS)
    name = f'{len(items):03d}_{tag}'
    im.save(OUT + name + '.png')
    cap = ', '.join(x for x in ['rzstyle', ST[style], subj] if x)
    open(OUT + name + '.txt', 'w').write(cap)
    items.append((name, style, cap))

# ---- 第一章背景 ----
for f in sorted(glob.glob(A + 'bg_*.jpg')):
    b = os.path.basename(f)
    EXTRA = {'bg_nt_dog': 'inside pink night train, ' + CH['puppy'], 'bg_nt_lulu': 'inside pink night train, ' + CH['lulu'],
             'bg_nt_mochi': 'inside pink night train, ' + CH['mochi'] + ', ' + CH['bu'], 'bg_nt_popo': 'inside pink night train, ' + CH['popo'] + ', ' + CH['lulu'],
             'bg_nt_tama': 'inside pink night train, ' + CH['tama'], 'bg_platform': 'train platform, ' + CH['bu'], 'bg_train': 'inside pink train, ' + CH['bu'] + ', ' + CH['conductor'],
             'bg_mayor_broken': 'torn apart bear plush on the floor, stuffing spilled, ' + CH['mayor'], 'bg_glove': 'close-up of white gloved hands', 'bg_town2': 'dark town, tied up plush toys on a platform'}
    k = b[:-4]
    if 'hospital' in b:
        st, sub = 'memory', 'pencil sketch, monochrome graphite drawing, dream, hospital corridor'
    elif any(x in b for x in ('mem_', 'classroom')):
        st, sub = 'memory', 'scene, ' + words(b)
    else:
        st, sub = 'town', 'scene, ' + words(b)
    if k in EXTRA: sub = EXTRA[k]
    if k.startswith('bg_nt_') or k in ('bg_platform', 'bg_train', 'bg_mayor_broken'):
        st = 'plush'
    add(Image.open(f), st, sub, k)
for f in sorted(glob.glob(A + 'int_*.jpg')):
    b = os.path.basename(f)
    if b == 'int_mirror.jpg': continue   # 自己生成的，不學
    add(Image.open(f), 'town', 'dollhouse room interior, miniature diorama, ' + words(b) + ' house', b[:-4])
for f in ['title_platform.jpg', 'room.jpg', 'forest_map.jpg']:
    if os.path.exists(A + f): add(Image.open(A + f), 'town', 'background, ' + words(f), f[:-4])
# ---- 第一章扁平角色 ----
for f in sorted(glob.glob(A + 'face_*.png')):
    k = os.path.basename(f)[5:-4]
    im = Image.open(f); cw = im.width // 4; chh = im.height // 2
    for i in (0, 5):
        r, c = divmod(i, 4)
        add(im.crop((c * cw, r * chh, (c + 1) * cw, (r + 1) * chh)), 'flat', 'bust portrait, ' + CH.get(k, k), f'face_{k}{i}')
for f in sorted(glob.glob(A + 'item_stand_*.png')):
    b = os.path.basename(f); k = b[11:-4]
    ks = [CH[x] for x in CH if k.startswith(x)]
    add(Image.open(f), 'flat', 'full body standing, ' + (ks[0] if ks else k) + (', broken' if 'broken' in b else ''), b[:-4])
for f in sorted(glob.glob(A + 'walk_*.png')):
    k = os.path.basename(f)[5:-4]
    if k in ('mask', 'fen'): continue      # fen 另有角色 LoRA；mask 不是角色圖
    im = Image.open(f)
    for r, v in ((0, 'front view'), (1, 'side view')):
        add(im.crop((192, r * 192, 384, (r + 1) * 192)), 'flat', 'chibi map sprite, full body, ' + v + ', ' + CH.get(k, k), f'walk_{k}{r}')
# ---- 第一章布偶寫實 ----
for f in sorted(glob.glob(A + 'title_bu_*.png'))[:2]:
    add(Image.open(f), 'plush', 'full body, ' + CH['bu'], os.path.basename(f)[:-4])
for f in sorted(glob.glob(A + 'scare_*.png')):
    k = os.path.basename(f)[6:-4]
    add(Image.open(f), 'plush', 'extreme close-up, creepy, ' + CH.get(k, k), 'scare_' + k)
for f in sorted(glob.glob(A + 'scissors/*.jpg'))[:3]:
    add(Image.open(f), 'plush', 'dark dramatic scene, ' + CH['mayor'], 'scissors_' + os.path.basename(f)[:-4])
# 設定圖：每張排版不同，各自的座標（1536×1024）；blur＝要遮掉的文字標籤
SHEETS = {
 '01_pip': ('bu', [(565,105,860,400),(900,105,1120,400),(1170,105,1470,400)], [(580,480,760,650),(760,480,945,650),(950,480,1135,650)], (20,300,575,1000), []),
 '02_mayor': ('mayor', [(645,160,905,480),(905,160,1105,480),(1105,160,1360,480)], [], (140,60,560,960), [(505,135,560,178)]),
 '03_lulu': ('lulu', [(730,160,1000,470),(1010,160,1190,470),(1195,160,1460,470)], [(685,555,835,775),(845,555,995,775),(1003,555,1153,775)], (40,60,690,820),
             [(70,155,185,190),(550,200,680,235),(30,555,185,590),(525,535,620,565),(505,645,660,675)]),
 '04_fen': ('fen', [(745,205,945,465),(1000,205,1240,465),(1250,205,1460,465)], [(645,545,800,712),(805,545,960,712),(970,545,1130,712)], (20,40,560,1000),
            [(370,40,540,80),(490,385,540,415),(60,495,180,525),(60,705,180,740),(500,600,540,640)]),
 '05_popo': ('popo', [(680,100,940,400),(950,100,1220,400),(1225,100,1490,400)], [(720,450,960,650),(990,450,1225,650),(1240,450,1480,650)], (150,140,600,900),
             [(155,510,245,550),(565,175,600,210)]),
 '06_mirror_child': ('mirror_child', [(620,140,860,480),(880,140,1110,480),(1120,140,1360,480)], [(635,565,785,740),(788,565,930,740),(935,565,1080,740)], (0,40,480,960), []),
 '07_mochi': ('mochi', [(740,130,1000,420),(1010,130,1230,420),(1240,130,1495,420)], [(745,510,1000,670),(1000,510,1240,670),(1255,510,1500,670)], (40,190,720,900),
              [(35,200,140,265),(565,210,705,245),(10,415,135,450),(30,705,155,740)]),
 '08_tama': ('tama', [(735,170,960,480),(975,170,1240,480),(1245,170,1490,480)], [(670,600,820,810),(825,600,980,810),(985,600,1130,810)], (60,100,700,850),
             [(75,105,175,175),(55,400,175,435),(595,300,725,335),(590,500,750,535),(40,765,140,805)]),
}
for s_, (k, turns, exprs, main, blur) in SHEETS.items():
    sh = Image.open(R + f'docs/art/{s_}.jpg').convert('RGB')
    if sh.size != (1536, 1024): sh = sh.resize((1536, 1024), Image.LANCZOS)
    for b in blur:
        sh.paste(sh.crop(b).filter(ImageFilter.GaussianBlur(25)), b)
    for i, box in enumerate(turns):
        add(sh.crop(box), 'plush', 'character turnaround, full body, plain background, ' + ['front view', 'side view', 'back view'][i] + ', ' + CH[k], f'sheet_{k}{i}')
    for i, box in enumerate(exprs):
        add(sh.crop(box), 'plush', 'head and shoulders close-up, facial expression, ' + CH[k], f'sheet_{k}_face{i}')
    add(sh.crop(main), 'plush', 'hero shot, standing in a warm storybook town, ' + CH[k], f'sheet_{k}_main')
# ---- 第二章 ----
for f in sorted(glob.glob(A + 'ch2/backgrounds/*.jpg')):
    b = os.path.basename(f)
    add(Image.open(f), 'bleach', 'background, no characters, ' + words(b), b[:-4])
for f in sorted(glob.glob(A + 'ch2/cg/*.jpg')):
    b = os.path.basename(f)
    if any(x in b for x in ('_blank', '_stitch_', 'overlay', 'referral', 'ticket', 'clipboard', 'diary')): continue
    cs = chars_in(b[4:])
    add(Image.open(f), 'plush', 'cinematic event scene, bleach town, ' + words(b) + (', ' + ', '.join(cs) if cs else ''), b[:-4])
seen = {}
for f in sorted(glob.glob(A + 'ch2/characters/portraits/*.png')):
    b = os.path.basename(f)
    if b.startswith('ch2_fen_portrait_a_'): continue   # 自己生成的 Fen 替代立繪
    k = b[4:].split('_portrait')[0]
    if seen.get(k, 0) >= (3 if k in ('dove', 'baimian', 'xiaoji', 'tiaoma', 'youyou', 'gaga', 'zhongzhong') else 2): continue
    seen[k] = seen.get(k, 0) + 1
    expr = words(b.split('_portrait')[1]) if '_portrait' in b else ''
    add(Image.open(f), 'plush', 'character portrait, upper body, plain white background, ' + CH.get(k, k) + (', ' + expr if expr else ''), b[:-4])
from collections import Counter
print(len(items), Counter(s for _, s, _ in items))
json.dump(items, open(OUT + '../items.json', 'w'), ensure_ascii=False, indent=0)
