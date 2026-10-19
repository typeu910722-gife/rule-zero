extends CanvasLayer
## 手機觸控操作：左下虛擬搖桿、右下「互動」「日記」按鈕。
## 只在有觸控螢幕時出現；對話、選項、公告欄直接點畫面即可。

## 由 main 提供：回傳 "explore"（可走動）、"menu"（日記開著）或 ""（隱藏）
var mode_provider: Callable

const JOY_CENTER := Vector2(150, 570)
const JOY_RADIUS := 90.0
const BTN_INTERACT := Vector2(1150, 590)
const BTN_MENU := Vector2(1170, 450)
const BTN_RADIUS := 62.0

var enabled := false
var _joy_index := -1
## 浮動搖桿：手指按在左半邊哪裡，搖桿就出現在哪裡；放開回到預設位置
var _joy_center := JOY_CENTER
const JOY_ZONE := Rect2(0, 160, 560, 560)
var _joy_vec := Vector2.ZERO
var _area: Control
var _rotate_hint: Label
var _joy_visible := false
var _buttons_visible := false
var _menu_only := false


func _ready() -> void:
	layer = 55
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios")
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	_rotate_hint = Label.new()
	_rotate_hint.text = "請把手機橫過來玩 ↻"
	_rotate_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rotate_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rotate_hint.add_theme_font_size_override("font_size", 40)
	_rotate_hint.add_theme_color_override("font_color", Color("#b56576"))
	_rotate_hint.visible = false
	add_child(_rotate_hint)


func _process(_delta: float) -> void:
	if not enabled:
		return
	var win := get_window().size
	_rotate_hint.visible = win.y > win.x
	var mode: String = mode_provider.call() if mode_provider.is_valid() else ""
	var joystick_game := get_tree().get_nodes_in_group("touch_joystick").size() > 0
	_joy_visible = mode == "explore" or joystick_game
	_buttons_visible = mode in ["explore", "menu"]
	_menu_only = mode == "menu"
	if not _joy_visible and _joy_index != -1:
		_release_joystick()
	_area.queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		GameState.last_device = "touch"
		if event.pressed:
			if _joy_visible and _joy_index == -1 and (JOY_ZONE.has_point(event.position) or event.position.distance_to(JOY_CENTER) < JOY_RADIUS * 1.6):
				_joy_index = event.index
				_joy_center = event.position.clamp(Vector2(JOY_RADIUS + 10, 160 + JOY_RADIUS), Vector2(560, 720 - JOY_RADIUS - 10))
				_update_joystick(event.position)
				get_viewport().set_input_as_handled()
			elif _buttons_visible and event.position.distance_to(BTN_INTERACT) < BTN_RADIUS and not _menu_only:
				_fire("interact")
				get_viewport().set_input_as_handled()
			elif _buttons_visible and event.position.distance_to(BTN_MENU) < BTN_RADIUS * 0.8:
				_fire("menu")
				get_viewport().set_input_as_handled()
		elif event.index == _joy_index:
			_release_joystick()
	elif event is InputEventScreenDrag and event.index == _joy_index:
		_update_joystick(event.position)
		get_viewport().set_input_as_handled()


func _update_joystick(pos: Vector2) -> void:
	_joy_vec = ((pos - _joy_center) / JOY_RADIUS).limit_length(1.0)
	var dirs := {"move_left": -_joy_vec.x, "move_right": _joy_vec.x, "move_up": -_joy_vec.y, "move_down": _joy_vec.y}
	for action in dirs:
		var v: float = dirs[action]
		if v > 0.2:
			Input.action_press(action, v)
		else:
			Input.action_release(action)


func _release_joystick() -> void:
	_joy_index = -1
	_joy_vec = Vector2.ZERO
	_joy_center = JOY_CENTER
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)


func _fire(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)


func _draw_area() -> void:
	if not enabled:
		return
	var f: Font = GameState.font
	if _joy_visible:
		_area.draw_circle(_joy_center, JOY_RADIUS, Color(1, 1, 1, 0.35))
		_area.draw_arc(_joy_center, JOY_RADIUS, 0, TAU, 40, Color(0.9, 0.6, 0.75, 0.7), 4)
		_area.draw_circle(_joy_center + _joy_vec * JOY_RADIUS * 0.6, 38, Color(1, 0.85, 0.9, 0.85))
	if _buttons_visible:
		if not _menu_only:
			_area.draw_circle(BTN_INTERACT, BTN_RADIUS, Color(1, 0.88, 0.92, 0.8))
			_area.draw_arc(BTN_INTERACT, BTN_RADIUS, 0, TAU, 40, Color("#e8a0bf"), 4)
			_area.draw_string(f, BTN_INTERACT + Vector2(-60, 10), "互動", HORIZONTAL_ALIGNMENT_CENTER, 120, 28, Color("#8a4b68"))
		_area.draw_circle(BTN_MENU, BTN_RADIUS * 0.75, Color(1, 1, 1, 0.75))
		_area.draw_arc(BTN_MENU, BTN_RADIUS * 0.75, 0, TAU, 40, Color("#cdb4db"), 3)
		_area.draw_string(f, BTN_MENU + Vector2(-60, 8), "日記", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Color("#6d597a"))
