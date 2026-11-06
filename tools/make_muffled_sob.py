"""第四章「那一天」：隔著廁所門的哭聲（用現有的喘氣、呼吸錄音組合，不是新錄的）。
一下一下抽噎的吸氣＋顫抖的吐氣，整段用低通濾波（隔著門），音量忽大忽小。
用法：py -3.11 tools/make_muffled_sob.py  → game/audio/ch4/sob_muffled.wav（OGG 寫入在這台電腦會當掉）
"""
import numpy as np
import soundfile as sf


def resample(x, n):
    """線性內插重新取樣（不用 scipy.signal：這台電腦的 scipy 有一個模組壞掉）"""
    return np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)


def lowpass(x, fc):
    """FFT 低通（柔和的邊緣）"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1.0 / (1.0 + (f / fc) ** 8)
    return np.fft.irfft(X, len(x))

SR = 44100
rng = np.random.default_rng(7)


def load(p):
    d, sr = sf.read(p)
    if d.ndim > 1:
        d = d.mean(1)
    if sr != SR:
        d = resample(d, int(len(d) * SR / sr))
    return d / (np.abs(d).max() + 1e-9)


def pitch(x, f):
    """簡單變調（重新取樣）：f>1 聲音變高、變短"""
    return resample(x, max(16, int(len(x) / f)))


gasps = [load(f"game/audio/voice/gasp_{i}.ogg") for i in (1, 2, 3)]
breath = load("game/audio/ch4/breath.ogg")
total = int(SR * 14.0)
out = np.zeros(total)
t = 0.3
while t < 13.0:
    # 一串 2～4 下抽噎（短促吸氣，越來越高）
    n = rng.integers(2, 5)
    for k in range(n):
        g = pitch(gasps[rng.integers(0, 3)], 1.25 + 0.08 * k + rng.uniform(-0.05, 0.05))
        g = g[: int(SR * 0.28)] * np.hanning(min(len(g), int(SR * 0.28)))
        i = int(t * SR)
        out[i:i + len(g)] += g[: max(0, total - i)] * (0.55 + 0.1 * k)
        t += rng.uniform(0.16, 0.24)
    # 顫抖的吐氣（呼吸錄音的一段，加上 6Hz 的抖動）
    seg_len = int(SR * rng.uniform(0.9, 1.4))
    s0 = rng.integers(0, len(breath) - seg_len)
    b = pitch(breath[s0:s0 + seg_len], 1.15) * np.hanning(len(pitch(breath[s0:s0 + seg_len], 1.15)))
    trem = 1.0 - 0.45 * (0.5 + 0.5 * np.sin(2 * np.pi * 6.0 * np.arange(len(b)) / SR))
    i = int(t * SR)
    out[i:i + len(b)] += (b * trem)[: max(0, total - i)] * 0.5
    t += len(b) / SR + rng.uniform(0.5, 1.3)
# （試過用程式合成有聲調的「嗚——」，聽起來像貓叫，拿掉了；真的哭聲要用錄音）
# 隔著門：低通、帶一點點迴響
out = lowpass(out, 900)
echo = np.zeros_like(out)
d = int(SR * 0.045)
echo[d:] = out[:-d] * 0.35
out = out + echo
# 音量慢慢起伏（時遠時近），頭尾淡入淡出
env = 0.75 + 0.25 * np.sin(2 * np.pi * 0.17 * np.arange(total) / SR)
fade = np.ones(total)
fade[: SR] = np.linspace(0, 1, SR)
fade[-SR:] = np.linspace(1, 0, SR)
out = out * env * fade
out = out / (np.abs(out).max() + 1e-9) * 0.7
out22 = resample(out, len(out) // 2)
sf.write("game/audio/ch4/sob_muffled.wav", out22.astype(np.float32), SR // 2, subtype="PCM_16")
print("game/audio/ch4/sob_muffled.wav", round(total / SR, 1), "s")
