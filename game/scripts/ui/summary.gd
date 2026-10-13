extends CanvasLayer
## 原型結尾：縫線布告風格的結算畫面。

signal restart

func _ready() -> void:
	layer = 60
	var bg := ColorRect.new()
	bg.color = Color("#2a2230")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(340, 70)
	box.custom_minimum_size = Vector2(600, 560)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.add_theme_color_override("default_color", Color("#f3e9f1"))
	t.add_theme_font_size_override("normal_font_size", 22)
	var found := GameState.secrets_found()
	var stars := "★".repeat(found.size()) + "☆".repeat(GameState.SECRETS.size() - found.size())
	var txt := "[center][font_size=34]第一章　歡迎回來[/font_size]\n[color=#a39ba8]（原型：第一～二天）[/color][/center]\n\n"
	txt += "發現的秘密　　%s　(%d / %d)\n" % [stars, found.size(), GameState.SECRETS.size()]
	txt += "帶走的線頭　　%d 條\n" % GameState.threads_earned()
	txt += "懷疑值　　　　%d\n\n" % GameState.suspicion
	txt += "[color=#a39ba8]第三天（森林、鐘聲、修理）與第二章開場尚未實作。\n"
	txt += "「黃色蝴蝶結」「狐狸尾巴」在第三天；「露露哼的另一首歌」需要揉麵團小遊戲。[/color]"
	t.text = txt
	box.add_child(t)
	var b := Button.new()
	b.text = "重新開始"
	b.pressed.connect(func(): restart.emit())
	box.add_child(b)
	b.grab_focus.call_deferred()
