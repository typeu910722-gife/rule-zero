extends CanvasLayer
## 公告欄：棉花糖鎮好孩子守則。異常會悄悄改變它的內容（不提示）。

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
		"11. 不要和以前的朋友說話。" if GameState.has("chapter2") else "",
		"",
		"[center][color=#a1887f][font_size=18]（按 E／空白鍵，或點一下畫面 關閉）[/font_size][/color][/center]",
	]
	return "\n".join(lines)


func open() -> void:
	_text.text = rules_bbcode()
	visible = true
	if GameState.fast:
		close()
		return
	await closed


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if visible and (event.is_action_pressed("interact") or event.is_action_pressed("menu") or tap):
		get_viewport().set_input_as_handled()
		close()
