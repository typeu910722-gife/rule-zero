extends CanvasLayer
## 探視：按住不要拉那條線。拉一下，棉花會鼓出來，警戒上升。
## 介面是可愛的；殘忍的是「拉了會怎樣」。

signal done

var _hold := 0.0
var _running := false
var _down := false
var _area: Control


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw)
	add_child(_area)
	var pull := Button.new()
	pull.text = "拉一下"
	pull.position = Vector2(560, 520)
	pull.pressed.connect(_pull)
	add_child(pull)
	var leave := Button.new()
	leave.text = "把手放下"
	leave.position = Vector2(700, 520)
	leave.pressed.connect(_finish)
	add_child(leave)


func play() -> void:
	if GameState.fast:
		queue_free()
		return
	_running = true
	await done
	queue_free()


func _process(delta: float) -> void:
	if not _running:
		return
	var hold := _down or Input.is_action_pressed("interact")
	if hold:
		_hold = minf(1.0, _hold + delta / 4.0)
	else:
		_hold = maxf(0.0, _hold - delta / 3.0)
	_area.queue_redraw()
	if _hold >= 1.0:
		_finish()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_down = event.pressed


func _pull() -> void:
	GameState.set_flag("wire_pulled")
	_finish()


func _finish() -> void:
	if not _running:
		return
	_running = false
	done.emit()


func _draw() -> void:
	var f: Font = GameState.font
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color("#e7eee9"))
	_area.draw_rect(Rect2(180, 250, 220, 90), Color("#f7f7f4"))
	_area.draw_rect(Rect2(200, 230, 70, 36), Color("#ffffff"))
	_area.draw_circle(Vector2(250, 248), 6, Color("#f4a3c1"))
	_area.draw_line(Vector2(400, 270), Vector2(860, 180), Color("#c5d5ce"), 3)
	_area.draw_circle(Vector2(860, 180), 16, Color("#f7c1d0"))
	_area.draw_arc(Vector2(860, 180), 16, 0, TAU * _hold, 24, Color("#e27a9a"), 4)
	_area.draw_string(f, Vector2(0, 120), "不要拉那條線", HORIZONTAL_ALIGNMENT_CENTER, 1280, 36, Color("#3e5c52"))
	_area.draw_string(f, Vector2(0, 170), "按住畫面，或按住 E。拉一下也可以。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color("#6a8a80"))
