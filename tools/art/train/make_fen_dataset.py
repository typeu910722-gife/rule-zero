from PIL import Image, ImageDraw, ImageFilter
import os
import sys
R=os.path.dirname(os.path.abspath(__file__))+'/../../../'
A=R+'game/art/'; D=(sys.argv[1] if len(sys.argv)>1 else '/tmp/rz-art/datasets/fen')+'/10_rzfen/'; os.makedirs(D, exist_ok=True)
sheet=Image.open(R+'docs/art/04_fen.jpg').convert('RGB')
P='rzfen, red fox plush doll, orange fur, cream chest, dark grey patched hooded vest, brown leather satchel strap'
PL=P+', realistic plush toy, felt and fur texture, stitched seams'
FL=P+', flat cel illustration, thick brown outline, game art'
items=[]
def put(name, im, cap, bg=(242,234,220)):
    if im.mode=='RGBA':
        b=Image.new('RGBA',im.size,bg+(255,)); b.alpha_composite(im); im=b.convert('RGB')
    w,h=im.size; s=1024/max(w,h)
    if s>1: im=im.resize((int(w*s),int(h*s)),Image.LANCZOS)
    im.save(D+name+'.png'); open(D+name+'.txt','w').write(cap); items.append(name)
# 設定圖：主圖（遮掉標籤字）
m=sheet.crop((20,40,560,1000)).copy(); d=ImageDraw.Draw(m)
for box in [(370,40,540,80),(490,385,540,415),(60,495,180,525),(60,705,180,740),(500,600,540,640)]:
    patch=m.crop(box).filter(ImageFilter.GaussianBlur(20)); m.paste(patch,box)
put('sheet_main', m, PL+', three-quarter view, standing, holding a leather notebook, big fluffy tail with cream tip, frowning')
for i,(x0,x1,v) in enumerate([(745,945,'front view'),(1000,1240,'side view facing left'),(1250,1460,'back view, hood up')]):
    put(f'sheet_turn{i}', sheet.crop((x0,205,x1,465)), PL+', full body, '+v+', fluffy tail, plain background')
for i,(x0,x1,e) in enumerate([(645,800,'alert frown'),(805,960,'suspicious look'),(970,1130,'quietly worried')]):
    put(f'sheet_face{i}', sheet.crop((x0,545,x1,712)), PL+', head and shoulders, hood, '+e+', never smiling')
sc=Image.open(A+'scare_fen.png').convert('RGBA')
put('scare', sc, PL+', extreme close-up face, hood, patched ear with stitches, wide eyes, glaring', bg=(30,26,28))
f=Image.open(A+'face_fen.png').convert('RGBA')
ex=['frowning','sad tired eyes','suspicious side glance','annoyed','looking away, uneasy','surprised wide eyes','angry glare','serious frown']
for i in range(8):
    r,c=divmod(i,4); put(f'face{i}', f.crop((c*256,r*256,(c+1)*256,(r+1)*256)), FL+', bust portrait, hood, '+ex[i], bg=(255,255,255))
w=Image.open(A+'walk_fen.png').convert('RGBA')
for (r,c,v) in [(0,1,'front view walking'),(1,1,'side view walking left'),(2,1,'side view walking right'),(3,1,'back view walking, hood')]:
    put(f'walk{r}', w.crop((c*192,r*192,(c+1)*192,(r+1)*192)), FL+', chibi map sprite, full body, fluffy tail, '+v, bg=(255,255,255))
t=Image.open(A+'item_fox_tail.png').convert('RGBA')
put('tail', t, 'rzfen, red fox plush tail only, orange fur with cream tip, stitched seam, realistic plush toy', bg=(242,234,220))
print(len(items))
