# 追逐戰音樂（bgm_04_chase.ogg）與剪刀／追逐音效：python3 tools/make_chase_audio.py（在 game/audio 執行）
import numpy as np, subprocess, sys
SR=44100
rng=np.random.default_rng(7)
def t(n): return np.arange(n)/SR
def lp(x,a):  # one-pole lowpass, a in (0,1)
    y=np.empty_like(x); s=0.0
    for i in range(len(x)): s+=a*(x[i]-s); y[i]=s
    return y
def lpf(x,cut):
    a=1-np.exp(-2*np.pi*cut/SR); 
    from scipy.signal import lfilter
    return lfilter([a],[1,-(1-a)],x)
def hpf(x,cut): return x-lpf(x,cut)
def bpf(x,lo,hi): return hpf(lpf(x,hi),lo)
def env(n,a,d):
    tt=t(n); return np.minimum(1,tt/max(a,1e-4))*np.exp(-tt/d)
def write(name,x,ogg=False):
    x=x/ (np.max(np.abs(x))+1e-9)*0.92
    raw=(x*32767).astype(np.int16)
    ch=1 if x.ndim==1 else 2
    args=['ffmpeg','-y','-loglevel','error','-f','s16le','-ar',str(SR),'-ac',str(ch),'-i','-']
    args+= (['-c:a','libvorbis','-q:a','5'] if ogg else [])+[name]
    subprocess.run(args,input=raw.tobytes(),check=True)
def reverb(x,decay=1.2,mix=0.3,wrap=False):
    n=int(SR*decay*1.5); ir=rng.standard_normal(n)*np.exp(-t(n)/ (decay/6.9)); ir=lpf(ir,4000)
    from scipy.signal import fftconvolve
    w=fftconvolve(x,ir)
    if wrap:
        out=w[:len(x)].copy(); out[:len(w)-len(x)]+=w[len(x):]; w=out
    else:
        x=np.concatenate([x,np.zeros(len(w)-len(x))])
    w=w/ (np.max(np.abs(w))+1e-9)*np.max(np.abs(x))
    return x*(1-mix)+w*mix
def note(f): return 440*2**((f-69)/12)

# ---------- chase BGM ----------
BPM=152; beat=60/BPM; bars=24; N=int(round(bars*4*beat*SR))
L=np.zeros(N); R=np.zeros(N)
def add(buf,pos,sig):
    i=int(pos*SR)%N; e=min(N,i+len(sig)); buf[i:e]+=sig[:e-i]
    if i+len(sig)>N: buf[:i+len(sig)-N]+=sig[e-i:]
def kick():
    n=int(0.35*SR); tt=t(n); f=45+120*np.exp(-tt*28)
    ph=2*np.pi*np.cumsum(f)/SR; return np.sin(ph)*np.exp(-tt*9)*1.0
def snare():
    n=int(0.25*SR); x=rng.standard_normal(n); x=bpf(x,1200,7000)*np.exp(-t(n)*18)
    return x*0.5+np.sin(2*np.pi*190*t(n))*np.exp(-t(n)*25)*0.3
def tick():
    n=int(0.04*SR); x=bpf(rng.standard_normal(n),3000,9000)*np.exp(-t(n)*120); return x*0.25
def bass(f,dur):
    n=int(dur*SR); tt=t(n); s=0
    for d in (-0.08,0.0,0.08):
        s=s+(2*((tt*f*2**(d/12))%1)-1)
    s=lpf(s/3,520)+lpf(s/3,1600)*np.exp(-tt*14)*0.6; return s*np.minimum(1,tt/0.005)*np.exp(-tt*3)*0.55
def mbox(f,dur=1.2):
    n=int(dur*SR); tt=t(n); det=1+0.012*np.sin(2*np.pi*0.7*tt)  # 走音
    s=np.sin(2*np.pi*f*det*tt)+0.35*np.sin(2*np.pi*f*3.01*tt)*np.exp(-tt*6)+0.15*np.sin(2*np.pi*f*5.43*tt)*np.exp(-tt*9)
    return s*np.minimum(1,tt/0.002)*np.exp(-tt*2.6)*0.28
def strings(f,dur):
    n=int(dur*SR); tt=t(n); s=0
    for d in (-0.12,-0.04,0.05,0.13):
        s=s+(2*((tt*f*2**(d/12)+rng.random())%1)-1)
    s=lpf(s/4,1400); a=np.clip(tt/dur,0,1); return s*(a**1.6)*np.minimum(1,(dur-tt)/0.05)*0.22

# drums: kick on 1 & 3 + heartbeat double before bar line; snare on 2,4 from bar 4
for b in range(bars):
    base=b*4*beat
    for q in range(4):
        add(L,base+q*beat,tick()); add(R,base+q*beat+beat/2,tick())
    if b>=2:
        for q in (0,2): k=kick(); add(L,base+q*beat,k); add(R,base+q*beat,k)
        k=kick()*0.7; add(L,base+3.5*beat,k); add(R,base+3.5*beat,k)
    if b>=4:
        for q in (1,3): s=snare(); add(L,base+q*beat,s*0.9); add(R,base+q*beat+0.004,s)
    if b>=12 and b%2==1:
        for s16 in range(4): sn=snare()*0.45; add(L,base+3*beat+s16*beat/4,sn); add(R,base+3*beat+s16*beat/4,sn)
# bass ostinato in D minor, 8th notes
prog=[[38,38,50,38,41,38,49,38],[38,38,50,38,44,43,41,40],[34,34,46,34,38,34,45,34],[36,36,48,36,37,37,49,37]]
for b in range(bars):
    pat=prog[(b//2)%4]
    for i,m in enumerate(pat):
        s=bass(note(m),beat/2*0.95); add(L,b*4*beat+i*beat/2,s); add(R,b*4*beat+i*beat/2,s)
# music box melody (detuned, childlike), starts bar 4
mel=[74,77,76,74,72,74,69,None, 74,77,79,81,80,77,76,None, 70,74,77,76,74,72,73,None, 72,76,79,77,76,74,73,69]
for b in range(4,bars):
    for i in range(8):
        m=mel[((b-4)%4)*8+i]
        if m is None: continue
        s=mbox(note(m)); add(L,b*4*beat+i*beat/2,s*0.9); add(R,b*4*beat+i*beat/2+0.011,s)
# rising strings every 4 bars after bar 8
chords=[[62,65,69],[58,62,65],[60,64,67],[61,64,69]]
for b in range(8,bars,4):
    for j,m in enumerate(chords[(b//4)%4]):
        s=strings(note(m),4*4*beat); add(L if j%2 else R,b*4*beat,s); add(R if j%2 else L,b*4*beat,s*0.6)
# riser + cymbal into the loop point
n=int(4*beat*SR); rs=bpf(rng.standard_normal(n),500,8000)*(t(n)/(4*beat))**3*0.35
add(L,(bars-1)*4*beat,rs); add(R,(bars-1)*4*beat,rs)
L=reverb(L,1.4,0.22,True); R=reverb(R,1.4,0.22,True)
write('bgm_04_chase.ogg',np.stack([L,R],1).reshape(-1) if False else np.column_stack([L,R]),ogg=True)

# ---------- SFX ----------
def rip(dur,bright=1.0):
    n=int(dur*SR); x=rng.standard_normal(n)
    # crackle: amplitude modulated by random grains
    g=(rng.random(n)<0.02).astype(float); g=lpf(g,60)*40
    x=bpf(x,600,6000*bright)*np.clip(g,0,1.5)
    return x*np.minimum(1,t(n)/0.01)*np.exp(-t(n)/(dur*0.5))
def thud(f0=70,dur=0.5):
    n=int(dur*SR); tt=t(n); f=f0+180*np.exp(-tt*35)
    return np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-tt*7)+lpf(rng.standard_normal(n),300)*np.exp(-tt*25)*0.6
def shink(dur=0.6):
    n=int(dur*SR); tt=t(n); s=0
    for f,a in ((2630,1),(3911,.6),(5230,.4),(7120,.3)): s=s+a*np.sin(2*np.pi*f*tt)*np.exp(-tt*(6+f/1500))
    sl=bpf(rng.standard_normal(n),3000,10000)*np.exp(-tt*40)
    return s*0.25+sl*0.4
def pad(x,n): return np.concatenate([x,np.zeros(max(0,n-len(x)))])[:n]
n=int(0.7*SR)
stab=pad(shink(0.5),n)*0.6+pad(thud(60,0.5),n)*1.0+pad(np.concatenate([np.zeros(int(0.02*SR)),rip(0.3)]),n)*1.2
write('sfx_stab.wav',reverb(stab,0.6,0.15))
n=int(1.4*SR)
tear=pad(rip(1.0,1.3),n)*1.4+pad(thud(45,0.9),n)*0.8+pad(np.concatenate([np.zeros(int(0.3*SR)),rip(0.6)]),n)
write('sfx_tear.wav',reverb(tear,1.0,0.25))
# boom: sub drop + noise burst + long tail + broken music box
n=int(3.5*SR); tt=t(n); f=30+90*np.exp(-tt*4)
boom=np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-tt*1.3)*1.2+lpf(rng.standard_normal(n),900)*np.exp(-tt*3)*0.9+pad(rip(1.5,1.2),n)*0.6
for i,m in enumerate([86,85,80,79,74]):
    boom+=pad(np.concatenate([np.zeros(int((0.6+i*0.28)*SR)),mbox(note(m)*0.985,1.5)]),n)*0.9
write('sfx_boom.wav',reverb(boom,2.2,0.35))
# whoosh
n=int(0.45*SR); tt=t(n); x=rng.standard_normal(n); a=np.sin(np.pi*tt/0.45)**2
wh=np.zeros(n); 
from scipy.signal import lfilter
for k in range(0,n,512):
    fc=800+5000*(k/n); seg=x[k:k+512]; wh[k:k+512]=bpf(seg,fc*0.6,fc*1.4)
write('sfx_whoosh.wav',wh*a)
# growl: low detuned saws with tremolo + noise
n=int(1.1*SR); tt=t(n); f=70-20*tt
g=sum((2*((np.cumsum(f*r)/SR)%1)-1) for r in (1,1.013,0.5,1.5))
g=lpf(g*(0.6+0.4*np.sin(2*np.pi*23*tt)),900)+bpf(rng.standard_normal(n),200,1500)*0.5
g=np.tanh(g*2.5)*np.minimum(1,tt/0.08)*np.exp(-tt*1.6)
write('sfx_growl.wav',reverb(g,0.8,0.2))
# caught impact: thud + glitch-ish squelch
n=int(1.2*SR); hit=pad(thud(50,1.0),n)*1.2+pad(rip(0.5),n)*0.5+pad(shink(0.8),n)*0.3
write('sfx_impact.wav',reverb(hit,1.2,0.3))
print('ok', N/SR)
