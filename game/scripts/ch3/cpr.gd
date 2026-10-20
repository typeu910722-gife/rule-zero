extends Ch3Mini
## 心臟按壓：跟著節拍按（約每分鐘 110 下）。節奏＝主旋律。
## 24 拍裡要按準 16 拍以上。回傳：true＝心電圖回來了。

const BPM := 110.0
const BEATS := 24
var beat_t := 0.0
var beat_i := 0
var good := 0
var _pressed_this := false
var pulse := 0.0
var feedback := ""


func _setup() -> void:
	title = "心臟按壓"
	hint = "跟著節奏按。一下、一下、一下。"
	fast_result = true


func _tick(delta: float) -> void:
	var period := 60.0 / BPM
	beat_t += delta
	pulse = maxf(0.0, pulse - delta * 4.0)
	if beat_t >= period:
		beat_t -= period
		if not _pressed_this and beat_i > 0:
			feedback = "……"
		beat_i += 1
		_pressed_this = false
		if not GameState.fast:
			Sfx.play(self, "monitor_beat", -18.0)
		if beat_i > BEATS:
			finish(good >= 16)


func _press(down: bool, _e: InputEvent) -> void:
	if not down or _pressed_this:
		return
	_pressed_this = true
	var period := 60.0 / BPM
	var off := minf(beat_t, period - beat_t)
	if off < 0.12:
		good += 1
		pulse = 1.0
		feedback = "好"
		Motif.note(self, good - 1, -10.0)
	else:
		feedback = "太快了" if beat_t > period * 0.5 else "太慢了"


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	var period := 60.0 / BPM
	var k := 1.0 - beat_t / period
	# 節拍圈
	c.draw_circle(Vector2(640, 330), 70 + 60 * k, Color(PINK, 0.25))
	c.draw_circle(Vector2(640, 330), 70 + pulse * 20, PINK)
	c.draw_string(f, Vector2(0, 345), "按", HORIZONTAL_ALIGNMENT_CENTER, 1280, 36, Color.WHITE)
	c.draw_string(f, Vector2(0, 500), feedback, HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, INK)
	c.draw_string(f, Vector2(0, 560), "%d／%d" % [good, 16], HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, SOFT)
	# 心電圖：越準越接近正常
	var pts := PackedVector2Array()
	var alive := clampf(good / 16.0, 0.0, 1.0)
	for i in 100:
		var x := 290.0 + i * 7.0
		var ph := fmod(t * BPM / 60.0 + i / 30.0, 1.0)
		var y := 620.0
		if ph > 0.45 and ph < 0.5:
			y -= 46.0 * alive
		pts.append(Vector2(x, y))
	c.draw_polyline(pts, GREEN if alive > 0.6 else RED, 2.0)
