extends CanvasLayer
## 道歉練習（第二章小遊戲 1）：跟著音樂盒的拍子按出「對、不、起」。
## 介面要可愛到不合理。按錯的時候，被電的不是小布，是旁邊的重重。
## 隱藏選擇：連續故意亂按 5 次（不在拍子上） → 愛心電量計爆表 → 和平鴿把電擊轉到小布身上（膽量 -1、操行 -10），
## 玩家要按住「我很乖」撐過去。

signal done

const BEAT := 0.75
const NOTES := 18
const LEAD := 2.0
const PERFECT := 0.12
const GOOD := 0.25
const WORDS := ["對", "不", "起"]
const MELODY := [523.3, 659.3, 784.0, 659.3, 587.3, 523.3]
const TARGET := Vector2(430, 560)
const SPAWN_X := 1180.0
const OVERLOAD := 5          # 連續按錯幾次會爆表
const HOLD_TIME := 3.0
const ZZ_POS := Vector2(250, 360)
const PIP_POS := Vector2(1060, 360)
## 外包美術（game/art/ch2/minigames/apology/）；檔案不在時退回程式畫的版本
const ART := "res://art/ch2/minigames/apology/ch2_apology_%s.png"
const BG := "res://art/ch2/backgrounds/ch2_bg_classroom.jpg"
const NOTE_ART := {"對": "note_dui", "不": "note_bu", "起": "note_qi"}
## 「我很乖（按住）」按鈕（美術版：按鈕 300×75，下面接按住進度條）
const BTN_ART := Rect2(490, 552, 300, 75)

var perfects := 0
var took_shock := false
var _t := -1.0
var _area: Control
var _notes: Array = []       # {time, word, state}
var _popups: Array = []      # {text, t, color, pos}
var _smoke: Array = []       # {pos, vel, t}
var _meter := 0              # 愛心電量
var _wrong_streak := 0
var _jolt := 0.0             # 重重被電的晃動
var _phase := "idle"         # idle / play / overload / hold / flash
var _phase_t := 0.0
var _hold := 0.0
var _mouse_down := false
var _tex := {}               # 名稱 → Texture2D（缺檔就沒有這個 key）
var _panels := {}            # 名稱 → StyleBoxTexture（九宮格貼紙）


## 安全載入：檔案不存在就回傳 null，讓呼叫的地方退回程式畫的版本
static func tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	_load_art()
	for k in NOTES:
		_notes.append({"time": LEAD + 1.0 + k * BEAT, "word": WORDS[k % 3], "state": "wait"})


func _load_art() -> void:
	var names := ["judge_ring", "track", "zhongzhong_shocked", "good_button_normal", "good_button_hover",
		"good_button_pressed", "sticker_01_blank", "sticker_02", "sticker_03"]
	names.append_array(NOTE_ART.values())
	for k in 5:
		names.append("heart_meter_%d" % k)
		names.append("hold_progress_%02d" % k)
	for n in names:
		var t := tex(ART % n)
		if t:
			_tex[n] = t
	var bg := tex(BG)
	if bg:
		_tex["bg"] = bg
	# 會拉長的部分用九宮格，縫線和圓角才不會變形
	for n in ["track", "sticker_01_blank"]:
		if _tex.has(n):
			var sb := StyleBoxTexture.new()
			sb.texture = _tex[n]
			sb.set_texture_margin_all(20)
			_panels[n] = sb


func _has_art(names: Array) -> bool:
	for n in names:
		if not _tex.has(n):
			return false
	return true


func play() -> void:
	if GameState.fast:
		if GameState.fast_apology_take and GameState.courage >= 1:
			_take_shock()
		queue_free()
		return
	_phase = "play"
	_t = 0.0
	await done
	queue_free()


func _take_shock() -> void:
	took_shock = true
	GameState.spend_courage(1)
	GameState.add_conduct(-10)
	GameState.set_flag("took_shock_for_zhongzhong")


func _process(delta: float) -> void:
	if _phase == "idle":
		return
	_phase_t += delta
	_jolt = maxf(0.0, _jolt - delta * 2.5)
	for p in _popups:
		p.t += delta
	_popups = _popups.filter(func(p): return p.t < 0.9)
	for s in _smoke:
		s.t += delta
		s.pos += s.vel * delta
	_smoke = _smoke.filter(func(s): return s.t < 1.2)
	match _phase:
		"play":
			_t += delta
			for n in _notes:
				if n.state == "wait" and _t - n.time > GOOD:
					n.state = "miss"
					_wrong(false)
			if _phase == "play" and _t > _notes[-1].time + 1.0:
				_end()
		"overload":
			if _phase_t > 2.2:
				_phase = "hold"
				_phase_t = 0.0
		"hold":
			var held := Input.is_action_pressed("interact") or _mouse_down
			_hold = clampf(_hold + (delta / HOLD_TIME if held else -delta * 0.15), 0.0, 1.0)
			if held and fmod(_phase_t, 0.35) < delta:
				Tones.buzz(self, 0.25)
			if _hold >= 1.0:
				_phase = "flash"
				_phase_t = 0.0
		"flash":
			if _phase_t > 1.4:
				_end()
	_area.queue_redraw()


func _end() -> void:
	_phase = "idle"
	done.emit()


## pressed：是不是玩家亂按的（沒按到只會電重重，不會累積「故意」）
func _wrong(pressed: bool) -> void:
	_meter += 1
	if pressed:
		_wrong_streak += 1
	_jolt = minf(1.0, 0.35 + _meter * 0.08)
	Tones.buzz(self, minf(0.6, 0.15 + _meter * 0.04))
	for k in 3 + mini(_meter, 6):
		_smoke.append({"pos": ZZ_POS + Vector2(randf_range(-40, 40), randf_range(-150, -60)),
			"vel": Vector2(randf_range(-15, 15), randf_range(-60, -30)), "t": 0.0})
	_popups.append({"text": "再加油一點點！", "t": 0.0, "color": Color("#e05780"), "pos": Vector2(640, 250)})
	if _wrong_streak >= OVERLOAD and GameState.courage >= 1 and not took_shock:
		_take_shock()
		_phase = "overload"
		_phase_t = 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if _phase != "play" or not (event.is_action_pressed("interact") or tap):
		return
	get_viewport().set_input_as_handled()
	var best: Dictionary = {}
	var best_dt := INF
	for n in _notes:
		if n.state != "wait":
			continue
		var dt := absf(_t - n.time)
		if dt < best_dt:
			best_dt = dt
			best = n
	if best.is_empty() or best_dt > GOOD:
		# 太快，是在敷衍
		_wrong(true)
		return
	var idx := _notes.find(best)
	Tones.play(self, MELODY[idx % MELODY.size()])
	_wrong_streak = 0
	if best_dt <= PERFECT:
		best.state = "perfect"
		perfects += 1
		_popups.append({"text": "Perfect！%s！" % best.word, "t": 0.0, "color": Color("#e05780"), "pos": TARGET + Vector2(0, -80)})
	else:
		best.state = "good"
		_popups.append({"text": "%s～" % best.word, "t": 0.0, "color": Color("#7a9a7f"), "pos": TARGET + Vector2(0, -80)})


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	if _tex.has("bg"):
		# 教室背景：黑板本來就畫在背景裡
		a.draw_texture_rect(_tex.bg, Rect2(0, 0, 1280, 720), false)
		a.draw_string(f, Vector2(350, 190), "今天的練習：對、不、起", HORIZONTAL_ALIGNMENT_CENTER, 620, 38, Color("#f4f4f2"))
		a.draw_string(f, Vector2(350, 232), GameState.hint("音符碰到圓圈時按 E／空白鍵（手機：點畫面）"), HORIZONTAL_ALIGNMENT_CENTER, 620, 22, Color("#d8d8d4"))
		for k in 3:
			_star(Vector2(895 + k * 26, 300), 9, Color("#ffd1dc"))
	else:
		a.draw_rect(Rect2(0, 0, 1280, 720), Color("#ececea"))
		# 黑板與可愛的貼紙
		a.draw_rect(Rect2(340, 40, 600, 150), Color("#4a4f4a"))
		a.draw_rect(Rect2(340, 40, 600, 150), Color("#9a9a9a"), false, 6)
		a.draw_string(f, Vector2(340, 100), "今天的練習：對、不、起", HORIZONTAL_ALIGNMENT_CENTER, 600, 34, Color("#f4f4f2"))
		a.draw_string(f, Vector2(340, 150), GameState.hint("音符碰到圓圈時按 E／空白鍵（手機：點畫面）"), HORIZONTAL_ALIGNMENT_CENTER, 600, 20, Color("#cfcfcf"))
		for k in 3:
			_star(Vector2(1110 + k * 30, 212), 11, Color("#ffd1dc"))

	# 愛心電量計（就是電壓）
	var heart := Vector2(1140, 110)
	var fill := clampf(_meter / float(OVERLOAD + 3), 0.0, 1.0)
	var heart_idx := mini(4, ceili(fill * 4.0))
	if took_shock:
		heart_idx = 4
	if _tex.has("heart_meter_%d" % heart_idx):
		var ht: Texture2D = _tex["heart_meter_%d" % heart_idx]
		a.draw_texture(ht, heart - ht.get_size() * 0.5 + Vector2(0, -6))
	else:
		_heart(heart, 46, Color("#f7d6e0"))
		_heart(heart, 46 * fill, Color("#ff5c8a"))
	_label(heart + Vector2(-80, 86), "愛心電量", 160, 20, Color("#c2558a"))

	# 重重：手腕上的金屬環
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * _jolt
	var zz_lift := Vector2(0, -40.0 * _jolt)
	var zz_hit := _phase in ["play", "idle"]
	if _tex.has("zhongzhong_shocked"):
		# 外包的重重（手腕上的金屬環、被電的線條都畫在圖裡）；被電時發白
		var zt: Texture2D = _tex.zhongzhong_shocked
		var zsize := zt.get_size() * 0.72
		var zmod := Color(1.35, 1.35, 1.35) if _jolt >= 0.5 and zz_hit else Color.WHITE
		a.draw_texture_rect(zt, Rect2(ZZ_POS + shake + zz_lift - Vector2(zsize.x * 0.5, zsize.y - 20), zsize), false, zmod)
		_label(ZZ_POS + Vector2(-80, 50), "重重", 160, 20, Color("#555555"))
	else:
		a.draw_rect(Rect2(ZZ_POS + Vector2(-70, -10), Vector2(140, 16)), Color("#8d8d8d"))
		a.draw_set_transform(ZZ_POS + shake + zz_lift, 0.0, Vector2(3.0, 3.0))
		Ch2Critter.draw(a, "hippo", Color("#9c9c9c") if _jolt < 0.5 or not zz_hit else Color("#f4f4f2"), 1.0, Vector2(0.5, 0), false)
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for side in [-1, 1]:
			a.draw_arc(ZZ_POS + shake + zz_lift + Vector2(side * 52, -40), 10, 0, TAU, 16, Color("#5a5a5a"), 4)
		a.draw_string(f, ZZ_POS + Vector2(-80, 50), "重重", HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color("#555555"))
	for s in _smoke:
		var c := Color(0.5, 0.5, 0.5, 0.6 * (1.0 - s.t / 1.2))
		a.draw_circle(s.pos, 6 + s.t * 10, c)

	# 小布
	var pip_shake := Vector2.ZERO
	if _phase == "hold" and (Input.is_action_pressed("interact") or _mouse_down):
		pip_shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 8.0
	a.draw_set_transform(PIP_POS + pip_shake, 0.0, Vector2(2.6, 2.6))
	Ch2Critter.draw(a, "sheep", Color("#fffdf8"), 1.0, Vector2(-0.5, 0), _phase == "play", false, true,
		{"grey_patch": GameState.has("c2_grey_patch")})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if took_shock:
		for side in [-1, 1]:
			a.draw_arc(PIP_POS + pip_shake + Vector2(side * 44, -36), 9, 0, TAU, 16, Color("#5a5a5a"), 4)

	if _phase == "play" and _has_art(["track", "judge_ring", "note_dui", "note_bu", "note_qi"]):
		# 外包的軌道、判定圈與「對／不／起」音符
		_panels.track.modulate_color = Color.WHITE
		a.draw_style_box(_panels.track, Rect2(TARGET.x - 115, TARGET.y - 45, SPAWN_X - TARGET.x + 175, 90))
		var ring: Texture2D = _tex.judge_ring
		a.draw_texture(ring, TARGET - ring.get_size() * 0.5)
		for n in _notes:
			if n.state != "wait":
				continue
			var dt: float = n.time - _t
			if dt > LEAD:
				continue
			var x := TARGET.x + (SPAWN_X - TARGET.x) * (dt / LEAD)
			var nt: Texture2D = _tex[NOTE_ART[n.word]]
			a.draw_texture(nt, Vector2(x, TARGET.y) - nt.get_size() * 0.5)
	elif _phase == "play":
		a.draw_line(TARGET, Vector2(SPAWN_X, TARGET.y), Color("#f8c8d8"), 8)
		a.draw_arc(TARGET, 40, 0, TAU, 32, Color("#e05780"), 5)
		for n in _notes:
			if n.state != "wait":
				continue
			var dt: float = n.time - _t
			if dt > LEAD:
				continue
			var x := TARGET.x + (SPAWN_X - TARGET.x) * (dt / LEAD)
			a.draw_circle(Vector2(x, TARGET.y), 28, Color("#fffaf2"))
			a.draw_arc(Vector2(x, TARGET.y), 28, 0, TAU, 24, Color("#e8a0bf"), 3)
			a.draw_string(f, Vector2(x - 30, TARGET.y + 11), n.word, HORIZONTAL_ALIGNMENT_CENTER, 60, 30, Color("#8a4b68"))
	elif _phase == "overload":
		if _tex.has("sticker_03"):
			# 貼紙上本來就寫著「嗶——」
			var bt: Texture2D = _tex.sticker_03
			a.draw_texture(bt, Vector2(640, 565) - bt.get_size() * 0.5)
		else:
			a.draw_string(f, Vector2(0, 600), "嗶——", HORIZONTAL_ALIGNMENT_CENTER, 1280, 40, Color("#e05780"))
		_label(Vector2(0, 650), "和平鴿：……喔？小布，你是故意的嗎？好孩子。願意替朋友受罰，是很美的事。",
			1280, 22, Color("#444444"))
	elif _phase == "hold" and _has_art(["good_button_normal", "good_button_hover", "good_button_pressed", "hold_progress_00"]):
		# 外包按鈕：按鈕上本來就寫著「我很乖（按住）」
		var held := Input.is_action_pressed("interact") or _mouse_down
		var state := "pressed" if held else ("hover" if BTN_ART.has_point(a.get_local_mouse_position()) else "normal")
		a.draw_texture(_tex["good_button_" + state], BTN_ART.position)
		var prog: Texture2D = _tex.get("hold_progress_%02d" % mini(4, int(_hold * 5.0)), _tex.hold_progress_00)
		a.draw_texture(prog, Vector2(BTN_ART.position.x, BTN_ART.end.y + 12))
		_label(Vector2(0, 690), GameState.hint("按住 E／空白鍵（手機：按住畫面）"), 1280, 18, Color("#666666"))
		# 越撐越白
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _hold * 0.55))
	elif _phase == "hold":
		var btn := Rect2(440, 560, 400, 90)
		a.draw_rect(btn, Color("#ffe1ec"))
		a.draw_rect(Rect2(btn.position, Vector2(btn.size.x * _hold, btn.size.y)), Color("#ffb3c9"))
		a.draw_rect(btn, Color("#e05780"), false, 4)
		a.draw_string(f, Vector2(btn.position.x, btn.position.y + 58), "我很乖（按住）", HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 34, Color("#8a4b68"))
		a.draw_string(f, Vector2(0, 690), GameState.hint("按住 E／空白鍵（手機：按住畫面）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#888888"))
		# 越撐越白
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _hold * 0.55))
	elif _phase == "flash":
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 1.0 - _phase_t * 0.3))

	for p in _popups:
		var c: Color = p.color
		c.a = 1.0 - p.t / 0.9
		var pos: Vector2 = p.pos + Vector2(0, -p.t * 40)
		if p.text == "再加油一點點！" and _tex.has("sticker_02"):
			# 貼紙上的字跟遊戲的字一模一樣，直接用
			# 往下挪一點，才不會蓋住黑板上的說明
			var st: Texture2D = _tex.sticker_02
			a.draw_texture_rect(st, Rect2(pos + Vector2(0, 45) - st.get_size() * 0.4, st.get_size() * 0.8), false, Color(1, 1, 1, c.a))
		elif _panels.has("sticker_01_blank"):
			# 空白貼紙＋遊戲自己的字
			var w := f.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 56
			_panels.sticker_01_blank.modulate_color = Color(1, 1, 1, c.a)
			a.draw_style_box(_panels.sticker_01_blank, Rect2(pos.x - w * 0.5, pos.y - 38, w, 54))
			a.draw_string(f, Vector2(pos.x - w * 0.5, pos.y - 2), p.text, HORIZONTAL_ALIGNMENT_CENTER, w, 26, c)
		else:
			a.draw_string(f, p.pos + Vector2(-200, -p.t * 40), p.text, HORIZONTAL_ALIGNMENT_CENTER, 400, 28, c)


## 有背景圖時，文字底下墊一張空白貼紙，才看得清楚
func _label(pos: Vector2, text: String, width: float, size: int, col: Color) -> void:
	var f: Font = GameState.font
	if _tex.has("bg") and _panels.has("sticker_01_blank"):
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 40
		var h := size + 22.0
		_panels.sticker_01_blank.modulate_color = Color(1, 1, 1, 0.92)
		_area.draw_style_box(_panels.sticker_01_blank, Rect2(pos.x + width * 0.5 - w * 0.5, pos.y - size - 6, w, h))
	_area.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


func _heart(c: Vector2, size: float, col: Color) -> void:
	if size <= 1.0:
		return
	_area.draw_circle(c + Vector2(-size * 0.45, -size * 0.2), size * 0.5, col)
	_area.draw_circle(c + Vector2(size * 0.45, -size * 0.2), size * 0.5, col)
	_area.draw_colored_polygon(PackedVector2Array([c + Vector2(-size * 0.92, -size * 0.05),
		c + Vector2(size * 0.92, -size * 0.05), c + Vector2(0, size * 0.95)]), col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * rad)
	_area.draw_colored_polygon(pts, col)
