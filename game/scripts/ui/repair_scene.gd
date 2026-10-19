extends CanvasLayer
## 修理室：第一次看見門的後面。最後畫面被一針一針縫起來。

const SEW_TIME := 3.5
const BG := preload("res://art/bg_repair.jpg")
const MAYOR := preload("res://art/item_stand_mayor.png")

var _area: Control
var _sew := 0.0
var _sewing := false


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	# 修理室（美術：bg_repair.jpg）：工作台、縫紉機、一整排「小布」名牌
	_area.draw_texture_rect(BG, Rect2(0, 0, 1280, 720), false)
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.05, 0.08, 0.25))
	# 工作台上的小布（躺著）
	_area.draw_set_transform(Vector2(470, 300), -PI / 2.2, Vector2(1.25, 1.25))
	Critter.draw(_area, "sheep", Color("#fffdf8"), 1.0, Vector2.ZERO, false, false, true)
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 鎮長（立繪），站在右邊
	var mh := 520.0
	var mw := mh * MAYOR.get_width() / MAYOR.get_height()
	_area.draw_texture_rect(MAYOR, Rect2(1180 - mw, 700 - mh, mw, mh), false)

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
