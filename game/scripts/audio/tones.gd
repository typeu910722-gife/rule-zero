class_name Tones
extends RefCounted
## 用程式產生的音樂盒音色（原型用，正式版替換為錄製音效）。

const RATE := 22050
static var _cache := {}


static func music_box(freq: float, length := 0.6) -> AudioStreamWAV:
	var key := "%d_%d" % [int(freq), int(length * 100)]
	if _cache.has(key):
		return _cache[key]
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 6.0) * minf(1.0, t * 400.0)
		var v := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.2 + sin(TAU * freq * 3.0 * t) * 0.1
		data.encode_s16(i * 2, int(clampf(v * env * 0.5, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_cache[key] = wav
	return wav


static func play(parent: Node, freq: float, volume_db := -6.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = music_box(freq)
	p.volume_db = volume_db
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
