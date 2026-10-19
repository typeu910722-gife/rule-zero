extends CanvasLayer
## 對話系統：解析腳本並以「縫在布上的標籤」風格顯示。
## 使用方式：await Dialogue.run("label")

signal finished
## 腳本中的 @event 會發出此訊號；處理者完成後必須呼叫 Dialogue.event_done.emit()
signal event_requested(name: String)
signal event_done
## 腳本中的 @bgm：請章節導演換配樂（"" 或 stop：停止）
signal bgm_requested(name: String)
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

## 第二章立繪：說話的人有立繪時顯示在右邊。
## 檔名 ch2_<id>_portrait_<狀態>_<表情>.png；狀態由章節導演給（portrait_state），表情由腳本的 @face 指定
const PORTRAITS := {
	"白面": "baimian", "小棘": "xiaoji", "條碼": "tiaoma", "嘎嘎": "gaga",
	"重重": "zhongzhong", "鼬鼬": "youyou", "和平鴿": "dove",
	"露露": "lulu", "麻糬": "mochi", "波波": "popo", "小布": "pip", "車掌": "conductor", "職員": "staff",
}
const PORTRAIT_DIR := "res://art/ch2/characters/portraits/ch2_%s_portrait_"
## 第二章的室內背景與 CG（@bg 的名字 → 圖）。沒有圖時退回 BG_COLORS 的底色
const BG_ART := "res://art/ch2/backgrounds/ch2_bg_%s.jpg"
const CG_ART := "res://art/ch2/cg/ch2_%s.jpg"
const BG_FALLBACK := {"platform_negative": "white", "ending_grey": "grey_train", "ending_color": "grey_train"}

var running := false
## 由章節導演設定：這個角色現在是哪個樣子（例如小棘剪光刺之後是 "bald"）。回傳 "" 表示用預設
var portrait_state: Callable
## @face 指定的表情（每段對話開始時清空）
var _faces := {}
var _portrait_cache := {}
var _bg_art: TextureRect
var _cg_shown := false
## 每次換背景就加一：事件裡換過背景的話，事件結束後不要蓋回舊的
var _bg_serial := 0
var parser := DialogueParser.new()

var _bg: ColorRect
## 恐怖畫面效果（背景之上、對話框之下）
var fx: AnomalyFX
## 序章的粉紅車廂（@bg train）
var _train: TrainView
var _box: PanelContainer
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _typing := false
var _choosing := false
var _shown_at := 0
var _portrait: TextureRect
var _blip := 0


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
	_faces.clear()
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
	_portrait.visible = false
	# 室內背景與 CG 只屬於這段對話：結束時收起來，回到地圖
	if _bg_art.visible:
		set_bg("none")
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
				_portrait.visible = false
				await get_tree().create_timer(float(args[0])).timeout
		"bg":
			set_bg(args[0])
		"fx":
			fx.command(args)
		"bgm":
			bgm_requested.emit("" if args.is_empty() or args[0] == "stop" else args[0])
		"face":
			# @face 小棘 cry ／ @face 小棘 （不寫表情：回到預設）
			_faces[args[0]] = args[1] if args.size() > 1 else "default"
		"sfx":
			if not GameState.fast:
				Sfx.play(self, args[0])
		"event":
			_box.visible = false
			_portrait.visible = false
			# 背景圖在對話層（比小遊戲、照片高）：事件進行時先收起來，不然會把小遊戲整個蓋住
			var bg_was := _bg.visible
			var serial := _bg_serial
			_bg.visible = false
			event_requested.emit(args[0])
			await event_done
			if serial == _bg_serial:
				_bg.visible = bg_was
	return -1


## 一張背景上疊好幾層（結尾的車廂：上車的人每人一層）
func set_bg_layers(paths: Array) -> void:
	set_bg("none")
	_bg_serial += 1
	var first := true
	for path in paths:
		if not ResourceLoader.exists(path):
			continue
		if first:
			_bg.visible = true
			_bg.color = BG_COLORS.grey_train
			_bg_art.texture = load(path)
			_bg_art.visible = true
			_cg_shown = true
			first = false
		else:
			var layer := TextureRect.new()
			layer.set_anchors_preset(Control.PRESET_FULL_RECT)
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.texture = load(path)
			_bg_art.add_child(layer)


func set_bg(mode: String) -> void:
	_bg_serial += 1
	# 夢境自動褪色、加顆粒；離開夢境就關掉
	if mode == "dream":
		fx.set_preset("dream")
	elif fx.preset == "dream":
		fx.set_preset("off")
	_bg.visible = mode != "none"
	_bg_art.visible = false
	_train.visible = mode == "train"
	for layer in _bg_art.get_children():
		layer.queue_free()
	if not _bg.visible:
		return
	var art := ""
	if mode.begins_with("cg"):
		art = CG_ART % mode
	elif not BG_COLORS.has(mode) or mode == "grey_train":
		art = BG_ART % ("train_grey" if mode == "grey_train" else mode)
	if art != "" and ResourceLoader.exists(art):
		_bg_art.texture = load(art)
		_bg_art.visible = true
		_cg_shown = mode.begins_with("cg")
	_bg.color = BG_COLORS.get(mode, BG_COLORS.get(BG_FALLBACK.get(mode, ""), BG_COLORS.white if mode.begins_with("cg") else BG_COLORS.black))


func _say(who: String, text: String) -> void:
	text = text.replace("{name}", GameState.player_name())
	_show_portrait(who)
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
		# 漂白鎮的打字聲：每幾個字「嗒」一下
		if GameState.chapter == 2:
			_blip += 1
			if _blip % 4 == 0:
				Sfx.play(self, "text", -14.0)
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
	_bg_art = TextureRect.new()
	_bg_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_art.visible = false
	_bg.add_child(_bg_art)
	_train = TrainView.new()
	_train.visible = false
	_bg.add_child(_train)
	fx = AnomalyFX.new()
	add_child(fx)

	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(930, 40)
	_portrait.size = Vector2(330, 495)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	add_child(_portrait)

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


func _show_portrait(who: String) -> void:
	var id: String = PORTRAITS.get(who, "")
	var path := portrait_path(id, _faces.get(who, "default")) if GameState.chapter == 2 and id != "" else ""
	# CG（一整張畫好的畫面）上不再疊立繪
	if _bg_art.visible and _cg_shown:
		path = ""
	if path != "":
		_portrait.texture = load(path)
		_portrait.visible = true
	else:
		_portrait.visible = false


## 依狀態與表情找立繪；找不到這個組合時，依序退回：只看表情 → 這個狀態的預設 → 預設
func portrait_path(id: String, face := "default") -> String:
	var state: String = portrait_state.call(id) if portrait_state.is_valid() else ""
	var key := "%s/%s/%s" % [id, state, face]
	if _portrait_cache.has(key):
		return _portrait_cache[key]
	var base := PORTRAIT_DIR % id
	var tries: Array = []
	if state != "":
		tries += ["%s_%s" % [state, face], state if face == "default" else "", "%s_default" % state]
	tries += ["a_%s" % face, face, "a_default", "default"]
	var found := ""
	for t in tries:
		if t != "" and ResourceLoader.exists(base + t + ".png"):
			found = base + t + ".png"
			break
	_portrait_cache[key] = found
	return found


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
