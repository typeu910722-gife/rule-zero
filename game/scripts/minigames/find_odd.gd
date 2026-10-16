extends CanvasLayer
## 找出壞孩子（第二章小遊戲 3）：一排長得一模一樣的灰色玩偶，找出「笑得不標準」的那一個。
## round 1：嘴角被線拉上去、一隻眼睛是相機鏡頭（嘎嘎）
## round 2：脖子上露出一截紅色（鼬鼬）
## round 3：全部都一樣。倒數結束前一秒，有人舉手。
## 操作：點那一隻；鍵盤用方向鍵移動框框、E 選。

signal done

const COLS := 6
const ROWS := 2
const TIME := 20.0
const ORIGIN := Vector2(240, 300)
const STEP := Vector2(160, 190)
## 外包美術（game/art/ch2/minigames/find_odd/）；檔案不在時退回程式畫的版本
const ART := "res://art/ch2/minigames/find_odd/ch2_find_odd_%s.png"
const BG := "res://art/ch2/backgrounds/ch2_bg_classroom.jpg"
## 字底下墊的空白貼紙（跟道歉練習同一套）
const STICKER := "res://art/ch2/minigames/apology/ch2_apology_sticker_01_blank.png"
## 美術版玩偶（150×180）：腳底對齊 _slot()，點擊判定用玩偶的中心
const ART_ORIGIN := Vector2(240, 345)
const ART_HIT := Vector2(0, -88)
const ART_HIT_R := 76.0
## 放大鏡計時器的位置（圖 120×140，鏡片中心在圖上的 (55, 55)、半徑 43）
const TIMER_POS := Vector2(1098, 20)
## 第 3 輪：剩幾秒時，全部的玩偶一起轉過來盯著你
const STARE_AT := 3.0

var round_no := 1
## 找到了嗎（第 3 輪永遠是 false）
var found := false
var _odd := -1
var _cursor := 0
var _t := TIME
var _running := false
var _area: Control
var _flash := 0.0
var _tex := {}               # 名稱 → Texture2D（缺檔就沒有這個 key）
var _panel: StyleBoxTexture
var _sel: StyleBoxTexture


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
	for n in ["normal", "camera", "redthread", "stare", "selection", "timer"]:
		var t := tex(ART % n)
		if t:
			_tex[n] = t
	var bg := tex(BG)
	if bg:
		_tex["bg"] = bg
	var st := tex(STICKER)
	if st:
		_panel = StyleBoxTexture.new()
		_panel.texture = st
		_panel.set_texture_margin_all(20)
	if _tex.has("selection"):
		# 選取框用九宮格拉長，圓角才不會變形
		_sel = StyleBoxTexture.new()
		_sel.texture = _tex.selection
		_sel.set_texture_margin_all(32)


func _art() -> bool:
	return _tex.has("normal") and _tex.has("camera") and _tex.has("redthread") and _tex.has("stare")


func play(p_round: int) -> bool:
	round_no = p_round
	var rng := RandomNumberGenerator.new()
	rng.seed = 47 + p_round
	_odd = rng.randi_range(0, COLS * ROWS - 1) if round_no < 3 else -1
	if GameState.fast:
		found = round_no < 3
		queue_free()
		return found
	_running = true
	await done
	queue_free()
	return found


func _process(delta: float) -> void:
	if not _running:
		return
	_t -= delta
	_flash = maxf(0.0, _flash - delta)
	# 第 3 輪：倒數結束前一秒，有人舉手
	if _t <= (1.0 if round_no == 3 else 0.0):
		_end(false)
	_area.queue_redraw()


func _end(ok: bool) -> void:
	found = ok
	_running = false
	done.emit()


func _pick(i: int) -> void:
	if i == _odd:
		Tones.play(self, 1046.5)
		_end(true)
	else:
		_flash = 0.4


func _slot(i: int) -> Vector2:
	return (ART_ORIGIN if _art() else ORIGIN) + Vector2(i % COLS, i / COLS) * STEP


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in COLS * ROWS:
			var hit: bool = event.position.distance_to(_slot(i) + ART_HIT) < ART_HIT_R if _art() \
				else event.position.distance_to(_slot(i) + Vector2(0, -60)) < 70
			if hit:
				get_viewport().set_input_as_handled()
				_cursor = i
				_pick(i)
				return
	var moves := {"move_left": -1, "move_right": 1, "move_up": -COLS, "move_down": COLS}
	for action in moves:
		if event.is_action_pressed(action):
			_cursor = clampi(_cursor + moves[action], 0, COLS * ROWS - 1)
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_pick(_cursor)


func _draw_area() -> void:
	if _art():
		_draw_art()
	else:
		_draw_fallback()


## 美術版：教室背景＋外包玩偶
func _draw_art() -> void:
	var f: Font = GameState.font
	var a := _area
	if _tex.has("bg"):
		a.draw_texture_rect(_tex.bg, Rect2(0, 0, 1280, 720), false)
	else:
		a.draw_rect(Rect2(0, 0, 1280, 720), Color("#e6e6e3"))
	_label(Vector2(0, 62), "找出笑得不標準的壞孩子！（第 %d 輪）" % round_no, 1280, 32, Color("#c2558a"))
	_label(Vector2(0, 112), "點那一隻（鍵盤：方向鍵移動、E 選）　找到的人，有糖果 ♥", 1280, 20, Color("#6b6b6b"))
	# 放大鏡計時
	var frac := clampf(_t / TIME, 0.0, 1.0)
	var lens := TIMER_POS + Vector2(55, 55)
	if _tex.has("timer"):
		a.draw_texture(_tex.timer, TIMER_POS)
		a.draw_arc(lens, 46, -PI / 2, -PI / 2 + TAU * frac, 40, Color("#e05780"), 6)
		a.draw_string(f, lens + Vector2(-50, 32), "%d" % ceili(maxf(_t, 0.0)), HORIZONTAL_ALIGNMENT_CENTER, 100, 24, Color("#8a4b68"))
	else:
		a.draw_arc(lens, 34, -PI / 2, -PI / 2 + TAU * frac, 32, Color("#e05780"), 8)
		a.draw_string(f, lens + Vector2(-50, 10), "%d" % ceili(maxf(_t, 0.0)), HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color("#8a4b68"))
	# 第 3 輪快結束時，大家一起轉過來
	var stare := round_no == 3 and _t <= STARE_AT
	for i in COLS * ROWS:
		var p := _slot(i)
		var n := "normal"
		if stare:
			n = "stare"
		elif i == _odd and round_no == 1:
			n = "camera"
		elif i == _odd and round_no == 2:
			n = "redthread"
		var t: Texture2D = _tex[n]
		a.draw_texture(t, p - Vector2(t.get_size().x * 0.5, t.get_size().y - 2))
		if i == _cursor:
			var r := Rect2(p + Vector2(-74, -184), Vector2(148, 190))
			if _sel:
				a.draw_style_box(_sel, r)
			else:
				a.draw_rect(r, Color("#e05780"), false, 4)
	if _flash > 0:
		_label(Vector2(0, 680), "不是這隻喔～", 1280, 24, Color(0.88, 0.34, 0.5, _flash / 0.4))


## 有背景圖時，文字底下墊一張空白貼紙，才看得清楚
func _label(pos: Vector2, text: String, width: float, size: int, col: Color) -> void:
	var f: Font = GameState.font
	if _panel:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 48
		_panel.modulate_color = Color(1, 1, 1, 0.92 * col.a)
		_area.draw_style_box(_panel, Rect2(pos.x + width * 0.5 - w * 0.5, pos.y - size - 8, w, size + 26))
	_area.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


## 外包美術還沒到時的程式畫版本（保留當備用）
func _draw_fallback() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#e6e6e3"))
	a.draw_string(f, Vector2(0, 70), "找出笑得不標準的壞孩子！（第 %d 輪）" % round_no, HORIZONTAL_ALIGNMENT_CENTER, 1280, 32, Color("#c2558a"))
	a.draw_string(f, Vector2(0, 110), "點那一隻（鍵盤：方向鍵移動、E 選）　找到的人，有糖果 ♥", HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color("#888888"))
	# 放大鏡計時
	var frac := clampf(_t / TIME, 0.0, 1.0)
	a.draw_arc(Vector2(1160, 90), 34, -PI / 2, -PI / 2 + TAU * frac, 32, Color("#e05780"), 8)
	a.draw_string(f, Vector2(1110, 100), "%d" % ceili(maxf(_t, 0.0)), HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color("#8a4b68"))
	for i in COLS * ROWS:
		var p := _slot(i)
		a.draw_set_transform(p, 0.0, Vector2(2.2, 2.2))
		var opts := {}
		if i == _odd and round_no == 2:
			opts["thread"] = true
		Critter.draw(a, "puppy", Color("#a9a9a6"), 1.0, Vector2.ZERO, true, i == _odd and round_no == 1, false, opts)
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if i == _odd and round_no == 1:
			# 一隻眼睛是相機鏡頭
			var lens := p + Vector2(7, -26) * 2.2
			a.draw_circle(lens, 10, Color("#d9d9d9"))
			a.draw_circle(lens, 7.5, Color("#1d1d1d"))
			a.draw_circle(lens, 4, Color("#4b6cb7"))
			a.draw_circle(lens + Vector2(-1.5, -1.5), 1.5, Color.WHITE)
		if i == _cursor:
			a.draw_rect(Rect2(p + Vector2(-66, -130), Vector2(132, 150)), Color("#e05780"), false, 4)
	if _flash > 0:
		a.draw_string(f, Vector2(0, 680), "不是這隻喔～", HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Color(0.88, 0.34, 0.5, _flash / 0.4))
