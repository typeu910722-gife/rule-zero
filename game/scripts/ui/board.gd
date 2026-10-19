extends CanvasLayer
## 公告欄：棉花糖鎮好孩子守則（美術：art/ui_rules_board.png，十條木牌）。
## 異常會悄悄改變它的內容（不提示）。

signal closed

const BOARD := preload("res://art/ui_rules_board.png")
## 原圖上十條木牌的上緣（像素），每條高約 25px；可寫字的左右範圍
const SLATS := [134, 179, 219, 260, 301, 342, 383, 424, 465, 506]
const SLAT_H := 26.0
const TEXT_X := Vector2(92, 432)
const SHOW_H := 680.0

var _board: TextureRect
var _rows: Array[RichTextLabel] = []
var _hint: Label


func _ready() -> void:
	layer = 45
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var k := SHOW_H / BOARD.get_height()
	var size := Vector2(BOARD.get_width(), BOARD.get_height()) * k
	_board = TextureRect.new()
	_board.texture = BOARD
	_board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_board.size = size
	_board.position = Vector2(640 - size.x / 2, 360 - size.y / 2 - 8)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	for y in SLATS:
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.scroll_active = false
		r.clip_contents = false
		r.position = Vector2(TEXT_X.x, y + 2) * k
		r.size = Vector2(TEXT_X.y - TEXT_X.x, SLAT_H) * k
		r.add_theme_color_override("default_color", Color("#4e342e"))
		r.add_theme_font_size_override("normal_font_size", 16)
		r.add_theme_font_size_override("bold_font_size", 16)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_board.add_child(r)
		_rows.append(r)
	_hint = Label.new()
	_hint.text = GameState.hint("按 E／空白鍵，或點一下畫面 關閉")
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("#f3e9f1"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 692)
	_hint.size = Vector2(1280, 24)
	add_child(_hint)


func rules() -> Array:
	# 第二天起：第 9 條的「回來」字型變粗，像是後來補寫的
	var back := "回來" if GameState.day < 2 else "[b]回來[/b]"
	return [
		"1. 每天都要笑嘻嘻！",
		"2. 晚上八點鐘聲響起前，要乖乖回家睡覺。",
		"3. 不可以去鐘塔後面的森林。",
		"4. 好朋友不可以吵架。" if GameState.day < 3 else "4. [color=#8e3b46][u]好朋友不可以吵架。[/u][/color]",
		"5. 名牌要一直戴好喔。",
		"6. 壞掉的東西，交給熊熊鎮長修理。",
		"7. 不要問「以前」的事。",
		"8. 鏡子是用來整理儀容的，不要盯著看太久。",
		"9. 新朋友來的時候，大家要說「歡迎%s」。" % back,
		"10. 守則永遠只有十條。",
	]


func rules_bbcode() -> String:
	return "\n".join(rules())


func open() -> void:
	var lines := rules()
	for i in _rows.size():
		_rows[i].text = "[center]%s[/center]" % lines[i]
	_hint.text = GameState.hint("按 E／空白鍵，或點一下畫面 關閉")
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
