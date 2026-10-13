extends CanvasLayer
## 左上角狀態、互動提示、Tab 選單（守則／日記／名牌）。

signal tag_toggle_requested
signal board_requested
signal title_requested

var menu_open := false
var show_debug := false

var _status: Label
var _objective: Label
var _status_panel: PanelContainer
var _prompt: Label
var _toast: PanelContainer
var _toast_text: Label
var _toast_queue: Array = []
var _toast_busy := false
## 今天要做的事（main.gd 設定）：[[名稱, 是否完成], …]
var checklist: Array = []
var _menu: PanelContainer
var _menu_text: RichTextLabel
var _tag_button: Button


func _ready() -> void:
	layer = 20
	# 左上角：半透明的小卡片墊在字後面，地圖再花也看得清楚
	_status_panel = PanelContainer.new()
	_status_panel.position = Vector2(14, 10)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(1.0, 0.98, 0.95, 0.86)
	psb.border_color = Color("#e8c4d4")
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	psb.content_margin_left = 16
	psb.content_margin_right = 18
	psb.content_margin_top = 8
	psb.content_margin_bottom = 10
	_status_panel.add_theme_stylebox_override("panel", psb)
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	_status_panel.add_child(sv)
	_status = _label(Vector2.ZERO, 22, Color("#6d597a"), sv)
	_objective = _label(Vector2.ZERO, 17, Color("#7a6576"), sv)
	_objective.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_objective.custom_minimum_size = Vector2(380, 0)
	_prompt = _label(Vector2(0, 0), 22, Color("#ffffff"))
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
	_build_toast()
	GameState.changed.connect(refresh)
	refresh()


func _label(pos: Vector2, font_size: int, col: Color, parent: Node = null) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else self).add_child(l)
	return l


## 畫面上方中間跳出的小提示（第一次看到某樣東西時），幾秒後自己消失
func toast(text: String, seconds := 5.0) -> void:
	_toast_queue.append([text, seconds])
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	var item: Array = _toast_queue.pop_front()
	_toast_text.text = item[0]
	_toast.visible = true
	_toast.modulate.a = 0.0
	_toast.reset_size()
	_toast.position = Vector2(640 - _toast.size.x / 2, 18)
	if GameState.fast:
		_toast.visible = false
		_next_toast()
		return
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.25)
	tw.tween_interval(item[1])
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	await tw.finished
	_toast.visible = false
	_next_toast()


func _build_toast() -> void:
	_toast = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#4a3b47", 0.88)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_toast.add_theme_stylebox_override("panel", sb)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	add_child(_toast)
	_toast_text = Label.new()
	_toast_text.add_theme_font_size_override("font_size", 19)
	_toast_text.add_theme_color_override("font_color", Color("#fff3f8"))
	_toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_text)


func refresh() -> void:
	var day_names := ["", "第一天", "第二天", "第三天"]
	var stars := "★".repeat(GameState.courage) + "☆".repeat(GameState.MAX_COURAGE - GameState.courage)
	_status.text = "%s　｜　膽量 %s" % [day_names[mini(GameState.day, 3)], stars]
	if show_debug:
		_status.text += "　｜　[debug] 鎮長懷疑值 %d" % GameState.suspicion
	_objective.text = GameState.objective
	_objective.visible = _status_panel.visible and GameState.objective != ""
	if menu_open:
		_fill_menu()


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_status_visible(v: bool) -> void:
	_status_panel.visible = v
	_objective.visible = v and GameState.objective != ""


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
	# 今天要做的事
	if GameState.objective != "":
		t += "[font_size=22]今天要做的事[/font_size]\n%s\n" % GameState.objective.split("\n")[0]
		for item in checklist:
			t += ("[color=#9bb59a]　✓ %s[/color]\n" % item[0]) if item[1] else ("　□ %s\n" % item[0])
		t += "\n"
	# 收到的東西
	var gifts: Array = GameState.GIFTS.keys().filter(func(k): return GameState.has(k))
	if not gifts.is_empty():
		t += "[font_size=22]口袋裡的東西[/font_size]\n"
		for k in gifts:
			t += "・%s\n" % GameState.GIFTS[k]
		t += "\n"
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
	_style_button(board_btn)
	board_btn.pressed.connect(func(): board_requested.emit())
	v.add_child(board_btn)
	_tag_button = Button.new()
	_style_button(_tag_button)
	_tag_button.pressed.connect(func(): tag_toggle_requested.emit())
	v.add_child(_tag_button)
	var title_btn := Button.new()
	title_btn.text = "回到標題（從今天早上的存檔繼續）"
	_style_button(title_btn)
	title_btn.pressed.connect(func(): title_requested.emit())
	v.add_child(title_btn)
	var hint := Label.new()
	hint.text = "Tab / Esc 關閉"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color("#a39ba8"))
	v.add_child(hint)


func _style_button(b: Button) -> void:
	b.add_theme_font_size_override("font_size", 18)
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#fff8f0") if state in ["normal", "disabled"] else Color("#ffe1ec")
		sb.border_color = Color("#e8a0bf") if state != "disabled" else Color("#d9cfd6")
		sb.set_border_width_all(3 if state in ["hover", "focus"] else 2)
		sb.set_corner_radius_all(12)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color("#4a3b47"))
	b.add_theme_color_override("font_hover_color", Color("#c2558a"))
	b.add_theme_color_override("font_focus_color", Color("#c2558a"))
	b.add_theme_color_override("font_disabled_color", Color("#b8aab4"))
