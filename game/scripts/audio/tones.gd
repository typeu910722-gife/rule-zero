class_name Tones
extends RefCounted
## 用程式產生的音樂盒音色（原型用，正式版替換為錄製音效）。小遊戲的提示音、Motif.note() 用這個。

const RATE := 22050
static var _cache := {}


static func music_box(freq: float, length := 0.6) -> AudioStreamWAV:
	# 混音 QA（2026-10-21）：原本是 1、2、3 倍頻的純正弦，聽起來像電子嗶聲。
	# 改成比較像真的音樂盒簧片：基頻＋稍微走音的第二根簧片（慢慢的拍頻）、
	# 簧片本身的第二振動模態（約 5.9 倍，很快消失）、撥動那一下的小「喀」、木盒的一點點共鳴。
	var key := "%d_%d" % [int(freq), int(length * 100)]
	if _cache.has(key):
		return _cache[key]
	var rate := 32000
	var n := int(rate * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 10.0)
	var detune := 1.0 + rng.randf_range(0.0008, 0.0018)
	var ph2 := rng.randf() * TAU
	var mode2 := freq * 5.93
	var nyq := rate * 0.45
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var att := minf(1.0, t * 1500.0)
		var v := sin(TAU * freq * t) * exp(-t * 4.0)
		v += sin(TAU * freq * detune * t + ph2) * 0.35 * exp(-t * 3.2)
		if mode2 < nyq:
			v += sin(TAU * mode2 * t) * 0.18 * exp(-t * 28.0)
		v += sin(TAU * freq * 2.0 * t) * 0.05 * exp(-t * 9.0)
		# 撥動的「喀」：很短的噪音，先過一個簡單的低通
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		v += lp * 0.25 * exp(-t * 900.0)
		var tail := minf(1.0, (length - t) * 40.0)
		data.encode_s16(i * 2, int(clampf(v * att * tail * 0.36, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	_cache[key] = wav
	return wav


static func play(parent: Node, freq: float, volume_db := -6.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = music_box(freq)
	p.volume_db = volume_db + Audio.sfx_db()
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## 電擊的嗡嗡聲（方波＋雜訊）
static func buzz_wave(length := 0.3) -> AudioStreamWAV:
	var key := "buzz_%d" % int(length * 100)
	if _cache.has(key):
		return _cache[key]
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t * 200.0) * minf(1.0, (length - t) * 30.0)
		var sq := 1.0 if fmod(t * 120.0, 1.0) < 0.5 else -1.0
		var v := sq * 0.5 + rng.randf_range(-0.35, 0.35)
		data.encode_s16(i * 2, int(clampf(v * env * 0.35, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_cache[key] = wav
	return wav


static func buzz(parent: Node, length := 0.3, volume_db := -10.0) -> void:
	# 有外包的電擊音效就用它（短／中／長），沒有才用程式合成的嗡嗡聲
	var kind := "shock_short" if length < 0.25 else ("shock_medium" if length < 0.5 else "shock_long")
	if Sfx.play(parent, kind, volume_db + 4.0):
		return
	var p := AudioStreamPlayer.new()
	p.stream = buzz_wave(snappedf(length, 0.05))
	p.volume_db = volume_db + Audio.sfx_db()
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
