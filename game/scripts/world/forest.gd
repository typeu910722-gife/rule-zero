extends Node2D
## 鐘塔後面的森林（美術：art/forest_map.jpg）。小徑分成好幾條岔路，
## 零件散在各條路的盡頭，最深處（地圖最上面）是被拆掉的小綿羊堆。

const MAP := preload("res://art/forest_map.jpg")
const MASK_TEX := preload("res://art/forest_mask.png")
const SCALE := 1.6
const MASK_SCALE := 2.0
const W := 1479.0 * SCALE
const H := 1064.0 * SCALE
const BOUNDS := Rect2(20, 20, W - 40, H - 40)
const START := Vector2(1232, 1664)
static var _mask: Image


static func blocked(p: Vector2) -> bool:
	if _mask == null:
		_mask = MASK_TEX.get_image()
		if _mask.is_compressed():
			_mask.decompress()
	var q := p / SCALE / MASK_SCALE
	var x := int(q.x)
	var y := int(q.y)
	if x < 0 or y < 0 or x >= _mask.get_width() or y >= _mask.get_height():
		return true
	return _mask.get_pixel(x, y).r < 0.5


static func nearest_walkable(p: Vector2) -> Vector2:
	if not blocked(p):
		return p
	for r in range(6, 400, 6):
		var steps := maxi(8, int(r / 4.0))
		for k in steps:
			var q := p + Vector2.from_angle(TAU * k / steps) * r
			if not blocked(q):
				return q
	return p


func _draw() -> void:
	draw_texture_rect(MAP, Rect2(0, 0, W, H), false)
