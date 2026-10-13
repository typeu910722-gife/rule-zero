extends CanvasLayer
## 原型的最後：第二章開場後才出現選單。

func _ready() -> void:
	layer = 60
	var bg := ColorRect.new()
	bg.color = Color("#1b1620")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(440, 200)
	box.custom_minimum_size = Vector2(400, 300)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var t := Label.new()
	t.text = "第二章「新的 Fen」\n（製作中）"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color("#f3e9f1"))
	box.add_child(t)
	var hint := Label.new()
	hint.text = "未發現的秘密：%d 個。重玩時試試不同的選擇吧。" % (GameState.SECRETS.size() - GameState.secrets_found().size())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("#a39ba8"))
	box.add_child(hint)
	var again := Button.new()
	again.text = "從第一章重新開始"
	again.pressed.connect(func():
		Dialogue.set_bg("none")
		get_tree().reload_current_scene())
	box.add_child(again)
	var quit := Button.new()
	quit.text = "離開遊戲"
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)
	again.grab_focus.call_deferred()
