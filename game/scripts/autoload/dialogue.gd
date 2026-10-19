extends CanvasLayer
## 對話系統：解析腳本並以「縫在布上的標籤」風格顯示。
## 使用方式：await Dialogue.run("label")

signal finished
## 腳本中的 @event 會發出此訊號；處理者完成後必須呼叫 Dialogue.event_done.emit()
signal event_requested(name: String)
signal event_done
## 腳本中的 @bgm：請章節導演換配樂（"" 或 stop：停止）。第二章用
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

## ───── 第二章「漂白鎮」 ─────
## 立繪：說話的人有立繪時顯示在右邊。
## 檔名 ch2_<id>_portrait_<狀態>_<表情>.png；狀態由章節導演給（portrait_state），表情由腳本的 @face 指定
const PORTRAITS := {
	"白面": "baimian", "小棘": "xiaoji", "條碼": "tiaoma", "嘎嘎": "gaga",
	"重重": "zhongzhong", "鼬鼬": "youyou", "和平鴿": "dove",
	"露露": "lulu", "麻糬": "mochi", "波波": "popo", "小布": "pip", "車掌": "conductor", "職員": "staff",
}
const PORTRAIT_DIR := "res://art/ch2/characters/portraits/ch2_%s_portrait_"
## 室內背景與 CG（@bg 的名字 → 圖）。第二章時優先找這裡；沒有圖時退回 BG_COLORS 的底色
const BG_ART := "res://art/ch2/backgrounds/ch2_bg_%s.jpg"
const CG_ART := "res://art/ch2/cg/ch2_%s.jpg"
const BG_FALLBACK := {"platform_negative": "white", "ending_grey": "grey_train", "ending_color": "grey_train"}
## 有美術的背景（game/art/bg_*.jpg）。@bg 名稱 → 全畫面背景圖
const BG_IMAGES := ["train", "platform", "plaza", "bakery", "repair", "clocktower", "room_night",
	"hospital_child", "hospital_empty", "hospital_haruka", "classroom", "train_night", "town2",
	"mem_sea", "mem_class", "mem_toilet", "mem_hospital",
	"nt_lulu", "nt_popo", "nt_tama", "nt_mochi", "nt_dog", "glove", "mayor_broken"]
## 夢境（醫院）時換成「記憶揭露」的音樂
const MEMORY_BGS := ["dream", "hospital_child", "hospital_empty", "hospital_haruka", "classroom",
	"mem_sea", "mem_class", "mem_toilet", "mem_hospital"]

## 說話者 → 表情圖（game/art/face_*.png，4 欄 × 2 列，每格 256px）
const FACES := {
	"小布": "bu", "遙": "bu", "熊熊鎮長": "mayor", "鎮長": "mayor", "露露": "lulu", "Fen": "fen",
	"波波": "popo", "麻糬": "mochi", "小玉": "tama",
	"車掌": "conductor", "居民": "puppy", "小狗居民": "puppy", "貓居民": "cat",
}
const FACE_CELL := 256.0

var running := false
var parser := DialogueParser.new()
var _portrait: TextureRect
var _face_tex := {}
## 第二章：由章節導演設定角色現在是哪個樣子（例如小棘剪光刺之後是 "bald"）。回傳 "" 表示用預設
var portrait_state: Callable
## 第二章：@face 指定的表情（每段對話開始時清空）
var _faces := {}
var _portrait_cache := {}
## 第二章的立繪（右邊，大張）
var _ch2_portrait: TextureRect
var _cg_shown := false
## 每次換背景就加一：事件裡換過背景的話，事件結束後不要蓋回舊的
var _bg_serial := 0
var _blip := 0
var _skin_box: StyleBox
var _cold_box: StyleBoxFlat

var _bg: ColorRect
var _bg_img: TextureRect
var _item: TextureRect
var _item_tw: Tween
var _more: Label
var _hint: Label
var _tip: Label
var _box: PanelContainer
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _typing := false
var _choosing := false
var _shown_at := 0
var _hold_t := 0.0
var _skip_t := 0.0
## 全螢幕效果（驚悚閃爍、森林暗角）
var fx: ScreenFx


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	for path in SCRIPTS:
		parser.parse_file(path)
	for e in parser.errors:
		push_error(e)
	_build_ui()
	fx = ScreenFx.new()
	add_child(fx)


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
	_ch2_portrait.visible = false
	_more.visible = false
	_hint.visible = false
	show_item("none")
	# 第二章：室內背景與 CG 只屬於這段對話，結束時收起來，回到地圖
	if _ch2() and _bg_img.visible:
		set_bg("none")
	running = false
	finished.emit()


func _command(op: String, args: Array) -> int:
	match op:
		"set":
			GameState.set_flag(args[0], true if args.size() < 2 else args[1])
		"unset":
			GameState.set_flag(args[0], false)
		"add":
			# @add 旗標 數字：計數用（例如麻糬的委託問了幾個人）
			GameState.set_flag(args[0], int(GameState.flags.get(args[0], 0)) + (int(args[1]) if args.size() > 1 else 1))
		"roll":
			# @roll N：擲一個 0～N-1 的隨機數，存在旗標 roll（台詞用 [roll==1] 判斷），讓同一段每次有點不一樣
			GameState.set_flag("roll", randi() % maxi(int(args[0]), 1))
		"mem":
			# @mem key：跨輪記住（例如這一層的過去已經想起來了）
			GameState.remember(args[0])
		"sus":
			GameState.add_suspicion(int(args[0]))
		"conduct":
			GameState.add_conduct(int(args[0]))
		"bgm":
			bgm_requested.emit("" if args.is_empty() or args[0] == "stop" else args[0])
		"face":
			# @face 小棘 cry ／ @face 小棘 （不寫表情：回到預設）
			_faces[args[0]] = args[1] if args.size() > 1 else "default"
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
				_ch2_portrait.visible = false
				await get_tree().create_timer(float(args[0])).timeout
		"bg":
			set_bg(args[0])
		"show":
			# @show 物件名：在對話框上方秀出一張物件圖（game/art/item_*.png）；@show none 收起來
			show_item(args[0])
		"idle":
			# 閒聊：輪流出現 4 句普通的，第 3 次會出現一次驚悚的（整個存檔只一次）
			var pool := 0
			while has_label("idle_%s_%d" % [args[0], pool + 1]):
				pool += 1
			return parser.labels[GameState.idle_label(args[0], pool)]
		"sfx":
			if not GameState.fast:
				if _ch2():
					Sfx.play(self, args[0])
				else:
					Sound.sfx(args[0])
		"scare":
			fx.scare()
		"event":
			_box.visible = false
			_portrait.visible = false
			_ch2_portrait.visible = false
			_more.visible = false
			if _ch2():
				# 第二章：背景圖在對話層（比小遊戲、照片高），事件進行時先收起來，不然會把小遊戲整個蓋住
				var bg_was := _bg.visible
				var serial := _bg_serial
				_bg.visible = false
				event_requested.emit(args[0])
				await event_done
				if serial == _bg_serial:
					_bg.visible = bg_was
			else:
				event_requested.emit(args[0])
				await event_done
	return -1


func _ch2() -> bool:
	return GameState.chapter == 2


func set_bg(mode: String) -> void:
	_bg_serial += 1
	for layer in _bg_img.get_children():
		layer.queue_free()
	if _ch2():
		_set_bg_ch2(mode)
		return
	_bg.visible = mode != "none"
	if _bg.visible:
		_bg.color = BG_COLORS.get(mode, BG_COLORS.black)
	_bg_img.visible = mode in BG_IMAGES
	if _bg_img.visible:
		_bg_img.texture = load("res://art/bg_%s.jpg" % mode)
	Sound.override_bgm("memory" if mode in MEMORY_BGS else "")


## 第二章的背景：外包的室內圖與 CG
func _set_bg_ch2(mode: String) -> void:
	_bg.visible = mode != "none"
	_bg_img.visible = false
	_cg_shown = false
	if not _bg.visible:
		return
	var art := ""
	if mode.begins_with("cg"):
		art = CG_ART % mode
	elif not BG_COLORS.has(mode) or mode == "grey_train":
		art = BG_ART % ("train_grey" if mode == "grey_train" else mode)
	if art != "" and ResourceLoader.exists(art):
		_bg_img.texture = load(art)
		_bg_img.visible = true
		_cg_shown = mode.begins_with("cg")
	_bg.color = BG_COLORS.get(mode, BG_COLORS.get(BG_FALLBACK.get(mode, ""), BG_COLORS.white if mode.begins_with("cg") else BG_COLORS.black))


## 一張背景上疊好幾層（第二章結尾的車廂：上車的人每人一層）
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
			_bg_img.texture = load(path)
			_bg_img.visible = true
			_cg_shown = true
			first = false
		else:
			var layer := TextureRect.new()
			layer.set_anchors_preset(Control.PRESET_FULL_RECT)
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.texture = load(path)
			_bg_img.add_child(layer)


func show_item(name: String) -> void:
	if _item_tw:
		_item_tw.kill()
	if name == "none" or name == "":
		_item.visible = false
		return
	_item.texture = load("res://art/item_%s.png" % name)
	_item.visible = true
	_item.modulate.a = 0.0
	_item.scale = Vector2(0.92, 0.92)
	_item_tw = create_tween().set_parallel()
	_item_tw.tween_property(_item, "modulate:a", 1.0, 0.25)
	_item_tw.tween_property(_item, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _say(who: String, text: String) -> void:
	text = GameState.fill(text)
	_box.visible = true
	# 名字放在對話框左上角的布標上；旁白時留空（版面不跳動）
	_name.visible = true
	_name.text = who
	if _ch2():
		_portrait.visible = false
		_show_portrait_ch2(who)
	else:
		_ch2_portrait.visible = false
		_show_face(who, text)
		if who != "" and not GameState.fast:
			Sound.sfx("talk")
	if who == "":
		_text.text = "[color=%s]%s[/color]" % ["#777777" if _ch2() else "#7a6a78", text]
	else:
		_text.text = text
	if GameState.fast:
		return
	_text.visible_characters = 0
	_typing = true
	_more.visible = false
	_shown_at = Time.get_ticks_msec()
	await _advance
	_more.visible = false


func _process(delta: float) -> void:
	# 一句話打完了：右下角的 ▼ 輕輕跳動，告訴玩家可以按下一句
	_hint.visible = running and _box.visible and not _choosing and not GameState.touch_ui()
	_hint.text = GameState.hint("按住 E 快轉")
	if running and _box.visible and not _typing and not _choosing:
		_more.visible = true
		var bob := sin(Time.get_ticks_msec() / 160.0) * 3.0
		_more.offset_top = -76 + bob
		_more.offset_bottom = -50 + bob
	# 按住互動鍵（或按住畫面）超過 0.4 秒：快轉對話，重玩時不會煩
	if running and _box.visible and not _choosing:
		var held := Input.is_action_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		_hold_t = _hold_t + delta if held else 0.0
		if _hold_t > 0.4:
			_skip_t += delta
			if _skip_t > 0.07:
				_skip_t = 0.0
				_text.visible_characters = -1
				_typing = false
				_advance.emit()
	if _typing:
		_text.visible_characters += maxi(1, int(CHARS_PER_SEC * delta + 0.5))
		# 漂白鎮的打字聲：每幾個字「嗒」一下
		if _ch2():
			_blip += 1
			if _blip % 4 == 0:
				Sfx.play(self, "text", -14.0)
		if _text.visible_characters >= _text.get_total_character_count():
			_text.visible_characters = -1
			_typing = false


func _unhandled_input(event: InputEvent) -> void:
	# 選項出現時：E（互動鍵）也可以確定目前選中的選項，不只是 Enter
	if running and _choosing and event.is_action_pressed("interact") and not event.is_action_pressed("ui_accept"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and f.get_parent() == _choices and not (f as Button).disabled:
			get_viewport().set_input_as_handled()
			(f as Button).pressed.emit()
		return
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
		b.text = GameState.fill(o.text)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if _ch2():
			b.add_theme_font_size_override("font_size", 30 if GameState.touch_ui() else 22)
			_style_button(b)
		else:
			UiSkin.button(b, 26 if GameState.touch_ui() else 21)
		if GameState.touch_ui():
			b.custom_minimum_size.y = 72
		if o.cost > 0:
			b.text = "★ %s　（違反守則・膽量 -%d）" % [GameState.fill(o.text), o.cost]
			if GameState.courage < o.cost:
				b.text = "★ %s　（膽量不足）" % GameState.fill(o.text)
				b.disabled = true
		if o.text.begins_with("〔記得〕"):
			# 上一輪的記憶：紫色，提醒玩家這會讓鎮長起疑
			b.add_theme_color_override("font_color", Color("#5b2d7a"))
			b.add_theme_color_override("font_focus_color", Color("#5b2d7a"))
			b.text += "　（鎮長懷疑值↑）"
		b.pressed.connect(func():
			if not _ch2():
				Sound.sfx("choice")
			_chosen.emit(k))
		_choices.add_child(b)
		if first == null and not b.disabled:
			first = b
	# 第一次看到要用膽量的選項：在選項上面說明一次
	var has_cost := opts.any(func(o): return o.cost > 0)
	_tip.visible = has_cost and not GameState.meta.get("tip_courage", false)
	if _tip.visible:
		GameState.meta["tip_courage"] = true
		GameState.save_meta()
	_choices.visible = true
	if first:
		first.grab_focus.call_deferred()
	var idx: int = await _chosen
	_choices.visible = false
	_tip.visible = false
	_choosing = false
	return idx


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	add_child(_bg)
	_bg_img = TextureRect.new()
	_bg_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_img.visible = false
	add_child(_bg_img)
	# 物件特寫：畫面中間偏上，對話框上面
	_item = TextureRect.new()
	_item.position = Vector2(440, 40)
	_item.size = Vector2(400, 440)
	_item.pivot_offset = _item.size / 2
	_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item.visible = false
	add_child(_item)

	_box = PanelContainer.new()
	_box.anchor_left = 0.0
	_box.anchor_right = 1.0
	_box.anchor_top = 1.0
	_box.anchor_bottom = 1.0
	_box.offset_left = 60
	_box.offset_right = -60
	_box.offset_top = -200
	_box.offset_bottom = -24
	# 布料對話框（art/ui_dialog.png）
	var sb := UiSkin.tex("ui_dialog", 80, 60, 80, 50, Vector4(50, 2, 50, 16))
	_box.add_theme_stylebox_override("panel", sb)
	_skin_box = sb
	# 第二章：被洗白的布標（灰白色、灰邊）
	_cold_box = StyleBoxFlat.new()
	_cold_box.bg_color = Color("#f4f4f2")
	_cold_box.border_color = Color("#9a9a9a")
	_cold_box.set_border_width_all(4)
	_cold_box.set_corner_radius_all(20)
	_cold_box.content_margin_left = 28
	_cold_box.content_margin_right = 28
	_cold_box.content_margin_top = 16
	_cold_box.content_margin_bottom = 16
	_cold_box.shadow_color = Color(0, 0, 0, 0.12)
	_cold_box.shadow_size = 6
	_box.visible = false
	add_child(_box)


	# ▼（下一句）與「按住快轉」提示，貼在對話框右下角
	_more = Label.new()
	_more.text = "▼"
	_more.add_theme_font_size_override("font_size", 20)
	_more.add_theme_color_override("font_color", Color("#e8a0bf"))
	_more.anchor_left = 1.0
	_more.anchor_right = 1.0
	_more.anchor_top = 1.0
	_more.anchor_bottom = 1.0
	_more.offset_left = -160
	_more.offset_right = -136
	_more.offset_top = -76
	_more.offset_bottom = -50
	_more.visible = false
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_more)
	_hint = Label.new()
	_hint.text = "按住畫面快轉" if DisplayServer.is_touchscreen_available() else "按住 E 快轉"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("#c9b3bf"))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -350
	_hint.offset_right = -170
	_hint.offset_top = -72
	_hint.offset_bottom = -52
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_tip = Label.new()
	_tip.text = "★ 是違反守則的選項，要用掉左上角的「膽量」。\n會知道更多事情——但也會有人注意到你。膽量睡一覺就會恢復。"
	_tip.add_theme_font_size_override("font_size", 17)
	_tip.add_theme_color_override("font_color", Color("#fff3f8"))
	_tip.add_theme_color_override("font_outline_color", Color("#7b4f6e"))
	_tip.add_theme_constant_override("outline_size", 6)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.anchor_left = 0.5
	_tip.anchor_right = 0.5
	_tip.offset_left = -420
	_tip.offset_right = 420
	_tip.offset_top = 150
	_tip.visible = false
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tip)

	# 說話者的表情頭像，站在對話框左上角
	_portrait = TextureRect.new()
	_portrait.anchor_left = 0.0
	_portrait.anchor_right = 0.0
	_portrait.anchor_top = 1.0
	_portrait.anchor_bottom = 1.0
	_portrait.offset_left = 64
	_portrait.offset_right = 64 + 220
	_portrait.offset_top = -196 - 214
	_portrait.offset_bottom = -192
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	add_child(_portrait)
	_ch2_portrait = TextureRect.new()
	_ch2_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ch2_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ch2_portrait.position = Vector2(930, 40)
	_ch2_portrait.size = Vector2(330, 495)
	_ch2_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ch2_portrait.visible = false
	add_child(_ch2_portrait)

	var v := VBoxContainer.new()
	# 名字在布標上，台詞往下一點，落在米色的布裡
	v.add_theme_constant_override("separation", 8)
	_box.add_child(v)
	# 名字：往右下一點，正好落在布標中間
	var name_pad := MarginContainer.new()
	name_pad.add_theme_constant_override("margin_left", 14)
	name_pad.add_theme_constant_override("margin_top", 5)
	name_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_pad)
	_name = Label.new()
	_name.add_theme_color_override("font_color", Color("#f8f1df"))
	_name.add_theme_color_override("font_outline_color", Color("#5e7048"))
	_name.add_theme_constant_override("outline_size", 4)
	_name.add_theme_font_size_override("font_size", 21)
	name_pad.add_child(_name)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("default_color", Color("#4a3b47"))
	# 手機螢幕小：字放大一點
	_text.add_theme_font_size_override("normal_font_size", 29 if GameState.touch_ui() else 26)
	v.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.anchor_left = 0.5
	_choices.anchor_right = 0.5
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	# 往右偏一點，不要擋住左邊的表情頭像
	_choices.offset_left = -290
	_choices.offset_right = 430
	_choices.offset_top = -480
	_choices.offset_bottom = -205
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 4)
	_choices.visible = false
	add_child(_choices)
	# 對話框本身不攔截點擊，讓「點畫面任何地方」都能前進（手機）
	for c in [_box, v, _name, _text]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_face(who: String, text: String) -> void:
	if not FACES.has(who):
		_portrait.visible = false
		return
	var key: String = FACES[who]
	if not _face_tex.has(key):
		_face_tex[key] = load("res://art/face_%s.png" % key)
	var idx := _expression(key, text)
	var at := AtlasTexture.new()
	at.atlas = _face_tex[key]
	at.region = Rect2((idx % 4) * FACE_CELL, (idx / 4) * FACE_CELL, FACE_CELL, FACE_CELL)
	_portrait.texture = at
	_portrait.visible = true
	# 隔著門說話：只看得到剪影
	_portrait.modulate = Color(0.16, 0.12, 0.18, 0.9) if text.begins_with("（門內）") else Color.WHITE


## 依台詞猜表情（表情圖的順序見 Expressions/表情索引.csv）：
## 0 平靜 1 開心 2 疑問 3 不安 4 難過 5 驚嚇 6／7 角色特有（堅定、警告、恍惚…）
func _expression(key: String, text: String) -> int:
	var t := text.strip_edges()
	if "！？" in t or "？！" in t or t.begins_with("咦") or t.begins_with("什") or t.begins_with("欸"):
		return 5
	match key:
		"mayor":
			if "壞掉" in t or "修理" in t:
				return 6
			if "守則" in t or "乖" in t:
				return 7
			if t.ends_with("？"):
				return 2
			return 1 if "！" in t else 0
		"fen":
			if "不准" in t or "快" in t or "別" in t or "不要" in t:
				return 7
			if "……" in t and ("對不起" in t or "沒辦法" in t):
				return 4
			if t.ends_with("？"):
				return 2
			if t.begins_with("……"):
				return 3
			return 0
		"puppy":
			# 小狗居民：0 平常 1 開心 2 疑問 3 低著頭（愧疚）4 難過 5 驚訝 6 釋然 7 說出對不起
			if "對不起" in t:
				return 7
			if "看到" in t or "沒有說" in t or "壞孩子" in t or "應該要" in t or "掃不" in t:
				return 3
			if "謝謝" in t:
				return 6
		"mochi", "tama":
			if "不用想" in t or "好吃" in t or "笑嘻嘻" in t:
				return 7
	if "嗚" in t or "對不起" in t:
		return 4
	if t.begins_with("……"):
		return 3
	if t.ends_with("？"):
		return 2
	if "～" in t or "嘿嘿" in t or "哈" in t or "！" in t:
		return 1
	return 0


## 第二章的立繪
func _show_portrait_ch2(who: String) -> void:
	var id: String = PORTRAITS.get(who, "")
	var path := portrait_path(id, _faces.get(who, "default")) if id != "" else ""
	# CG（一整張畫好的畫面）上不再疊立繪
	if _bg_img.visible and _cg_shown:
		path = ""
	if path != "":
		_ch2_portrait.texture = load(path)
		_ch2_portrait.visible = true
	else:
		_ch2_portrait.visible = false


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


## 依章節換對話框：第一章是布料對話框，第二章是被洗白的布標；手機上字放大
func _apply_style() -> void:
	var cold := _ch2()
	var touch := GameState.touch_ui()
	_box.add_theme_stylebox_override("panel", _cold_box if cold else _skin_box)
	if cold:
		_name.add_theme_color_override("font_color", Color("#555555"))
		_name.add_theme_constant_override("outline_size", 0)
		_text.add_theme_color_override("default_color", Color("#2e2e2e"))
		_name.add_theme_font_size_override("font_size", 28 if touch else 22)
		_text.add_theme_font_size_override("normal_font_size", 34 if touch else 26)
	else:
		_name.add_theme_color_override("font_color", Color("#f8f1df"))
		_name.add_theme_constant_override("outline_size", 4)
		_text.add_theme_color_override("default_color", Color("#4a3b47"))
		_name.add_theme_font_size_override("font_size", 21)
		_text.add_theme_font_size_override("normal_font_size", 29 if touch else 26)


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

