extends CanvasLayer
## 一輪結束的結局卡：結局名稱、這一輪發現的秘密、鎮長懷疑值、車票戳章。
## 玩家選「再一次」→ 下一輪；「回到標題」→ 也算進入下一輪，只是先回標題。

signal chosen(next_loop: bool)

var ending := ""


func _ready() -> void:
	layer = 60
	var bg := ColorRect.new()
	bg.color = Color("#1b1620")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var info: Dictionary = GameState.ENDINGS.get(ending, {"title": ending, "desc": ""})
	var idx := GameState.ENDING_ORDER.find(ending) + 1
	var seen: Array = GameState.meta.get("endings", [])
	var loop := GameState.loop_number()

	var t := RichTextLabel.new()
	t.position = Vector2(240, 60)
	t.size = Vector2(800, 470)
	t.bbcode_enabled = true
	t.add_theme_color_override("default_color", Color("#f3e9f1"))
	t.add_theme_font_size_override("normal_font_size", 22)
	var txt := "[center][color=#a39ba8]第 %d 個小布　的　第三天[/color]\n\n" % loop
	txt += "[font_size=40]結局 %d　%s[/font_size]\n\n" % [idx, info.title]
	txt += "[color=#d8c8d6]%s[/color][/center]\n\n" % info.desc
	var found := GameState.secrets_found()
	txt += "發現的秘密　%d / %d" % [found.size(), GameState.SECRETS.size()]
	if not found.is_empty():
		txt += "\n[font_size=18][color=#c9b3bf]%s[/color][/font_size]" % "、".join(found.map(func(k): return GameState.SECRETS[k]))
	txt += "\n鎮長懷疑值　%d / 100" % GameState.suspicion
	txt += "\n看過的結局　%d / %d" % [seen.size(), GameState.ENDING_ORDER.size()]
	txt += "\n\n[center][color=#e8a0bf]車票上，多了一個戳章。[/color]\n"
	txt += "[font_size=18][color=#a39ba8]你會記得一些事。不是全部。[/color][/font_size][/center]"
	t.text = txt
	add_child(t)

	var box := HBoxContainer.new()
	box.position = Vector2(380, 560)
	box.custom_minimum_size = Vector2(520, 0)
	box.add_theme_constant_override("separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	var again := _button("再搭一次火車（第 %d 個）" % (loop + 1))
	again.pressed.connect(func(): chosen.emit(true))
	box.add_child(again)
	var title := _button("回到標題")
	title.pressed.connect(func(): chosen.emit(false))
	box.add_child(title)
	again.grab_focus.call_deferred()


func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "focus", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#2a2230") if state == "normal" else Color("#3a2c40")
		sb.border_color = Color("#e8a0bf")
		sb.set_border_width_all(2 if state == "normal" else 3)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color("#f3e9f1"))
	b.add_theme_color_override("font_hover_color", Color("#ffd1e3"))
	b.add_theme_color_override("font_focus_color", Color("#ffd1e3"))
	b.pressed.connect(func(): Sound.sfx("choice"))
	return b
