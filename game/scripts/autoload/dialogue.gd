extends CanvasLayer
## 對話系統：解析腳本並以「縫在布上的標籤」風格顯示。
## 使用方式：await Dialogue.run("label")

signal finished
## 腳本中的 @event 會發出此訊號；處理者完成後必須呼叫 Dialogue.event_done.emit()
signal event_requested(name: String)
signal event_done
signal _advance
signal _chosen(index: int)

const CHARS_PER_SEC := 45.0
const BG_COLORS := {
	"black": Color(0.05, 0.04, 0.06),
	"train": Color("#f6d6e6"),
	"dream": Color("#d8d4cc"),
	"grey_train": Color("#d9cfd3"),
	"white": Color("#f4f4f2"),
}
## 對話腳本：每章一個檔案，標籤不能重複（第二章的標籤一律以 c2_ 開頭）
const SCRIPTS := ["res://dialogue/chapter1.txt", "res://dialogue/chapter2.txt"]

var running := false
var parser := DialogueParser.new()

var _bg: ColorRect
var _box: PanelContainer
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _typing := false
var _choosing := false
var _shown_at := 0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in SCRIPTS:
		parser.parse_file(path)
	for e in parser.errors:
		push_error(e)
	_build_ui()


func has_label(label: String) -> bool:
	return parser.labels.has(label)


func run(label: String) -> void:
	if not has_label(label):
		push_warning("對話標籤不存在：%s" % label)
		return
	running = true
	_apply_style()
	var cmds := parser.cmds
	var i: int = parser.labels[label]
	while i < cmds.size():
		var c: Dictionary = cmds[i]
		if c.t == "end":
			break
		if c.cond != "" and not GameState.check(c.cond):
			i += 1
			continue
		match c.t:
			"say":
				await _say(c.who, c.text)
				i += 1
			"choice":
				var opts: Array = []
				var j := i
				while j < cmds.size() and cmds[j].t == "choice":
					if cmds[j].cond == "" or GameState.check(cmds[j].cond):
						opts.append(cmds[j])
					j += 1
				if opts.is_empty():
					push_error("沒有可用的選項：%s" % c.where)
					break
				var k: int = await _choose(opts)
				var picked: Dictionary = opts[k]
				if picked.cost > 0:
					GameState.spend_courage(picked.cost)
				i = parser.labels[picked.target]
			"cmd":
				var next: int = await _command(c.op, c.args)
				if next == -2:
					break
				i = next if next >= 0 else i + 1
	_box.visible = false
	running = false
	finished.emit()


func _command(op: String, args: Array) -> int:
	match op:
		"set":
			GameState.set_flag(args[0], true if args.size() < 2 else args[1])
		"unset":
			GameState.set_flag(args[0], false)
		"sus":
			GameState.add_suspicion(int(args[0]))
		"conduct":
			GameState.add_conduct(int(args[0]))
		"courage":
			GameState.courage = clampi(GameState.courage + int(args[0]), 0, GameState.MAX_COURAGE)
			GameState.changed.emit()
		"goto":
			return parser.labels[args[0]]
		"if":
			if GameState.check(args[0]):
				return parser.labels[args[1]]
		"end":
			return -2
		"wait":
			if not GameState.fast:
				_box.visible = false
				await get_tree().create_timer(float(args[0])).timeout
		"bg":
			set_bg(args[0])
		"event":
			_box.visible = false
			event_requested.emit(args[0])
			await event_done
	return -1


func set_bg(mode: String) -> void:
	_bg.visible = mode != "none"
	if _bg.visible:
		_bg.color = BG_COLORS[mode]


func _say(who: String, text: String) -> void:
	text = text.replace("{name}", GameState.player_name())
	_box.visible = true
	_name.visible = who != ""
	_name.text = who
	if who == "":
		_text.text = "[color=%s]%s[/color]" % ["#777777" if GameState.chapter == 2 else "#7a6a78", text]
	else:
		_text.text = text
	if GameState.fast:
		return
	_text.visible_characters = 0
	_typing = true
	_shown_at = Time.get_ticks_msec()
	await _advance


func _process(delta: float) -> void:
	if _typing:
		_text.visible_characters += maxi(1, int(CHARS_PER_SEC * delta + 0.5))
		if _text.visible_characters >= _text.get_total_character_count():
			_text.visible_characters = -1
			_typing = false


func _unhandled_input(event: InputEvent) -> void:
	if not running or _choosing or not _box.visible:
		return
	var pressed: bool = event.is_action_pressed("interact") or \
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if Time.get_ticks_msec() - _shown_at < 120:
		return  # 觸控時，同一下點擊會再送一次模擬滑鼠事件
	if _typing:
		_text.visible_characters = -1
		_typing = false
	else:
		_advance.emit()


func _choose(opts: Array) -> int:
	if GameState.fast:
		# 自動測試：依序使用預先指定的選項，否則選第一個付得起的
		if not GameState.auto_choices.is_empty():
			return GameState.auto_choices.pop_front()
		for k in opts.size():
			if GameState.courage >= opts[k].cost:
				return k
	_choosing = true
	for child in _choices.get_children():
		child.queue_free()
	var first: Button = null
	for k in opts.size():
		var o: Dictionary = opts[k]
		var b := Button.new()
		b.text = o.text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22)
		_style_button(b)
		if o.cost > 0:
			b.text = "★ %s　（違反守則・膽量 -%d）" % [o.text, o.cost]
			if GameState.courage < o.cost:
				b.text = "★ %s　（膽量不足）" % o.text
				b.disabled = true
		b.pressed.connect(func(): _chosen.emit(k))
		_choices.add_child(b)
		if first == null and not b.disabled:
			first = b
	_choices.visible = true
	if first:
		first.grab_focus.call_deferred()
	var idx: int = await _chosen
	_choices.visible = false
	_choosing = false
	return idx


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	add_child(_bg)

	_box = PanelContainer.new()
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 60
	_box.offset_right = -60
	_box.offset_top = -200
	_box.offset_bottom = -24
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff8f0")
	sb.border_color = Color("#e8a0bf")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.12)
	sb.shadow_size = 6
	_box.add_theme_stylebox_override("panel", sb)
	_box.visible = false
	add_child(_box)

	var v := VBoxContainer.new()
	_box.add_child(v)
	_name = Label.new()
	_name.add_theme_color_override("font_color", Color("#c2558a"))
	_name.add_theme_font_size_override("font_size", 22)
	v.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("default_color", Color("#4a3b47"))
	_text.add_theme_font_size_override("normal_font_size", 26)
	v.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.anchor_left = 0.5
	_choices.anchor_right = 0.5
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = -360
	_choices.offset_right = 360
	_choices.offset_top = -420
	_choices.offset_bottom = -215
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 8)
	_choices.visible = false
	add_child(_choices)
	# 對話框本身不攔截點擊，讓「點畫面任何地方」都能前進（手機）
	for c in [_box, v, _name, _text]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 漂白鎮的對話框：同樣是縫在布上的標籤，只是被洗白了
func _apply_style() -> void:
	var cold := GameState.chapter == 2
	var sb: StyleBoxFlat = _box.get_theme_stylebox("panel")
	sb.bg_color = Color("#f4f4f2") if cold else Color("#fff8f0")
	sb.border_color = Color("#9a9a9a") if cold else Color("#e8a0bf")
	_name.add_theme_color_override("font_color", Color("#555555") if cold else Color("#c2558a"))
	_text.add_theme_color_override("default_color", Color("#2e2e2e") if cold else Color("#4a3b47"))


func _style_button(b: Button) -> void:
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#fff8f0") if state in ["normal", "disabled"] else Color("#ffe1ec")
		sb.border_color = Color("#e8a0bf") if state != "disabled" else Color("#d9cfd6")
		sb.set_border_width_all(3 if state in ["hover", "focus"] else 2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 20
		sb.content_margin_right = 20
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_color", Color("#4a3b47"))
	b.add_theme_color_override("font_hover_color", Color("#c2558a"))
	b.add_theme_color_override("font_focus_color", Color("#c2558a"))
	b.add_theme_color_override("font_disabled_color", Color("#b8aab4"))
