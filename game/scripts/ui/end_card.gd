extends CanvasLayer
## 原型的章節結尾選單。
## mode "to_ch2"：第一章結束、第二章預告播完後才出現（繼續第二章／回到標題）。
## mode "c2_done"：第二章結算（秘密、操行、每個居民的去向）。

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
		box.position = Vector2(340, 70)
		box.custom_minimum_size = Vector2(600, 300)
		t.text = "第二章　漂白鎮　—　完"
		var found := GameState.secrets_found().size()
		var total := GameState.secret_defs().size()
		hint.text = "發現的秘密　%s　(%d / %d)　　操行　%d 分" % ["★".repeat(found) + "☆".repeat(total - found), found, total, GameState.conduct]
		var fates := RichTextLabel.new()
		fates.bbcode_enabled = true
		fates.fit_content = true
		fates.custom_minimum_size = Vector2(600, 0)
		fates.add_theme_font_size_override("normal_font_size", 22)
		fates.add_theme_color_override("default_color", Color("#d8d0d6"))
		var names := {"baimian": "白面", "xiaoji": "小棘", "tiaoma": "條碼", "gaga": "嘎嘎", "zhongzhong": "重重", "youyou": "鼬鼬"}
		var words := {"aboard": "上車", "graduated": "[color=#9a9a9a]畢業[/color]", "dead": "[color=#8e3b46]處分[/color]", "unknown": "[color=#9a9a9a]留在月台[/color]"}
		var lines := []
		var fate_map: Dictionary = GameState.meta.get("ch2_fates", {})
		for id in names:
			lines.append("%s　%s" % [names[id], words.get(fate_map.get(id, ""), "？")])
		fates.text = "[center]%s[/center]" % "　　".join(lines.slice(0, 3)) + "\n[center]%s[/center]" % "　　".join(lines.slice(3))
		box.add_child(fates)
		var next := Label.new()
		next.text = "第三章「慈愛綜合醫院」（製作中）"
		next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next.add_theme_font_size_override("font_size", 20)
		next.add_theme_color_override("font_color", Color("#a39ba8"))
		box.add_child(next)
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
