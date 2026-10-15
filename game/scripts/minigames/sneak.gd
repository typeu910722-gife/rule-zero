extends CanvasLayer
## 一二三木頭人（第二章）：和平鴿在洗衣房裡背對著你，大衣掛在門口。
## 按住 E／空白鍵（手機：按住畫面）往前走；他轉頭之前哼歌會停下來——那時候要放開。
## 被看到也拿得到底片（他沒發現），只是操行 -10。

signal done

const SPEED := 0.22
const START := Vector2(180, 560)
const GOAL := Vector2(1000, 560)

var caught := false
var _p := 0.0
var _state := "back"     # back / warn / look
var _state_t := 2.0
var _running := false
var _area: Control
var _mouse_down := false
var _hum_t := 0.0
var _hum_i := 0
var _rng := RandomNumberGenerator.new()
const HUM := [523.3, 587.3, 659.3, 784.0, 659.3, 587.3]


func _ready() -> void:
	layer = 30
	_rng.seed = 3
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> bool:
	if GameState.fast:
		caught = GameState.fast_sneak_caught
		queue_free()
		return caught
	_running = true
	await done
	queue_free()
	return caught


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed


func _process(delta: float) -> void:
	if not _running:
		return
	_area.queue_redraw()
	var held := Input.is_action_pressed("interact") or _mouse_down
	_state_t -= delta
	match _state:
		"back":
			# 背對著你哼歌（棉花糖鎮的旋律）
			_hum_t -= delta
			if _hum_t <= 0:
				_hum_t = 0.45
				Tones.play(self, HUM[_hum_i % HUM.size()] * 0.5, -14.0)
				_hum_i += 1
			if _state_t <= 0:
				_state = "warn"
				_state_t = 0.55
		"warn":
			if _state_t <= 0:
				_state = "look"
				_state_t = 1.4
		"look":
			if held and _p > 0.02 and not caught:
				caught = true
				Tones.buzz(self, 0.2)
			if _state_t <= 0:
				_state = "back"
				_state_t = _rng.randf_range(1.2, 2.6)
	if held and _state != "look":
		_p = minf(1.0, _p + SPEED * delta)
	if _p >= 1.0:
		_running = false
		done.emit()


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#e3e3e0"))
	a.draw_rect(Rect2(0, 600, 1280, 120), Color("#cfcfcb"))
	a.draw_string(f, Vector2(0, 60), "一二三木頭人：去拿大衣口袋裡的底片", HORIZONTAL_ALIGNMENT_CENTER, 1280, 30, Color("#c2558a"))
	a.draw_string(f, Vector2(0, 98), "按住 E／空白鍵（手機：按住畫面）前進。哼歌停下來的時候，要放開！", HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color("#888888"))
	# 洗衣機
	a.draw_circle(Vector2(1150, 400), 120, Color("#a8a8a4"))
	a.draw_circle(Vector2(1150, 400), 90, Color("#c4c4c0"))
	# 門口的大衣
	a.draw_line(Vector2(1000, 300), Vector2(1000, 330), Color("#7a7a7a"), 3)
	a.draw_colored_polygon(PackedVector2Array([Vector2(970, 330), Vector2(1030, 330), Vector2(1050, 520), Vector2(950, 520)]), Color("#f7f7f5"))
	a.draw_rect(Rect2(1010, 430, 26, 30), Color("#e4e4e0"))
	# 和平鴿（只穿襯衫，背對你）
	var facing := _state == "look"
	a.draw_set_transform(Vector2(760, 640), 0.0, Vector2(2.4, 2.4))
	Critter.draw_dove(a, 1.0, false, 1.0)
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not facing:
		# 背影：用頭髮蓋住面具
		Critter.ellipse(a, Vector2(760, 640) + Vector2(0, -166) * 2.4, Vector2(17, 19) * 2.4, Color("#1d1d1d"))
	if _state == "warn":
		a.draw_string(f, Vector2(700, 160), "……", HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color("#333333"))
	if facing:
		a.draw_string(f, Vector2(600, 150), "（他轉過來了）", HORIZONTAL_ALIGNMENT_CENTER, 320, 24, Color("#e05780"))
	elif _state == "back":
		a.draw_string(f, Vector2(600, 150), "♪ ～", HORIZONTAL_ALIGNMENT_CENTER, 320, 30, Color("#999999"))
	# 小布
	var pip := START.lerp(GOAL, _p)
	a.draw_set_transform(pip, 0.0, Vector2(1.8, 1.8))
	Critter.draw(a, "sheep", Color("#fffdf8"), 1.0, Vector2(1, 0), not caught, false, true,
		{"grey_patch": GameState.has("c2_grey_patch")})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if caught:
		a.draw_string(f, Vector2(0, 690), "和平鴿：小布想幫我拿衣服嗎？好乖。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color("#555555"))
