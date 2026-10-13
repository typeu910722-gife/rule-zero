extends Node2D
## 棉花糖鎮：美術地圖（game/art/town_map.png）＋小布家的室內。
## 地圖原圖 1254×1254，在世界中放大 SCALE 倍；座標換算用 at(圖上座標)。

const MAP := preload("res://art/town_map.png")
const SCALE := 1.5
const MAP_PX := 1254.0
const W := MAP_PX * SCALE
const H := MAP_PX * SCALE

## 可以走的範圍（世界座標）
const WORLD_BOUNDS := Rect2(40, 110, W - 80, 1540)

## 小布家的室內：放在地圖右邊的空白處，鏡頭只看得到房間
const ROOM := Rect2(2300, 120, 840, 480)
## 地板上可以走的範圍（房間美術 art/room.jpg 的木地板，避開床、斗櫃、門邊的櫃子）
const ROOM_BOUNDS := Rect2(2440, 360, 790, 330)
const ROOM_ART := preload("res://art/room.jpg")
const CLOCK_ART := preload("res://art/item_clock.png")
const ROOM_VIEW := Rect2(ROOM.position.x + ROOM.size.x / 2 - 640, 0, 1280, 720)

## 可以走的地方：石板路、樓梯、橋（由 tools/build_walk_mask.py 從地圖產生）。
## 遮罩是原圖的一半解析度：白＝可以走。草地、花圃、圍籬、房子、河都不能走。
const WALK_MASK := preload("res://art/walk_mask.png")
const MASK_SCALE := 2.0
static var _mask: Image

## 鐘塔的鐘面（原圖座標）
const CLOCK := Vector2(578, 124)

## 第二天起出現的「異常」：鐘塔指針停在三點
var clock_stopped := false


static func at(x: float, y: float) -> Vector2:
	return Vector2(x, y) * SCALE


## 離 p 最近、可以走的位置（由內往外一圈一圈找）
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


## 世界座標 p 是否走不過去（不在路上）
static func blocked(p: Vector2) -> bool:
	if p.x > W:
		return false  # 室內
	if _mask == null:
		_mask = WALK_MASK.get_image()
		if _mask.is_compressed():
			_mask.decompress()
	var q := p / SCALE / MASK_SCALE
	var x := int(q.x)
	var y := int(q.y)
	if x < 0 or y < 0 or x >= _mask.get_width() or y >= _mask.get_height():
		return true
	return _mask.get_pixel(x, y).r < 0.5


func _draw() -> void:
	draw_texture_rect(MAP, Rect2(0, 0, W, H), false)
	if clock_stopped:
		# 指針停在三點（蓋掉原本的指針）
		var c := CLOCK * SCALE
		draw_texture_rect(CLOCK_ART, Rect2(c - Vector2(27, 25), Vector2(54, 50)), false)
	_draw_room()


## 小布的房間：美術圖（床、蓋著布的立鏡、門都在圖上），鏡頭剛好看到整張圖
func _draw_room() -> void:
	draw_texture_rect(ROOM_ART, ROOM_VIEW, false)
