extends CanvasLayer
## 歡迎會小遊戲：接住波波空投的糖果。
## 〔異常·極小〕糖果中會混進一顆灰色鈕扣，接到它不加分也不扣分。

signal done(score: int)

const DURATION := 20.0
const BASKET_Y := 640.0
const BASKET_W := 120.0

var _area: Control
var _score := 0
var _time := 0.0
var _spawn := 0.0
var _basket_x := 640.0
var _moving := false
var _items: Array = []   # {pos, kind, speed}
var _button_time := 0.0
var _button_spawned := false
var _running := false


func _ready() -> void:
	layer = 30
	add_to_group("touch_joystick")
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	_button_time = randf_range(5.0, 14.0)


func play() -> int:
	if GameState.fast:
		queue_free()
		return 0
	_running = true
	var s: int = await done
	queue_free()
	return s


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta
	var dir := Input.get_axis("move_left", "move_right")
	_basket_x = clampf(_basket_x + dir * 560.0 * delta, 70, 1210)
	_moving = dir != 0.0
	_spawn -= delta
	if _spawn <= 0 and _time < DURATION - 1.5:
		_spawn = randf_range(0.35, 0.6)
		_items.append({"pos": Vector2(randf_range(80, 1200), -20), "kind": "candy", "speed": randf_range(220, 340), "hue": randf()})
	if not _button_spawned and _time >= _button_time:
		_button_spawned = true
		_items.append({"pos": Vector2(randf_range(200, 1080), -20), "kind": "button", "speed": 200.0, "hue": 0.0})
	for it in _items.duplicate():
		it.pos = it.pos + Vector2(0, it.speed * delta)
		if it.pos.y > BASKET_Y - 20 and it.pos.y < BASKET_Y + 10 and absf(it.pos.x - _basket_x) < BASKET_W / 2:
			_items.erase(it)
			if it.kind == "candy":
				_score += 1
			else:
				GameState.set_flag("got_button")
		elif it.pos.y > 760:
			_items.erase(it)
	_area.queue_redraw()
	if _time >= DURATION:
		_running = false
		done.emit(_score)


func _draw_area() -> void:
	var f: Font = GameState.font
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color("#fde2e4"))
	_area.draw_string(f, Vector2(0, 60), "接糖果！（← → 移動）　%d 顆　剩下 %d 秒" % [_score, maxi(0, int(DURATION - _time))],
		HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#b56576"))
	for it in _items:
		if it.kind == "candy":
			var c := Color.from_hsv(it.hue, 0.35, 1.0)
			_area.draw_circle(it.pos, 14, c)
			_area.draw_colored_polygon(PackedVector2Array([it.pos + Vector2(-14, 0), it.pos + Vector2(-26, -8), it.pos + Vector2(-26, 8)]), c)
			_area.draw_colored_polygon(PackedVector2Array([it.pos + Vector2(14, 0), it.pos + Vector2(26, -8), it.pos + Vector2(26, 8)]), c)
		else:
			_area.draw_circle(it.pos, 11, Color("#8a8a8a"))
			for o in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
				_area.draw_circle(it.pos + o, 1.6, Color("#555"))
	# 小布捧著籃子（背對畫面、朝上看糖果）
	_area.draw_set_transform(Vector2(_basket_x, BASKET_Y + 76), 0.0, Vector2(1.5, 1.5))
	Critter.draw(_area, "sheep", Color.WHITE, 1.0, Vector2.UP, true, false, false, int(_time * 8.0) if _moving else -1)
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_area.draw_rect(Rect2(_basket_x - BASKET_W / 2, BASKET_Y, BASKET_W, 36), Color("#ddb892"))
	_area.draw_rect(Rect2(_basket_x - BASKET_W / 2, BASKET_Y, BASKET_W, 8), Color("#b08968"))
	# 竹籃的提把與編織紋
	_area.draw_arc(Vector2(_basket_x, BASKET_Y + 2), BASKET_W / 2 - 8, PI, TAU, 24, Color("#b08968"), 5)
	for k in 5:
		var x := _basket_x - BASKET_W / 2 + 14 + k * 23
		_area.draw_line(Vector2(x, BASKET_Y + 10), Vector2(x, BASKET_Y + 34), Color("#c9a27e"), 3)
