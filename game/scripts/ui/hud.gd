extends CanvasLayer
## 左上角狀態、互動提示、Tab 選單（守則／日記／名牌）。

signal tag_toggle_requested
signal board_requested
signal title_requested

var menu_open := false
var show_debug := false

var _status: Label
var _objective: Label
var _prompt: Label
var _menu: PanelContainer
var _menu_text: RichTextLabel
var _tag_button: Button
## 第二章的狀態框（外包美術；缺檔時用原本的文字列）
const HUD_TEX := "res://art/ch2/ui/ch2_ui_05_hud.png"
const STAR_ON_TEX := "res://art/ch2/ui/ch2_ui_05_star_bright.png"
const STAR_OFF_TEX := "res://art/ch2/ui/ch2_ui_05_star_dark.png"
const FRAME_POS := Vector2(16, 10)
var _frame: Control
var _status_on := true


func _ready() -> void:
	layer = 20
	_status = _label(Vector2(24, 18), 24, Color("#6d597a"))
	_objective = _label(Vector2(24, 54), 18, Color("#8e7d8a"))
	_prompt = _label(Vector2(0, 0), 20, Color("#ffffff"))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -200
	_prompt.offset_right = 200
	_prompt.offset_top = -60
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color("#b56576"))
	_prompt.add_theme_constant_override("outline_size", 6)
	_frame = Control.new()
	_frame.position = FRAME_POS
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	move_child(_frame, 0)
	_build_menu()
	GameState.changed.connect(refresh)
	refresh()


func _label(pos: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


func refresh() -> void:
	var day_names := ["", "第一天", "第二天", "第三天"]
	var stars := "★".repeat(GameState.courage) + "☆".repeat(GameState.MAX_COURAGE - GameState.courage)
	_status.text = "%s　｜　膽量 %s" % [day_names[mini(GameState.day, 3)], stars]
	if GameState.chapter == 2:
		_status.text += "　｜　操行 %d" % GameState.conduct
	var cold := GameState.chapter == 2
	_status.add_theme_color_override("font_color", Color("#444444") if cold else Color("#6d597a"))
	_objective.add_theme_color_override("font_color", Color("#6a6a6a") if cold else Color("#8e7d8a"))
	if show_debug:
		_status.text += "　｜　[debug] 懷疑值 %d" % GameState.suspicion
	_objective.text = GameState.objective
	# 第二章：用狀態框取代文字列（文字仍照舊更新）
	var framed := _use_frame()
	_frame.visible = framed and _status_on
	_status.visible = _status_on and not framed
	_objective.position.y = 96 if framed else 54
	_frame.queue_redraw()
	if menu_open:
		_fill_menu()


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_status_visible(v: bool) -> void:
	_status_on = v
	_status.visible = v and not _use_frame()
	_frame.visible = v and _use_frame()
	_objective.visible = v


func _use_frame() -> bool:
	return GameState.chapter == 2 and ResourceLoader.exists(HUD_TEX)


## 狀態框（原圖座標）：「第」「天」之間寫日子，中間是膽量的星星，「操行」後面寫分數
func _draw_frame() -> void:
	if not _use_frame():
		return
	var f: Font = GameState.font
	var ink := Color("#444444")
	_frame.draw_texture(_tex(HUD_TEX), Vector2.ZERO)
	var nums := ["", "一", "二", "三"]
	_frame.draw_string(f, Vector2(42, 46), nums[mini(GameState.day, 3)], HORIZONTAL_ALIGNMENT_CENTER, 26, 21, ink)
	_frame.draw_string(f, Vector2(118, 46), "膽量", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ink)
	for k in GameState.MAX_COURAGE:
		var on := k < GameState.courage
		var path := STAR_ON_TEX if on else STAR_OFF_TEX
		var r := Rect2(170 + k * 38, 19, 36, 36)
		if ResourceLoader.exists(path):
			_frame.draw_texture_rect(_tex(path), r, false)
		else:
			_frame.draw_string(f, r.position + Vector2(4, 28), "★" if on else "☆", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, ink)
	_frame.draw_string(f, Vector2(424, 46), "%d" % GameState.conduct, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ink)
	if show_debug:
		_frame.draw_string(f, Vector2(540, 46), "[debug] 懷疑值 %d" % GameState.suspicion, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)


func toggle_menu(allow_tag: bool) -> void:
	menu_open = not menu_open
	_menu.visible = menu_open
	_tag_button.visible = allow_tag
	if menu_open:
		_fill_menu()
		_tag_button.grab_focus.call_deferred()


func _fill_menu() -> void:
	var t := "[font_size=28]小布的日記[/font_size]\n\n"
	t += "名字：%s\n膽量：%d / %d\n" % [GameState.player_name(), GameState.courage, GameState.MAX_COURAGE]
	if GameState.chapter == 2:
		t += "操行：%d 分\n" % GameState.conduct
	t += "\n[font_size=22]發現的事情[/font_size]\n"
	var defs := GameState.secret_defs()
	for k in defs:
		t += ("・%s\n" % defs[k]) if GameState.has(k) else "・？？？\n"
	var clues: Array = GameState.CLUES.keys().filter(func(k): return GameState.has(k))
	if not clues.is_empty():
		t += "\n[font_size=22]記下的事[/font_size]\n"
		for k in clues:
			t += "・%s\n" % GameState.CLUES[k]
	_menu_text.text = t
	if GameState.has("tag_on"):
		_tag_button.text = "★ 拆下名牌　（違反守則 5・膽量 -1）"
		_tag_button.disabled = GameState.courage < 1
	else:
		_tag_button.text = "把名牌別回去"
		_tag_button.disabled = false


func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.position = Vector2(740, 30)
	_menu.custom_minimum_size = Vector2(500, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fffaf3")
	sb.border_color = Color("#cdb4db")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(24)
	_menu.add_theme_stylebox_override("panel", sb)
	_menu.visible = false
	add_child(_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_menu.add_child(v)
	_menu_text = RichTextLabel.new()
	_menu_text.bbcode_enabled = true
	_menu_text.fit_content = true
	_menu_text.add_theme_color_override("default_color", Color("#4a3b47"))
	v.add_child(_menu_text)
	var board_btn := Button.new()
	board_btn.text = "看守則"
	board_btn.pressed.connect(func(): board_requested.emit())
	v.add_child(board_btn)
	_tag_button = Button.new()
	_tag_button.pressed.connect(func(): tag_toggle_requested.emit())
	v.add_child(_tag_button)
	for bus in [["Music", "配樂"], ["SFX", "音效"]]:
		v.add_child(_volume_row(bus[0], bus[1]))
	var title_btn := Button.new()
	title_btn.text = "回到標題（從今天早上的存檔繼續）"
	title_btn.pressed.connect(func(): title_requested.emit())
	v.add_child(title_btn)
	var hint := Label.new()
	hint.text = "Tab / Esc 關閉"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#a39ba8"))
	v.add_child(hint)


## 音量列：「配樂 ───●── 80%」。鍵盤／手把選到滑桿後按左右調整。
func _volume_row(bus: String, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var title := Label.new()
	title.text = label
	title.custom_minimum_size.x = 56
	title.add_theme_color_override("font_color", Color("#4a3b47"))
	row.add_child(title)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 10
	slider.value = round(Audio.get_volume(bus) * 100)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 32
	row.add_child(slider)
	var pct := Label.new()
	pct.custom_minimum_size.x = 64
	pct.text = "%d%%" % slider.value
	pct.add_theme_color_override("font_color", Color("#a39ba8"))
	row.add_child(pct)
	slider.value_changed.connect(func(value: float):
		pct.text = "%d%%" % value
		Audio.set_volume(bus, value / 100.0)
		if GameState.chapter == 2:  # 第一章還沒有自己的介面音效
			Sfx.play(self, "cursor", -10.0))
	return row


## 畫圖時用到的貼圖要留著參照，不然畫完就被釋放、畫面上只剩白色
var _tex_cache := {}


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]
