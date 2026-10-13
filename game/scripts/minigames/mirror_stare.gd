extends CanvasLayer
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
	Critter.ellipse(_area, c, Vector2(230, 320), Color("#e9c46a"))
	Critter.ellipse(_area, c, Vector2(205, 295), Color("#dcebf0"))
	# 倒影中的床
	_area.draw_rect(Rect2(c + Vector2(30, 40), Vector2(150, 90)), Color("#a2d2ff"))
	_area.draw_rect(Rect2(c + Vector2(30, 40), Vector2(150, 22)), Color("#ffffff"))
	# 第 7～10 秒：床上坐著一個模糊的人影（人類小孩的輪廓）
	if _t >= 7.0 and _t < LENGTH:
		var a := clampf((_t - 7.0) / 0.6, 0.0, 1.0) * 0.17
		var shade := Color(0.25, 0.22, 0.3, a)
		_area.draw_circle(c + Vector2(110, -30), 26, shade)
		Critter.ellipse(_area, c + Vector2(110, 40), Vector2(34, 50), shade)
	# 鏡中的小布（輕微呼吸，讓畫面不是靜止圖）
	var breathe := sin(_t * 2.0) * 1.5
	_area.draw_set_transform(c + Vector2(-40, 150 + breathe), 0.0, Vector2(4.0, 4.0))
	Critter.draw(_area, "sheep", Color("#fffdf8"), 1.0, Vector2.ZERO, true, false, GameState.has("tag_on"))
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
