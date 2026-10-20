class_name Ch3Hud
extends CanvasLayer
## 第三章的狀態列：地點、膽量、每個人的棉花；選單（音量、減少驚嚇、回到標題）。

signal title_requested

var place := ""
## 第四、五章：狀態列只顯示這一行（空＝第三章的膽量、棉花）
var header := ""
var party: Array = []   # [[id, 名字]]
var _label: RichTextLabel
var _menu: PanelContainer
var menu_open := false


func _ready() -> void:
	layer = 20
	var back := Panel.new()
	back.position = Vector2(8, 6)
	back.size = Vector2(1000, 66)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.82)
	sb.set_corner_radius_all(12)
	back.add_theme_stylebox_override("panel", sb)
	add_child(back)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.position = Vector2(16, 10)
	_label.size = Vector2(980, 90)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 20)
	_label.add_theme_color_override("default_color", Color("#3d4a4f"))
	_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	var menu_btn := Button.new()
	menu_btn.text = "選單"
	menu_btn.position = Vector2(1170, 14)
	menu_btn.custom_minimum_size = Vector2(90, 44)
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.pressed.connect(toggle_menu)
	add_child(menu_btn)
	_build_menu()
	GameState.changed.connect(refresh)
	refresh()


func refresh() -> void:
	if header != "":
		_label.text = "%s　%s" % [header, place]
		return
	var t := "[b]第三章[/b]　%s　　膽量 %s\n棉花　" % [place, "★".repeat(GameState.courage) + "☆".repeat(GameState.MAX_COURAGE - GameState.courage)]
	var parts := []
	for p in party:
		var v := int(GameState.flags.get("c3_cotton_%s" % p[0], 10))
		var col := "#3d4a4f" if v > 3 else "#c0485a"
		parts.append("[color=%s]%s %d[/color]" % [col, p[1], v])
	_label.text = t + "　".join(parts)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		toggle_menu()


func toggle_menu() -> void:
	menu_open = not menu_open
	_menu.visible = menu_open
	if menu_open:
		var first := _menu.find_children("*", "Button", true, false)
		if not first.is_empty():
			(first[0] as Button).grab_focus()


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.position = Vector2(740, 70)
	_menu.custom_minimum_size = Vector2(500, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fbfcfc")
	sb.border_color = Color("#9fb3ba")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(20)
	_menu.add_theme_stylebox_override("panel", sb)
	_menu.visible = false
	add_child(_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_menu.add_child(v)
	for kind in [["Music", "配樂"], ["SFX", "音效"]]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = kind[1]
		l.custom_minimum_size.x = 60
		l.add_theme_color_override("font_color", Color("#3d4a4f"))
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0
		s.max_value = 100
		s.step = 10
		s.value = round(Audio.get_volume(kind[0]) * 100)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size.y = 32
		var k: String = kind[0]
		s.value_changed.connect(func(val: float): Audio.set_volume(k, val / 100.0))
		row.add_child(s)
		v.add_child(row)
	var g := CheckButton.new()
	g.text = "減少驚嚇與敏感內容（不閃屏、不突臉）"
	g.button_pressed = GameState.gentle()
	g.add_theme_color_override("font_color", Color("#3d4a4f"))
	g.add_theme_color_override("font_pressed_color", Color("#3d4a4f"))
	g.add_theme_color_override("font_focus_color", Color("#3d4a4f"))
	g.add_theme_color_override("font_hover_color", Color("#3d4a4f"))
	g.toggled.connect(func(on: bool): GameState.set_gentle(on))
	v.add_child(g)
	var back := Button.new()
	back.text = "回到標題（從這一段的開頭繼續）"
	back.pressed.connect(func(): title_requested.emit())
	v.add_child(back)
	var close := Button.new()
	close.text = "關閉"
	close.pressed.connect(toggle_menu)
	v.add_child(close)
