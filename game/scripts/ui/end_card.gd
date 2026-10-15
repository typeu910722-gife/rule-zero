extends CanvasLayer
## 原型的章節結尾選單。
## mode "to_ch2"：第一章結束、第二章預告播完後才出現（繼續第二章／回到標題）。
## mode "c2_day2"：第二章目前做到第二天。

const CHAPTER2 := "res://scenes/chapter2.tscn"
const TITLE := "res://scenes/main.tscn"

var mode := "to_ch2"


func _ready() -> void:
	layer = 60
	var bg := ColorRect.new()
	bg.color = Color("#1b1620") if mode == "to_ch2" else Color("#1c1c1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(400, 190)
	box.custom_minimum_size = Vector2(480, 300)
	box.add_theme_constant_override("separation", 16)
	add_child(box)
	var t := Label.new()
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", Color("#f3e9f1"))
	box.add_child(t)
	var hint := Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("#a39ba8"))
	box.add_child(hint)
	var first: Button
	if mode == "to_ch2":
		t.text = "第二章「漂白鎮」"
		hint.text = "第一章未發現的秘密：%d 個。重玩時試試不同的選擇吧。" % \
			(GameState.SECRETS.size() - GameState.SECRETS.keys().filter(func(k): return GameState.has(k)).size())
		first = _button(box, "繼續", func(): get_tree().change_scene_to_file(CHAPTER2))
		_button(box, "存檔並回到標題", _to_title)
	else:
		t.text = "第二章「漂白鎮」　第二天　—　完\n（第三天製作中）"
		hint.text = "操行：%d 分　｜　本章秘密：%d / %d" % [GameState.conduct, GameState.secrets_found().size(), GameState.secret_defs().size()]
		first = _button(box, "回到標題", _to_title)
	if not OS.has_feature("web"):
		_button(box, "離開遊戲", func(): get_tree().quit())
	first.grab_focus.call_deferred()


func _button(box: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _to_title() -> void:
	Dialogue.set_bg("none")
	get_tree().change_scene_to_file(TITLE)
