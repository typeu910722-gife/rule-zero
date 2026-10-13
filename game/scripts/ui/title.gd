extends CanvasLayer
## 標題畫面。會依跨周目記錄（GameState.meta）悄悄改變：
## 車票上的戳章數＝已完成章數＋1；玩過一章以後，角落會多一行「歡迎回來。」

signal new_game
signal continue_game

var _area: Control


func _ready() -> void:
	layer = 70
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.draw.connect(_draw_area)
	add_child(_area)

	var box := VBoxContainer.new()
	box.position = Vector2(120, 380)
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var cont := _button("繼續", func(): continue_game.emit())
	cont.disabled = not GameState.has_save()
	box.add_child(cont)
	box.add_child(_button("新遊戲", func(): new_game.emit()))
	box.add_child(_button("離開", func(): get_tree().quit()))
	(cont if not cont.disabled else box.get_child(1)).grab_focus.call_deferred()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#fff8f0") if state != "focus" and state != "hover" else Color("#ffe1ec")
		sb.border_color = Color("#e8a0bf") if state != "disabled" else Color("#e6dce2")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(16)
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color("#4a3b47"))
	b.add_theme_color_override("font_focus_color", Color("#c2558a"))
	b.add_theme_color_override("font_hover_color", Color("#c2558a"))
	b.add_theme_color_override("font_disabled_color", Color("#c9bcc4"))
	b.pressed.connect(cb)
	return b


func _draw_area() -> void:
	var f: Font = GameState.font
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color("#fbe7ee"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 60:
		_area.draw_circle(Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)), rng.randf_range(2, 5),
			[Color("#ffd6e0"), Color("#fff1a8"), Color("#e2d4f7")][k % 3])
	_area.draw_string(f, Vector2(110, 210), "第零條規則", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color("#6d4c5c"))
	_area.draw_string(f, Vector2(116, 270), "Rule Zero", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#b56576"))
	_area.draw_string(f, Vector2(116, 320), "一個溫柔的世界，藏著被遺忘的規則。", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#a38b98"))

	# 小布
	_area.draw_set_transform(Vector2(820, 560), 0.0, Vector2(6, 6))
	Critter.draw(_area, "sheep", Color("#fffdf8"), 1.0, Vector2(-0.3, 0.2), true, false, true)
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 車票：戳章會隨著完成的章數變多
	var ticket := Rect2(960, 120, 250, 140)
	_area.draw_rect(ticket, Color("#fff8ec"))
	_area.draw_rect(ticket, Color("#d4a373"), false, 3)
	_area.draw_string(f, ticket.position + Vector2(18, 38), "棉花糖鎮　單程票", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#7f5539"))
	var stamps := clampi(int(GameState.meta.get("chapters_done", 0)) + 1, 1, 6)
	for k in stamps:
		var c := ticket.position + Vector2(40 + (k % 3) * 70, 75 + (k / 3) * 40)
		_area.draw_arc(c, 18, 0, TAU, 24, Color(0.75, 0.2, 0.25, 0.75), 3)
		_area.draw_circle(c, 4, Color(0.75, 0.2, 0.25, 0.6))

	if int(GameState.meta.get("chapters_done", 0)) >= 1:
		_area.draw_string(f, Vector2(0, 690), "歡迎回來。", HORIZONTAL_ALIGNMENT_RIGHT, 1250, 18, Color("#c9b3bf"))
