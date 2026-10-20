extends Ch3Mini
## 第四章 4-1「自我介紹」（遙）：在講台上選要說的話。
## 每說一句，台下的笑聲就大一點，選項一個一個變灰；全部變灰就結束（這是遙的記憶，結果不會變）。
## 選：上下鍵＋E／點選項。回傳：最後說出口的那一句（字串）。

const WARM := Color("#efe6d6")
const LINES := ["我叫遙。", "我從很遠的地方轉來。", "我喜歡畫畫。", "請多指教。"]
const LAUGH := ["（有人小聲笑了一下）", "（後面幾排在笑）", "（整間教室都在笑）", "（笑聲大到聽不見自己的聲音）"]

var grey := {}          # 已經變灰的選項
var cursor := 0
var laugh := 0          # 0..4
var said: Array = []
var _shake := 0.0


func _setup() -> void:
	title = "自我介紹"
	hint = "上下選、E／點一下說出口"
	bg_color = WARM
	fast_result = LINES[0]


func _alive() -> Array:
	var a: Array = []
	for i in LINES.size():
		if not grey.has(i):
			a.append(i)
	return a


func _say(i: int) -> void:
	if grey.has(i):
		return
	said.append(LINES[i])
	grey[i] = true
	laugh = mini(laugh + 1, LAUGH.size())
	_shake = 0.5
	# 笑聲：遊戲裡既有的笑聲，越來越多
	for k in laugh:
		_laugh(k, 0.15 * k)
	# 另外一個選項也跟著變灰（說不出口了）
	var alive := _alive()
	if alive.size() > 1:
		grey[alive[randi() % alive.size()]] = true
	alive = _alive()
	if alive.is_empty():
		get_tree().create_timer(1.2).timeout.connect(func(): finish(said[-1]))
		return
	cursor = alive[0]


func _laugh(k: int, delay: float) -> void:
	if GameState.fast:
		return
	var kind: String = ["laugh", "giggle", "chuckle"][k % 3]
	var n: int = {"laugh": 3, "giggle": 3, "chuckle": 2}[kind]
	var path := "res://audio/voice/%s_%d.ogg" % [kind, randi_range(1, n)]
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.pitch_scale = randf_range(0.9, 1.25)
	p.volume_db = -10.0 + k * 1.5 + Audio.sfx_db()
	add_child(p)
	get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(p):
			p.play())
	p.finished.connect(p.queue_free)


func _tick(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)


func _other_input(e: InputEvent) -> void:
	var alive := _alive()
	if alive.is_empty():
		return
	var k := alive.find(cursor)
	if e.is_action_pressed("move_down") or e.is_action_pressed("ui_down"):
		cursor = alive[(k + 1) % alive.size()]
	elif e.is_action_pressed("move_up") or e.is_action_pressed("ui_up"):
		cursor = alive[(k - 1 + alive.size()) % alive.size()]


func _press(down: bool, e: InputEvent) -> void:
	if not down:
		return
	var pos := Vector2(-1, -1)
	if e is InputEventMouseButton or e is InputEventScreenTouch:
		pos = e.position
	if pos.x >= 0:
		for i in LINES.size():
			if _rect(i).has_point(pos):
				_say(i)
				return
		return
	_say(cursor)


func _rect(i: int) -> Rect2:
	return Rect2(390, 290 + i * 66, 500, 56)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake
	# 講台與台下（一排排的頭，看不清楚臉）
	for row in 3:
		for k in 9:
			var p := Vector2(110 + k * 132 + row * 20, 630 - row * 22) + sh * (row + 1) * 0.3
			c.draw_circle(p, 18, Color("#5c5246").lightened(row * 0.15))
	c.draw_string(f, Vector2(0, 150), "三年二班。黑板上寫著：「轉學生」", HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, INK)
	c.draw_string(f, Vector2(0, 250) + sh, LAUGH[laugh - 1] if laugh > 0 else "（安靜）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#a0583c") if laugh > 2 else SOFT)
	for i in LINES.size():
		var r := _rect(i)
		var g := grey.has(i)
		var sel := i == cursor and not g
		c.draw_rect(r, Color(1, 1, 1, 0.35 if g else 0.85))
		c.draw_rect(r, PINK if sel else Color("#b9a68a"), false, 4.0 if sel else 2.0)
		c.draw_string(f, r.position + Vector2(0, 40), LINES[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color("#c9c0b2") if g else INK)
