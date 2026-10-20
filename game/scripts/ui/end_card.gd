extends CanvasLayer
## 試玩版的最後：第一章結束的卡片。

func _ready() -> void:
	layer = 60
	Motif.play(self, "sting")
	var bg := ColorRect.new()
	bg.color = Color("#1b1620")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pic := TextureRect.new()
	pic.texture = load("res://art/ui_chapter_end_bg.jpg")
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.modulate = Color(1, 1, 1, 1)
	add_child(pic)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.06, 0.1, 0.12)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var box := VBoxContainer.new()
	box.position = Vector2(440, 200)
	box.custom_minimum_size = Vector2(400, 300)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var t := Label.new()
	t.text = "第一章「歡迎回來」\n— 完 —"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color("#4a3b47"))
	box.add_child(t)
	var hint := Label.new()
	hint.text = "未發現的秘密：%d 個。重玩時試試不同的選擇吧。" % (GameState.SECRETS.size() - GameState.secrets_found().size())
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("#6d5a68"))
	box.add_child(hint)
	# 第一章結束：搭著夜車，直接往第二章（第一章的選擇會帶過去）
	var next := Button.new()
	next.text = "前往第二章「漂白鎮」"
	next.pressed.connect(func():
		var Main := load("res://scripts/main.gd")
		Main.enter_chapter2(get_tree()))
	box.add_child(next)
	var again := Button.new()
	again.text = "回到標題"
	again.pressed.connect(func():
		Dialogue.set_bg("none")
		get_tree().reload_current_scene())
	box.add_child(again)
	var quit := Button.new()
	quit.text = "離開遊戲"
	quit.pressed.connect(func(): get_tree().quit())
	if not OS.has_feature("web"):
		box.add_child(quit)
	next.grab_focus.call_deferred()
