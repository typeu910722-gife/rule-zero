extends CanvasLayer
## 治療室：按住「我很乖」撐過去（第二章）。
## 每一題要按住到時間滿；放開的話進度會慢慢掉回去。越撐，畫面越白。
## 用法：var h := HoldEndure.new(); h.questions = [["你為什麼沒有笑？", 3.0], ...]; await h.play()

signal done

var questions: Array = []
var _i := 0
var _hold := 0.0
var _running := false
var _area: Control
var _mouse_down := false
var _flash := 0.0
var _buzz_t := 0.0


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast or questions.is_empty():
		queue_free()
		return
	_running = true
	await done
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed


func _process(delta: float) -> void:
	if not _running:
		return
	_area.queue_redraw()
	if _flash > 0:
		_flash -= delta
		if _flash <= 0:
			_i += 1
			_hold = 0.0
			if _i >= questions.size():
				_running = false
				done.emit()
		return
	var need: float = questions[_i][1]
	var held := Input.is_action_pressed("interact") or _mouse_down
	_hold = clampf(_hold + (delta / need if held else -delta * 0.15), 0.0, 1.0)
	if held:
		_buzz_t -= delta
		if _buzz_t <= 0:
			_buzz_t = 0.35
			Tones.buzz(self, 0.25)
	if _hold >= 1.0:
		_flash = 0.8


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#f4f4f2"))
	# 白色磁磚
	for x in 20:
		for y in 12:
			a.draw_rect(Rect2(x * 64, y * 64, 64, 64), Color("#e2e2df"), false, 1)
	# 牆上的海報
	a.draw_rect(Rect2(80, 70, 240, 100), Color("#fff3f7"))
	a.draw_rect(Rect2(80, 70, 240, 100), Color("#f2a7c3"), false, 4)
	a.draw_string(f, Vector2(80, 132), "乖孩子不痛！", HORIZONTAL_ALIGNMENT_CENTER, 240, 28, Color("#e05780"))
	# 小小的椅子與小布
	var held := Input.is_action_pressed("interact") or _mouse_down
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (8.0 if held else 0.0)
	a.draw_rect(Rect2(560, 450, 160, 20), Color("#9a9a9a"))
	a.draw_rect(Rect2(570, 470, 12, 70), Color("#8a8a8a"))
	a.draw_rect(Rect2(698, 470, 12, 70), Color("#8a8a8a"))
	a.draw_set_transform(Vector2(640, 450) + shake, 0.0, Vector2(2.6, 2.6))
	Critter.draw(a, "sheep", Color("#fffdf8"), 1.0, Vector2(0, -0.4), false, false, true,
		{"grey_patch": GameState.has("c2_grey_patch")})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for side in [-1, 1]:
		a.draw_arc(Vector2(640 + side * 44, 414) + shake, 9, 0, TAU, 16, Color("#5a5a5a"), 4)
	# 和平鴿（只看得到大衣和手套）
	a.draw_set_transform(Vector2(980, 760), 0.0, Vector2(3.2, 3.2))
	Critter.draw_dove(a, 1.0)
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _i < questions.size():
		a.draw_string(f, Vector2(0, 200), "和平鴿：%s" % questions[_i][0], HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#333333"))
	a.draw_string(f, Vector2(0, 236), "第 %d 題 / %d" % [mini(_i + 1, questions.size()), questions.size()], HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#999999"))
	var btn := Rect2(440, 560, 400, 90)
	a.draw_rect(btn, Color("#ffe1ec"))
	a.draw_rect(Rect2(btn.position, Vector2(btn.size.x * _hold, btn.size.y)), Color("#ffb3c9"))
	a.draw_rect(btn, Color("#e05780"), false, 4)
	a.draw_string(f, Vector2(btn.position.x, btn.position.y + 58), "我很乖（按住）", HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 34, Color("#8a4b68"))
	a.draw_string(f, Vector2(0, 690), "按住 E／空白鍵（手機：按住畫面）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#888888"))
	# 越撐越白
	var white := _hold * 0.5 + float(_i) / maxf(questions.size(), 1) * 0.3
	if _flash > 0:
		white = 1.0
	a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, white))
