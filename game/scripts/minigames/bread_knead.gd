extends CanvasLayer
## 揉麵團節奏小遊戲：音符滑到圓圈時按下 E／空白鍵。
## 判定很寬鬆（難度不要太高）。連續 8 個 Perfect → 露露開始哼「另一首歌」（秘密）。

signal done

const BEAT := 0.6
const NOTES := 26
const LEAD := 2.0            # 音符從出現到抵達圓圈的時間
const PERFECT := 0.11
const GOOD := 0.22
const STREAK_GOAL := 8
const TARGET := Vector2(330, 400)
const SPAWN_X := 1180.0
## 音樂盒旋律（C 大調五聲音階）
const MELODY := [523.3, 587.3, 659.3, 784.0, 659.3, 587.3, 523.3, 440.0]
## 露露哼的「另一首歌」：同樣的節拍，旋律不一樣（小調）
const OTHER_SONG := [440.0, 523.3, 493.9, 415.3, 440.0, 329.6, 349.2, 329.6]

var max_streak := 0
var _streak := 0
var _t := -1.0
var _area: Control
var _notes: Array = []       # {time, state}
var _popups: Array = []      # {text, t, color}
var _hums: Array = []        # {pos, t, odd}
var _running := false
var _hum_timer := 0.0


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	for k in NOTES:
		_notes.append({"time": LEAD + 1.0 + k * BEAT, "state": "wait"})


func play() -> int:
	if GameState.fast:
		max_streak = GameState.fast_rhythm_streak
		_finish()
		queue_free()
		return max_streak
	_running = true
	_t = 0.0
	await done
	queue_free()
	return max_streak


func _finish() -> void:
	if max_streak >= STREAK_GOAL:
		GameState.set_flag("lulu_song")


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	for n in _notes:
		if n.state == "wait" and _t - n.time > GOOD:
			n.state = "miss"
			_streak = 0
			_popups.append({"text": "Miss", "t": 0.0, "color": Color("#a39ba8")})
	for p in _popups:
		p.t += delta
	_popups = _popups.filter(func(p): return p.t < 0.6)
	# 露露的哼歌：連段越長，音符越多；達成 8 連 Perfect 後，飄出灰色的「另一首歌」
	_hum_timer -= delta
	if _hum_timer <= 0 and _streak >= 3:
		_hum_timer = 0.5
		_hums.append({"pos": Vector2(980, 260), "t": 0.0, "odd": max_streak >= STREAK_GOAL})
	for h in _hums:
		h.t += delta
		h.pos = h.pos + Vector2(-20, -40) * delta
	_hums = _hums.filter(func(h): return h.t < 2.2)
	_area.queue_redraw()
	if _t > _notes[-1].time + 1.2:
		_running = false
		_finish()
		done.emit()


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not _running or not (event.is_action_pressed("interact") or tap):
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
		return
	var idx := _notes.find(best)
	var song: Array = OTHER_SONG if max_streak >= STREAK_GOAL else MELODY
	Tones.play(self, song[idx % song.size()])
	if best_dt <= PERFECT:
		best.state = "perfect"
		_streak += 1
		max_streak = maxi(max_streak, _streak)
		_popups.append({"text": "Perfect!", "t": 0.0, "color": Color("#e05780")})
	else:
		best.state = "good"
		_streak = 0
		_popups.append({"text": "Good", "t": 0.0, "color": Color("#6d9773")})


func _draw_area() -> void:
	var f: Font = GameState.font
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color("#ffe5ec"))
	_area.draw_string(f, Vector2(0, 70), "揉麵團！音符碰到圓圈時按 E／空白鍵（手機：點畫面）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#b56576"))
	_area.draw_string(f, Vector2(0, 110), "連續 Perfect：%d" % _streak, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color("#c2558a"))
	# 麵團與露露
	Critter.ellipse(_area, Vector2(330, 560), Vector2(120, 50), Color("#fff3d6"))
	_area.draw_set_transform(Vector2(1000, 360), 0.0, Vector2(2.2, 2.2))
	Critter.draw(_area, "rabbit", Color("#f4b6c2"), 1.0, Vector2(-1, 0), true)
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for h in _hums:
		var c := Color("#8e8a99") if h.odd else Color("#f28fb0")
		c.a = 1.0 - h.t / 2.2
		_area.draw_string(f, h.pos, "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)
	# 軌道
	_area.draw_line(Vector2(TARGET.x, TARGET.y), Vector2(SPAWN_X, TARGET.y), Color("#f8c8d8"), 8)
	_area.draw_arc(TARGET, 38, 0, TAU, 32, Color("#e05780"), 5)
	for n in _notes:
		if n.state != "wait":
			continue
		var dt: float = n.time - _t
		if dt > LEAD:
			continue
		var x := TARGET.x + (SPAWN_X - TARGET.x) * (dt / LEAD)
		_area.draw_circle(Vector2(x, TARGET.y), 24, Color("#fffaf2"))
		_area.draw_arc(Vector2(x, TARGET.y), 24, 0, TAU, 24, Color("#d4a373"), 3)
	for p in _popups:
		var c: Color = p.color
		c.a = 1.0 - p.t / 0.6
		_area.draw_string(f, TARGET + Vector2(-80, -60 - p.t * 40), p.text, HORIZONTAL_ALIGNMENT_CENTER, 160, 26, c)
