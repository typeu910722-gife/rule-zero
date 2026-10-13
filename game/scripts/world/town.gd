extends Node2D
## 棉花糖鎮的地面、道路與建築（程式繪製的佔位美術）。
## 配置依照 docs/art/00_town_map.jpg。

const PATH_COLOR := Color("#f3e3c3")
const W := 1600.0
const H := 1150.0
const RIVER := [Vector2(1310, 280), Vector2(1225, 440), Vector2(1205, 610), Vector2(1250, 780), Vector2(1210, 950), Vector2(1260, 1150)]

## 第二天起出現的「異常」：鐘塔指針停在三點
var clock_stopped := false


func _draw() -> void:
	var f: Font = GameState.font
	draw_rect(Rect2(0, 0, W, H), Color("#dcefd2"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 160:
		var p := Vector2(rng.randf_range(0, W), rng.randf_range(0, H))
		draw_circle(p, 3, [Color("#ffd6e0"), Color("#fff1a8"), Color("#e2d4f7")][k % 3])

	# 道路
	for seg in [
		[Vector2(700, 1000), Vector2(640, 760)],     # 車站 → 廣場
		[Vector2(640, 620), Vector2(360, 590)],      # 廣場 → 小布的住處
		[Vector2(560, 520), Vector2(400, 390)],      # 廣場 → 露露的家
		[Vector2(660, 480), Vector2(700, 350)],      # 廣場 → 鐘塔
		[Vector2(700, 380), Vector2(870, 430)],      # 鐘塔 → 公館
		[Vector2(870, 430), Vector2(1070, 250)],     # 公館 → 修理室
		[Vector2(1070, 250), Vector2(1260, 280)],    # 修理室 → 森林
		[Vector2(940, 450), Vector2(1090, 480)],     # 公館 → 鏡之屋
		[Vector2(760, 640), Vector2(1150, 620)],     # 廣場 → 郵局 → 橋
		[Vector2(1260, 620), Vector2(1400, 700)],    # 橋 → 樹屋
		[Vector2(560, 760), Vector2(330, 900)],      # 廣場 → 居民小屋
	]:
		draw_line(seg[0], seg[1], PATH_COLOR, 44)
		draw_circle(seg[0], 22, PATH_COLOR)
		draw_circle(seg[1], 22, PATH_COLOR)

	# 河流與石橋
	draw_polyline(PackedVector2Array(RIVER), Color("#9ecae1"), 78)
	draw_polyline(PackedVector2Array(RIVER), Color("#b9dcef"), 56)
	draw_rect(Rect2(1145, 592, 120, 56), Color("#d6ccc2"))
	draw_rect(Rect2(1145, 592, 120, 8), Color("#b0a597"))
	draw_rect(Rect2(1145, 640, 120, 8), Color("#b0a597"))

	# 森林小徑（右上）
	for k in 20:
		var p := Vector2(1190 + (k % 7) * 58 + (k / 7) * 20, 40 + (k / 7) * 85 + (k % 2) * 18)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -60), p + Vector2(-30, 10), p + Vector2(30, 10)]), Color("#56766a"))
		draw_rect(Rect2(p + Vector2(-5, 10), Vector2(10, 14)), Color("#6d4c41"))
	_label("森林小徑", Vector2(1330, 300), Color("#3f5f52"))

	# 守則廣場
	draw_circle(Vector2(640, 620), 150, Color("#f8d7e3"))
	draw_circle(Vector2(640, 620), 140, Color("#fbe7ee"))
	draw_circle(Vector2(700, 660), 36, Color("#bde0fe"))
	draw_arc(Vector2(700, 660), 36, 0, TAU, 32, Color.WHITE, 5)
	_label("守則廣場", Vector2(690, 740), Color("#b56576"))

	# 鐘塔
	draw_rect(Rect2(650, 90, 100, 250), Color("#efe2d2"))
	draw_colored_polygon(PackedVector2Array([Vector2(636, 90), Vector2(764, 90), Vector2(700, 12)]), Color("#b5838d"))
	draw_circle(Vector2(700, 150), 32, Color.WHITE)
	draw_arc(Vector2(700, 150), 32, 0, TAU, 32, Color("#6d597a"), 3)
	# 指針：平常是八點；第二天開始停在三點
	var hour_angle := deg_to_rad(150.0) if not clock_stopped else 0.0
	draw_line(Vector2(700, 150), Vector2(700, 150) + Vector2.from_angle(hour_angle) * 17, Color("#6d597a"), 4)
	draw_line(Vector2(700, 150), Vector2(700, 150) + Vector2.from_angle(-PI / 2) * 24, Color("#6d597a"), 3)
	draw_rect(Rect2(682, 290, 36, 50), Color("#8d6e63"))
	_label("鐘塔", Vector2(780, 120), Color("#6d597a"))

	_building(Rect2(760, 250, 220, 150), Color("#e9c9a8"), Color("#5f6f52"), "鎮長公館")
	# 公館門上的熊頭裝飾
	draw_circle(Vector2(870, 230), 20, Color("#c99a6b"))
	draw_circle(Vector2(855, 214), 7, Color("#c99a6b"))
	draw_circle(Vector2(885, 214), 7, Color("#c99a6b"))
	_building(Rect2(1000, 120, 140, 100), Color("#7d6b6b"), Color("#4a3f3f"), "修理室")
	# 修理室的窗戶被布蓋住
	for x in [1018.0, 1092.0]:
		draw_rect(Rect2(x, 140, 30, 26), Color("#c9b7b7"))

	# 鏡之屋（玻璃圓頂）
	draw_rect(Rect2(1040, 400, 100, 60), Color("#d9d2e9"))
	draw_circle(Vector2(1090, 400), 50, Color(0.8, 0.85, 1.0, 0.85))
	draw_arc(Vector2(1090, 400), 50, PI, TAU, 24, Color("#b08968"), 4)
	for k in 5:
		var a := PI + PI * (k + 1) / 6.0
		draw_line(Vector2(1090, 400), Vector2(1090, 400) + Vector2.from_angle(a) * 50, Color("#b08968"), 2)
	_label("鏡之屋", Vector2(1090, 335), Color("#6d597a"))

	_building(Rect2(280, 230, 220, 140), Color("#ffd1dc"), Color("#e5989b"), "露露的家")
	draw_circle(Vector2(390, 205), 14, Color("#f4b6c2"))  # 屋頂上的兔子裝飾
	_building(Rect2(880, 520, 180, 130), Color("#cfe1f2"), Color("#b5524f"), "郵局")

	# 小布的住處（剖面娃娃屋）
	draw_rect(Rect2(60, 460, 300, 230), Color("#8fa9c9"))
	draw_rect(Rect2(75, 475, 270, 200), Color("#fdf0e8"))
	draw_rect(Rect2(345, 560, 15, 64), Color("#fdf0e8"))
	draw_colored_polygon(PackedVector2Array([Vector2(40, 460), Vector2(380, 460), Vector2(210, 385)]), Color("#5c7aa3"))
	_label("小布的住處", Vector2(210, 440), Color.WHITE)

	# 居民小屋
	_building(Rect2(150, 790, 130, 100), Color("#f6e7cb"), Color("#d08c60"), "居民小屋")
	_building(Rect2(330, 820, 110, 90), Color("#e9edc9"), Color("#7f9a77"), "")

	# Fen 的樹屋（河的另一邊）
	draw_rect(Rect2(1388, 600, 24, 120), Color("#7f5539"))
	draw_circle(Vector2(1400, 580), 78, Color("#d4a373"))
	draw_circle(Vector2(1350, 610), 48, Color("#e9c46a"))
	draw_rect(Rect2(1370, 540, 60, 40), Color("#a98467"))
	_label("Fen 的樹屋", Vector2(1400, 490), Color("#7f5539"))

	# 火車站與鐵軌
	for k in 46:
		draw_line(Vector2(k * 36, 1058), Vector2(k * 36, 1100), Color("#a68a64"), 6)
	draw_line(Vector2(0, 1068), Vector2(W, 1068), Color("#8d99ae"), 4)
	draw_line(Vector2(0, 1090), Vector2(W, 1090), Color("#8d99ae"), 4)
	draw_rect(Rect2(540, 1010, 320, 40), Color("#e9edc9"))
	_building(Rect2(560, 880, 280, 110), Color("#c9ada7"), Color("#4a4e69"), "火車站")
	draw_circle(Vector2(700, 860), 18, Color.WHITE)
	draw_arc(Vector2(700, 860), 18, 0, TAU, 20, Color("#4a4e69"), 3)


func _label(text: String, center: Vector2, col: Color) -> void:
	draw_string(GameState.font, center + Vector2(-100, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 200, 18, col)


func _building(r: Rect2, wall: Color, roof: Color, label: String) -> void:
	draw_rect(r, wall)
	draw_colored_polygon(PackedVector2Array([
		r.position + Vector2(-18, 0), r.position + Vector2(r.size.x + 18, 0),
		r.position + Vector2(r.size.x / 2, -minf(70, r.size.y * 0.6))]), roof)
	draw_rect(Rect2(r.position + Vector2(r.size.x / 2 - 18, r.size.y - 54), Vector2(36, 54)), wall.darkened(0.3))
	if r.size.x > 150:
		for x in [26.0, r.size.x - 66.0]:
			draw_rect(Rect2(r.position + Vector2(x, 28), Vector2(40, 32)), Color("#fffbe6"))
	if label != "":
		_label(label, r.position + Vector2(r.size.x / 2, -minf(70, r.size.y * 0.6) - 12), Color("#6d597a"))
