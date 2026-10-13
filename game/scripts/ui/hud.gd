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
	if show_debug:
		_status.text += "　｜　[debug] 鎮長懷疑值 %d" % GameState.suspicion
	_objective.text = GameState.objective
	if menu_open:
		_fill_menu()


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_status_visible(v: bool) -> void:
	_status.visible = v
	_objective.visible = v


func toggle_menu(allow_tag: bool) -> void:
	menu_open = not menu_open
	_menu.visible = menu_open
	Sound.sfx("menu")
	_tag_button.visible = allow_tag
	if menu_open:
		_fill_menu()
		_tag_button.grab_focus.call_deferred()


func _fill_menu() -> void:
	var t := "[font_size=28]小布的日記[/font_size]\n\n"
	t += "名字：%s\n膽量：%d / %d\n車票上的戳章：%d 個\n\n" % [GameState.player_name(), GameState.courage, GameState.MAX_COURAGE,
		GameState.loop_number() - GameState.FIRST_LOOP + 1]
	# 進行中的委託（支線）
	var quests := []
	if GameState.has("q_letters") and not GameState.has("letter_done"):
		quests.append("波波：送三封信（%d / 3）" % int(GameState.flags.get("letters", 0)))
	if GameState.has("q_mochi") and not GameState.has("q_mochi_done"):
		quests.append("麻糬：問大家他本來的名字（%d / 3）" % mini(int(GameState.flags.get("mq_count", 0)), 3))
	if GameState.has("q_tama") and not GameState.has("tama_done"):
		quests.append("小玉：找回三顆糖果（%d / 3）" % int(GameState.flags.get("candies", 0)))
	if GameState.has("q_notes") and not GameState.has("notes_returned"):
		quests.append("Fen：撿回被吹散的筆記（%d / 3）" % int(GameState.flags.get("notes", 0)))
	if not quests.is_empty():
		t += "[font_size=22]委託[/font_size]\n"
		for q in quests:
			t += "・%s\n" % q
		t += "\n"
	t += "[font_size=22]發現的事情[/font_size]\n"
	for k in GameState.SECRETS:
		t += ("・%s\n" % GameState.SECRETS[k]) if GameState.has(k) else "・？？？\n"
	var clues: Array = GameState.CLUES.keys().filter(func(k): return GameState.has(k))
	if not clues.is_empty():
		t += "\n[font_size=22]記下的事[/font_size]\n"
		for k in clues:
			t += "・%s\n" % GameState.CLUES[k]
	# 記憶碎片（棉花）：跨輪保留
	var tufts: Array = GameState.meta.get("tufts", [])
	t += "\n[font_size=22][color=#c2558a]記憶碎片　%d / 10[/color][/font_size]\n" % tufts.size()
	for k in GameState.TUFT_TEXT:
		if k in tufts:
			t += "[color=#c2558a]・%s[/color]\n" % GameState.TUFT_TEXT[k]
	# 上一輪記下的事：跨輪保留，但被修理過的那幾頁被剪掉了
	var past: Array = GameState.meta.get("past_clues", [])
	if GameState.is_repeat() and not past.is_empty():
		var cut: Array = GameState.meta.get("cut_clues", [])
		t += "\n[font_size=22][color=#7b4fa0]上一輪記得的事[/color][/font_size]\n"
		for k in past:
			if k in cut:
				t += "[color=#b8aab4]・（這一頁被剪掉了一半）%s……[/color]\n" % GameState.CLUES[k].left(4)
			else:
				t += "[color=#7b4fa0]・%s[/color]\n" % GameState.CLUES[k]
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
	# 內容會越來越多（委託、碎片、上一輪的事）：固定高度、可以捲動
	_menu_text.fit_content = false
	_menu_text.scroll_active = true
	_menu_text.custom_minimum_size = Vector2(452, 400)
	_menu_text.add_theme_color_override("default_color", Color("#4a3b47"))
	v.add_child(_menu_text)
	var board_btn := Button.new()
	board_btn.text = "看守則"
	board_btn.pressed.connect(func(): board_requested.emit())
	v.add_child(board_btn)
	_tag_button = Button.new()
	_tag_button.pressed.connect(func(): tag_toggle_requested.emit())
	v.add_child(_tag_button)
	var title_btn := Button.new()
	title_btn.text = "回到標題（從今天早上的存檔繼續）"
	title_btn.pressed.connect(func(): title_requested.emit())
	v.add_child(title_btn)
	var hint := Label.new()
	hint.text = "Tab / Esc 關閉"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#a39ba8"))
	v.add_child(hint)
