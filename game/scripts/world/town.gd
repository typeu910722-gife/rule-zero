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
const ROOM_BOUNDS := Rect2(2340, 330, 760, 240)
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
		draw_circle(c, 24, Color("#fbf3dc"))
		draw_arc(c, 24, 0, TAU, 32, Color("#7a5a3a"), 3)
		draw_line(c, c + Vector2(15, 0), Color("#3d2b22"), 4)
		draw_line(c, c + Vector2(0, -20), Color("#3d2b22"), 3)
		draw_circle(c, 3, Color("#3d2b22"))
	_draw_room()


## 小布的房間：木地板、碎花壁紙、小窗、門墊
func _draw_room() -> void:
	var r := ROOM
	draw_rect(Rect2(ROOM_VIEW.position, ROOM_VIEW.size), Color("#2b2228"))
	# 牆
	draw_rect(Rect2(r.position, Vector2(r.size.x, 200)), Color("#f6e3d3"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 46
	for k in 70:
		var p := r.position + Vector2(rng.randf_range(10, r.size.x - 10), rng.randf_range(10, 185))
		draw_circle(p, 3, [Color("#f2c4ce"), Color("#cfe3c8"), Color("#f8e1a8")][k % 3])
	draw_rect(Rect2(r.position + Vector2(0, 190), Vector2(r.size.x, 12)), Color("#c9a27e"))
	# 地板
	var floor_r := Rect2(r.position + Vector2(0, 202), Vector2(r.size.x, r.size.y - 202))
	draw_rect(floor_r, Color("#d9b48c"))
	for k in 8:
		var y := floor_r.position.y + k * floor_r.size.y / 8.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color("#c49a72"), 2)
	# 窗戶（外面是鐘塔的方向）
	var win := Rect2(r.position + Vector2(r.size.x / 2 - 70, 40), Vector2(140, 100))
	draw_rect(win, Color("#bfe0f2"))
	draw_rect(win, Color("#a47551"), false, 8)
	draw_line(win.position + Vector2(70, 0), win.position + Vector2(70, 100), Color("#a47551"), 5)
	draw_line(win.position + Vector2(0, 50), win.position + Vector2(140, 50), Color("#a47551"), 5)
	# 地毯
	Critter.ellipse(self, r.position + Vector2(r.size.x / 2, 360), Vector2(200, 60), Color("#e8a0bf"))
	Critter.ellipse(self, r.position + Vector2(r.size.x / 2, 360), Vector2(180, 50), Color("#f6c6d6"))
	# 門（右下）與門墊
	var door := Rect2(r.end.x - 120, r.position.y + 70, 80, 132)
	draw_rect(door, Color("#8d5524"))
	draw_rect(door, Color("#5e3a1a"), false, 4)
	draw_circle(door.position + Vector2(64, 70), 5, Color("#ffd166"))
	draw_rect(Rect2(door.position + Vector2(-6, 136), Vector2(92, 18)), Color("#9c6b98"))
	# 外框
	draw_rect(r, Color("#5e3a1a"), false, 10)
