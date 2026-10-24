extends CanvasLayer
## 公告欄：棉花糖鎮好孩子守則／漂白鎮矯正守則、操行成績單。異常會悄悄改變它的內容（不提示）。

signal closed

## 第二章的外包美術（缺檔時退回程式畫的面板）
const UI := "res://art/ch2/ui/"
const RULES_TEX := UI + "ch2_ui_03_rules.png"
const DRIPS_TEX := UI + "ch2_ui_03_ink_drips.png"
const CONDUCT_TEX := UI + "ch2_ui_02_conduct.png"
const HEART_TEX := UI + "ch2_ui_11_heart_stamp.png"
## 成績單在畫面上的縮放（原圖 620×750，太高放不下 720）
const CARD_SCALE := 0.86

var _panel: PanelContainer
var _text: RichTextLabel
var _flat: StyleBoxFlat
var _drips: Control
var _card: Control


func _ready() -> void:
	layer = 45
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 560)
	_panel.position = Vector2(320, 70)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff3e0")
	sb.border_color = Color("#a1887f")
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	_flat = sb
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.add_theme_color_override("default_color", Color("#4e342e"))
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.add_theme_font_size_override("bold_font_size", 24)
	_panel.add_child(_text)
	# 第 3 條後半新加的字：墨水還沒乾，往下滴（第二章、第二天起）
	_drips = Control.new()
	_drips.draw.connect(_draw_drips)
	_text.add_child(_drips)
	# 第二章的操行成績單：外包的表格底圖，字由遊戲自己寫上去
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.visible = false
	_card.draw.connect(_draw_card)
	add_child(_card)
	for c in [dim, _panel, _text, _drips, _card]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func rules_bbcode() -> String:
	if GameState.chapter == 2:
		return bleach_rules_bbcode()
	if GameState.chapter >= 3:
		return later_rules_bbcode()
	# 第二天起：第 9 條的「回來」字型變粗，像是後來補寫的
	var back := "回來" if GameState.day < 2 else "[b]回來[/b]"
	var lines := [
		"[center][font_size=30]棉花糖鎮　好孩子守則[/font_size][/center]",
		"",
		"1. 每天都要笑嘻嘻！",
		"2. 晚上八點鐘聲響起前，要乖乖回家睡覺。",
		"3. 不可以去鐘塔後面的森林。",
		"4. 好朋友不可以吵架。" if GameState.day < 3 else "4. [color=#8e3b46][u]好朋友不可以吵架。[/u][/color]",
		"5. 名牌要一直戴好喔。",
		"6. 壞掉的東西，交給熊熊鎮長修理。",
		"7. 不要問「以前」的事。",
		"8. 鏡子是用來整理儀容的，不要盯著看太久。",
		"9. 新朋友來的時候，大家要一起說「歡迎%s」。" % back,
		"10. 守則永遠只有十條。",
		"",
		"[center][color=#a1887f][font_size=18]（按 E／空白鍵，或點一下畫面 關閉）[/font_size][/color][/center]",
	]
	return "\n".join(lines)


## 漂白鎮的矯正守則：每天會變（第二天第 3 條加字，第三天多一條）
func bleach_rules_bbcode() -> String:
	var lines := [
		"[center][font_size=30]慈愛組織　漂白鎮　矯正守則[/font_size][/center]",
		"",
		"1. 說「對不起」，要說到老師滿意為止。",
		"2. 不可以有顏色。",
		"3. 不可以哭。眼淚會弄髒棉花。" if GameState.day < 2 else "3. 不可以哭。[color=#555555]哭的人加倍。[/color]",
		"4. 不可以和河對岸的模範生說話。",
		"5. 舉報壞孩子的人，可以得到一顆糖。",
		"6. 點名沒到的人，送去洗衣房。",
		"7. 你做過的事，你自己最清楚。",
		"8. 畢業的孩子，不會再回來。" if GameState.day >= 3 else "",
		"",
		"[center][color=#9a9a9a][font_size=18]（按 E／空白鍵，或點一下畫面 關閉）[/font_size][/color][/center]",
	]
	return "\n".join(lines)


## 第三～七章的公告。每一章的「正常」都不一樣，不另外做提示。
func later_rules_bbcode() -> String:
	var lines: PackedStringArray = []
	match GameState.chapter:
		3:
			lines = PackedStringArray([
				"[center][font_size=30]慈愛綜合醫院　探視守則[/font_size][/center]",
				"",
				"1. 探視時間十五分鐘。",
				"2. 不要叫醒身體。" if GameState.day < 2 else "2. 不要叫醒身體。\n[color=#7d8f88]　尤其是捲頭髮的那個。[/color]",
				"3. 不要拉頭上的線。",
				"4. 比斯泰德棟，不准進入。",
				"5. 病歷上的字，不要念出聲。",
				"6. 空的床，不要躺上去。",
				"7. 沒有名字的人，不要問他叫什麼。",
				"8. 守則是為了你好。",
			])
		4:
			lines = PackedStringArray([
				"[center][font_size=30]班級生活公約[/font_size][/center]",
				"",
				"1. 制服要穿整齊。",
				"2. 名字寫在名牌上。",
				"3. 不要在桌上留字。",
				"4. 信件交給本人。",
				"5. 走廊上不要跑。",
				"",
				"點名：遙　小滿　希露飛　銘越　辛禾　薙文　郡主　李恩　芬　秋歌",
				"[color=#8a8074]有一個位置沒有名字。[/color]",
			])
		5:
			lines = PackedStringArray([
				"[center][font_size=30]守則的草稿[/font_size][/center]",
				"",
				"[color=#8d6e63]0. 不要想起來。[/color]",
				"[color=#a89880]（這一行被箭頭指到很後面。後面沒有寫出來。）[/color]",
				"",
				"1. 每天都要笑嘻嘻！",
				"2. 晚上八點以前回家。",
				"7. 不要問「以前」的事。",
				"",
				"[color=#a89880]頁邊：送回總部，會更乾淨。[/color]",
			])
		_:
			var zero := ""
			if GameState.has("rule_zero_seen"):
				zero = "[color=#8e3b46]0. 不要想起來。[/color]\n" if not GameState.has("rewrote_zero") else "[color=#8e3b46]0. [s]不要想起來。[/s][/color]\n"
			lines = PackedStringArray([
				"[center][font_size=30]棉花糖鎮　好孩子守則[/font_size][/center]",
				"",
				zero + "1. 每天都要笑嘻嘻！",
				"9. 新朋友來的時候，大家要一起說「歡迎[b]回來[/b]」。",
				"10. 守則永遠只有十條。",
				"11. [color=#8e3b46]笑的時候，牙齒要算清楚。[/color]",
			])
	lines.append("")
	lines.append("[center][color=#a1887f][font_size=18]（按 E／空白鍵，或點一下畫面 關閉）[/font_size][/color][/center]")
	return "\n".join(lines)


## 操行成績單
func report_bbcode() -> String:
	var lines := [
		"[center][font_size=30]慈愛組織　漂白鎮　操行成績單[/font_size][/center]",
		"",
		"姓名：%s　　分類：壞孩子" % GameState.player_name(),
		"",
		"[font_size=40]操行：%d 分[/font_size]" % GameState.conduct,
		"",
		"評語：",
		"",
		"[color=#9a9a9a][font_size=18]違反守則、不服從，會扣操行分數。\n分數太低的孩子，會得到「特別的愛」。[/font_size][/color]",
		"",
		"[center][color=#9a9a9a][font_size=18]（按 E／空白鍵，或點一下畫面 關閉）[/font_size][/color][/center]",
	]
	return "\n".join(lines)


func open_report() -> void:
	_show(report_bbcode(), _use_card())
	if visible:
		await closed


func open() -> void:
	_show(rules_bbcode())
	if visible:
		await closed


func _show(bbcode: String, card := false) -> void:
	_text.text = bbcode
	var sb := _flat
	sb.bg_color = Color("#f2f2f0") if GameState.chapter == 2 else Color("#fff3e0")
	sb.border_color = Color("#8a8a8a") if GameState.chapter == 2 else Color("#a1887f")
	_panel.add_theme_stylebox_override("panel", _rules_stylebox() if GameState.chapter == 2 else sb)
	_text.add_theme_color_override("default_color", Color("#333333") if GameState.chapter == 2 else Color("#4e342e"))
	# 第二章行距拉開一點，留位置給往下滴的墨水
	if GameState.chapter == 2:
		_text.add_theme_constant_override("line_separation", 8)
	else:
		_text.remove_theme_constant_override("line_separation")
	_panel.visible = not card
	_card.visible = card
	_card.queue_redraw()
	_drips.queue_redraw()
	visible = true
	if GameState.fast:
		close()


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if visible and (event.is_action_pressed("interact") or event.is_action_pressed("menu") or tap):
		get_viewport().set_input_as_handled()
		close()


func _use_card() -> bool:
	return GameState.chapter == 2 and ResourceLoader.exists(CONDUCT_TEX)


## 第二章守則板：外包的紙板底圖（九宮格拉伸，虛線縫邊用平鋪）
func _rules_stylebox() -> StyleBox:
	if not ResourceLoader.exists(RULES_TEX):
		return _flat
	var st := StyleBoxTexture.new()
	st.texture = load(RULES_TEX)
	st.set_texture_margin_all(24)
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	st.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	st.set_content_margin_all(36)
	return st


func _draw_drips() -> void:
	if GameState.chapter != 2 or GameState.day < 2 or not _panel.visible or not ResourceLoader.exists(DRIPS_TEX):
		return
	# 第 3 條在第 4 段（標題、空行、1、2、3）
	var f: Font = GameState.font
	var fs := 24
	var head := f.get_string_size("3. 不可以哭。", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tail := f.get_string_size("哭的人加倍。", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var y := _text.get_paragraph_offset(4) + f.get_ascent(fs) + 2
	var tex: Texture2D = _tex(DRIPS_TEX)
	# 只取有墨水的部分（原圖左右有透明邊），也只取上半段，免得蓋到下一條
	var src := Rect2(40, 0, 348, 56)
	var k := tail / src.size.x
	_drips.draw_texture_rect_region(tex, Rect2(head, y, tail, src.size.y * k), src, Color(1, 1, 1, 0.5))


func _draw_card() -> void:
	if not _use_card():
		return
	var f: Font = GameState.font
	var tex: Texture2D = _tex(CONDUCT_TEX)
	var size := tex.get_size() * CARD_SCALE
	var o := Vector2((1280 - size.x) / 2, 14)
	_card.draw_texture_rect(tex, Rect2(o, size), false)
	var ink := Color("#333333")
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * CARD_SCALE
	# 欄位（原圖座標）：姓名、分類的底線在 y=230、315；分數欄 330～500；評語留白
	_card.draw_string(f, p.call(150, 218), GameState.player_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
	_card.draw_string(f, p.call(150, 303), "壞孩子", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, ink)
	_card.draw_string(f, p.call(150, 470), "%d 分" % GameState.conduct, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, ink)
	if ResourceLoader.exists(HEART_TEX):
		# 慈愛組織的愛心印章，蓋在分數旁邊
		var heart: Texture2D = _tex(HEART_TEX)
		_card.draw_set_transform(p.call(470, 420), -0.18, Vector2.ONE)
		_card.draw_texture_rect(heart, Rect2(Vector2(-55, -55), Vector2(110, 110)), false, Color(1, 1, 1, 0.8))
		_card.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var gray := Color("#9a9a9a")
	_card.draw_string(f, p.call(55, 714), "違反守則、不服從，會扣操行分數。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gray)
	_card.draw_string(f, p.call(55, 733), "分數太低的孩子，會得到「特別的愛」。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gray)
	_card.draw_string(f, Vector2(0, o.y + size.y + 36), "（按 E／空白鍵，或點一下畫面 關閉）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#e0e0e0"))


## 畫圖時用到的貼圖要留著參照，不然畫完就被釋放、畫面上只剩白色
var _tex_cache := {}


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]
