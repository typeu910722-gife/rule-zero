extends Node2D
## 棉花糖鎮的地面、道路與建築（程式繪製的佔位美術）。

const PATH_COLOR := Color("#f3e3c3")
const W := 1600.0
const H := 1300.0

## 第二天起出現的「異常」：鐘塔指針停在三點
var clock_stopped := false


func _draw() -> void:
	var f: Font = GameState.font
	draw_rect(Rect2(0, 0, W, H), Color("#d8efd0"))
	# 草地上的小花
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 140:
		var p := Vector2(rng.randf_range(0, W), rng.randf_range(0, H))
		draw_circle(p, 3, [Color("#ffd6e0"), Color("#fff1a8"), Color("#e2d4f7")][k % 3])

	# 道路
	for seg in [
		[Vector2(800, 380), Vector2(800, 1150)],
		[Vector2(460, 600), Vector2(1280, 690)],
		[Vector2(410, 1060), Vector2(1150, 1060)],
		[Vector2(760, 330), Vector2(430, 240)],
	]:
		draw_line(seg[0], seg[1], PATH_COLOR, 46)
		draw_circle(seg[0], 23, PATH_COLOR)
		draw_circle(seg[1], 23, PATH_COLOR)

	# 森林（鐘塔後面）
	for k in 18:
		var p := Vector2(120 + (k % 9) * 55 + (k / 9) * 25, 70 + (k / 9) * 90 + (k % 2) * 20)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -60), p + Vector2(-30, 10), p + Vector2(30, 10)]), Color("#5b7f6b"))
		draw_rect(Rect2(p + Vector2(-5, 10), Vector2(10, 14)), Color("#6d4c41"))
	draw_string(f, Vector2(250, 300), "森林", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#4f6f5f"))

	# 廣場與噴水池
	draw_circle(Vector2(800, 600), 170, Color("#f8d7e3"))
	draw_circle(Vector2(800, 600), 160, Color("#fbe4ec"))
	draw_circle(Vector2(850, 630), 40, Color("#bde0fe"))
	draw_arc(Vector2(850, 630), 40, 0, TAU, 32, Color("#ffffff"), 5)
	draw_string(f, Vector2(870, 715), "中央廣場", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#b56576"))

	# 鐘塔
	draw_rect(Rect2(745, 110, 110, 260), Color("#f1e3d3"))
	draw_colored_polygon(PackedVector2Array([Vector2(730, 110), Vector2(870, 110), Vector2(800, 30)]), Color("#cdb4db"))
	draw_circle(Vector2(800, 170), 34, Color.WHITE)
	draw_arc(Vector2(800, 170), 34, 0, TAU, 32, Color("#6d597a"), 3)
	# 指針：平常是八點；第二天開始停在三點
	var hour_angle := deg_to_rad(240.0 - 90.0) if not clock_stopped else deg_to_rad(90.0 - 90.0)
	draw_line(Vector2(800, 170), Vector2(800, 170) + Vector2.from_angle(hour_angle) * 18, Color("#6d597a"), 4)
	draw_line(Vector2(800, 170), Vector2(800, 170) + Vector2.from_angle(deg_to_rad(-90)) * 26, Color("#6d597a"), 3)
	draw_rect(Rect2(780, 320, 40, 50), Color("#8d6e63"))
	draw_string(f, Vector2(770, 100), "鐘塔", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#6d597a"))

	# 小布的家（剖面娃娃屋）
	draw_rect(Rect2(170, 455, 300, 250), Color("#e5989b"))
	draw_rect(Rect2(185, 470, 270, 220), Color("#fdf0e8"))
	draw_rect(Rect2(455, 560, 15, 70), Color("#fdf0e8"))  # 門口
	draw_colored_polygon(PackedVector2Array([Vector2(150, 455), Vector2(490, 455), Vector2(320, 380)]), Color("#b5838d"))
	draw_string(f, Vector2(270, 430), "小布的家", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

	_building(Rect2(1140, 480, 280, 180), Color("#a98467"), Color("#6c584c"), "鎮長辦公室")
	_building(Rect2(300, 820, 220, 140), Color("#ffcad4"), Color("#f4acb7"), "露露麵包店")
	_building(Rect2(620, 820, 200, 140), Color("#bde0fe"), Color("#8ecae6"), "郵局")

	# Fen 的樹屋
	draw_rect(Rect2(1138, 820, 24, 120), Color("#7f5539"))
	draw_circle(Vector2(1150, 800), 80, Color("#95d5b2"))
	draw_circle(Vector2(1100, 830), 50, Color("#b7e4c7"))
	draw_rect(Rect2(1120, 760, 60, 40), Color("#ddb892"))
	draw_string(f, Vector2(1100, 720), "Fen 的樹屋", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#2d6a4f"))

	# 車站
	draw_rect(Rect2(700, 1150, 400, 90), Color("#e9edc9"))
	for k in 12:
		draw_line(Vector2(690 + k * 36, 1250), Vector2(690 + k * 36, 1290), Color("#a68a64"), 6)
	draw_line(Vector2(680, 1260), Vector2(1120, 1260), Color("#8d99ae"), 4)
	draw_line(Vector2(680, 1280), Vector2(1120, 1280), Color("#8d99ae"), 4)
	draw_string(f, Vector2(860, 1225), "棉花糖鎮站", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#6b705c"))


func _building(r: Rect2, wall: Color, roof: Color, label: String) -> void:
	draw_rect(r, wall)
	draw_colored_polygon(PackedVector2Array([
		r.position + Vector2(-20, 0), r.position + Vector2(r.size.x + 20, 0),
		r.position + Vector2(r.size.x / 2, -70)]), roof)
	draw_rect(Rect2(r.position + Vector2(r.size.x / 2 - 20, r.size.y - 60), Vector2(40, 60)), wall.darkened(0.3))
	for x in [30.0, r.size.x - 70.0]:
		draw_rect(Rect2(r.position + Vector2(x, 30), Vector2(40, 34)), Color("#fffbe6"))
	draw_string(GameState.font, r.position + Vector2(0, -80), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color("#6d597a"))
