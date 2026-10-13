extends CanvasLayer
## 修理室：第一次看見門的後面。最後畫面被一針一針縫起來。

const SEW_TIME := 3.5

var _area: Control
var _sew := 0.0
var _sewing := false


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.draw.connect(_draw_area)
	add_child(_area)


func sew() -> void:
	if GameState.fast:
		_sew = 1.0
		_area.queue_redraw()
		return
	_sewing = true
	while _sew < 1.0:
		await get_tree().process_frame
		_sew = minf(1.0, _sew + get_process_delta_time() / SEW_TIME)
		_area.queue_redraw()
	_sewing = false


func _draw_area() -> void:
	var f: Font = GameState.font
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color("#4a3a3a"))
	_area.draw_rect(Rect2(0, 470, 1280, 250), Color("#3a2c2c"))
	# 牆上一整排「小布」名牌
	for k in 14:
		var p := Vector2(90 + k * 80, 70 + (k % 2) * 14)
		_area.draw_line(p + Vector2(20, -10), p + Vector2(20, 0), Color("#8d7b6b"), 2)
		_area.draw_rect(Rect2(p, Vector2(42, 24)), Color("#f6efe6"))
		_area.draw_rect(Rect2(p, Vector2(42, 24)), Color("#e8a0bf"), false, 2)
		_area.draw_string(f, p + Vector2(0, 18), "小布", HORIZONTAL_ALIGNMENT_CENTER, 42, 13, Color("#7a6a78"))
	# 工作台、縫紉機、棉花籃
	_area.draw_rect(Rect2(380, 380, 520, 40), Color("#8d6e63"))
	_area.draw_rect(Rect2(400, 420, 20, 120), Color("#6d4c41"))
	_area.draw_rect(Rect2(860, 420, 20, 120), Color("#6d4c41"))
	_area.draw_rect(Rect2(700, 300, 140, 80), Color("#2f3a2f"))
	_area.draw_rect(Rect2(700, 260, 30, 50), Color("#2f3a2f"))
	_area.draw_line(Vector2(780, 380), Vector2(780, 395), Color("#c0c0c0"), 3)
	Critter.ellipse(_area, Vector2(300, 520), Vector2(70, 40), Color("#c9a37a"))
	for k in 6:
		_area.draw_circle(Vector2(260 + k * 16, 490 - (k % 2) * 8), 14, Color("#fbfbfb"))
	# 工作台上的小布
	_area.draw_set_transform(Vector2(560, 380), -PI / 2.4, Vector2(2.2, 2.2))
	Critter.draw(_area, "sheep", Color("#fffdf8"), 1.0, Vector2.ZERO, false, false, true)
	# 鎮長
	_area.draw_set_transform(Vector2(1060, 560), 0.0, Vector2(4.2, 4.2))
	Critter.draw(_area, "bear", Color("#c4894f"), 1.0, Vector2(-1, 0), true)
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 縫合：上下兩片布往中間合起來，邊緣有縫線
	if _sew > 0.0:
		var gap := lerpf(360.0, 6.0, ease(_sew, 0.6))
		var top := 360.0 - gap
		var cloth := Color("#1e1719")
		_area.draw_rect(Rect2(0, 0, 1280, top), cloth)
		_area.draw_rect(Rect2(0, 720 - top, 1280, top), cloth)
		var thread := Color("#e8a0bf")
		var n := int(_sew * 40)
		for k in n:
			var x := 20.0 + k * 31.0
			_area.draw_line(Vector2(x, top - 4), Vector2(x + 16, 720 - top + 4), thread, 3)
		if _sew >= 1.0:
			# 從縫裡看見鎮長的眼睛
			_area.draw_circle(Vector2(900, 360), 4, Color("#2b2024"))
			_area.draw_circle(Vector2(899, 359), 1.2, Color(1, 1, 1, 0.8))
