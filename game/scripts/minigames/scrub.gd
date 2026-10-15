extends CanvasLayer
## 洗白白（第二章小遊戲 2）：洗衣房裡，用刷子把條碼身上的斑紋刷乾淨。
## 刷越乾淨星星越多。刷的時候條碼小聲說話，越刷越聽不清楚。
## 隱藏選擇：斑紋還剩一點點（5%～35%）的時候按「完成」→ 條碼保住一段記憶（操行 -10）。
## 操作：滑鼠／手指在斑紋上來回拖；鍵盤按住 E／空白鍵自動刷；「完成」：點按鈕或按 Tab。

signal done

const POS := Vector2(640, 400)
const SCALE := 6.0
const STRIPES := 2
const KEEP_MIN := 0.05
const KEEP_MAX := 0.35
## 斑紋剩下多少時，條碼說什麼
const LINES := [
	[1.0, "欸你們知道嗎，三班的那個誰，他媽媽在夜市賣……"],
	[0.7, "欸你們知道嗎……那個誰……大家都不要跟他……"],
	[0.4, "欸你們……群組……是我開的……是我……"],
	[0.15, "……我其實……"],
	[0.0, "今天的天氣，很好。"],
]
const DONE_BTN := Rect2(1040, 600, 200, 70)

## 每條斑紋（左右各一）剩下的黑色 0..1
var stripes: Array = []
var kept_color := false
var _area: Control
var _running := false
var _brush := Vector2(-100, -100)
var _last_brush := Vector2.ZERO
var _mouse_down := false
var _popups: Array = []
var _bubbles: Array = []
var _holes: Array = []
var _too_dirty_t := 0.0
var _auto := 0


func _ready() -> void:
	layer = 30
	for k in STRIPES * 2:
		stripes.append(1.0)
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast:
		if GameState.fast_scrub_keep:
			kept_color = true
		_finish()
		queue_free()
		return
	_running = true
	await done
	queue_free()


func remaining() -> float:
	var t := 0.0
	for v in stripes:
		t += v
	return t / stripes.size()


func _finish() -> void:
	if kept_color:
		GameState.set_flag("tiaoma_color_left")
		GameState.add_conduct(-10)
	else:
		GameState.add_conduct(10)
	_running = false
	done.emit()


## 斑紋在畫面上的位置（對應 Critter.draw 的 zebra）
func _stripe_rect(k: int) -> Rect2:
	var side := -1 if k % 2 == 0 else 1
	var row := k / 2
	var head := POS + Vector2(0, -24) * SCALE
	var y := -12.0 + row * 7.0
	var cx := head.x + side * 12.0 * SCALE
	return Rect2(Vector2(cx - 9 * SCALE, head.y + (y - 2) * SCALE), Vector2(18 * SCALE, 8 * SCALE))


func _scrub_at(p: Vector2, amount: float) -> void:
	for k in stripes.size():
		if stripes[k] > 0 and _stripe_rect(k).grow(10).has_point(p):
			stripes[k] = maxf(0.0, stripes[k] - amount)
			if randf() < 0.4:
				_bubbles.append({"pos": p + Vector2(randf_range(-20, 20), randf_range(-10, 10)), "t": 0.0})
				Tones.play(self, 1046.5 + randf() * 300.0, -22.0)


func _process(delta: float) -> void:
	if not _running:
		return
	for b in _bubbles:
		b.t += delta
		b.pos += Vector2(0, -30) * delta
	_bubbles = _bubbles.filter(func(b): return b.t < 0.8)
	for p in _popups:
		p.t += delta
	_popups = _popups.filter(func(p): return p.t < 1.0)
	_too_dirty_t = maxf(0.0, _too_dirty_t - delta)
	if _mouse_down:
		var speed := _brush.distance_to(_last_brush) / maxf(delta, 0.001)
		if _brush.distance_to(_last_brush) > 1.0:
			_scrub_at(_brush, delta * 0.9)
		if speed > 2600.0 and randf() < 0.05 and _holes.size() < 6:
			# 刷太用力：刷出一個小破洞，棉花冒出來
			_holes.append(_brush)
			_popups.append({"text": "哎呀～輕一點點！", "t": 0.0})
		_last_brush = _brush
	elif Input.is_action_pressed("interact"):
		# 鍵盤：自動刷下一條還有顏色的斑紋
		var left := []
		for k in stripes.size():
			if stripes[k] > 0:
				left.append(k)
		if not left.is_empty():
			var r := _stripe_rect(left[0])
			_brush = r.get_center() + Vector2(sin(Time.get_ticks_msec() / 60.0) * r.size.x * 0.4, 0)
			_scrub_at(_brush, delta * 0.55)
	if remaining() <= 0.0:
		_finish()
	_area.queue_redraw()


func _try_done() -> void:
	var r := remaining()
	if r > KEEP_MAX:
		_too_dirty_t = 2.0
		return
	kept_color = r >= KEEP_MIN
	_finish()


func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and DONE_BTN.has_point(event.position):
			get_viewport().set_input_as_handled()
			_try_done()
			return
		_mouse_down = event.pressed
		_brush = event.position
		_last_brush = event.position
	elif event is InputEventMouseMotion:
		_brush = event.position
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_try_done()


func _current_line() -> String:
	var r := remaining()
	var line := ""
	for l in LINES:
		if r <= l[0] + 0.001:
			line = l[1]
	return line


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#e8e8e6"))
	# 牆上的海報
	a.draw_rect(Rect2(60, 60, 260, 120), Color("#fff3f7"))
	a.draw_rect(Rect2(60, 60, 260, 120), Color("#f2a7c3"), false, 4)
	a.draw_string(f, Vector2(60, 115), "白白的，", HORIZONTAL_ALIGNMENT_CENTER, 260, 30, Color("#e05780"))
	a.draw_string(f, Vector2(60, 155), "最乾淨！", HORIZONTAL_ALIGNMENT_CENTER, 260, 30, Color("#e05780"))
	a.draw_string(f, Vector2(0, 40), "洗白白！把黑色的地方刷乾淨（拖曳刷子／按住 E）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Color("#c2558a"))
	# 洗衣板與曬衣夾
	a.draw_rect(Rect2(POS.x - 230, POS.y - 300, 460, 340), Color("#cfc6b8"))
	for k in 14:
		a.draw_line(Vector2(POS.x - 220, POS.y - 290 + k * 23), Vector2(POS.x + 220, POS.y - 290 + k * 23), Color("#b9ae9e"), 3)
	a.draw_set_transform(POS, 0.0, Vector2(SCALE, SCALE))
	Critter.draw(a, "zebra", Color("#f4f4f2"), 1.0, Vector2.ZERO, false, false, false, {"stripes": 0})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in stripes.size():
		if stripes[k] <= 0:
			continue
		var r := _stripe_rect(k)
		var side := -1 if k % 2 == 0 else 1
		var p1 := Vector2(r.get_center().x + side * 4 * SCALE, r.position.y + 2 * SCALE)
		var p2 := Vector2(r.get_center().x - side * 6 * SCALE, r.position.y + 5 * SCALE)
		a.draw_line(p1, p2, Color(0.12, 0.12, 0.12, stripes[k]), 3 * SCALE)
	for side in [-1, 1]:
		var c := POS + Vector2(side * 150, -60)
		a.draw_rect(Rect2(c - Vector2(10, 28), Vector2(20, 56)), Color("#f6bd60"))
	for h in _holes:
		a.draw_circle(h, 9, Color("#fbfbfb"))
		a.draw_arc(h, 9, 0, TAU, 12, Color("#bdbdbd"), 2)
	for b in _bubbles:
		a.draw_arc(b.pos, 8 + b.t * 6, 0, TAU, 14, Color(0.7, 0.85, 1.0, 1.0 - b.t / 0.8), 2)
	# 刷子
	if _brush.x > 0:
		a.draw_rect(Rect2(_brush - Vector2(30, 10), Vector2(60, 20)), Color("#ff9ebb"))
		a.draw_rect(Rect2(_brush - Vector2(8, 50), Vector2(16, 42)), Color("#ffc8d8"))
		a.draw_circle(_brush + Vector2(0, -34), 6, Color("#e05780"))
	# 條碼說的話
	a.draw_string(f, Vector2(0, 560), "條碼：%s" % _current_line(), HORIZONTAL_ALIGNMENT_CENTER, 1280, 24,
		Color(0.25, 0.25, 0.25, clampf(0.35 + remaining(), 0.35, 1.0)))
	# 星星
	var stars := 3 - int(ceil(remaining() * 3.0))
	for k in 3:
		_star(Vector2(560 + k * 80, 640), 22, Color("#ffd166") if k < stars else Color("#dddddd"))
	# 完成按鈕
	a.draw_rect(DONE_BTN, Color("#fff8f0"))
	a.draw_rect(DONE_BTN, Color("#e8a0bf"), false, 3)
	a.draw_string(f, DONE_BTN.position + Vector2(0, 46), "完成（Tab）", HORIZONTAL_ALIGNMENT_CENTER, DONE_BTN.size.x, 24, Color("#8a4b68"))
	if _too_dirty_t > 0:
		a.draw_string(f, Vector2(0, 520), "和平鴿：還很髒喔。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Color("#555555"))
	for p in _popups:
		a.draw_string(f, Vector2(0, 480 - p.t * 30), p.text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color(0.88, 0.34, 0.5, 1.0 - p.t))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * rad)
	_area.draw_colored_polygon(pts, col)
