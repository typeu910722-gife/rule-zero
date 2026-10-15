extends CanvasLayer
## 畢業：重新塞棉花（第二章小遊戲 8）。和平鴿把針交到小布手上。
## ① 拉開縫線 ② 把黑色的棉花拿出來 ③ 塞進白色的棉花 ④ 縫好！（溫馨的手作風格）
## 每一步按 E／點畫面幾下完成。steps：這一段要做到第幾步（劇本會在中途停下來讓玩家選擇）。
## 拿出第一團黑色棉花的時候，畫面閃過一張孤兒院的照片——麻糬在門口揮手。

signal done

const STEP_NAMES := ["① 拉開縫線", "② 把黑色的棉花拿出來", "③ 塞進白色的棉花", "④ 縫好！"]
const TAPS := 4

var step := 0
var steps := 4
var target := "xiaoji"
var _taps := 0
var _flash := 0.0
var _running := false
var _area: Control


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast or step >= steps:
		step = steps
		queue_free()
		return
	_running = true
	await done
	queue_free()


func _tap() -> void:
	_taps += 1
	Tones.play(self, [523.3, 659.3, 784.0, 1046.5][step], -10.0)
	if step == 1 and _taps == 1:
		_flash = 1.2
	if _taps >= TAPS:
		_taps = 0
		step += 1
		if step >= steps:
			_running = false
			await get_tree().create_timer(0.8).timeout
			done.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	_flash = maxf(0.0, _flash - delta)
	_area.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if _running and (event.is_action_pressed("interact") or tap):
		get_viewport().set_input_as_handled()
		_tap()


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#fbf3ea"))
	# 手作風格的格紋桌布
	for k in 16:
		a.draw_line(Vector2(k * 80, 0), Vector2(k * 80, 720), Color(0.95, 0.75, 0.8, 0.25), 18)
		a.draw_line(Vector2(0, k * 80), Vector2(1280, k * 80), Color(0.95, 0.75, 0.8, 0.25), 18)
	a.draw_string(f, Vector2(0, 50), "畢業手作時間！（按 E／點畫面）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#c2558a"))
	for k in STEP_NAMES.size():
		var col := Color("#e05780") if k == step else (Color("#7ccf8a") if k < step else Color("#bbbbbb"))
		a.draw_string(f, Vector2(60, 140 + k * 46), STEP_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	var body := Vector2(700, 480)
	a.draw_rect(Rect2(body + Vector2(-260, 30), Vector2(520, 40)), Color("#f7f7f5"))
	a.draw_set_transform(body, 0.0, Vector2(5.0, 5.0))
	var hog_q := 1 if GameState.has("xiaoji_last_quill") else 0
	var c := Color("#2f2f2f").lerp(Color("#f4f4f2"), clampf(step / 3.0, 0.0, 1.0))
	Critter.draw(a, "hedgehog", c, 1.0, Vector2.ZERO, true, step >= 3, false, {"quills": hog_q})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if step >= 1 and step < 3:
		# 拉開的肚子
		Critter.ellipse(a, body + Vector2(0, -70), Vector2(60, 30), Color("#3a3030"))
		for k in 5 - step * 2:
			a.draw_circle(body + Vector2(-40 + k * 20, -70), 12, Color("#1a1a1a"))
	if step >= 2:
		for k in 4:
			a.draw_circle(Vector2(1080 + (k % 2) * 30, 200 + k * 26), 16, Color("#ffffff"))
	if step >= 1:
		for k in mini(step, 2) * 3:
			a.draw_circle(Vector2(320 + k * 26, 600), 14, Color("#1d1d1d"))
	# 針
	a.draw_line(Vector2(980, 560), Vector2(1120, 470), Color("#bdbdbd"), 4)
	a.draw_circle(Vector2(1120, 470), 4, Color("#888888"))
	if _flash > 0:
		# 孤兒院的照片：麻糬在門口揮手
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(0.9, 0.88, 0.84, _flash * 0.8))
		a.draw_rect(Rect2(440, 160, 400, 300), Color(0.75, 0.72, 0.66, _flash))
		a.draw_rect(Rect2(600, 220, 90, 200), Color(0.55, 0.5, 0.45, _flash))
		a.draw_set_transform(Vector2(560, 420), 0.0, Vector2(2.2, 2.2))
		Critter.draw(a, "hamster", Color(0.98, 0.95, 0.9, _flash), 1.0, Vector2.ZERO, true)
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
