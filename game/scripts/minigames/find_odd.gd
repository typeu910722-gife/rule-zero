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

var round_no := 1
## 找到了嗎（第 3 輪永遠是 false）
var found := false
var _odd := -1
var _cursor := 0
var _t := TIME
var _running := false
var _area: Control
var _flash := 0.0


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


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
	return ORIGIN + Vector2(i % COLS, i / COLS) * STEP


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in COLS * ROWS:
			if event.position.distance_to(_slot(i) + Vector2(0, -60)) < 70:
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
