class_name Score
extends RefCounted
## 程式音樂盒的循環旋律。音色跟 Tones.music_box 同一套（正弦＋泛音、很快衰減）。
## 第一章與第三～七章用它；第二章仍用外包的 ogg。

const RATE := 22050

## step：每個音幾秒。0 是休止。detune：第二聲部偏音，鏡子與修理用。
const THEMES := {
	"cotton": {"step": 0.50, "detune": 0.0, "notes": [659, 784, 880, 784, 659, 587, 523, 587]},
	"forest": {"step": 0.62, "detune": 0.014, "notes": [523, 622, 698, 622, 523, 494, 440, 494]},
	"dream": {"step": 0.70, "detune": 0.004, "notes": [523, 0, 587, 0, 494, 523, 0, 440]},
	"ward": {"step": 0.64, "detune": 0.0, "notes": [622, 0, 740, 831, 740, 622, 554, 494]},
	"mail": {"step": 0.48, "detune": 0.0, "notes": [659, 784, 880, 784, 698, 659, 587, 659]},
	"mirror": {"step": 0.56, "detune": 0.013, "notes": [659, 622, 587, 554, 523, 554, 494, 523]},
	"mayor": {"step": 0.58, "detune": 0.0, "notes": [392, 494, 523, 494, 440, 392, 349, 392]},
	"plaza": {"step": 0.50, "detune": 0.0, "notes": [523, 659, 784, 659, 698, 659, 587, 523]},
	"remember": {"step": 0.42, "detune": 0.0, "notes": [523, 659, 784, 880, 784, 880, 1046, 880]},
	"repair": {"step": 0.74, "detune": 0.02, "notes": [523, 494, 466, 440, 415, 392, 370, 349]},
}

static var _cache := {}


static func loop(name: String) -> AudioStreamWAV:
	if name == "" or not THEMES.has(name):
		return null
	if _cache.has(name):
		return _cache[name]
	var spec: Dictionary = THEMES[name]
	var step := float(spec.step)
	var notes: Array = spec.notes
	var detune := float(spec.detune)
	var total := int(RATE * step * notes.size())
	var mix := PackedFloat32Array()
	mix.resize(total)
	for ni in notes.size():
		var freq := float(notes[ni])
		if freq <= 0.0:
			continue
		var start := int(ni * step * RATE)
		var length := int(step * RATE)
		for i in length:
			var idx := start + i
			if idx >= total:
				break
			var t := float(i) / RATE
			var env := exp(-t * 4.2) * minf(1.0, t * 280.0)
			var v := sin(TAU * freq * t) * 0.62 + sin(TAU * freq * 2.0 * t) * 0.2 + sin(TAU * freq * 3.0 * t) * 0.08
			if detune > 0.0:
				v += sin(TAU * freq * (1.0 + detune) * t) * 0.34
			mix[idx] = mix[idx] + v * env
	var data := PackedByteArray()
	data.resize(total * 2)
	for i in total:
		data.encode_s16(i * 2, int(clampf(mix[i] * 0.45, -1.0, 1.0) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	_cache[name] = wav
	return wav
