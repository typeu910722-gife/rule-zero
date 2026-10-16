extends CanvasLayer
## 原型的章節結尾選單。
## mode "to_ch2"：第一章結束、第二章預告播完後才出現（繼續第二章／回到標題）。
## mode "c2_done"：第二章結算（秘密、操行、每個居民的去向）。

const CHAPTER2 := "res://scenes/chapter2.tscn"
const TITLE := "res://scenes/main.tscn"

var mode := "to_ch2"

## 第二章的外包美術（缺檔時退回原本的文字版面）
const UI := "res://art/ch2/ui/"
const RESULTS_TEX := UI + "ch2_ui_07_results.png"
const CH2_CARD_TEX := UI + "ch2_ui_09_chapter2_blank.png"
const CH3_CARD_TEX := UI + "ch2_ui_09_chapter3_blank.png"
## 居民去向 → 圖示（上車＝車、畢業＝白、處分＝×、留在月台＝站）
const FATE_ICONS := {"aboard": "train", "graduated": "graduate", "dead": "disposed", "unknown": "platform"}
## 結算框在畫面上的縮放與位置（原圖 1080×650）
const RES_SCALE := 0.8
const RES_POS := Vector2(208, 8)
const NAMES := {"baimian": "白面", "xiaoji": "小棘", "tiaoma": "條碼", "gaga": "嘎嘎", "zhongzhong": "重重", "youyou": "鼬鼬"}


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
		_card_title(box, t, CH2_CARD_TEX, Vector2(480, 96))
		hint.text = "第一章未發現的秘密：%d 個。重玩時試試不同的選擇吧。" % \
			(GameState.SECRETS.size() - GameState.SECRETS.keys().filter(func(k): return GameState.has(k)).size())
		first = _button(box, "繼續", func(): get_tree().change_scene_to_file(CHAPTER2))
		_button(box, "存檔並回到標題", _to_title)
	elif ResourceLoader.exists(RESULTS_TEX):
		_build_results(t, hint)
		box.position = Vector2(440, 556)
		box.custom_minimum_size = Vector2(400, 0)
		first = _button(box, "回到標題", _to_title)
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


## 章節標題：外包的空白名牌框（九宮格），字由遊戲寫在上面
func _card_title(box: Control, t: Label, tex_path: String, size: Vector2) -> void:
	if not ResourceLoader.exists(tex_path):
		return
	var card := _nine(tex_path, size)
	box.add_child(card)
	box.move_child(card, t.get_index())
	t.reparent(card, false)
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Color("#5a5560"))


func _nine(tex_path: String, size: Vector2) -> NinePatchRect:
	var n := NinePatchRect.new()
	n.texture = load(tex_path)
	n.patch_margin_left = 24
	n.patch_margin_top = 24
	n.patch_margin_right = 24
	n.patch_margin_bottom = 24
	n.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	n.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	n.custom_minimum_size = size
	n.size = size
	return n


## 第二章結算：外包的結算框（標題「第二章　漂白鎮　—　完」已印在圖上），
## 秘密、操行寫在欄位裡，每個居民一行：去向圖示＋名字＋去向
func _build_results(t: Label, hint: Label) -> void:
	t.visible = false
	hint.visible = false
	var area := Control.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.draw.connect(_draw_results.bind(area))
	add_child(area)
	move_child(area, 1)
	# 第三章預告：空白的章節框
	var next := Label.new()
	next.text = "第三章「慈愛綜合醫院」（製作中）"
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next.add_theme_font_size_override("font_size", 20)
	next.add_theme_color_override("font_color", Color("#7a7480"))
	# 放在最後一條橫線下面的右側
	var p := RES_POS + Vector2(560, 534) * RES_SCALE
	if ResourceLoader.exists(CH3_CARD_TEX):
		var card := _nine(CH3_CARD_TEX, Vector2(380, 70))
		card.position = p
		add_child(card)
		card.add_child(next)
		next.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		next.position = p
		next.size = Vector2(380, 70)
		add_child(next)


func _draw_results(area: Control) -> void:
	var f: Font = GameState.font
	var s := RES_SCALE
	var tex: Texture2D = _tex(RESULTS_TEX)
	area.draw_texture_rect(tex, Rect2(RES_POS, tex.get_size() * s), false)
	var p := func(x: float, y: float) -> Vector2: return RES_POS + Vector2(x, y) * s
	var ink := Color("#4a4550")
	var found := GameState.secrets_found().size()
	var total := GameState.secret_defs().size()
	# 「秘密」「操行」兩個欄位：寫在標籤右邊（原圖座標，標籤在 y≈148～168）
	area.draw_string(f, p.call(124, 168), "%s　(%d / %d)" % ["★".repeat(found) + "☆".repeat(total - found), found, total], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	area.draw_string(f, p.call(524, 168), "%d 分" % GameState.conduct, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	var words := {"aboard": ["上車", ink], "graduated": ["畢業", Color("#9a9a9a")], "dead": ["處分", Color("#8e3b46")], "unknown": ["留在月台", Color("#9a9a9a")]}
	var fate_map: Dictionary = GameState.meta.get("ch2_fates", {})
	var i := 0
	for id in NAMES:
		# 每個居民寫在一條橫線上（原圖橫線 y=240、296、…、520）
		var line_y := 240.0 + i * 56
		var fate: String = fate_map.get(id, "")
		var icon := UI + "ch2_ui_07_status_%s.png" % FATE_ICONS.get(fate, "platform")
		if fate in FATE_ICONS and ResourceLoader.exists(icon):
			area.draw_texture_rect(_tex(icon), Rect2(p.call(72, line_y - 52), Vector2(48, 48) * s), false)
		area.draw_string(f, p.call(140, line_y - 14), NAMES[id], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
		var w: Array = words.get(fate, ["？", ink])
		area.draw_string(f, p.call(260, line_y - 14), w[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, w[1])
		i += 1


func _button(box: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	box.add_child(b)
	return b


func _to_title() -> void:
	Dialogue.set_bg("none")
	get_tree().change_scene_to_file(TITLE)


## 畫圖時用到的貼圖要留著參照，不然畫完就被釋放、畫面上只剩白色
var _tex_cache := {}


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]
