extends CanvasLayer

const MIRROR_TEX := preload("res://art/mirror_states.png")
## 盯著鏡子 10 秒。不能跳過，玩家必須真的等。
## 第 7 秒：鏡中小布的身後，床上似乎坐著一個人。第 10 秒：沒有了。

signal done

const LENGTH := 10.0
var _t := 0.0
var _area: Control


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast:
		queue_free()
		return
	await done
	queue_free()


func _process(delta: float) -> void:
	_t += delta
	_area.queue_redraw()
	if _t >= LENGTH:
		set_process(false)
		done.emit()


func _draw_area() -> void:
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color("#2a2230"))
	var c := Vector2(640, 360)
	# 立鏡（美術：鏡中的孩子 4 種狀態，第 1 格是空鏡）
	var frame := Rect2(c.x - 260, c.y - 340, 520, 680)
	_area.draw_texture_rect_region(MIRROR_TEX, frame, Rect2(28, 0, 200, 256))
	# 第 7～10 秒：鏡子裡慢慢浮現一個人類小孩（第 2 格「浮現」）
	if _t >= 7.0 and _t < LENGTH:
		var a := clampf((_t - 7.0) / 0.8, 0.0, 1.0) * 0.55
		_area.draw_texture_rect_region(MIRROR_TEX, frame, Rect2(256 + 28, 0, 200, 256), Color(1, 1, 1, a))
	# 鏡中的小布（輕微呼吸，讓畫面不是靜止圖）
	var breathe := sin(_t * 2.0) * 1.5
	_area.draw_set_transform(c + Vector2(-60, 200 + breathe), 0.0, Vector2(2.4, 2.4))
	Critter.draw(_area, "sheep", Color("#fffdf8"), 1.0, Vector2.ZERO, true, false, GameState.has("tag_on"))
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
