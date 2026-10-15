extends CanvasLayer
## 公告欄：棉花糖鎮好孩子守則／漂白鎮矯正守則、操行成績單。異常會悄悄改變它的內容（不提示）。

signal closed

var _panel: PanelContainer
var _text: RichTextLabel


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
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.add_theme_color_override("default_color", Color("#4e342e"))
	_text.add_theme_font_size_override("normal_font_size", 24)
	_text.add_theme_font_size_override("bold_font_size", 24)
	_panel.add_child(_text)
	for c in [dim, _panel, _text]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func rules_bbcode() -> String:
	if GameState.chapter == 2:
		return bleach_rules_bbcode()
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
	_show(report_bbcode())
	if visible:
		await closed


func open() -> void:
	_show(rules_bbcode())
	if visible:
		await closed


func _show(bbcode: String) -> void:
	_text.text = bbcode
	var sb: StyleBoxFlat = _panel.get_theme_stylebox("panel")
	sb.bg_color = Color("#f2f2f0") if GameState.chapter == 2 else Color("#fff3e0")
	sb.border_color = Color("#8a8a8a") if GameState.chapter == 2 else Color("#a1887f")
	_text.add_theme_color_override("default_color", Color("#333333") if GameState.chapter == 2 else Color("#4e342e"))
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
