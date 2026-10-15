extends CanvasLayer
## 修剪（第二章小遊戲 5）：用印著小花的粉紅色剪刀，一根一根剪掉小棘的刺。
## 每剪一根，小棘的笑容計量表往下掉；掉到紅色，和平鴿就按遙控器把它「電」回綠色。
## 操作：點一根刺剪掉；鍵盤按 E 剪下一根。
## leave：剪到剩幾根就停（劇本會在中途停下來演那封信，再決定要不要留下最後一根）。

signal done

const TOTAL := 12
const ORIGIN := Vector2(640, 470)
const SCALE := 5.0

var quills := TOTAL
var leave := 0
var _smile := 1.0
var _zap := 0.0
var _running := false
var _area: Control
var _scissors := Vector2(-100, -100)
var _cotton: Array = []


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast:
		quills = leave
		queue_free()
		return
	_running = true
	if quills <= leave:
		_running = false
		queue_free()
		return
	await done
	queue_free()


func _quill_tip(k: int) -> Vector2:
	var head := ORIGIN + Vector2(0, -24) * SCALE
	var a := PI + PI * (k + 0.5) / TOTAL
	return head + Vector2.from_angle(a) * 34 * SCALE


func _cut(k: int, close := false) -> void:
	if k >= quills:
		return
	quills -= 1
	_smile -= 0.22
	Tones.play(self, 1567.98, -12.0)
	if close:
		# 剪太靠近皮膚：剪到肉，棉花露出來
		_cotton.append(_quill_tip(k).lerp(ORIGIN + Vector2(0, -24) * SCALE, 0.7))
	if _smile < 0.25:
		_zap = 0.6
		_smile = 0.9
		Tones.buzz(self, 0.4)
	if quills <= leave:
		_running = false
		await get_tree().create_timer(0.6).timeout
		done.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	_zap = maxf(0.0, _zap - delta)
	_area.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_scissors = event.position


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_scissors = event.position
		var head := ORIGIN + Vector2(0, -24) * SCALE
		for k in quills:
			var tip := _quill_tip(k)
			var d: float = event.position.distance_to(tip.lerp(head, 0.35))
			if d < 50:
				get_viewport().set_input_as_handled()
				_cut(quills - 1, event.position.distance_to(head) < 120)
				return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_cut(quills - 1)


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#f4f4f2"))
	a.draw_string(f, Vector2(0, 50), "修剪！一根一根剪掉刺（點刺／按 E）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#c2558a"))
	a.draw_string(f, Vector2(0, 84), "注意不要剪到肉喔～　小棘的笑容要保持在綠色！", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#888888"))
	a.draw_rect(Rect2(ORIGIN + Vector2(-200, 10), Vector2(400, 30)), Color("#bdbdbd"))
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _zap
	a.draw_set_transform(ORIGIN + shake, 0.0, Vector2(SCALE, SCALE))
	Critter.draw(a, "hedgehog", Color("#3a3a3a"), 1.0, Vector2.ZERO, _smile > 0.4, false, false, {"quills": 0})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var head := ORIGIN + Vector2(0, -24) * SCALE + shake
	for k in quills:
		var ang := PI + PI * (k + 0.5) / TOTAL
		var base := head + Vector2.from_angle(ang) * 18 * SCALE
		var tip := head + Vector2.from_angle(ang) * 34 * SCALE
		var side := Vector2.from_angle(ang + PI / 2) * 9
		a.draw_colored_polygon(PackedVector2Array([base - side, base + side, tip]), Color("#2a2a2a"))
	for c in _cotton:
		a.draw_circle(c, 12, Color("#fbfbfb"))
		a.draw_arc(c, 12, 0, TAU, 12, Color("#c9c9c9"), 2)
	# 笑容計量表
	var meter := Rect2(1060, 200, 40, 300)
	a.draw_rect(meter, Color("#eeeeee"))
	a.draw_rect(Rect2(meter.position + Vector2(0, meter.size.y * (1 - _smile)), Vector2(40, meter.size.y * _smile)),
		Color("#7ccf8a") if _smile > 0.4 else Color("#e05780"))
	a.draw_rect(meter, Color("#9a9a9a"), false, 2)
	a.draw_string(f, Vector2(1000, 540), "笑容", HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color("#555555"))
	if _zap > 0:
		a.draw_string(f, Vector2(0, 680), "嗶——", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color("#e05780"))
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _zap * 0.4))
	# 剪刀
	if _scissors.x > 0:
		a.draw_circle(_scissors + Vector2(-10, 14), 9, Color("#ff9ebb"))
		a.draw_circle(_scissors + Vector2(10, 14), 9, Color("#ff9ebb"))
		a.draw_line(_scissors + Vector2(-6, 6), _scissors + Vector2(8, -26), Color("#c0c0c0"), 4)
		a.draw_line(_scissors + Vector2(6, 6), _scissors + Vector2(-8, -26), Color("#c0c0c0"), 4)
	a.draw_string(f, Vector2(0, 620), "剩下 %d 根" % quills, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color("#8a4b68"))
