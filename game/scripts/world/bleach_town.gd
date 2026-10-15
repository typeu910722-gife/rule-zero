extends Node2D
## 漂白鎮（第二章）：整座鎮像被漂白水洗過，只剩黑、白、灰。
## 唯一的顏色是河對岸的模範生宿舍——看得到，過不去。
## 配置依照 docs/script/chapter2.md 第 4 節。

const W := 1600.0
const H := 1150.0
const GROUND := Color("#dcdcd9")
const PATH := Color("#c6c6c2")
const INK := Color("#4a4a4a")
const RIVER := [Vector2(1250, 0), Vector2(1235, 300), Vector2(1255, 560), Vector2(1232, 820), Vector2(1250, 1150)]
const FENCE_X := 1190.0

## 第三天：畢業典禮的布條；火車進站
var banner := false
var train := false


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), GROUND)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 140:
		draw_circle(Vector2(rng.randf_range(0, 1180), rng.randf_range(0, H)), 2.5, Color("#cbcbc7"))

	# 道路
	for seg in [
		[Vector2(700, 1000), Vector2(620, 760)],     # 車站 → 點名廣場
		[Vector2(620, 620), Vector2(360, 590)],      # 廣場 → 宿舍
		[Vector2(560, 520), Vector2(350, 340)],      # 廣場 → 教室
		[Vector2(600, 480), Vector2(480, 300)],      # 廣場 → 廣播塔
		[Vector2(660, 480), Vector2(735, 300)],      # 廣場 → 治療室
		[Vector2(760, 620), Vector2(1000, 480)],     # 廣場 → 洗衣房
		[Vector2(760, 660), Vector2(1150, 680)],     # 廣場 → 鐵絲網
		[Vector2(540, 760), Vector2(300, 900)],      # 廣場 → 食堂
	]:
		draw_line(seg[0], seg[1], PATH, 44)
		draw_circle(seg[0], 22, PATH)
		draw_circle(seg[1], 22, PATH)

	# 河對岸：模範生宿舍（全鎮唯一的顏色，像在嘲笑這一邊）
	draw_rect(Rect2(1270, 0, 330, H), Color("#e6f2df"))
	for k in 60:
		draw_circle(Vector2(rng.randf_range(1290, W), rng.randf_range(0, H)), 3, [Color("#ffd6e0"), Color("#fff1a8"), Color("#e2d4f7")][k % 3])
	_building(Rect2(1320, 470, 230, 200), Color("#ffd1dc"), Color("#9fd8c4"), "模範生宿舍", Color("#b56576"))
	draw_rect(Rect2(1310, 670, 250, 14), Color("#f6bd60"))
	for x in [1340.0, 1400.0, 1460.0, 1520.0]:
		draw_line(Vector2(x, 684), Vector2(x, 740), Color("#f6bd60"), 4)
	draw_rect(Rect2(1310, 736, 250, 8), Color("#f6bd60"))

	# 河
	draw_polyline(PackedVector2Array(RIVER), Color("#a9a9a6"), 80)
	draw_polyline(PackedVector2Array(RIVER), Color("#bebebb"), 58)

	# 鐵絲網
	for k in 24:
		var y := 20.0 + k * 48.0
		draw_line(Vector2(FENCE_X, y), Vector2(FENCE_X, y + 40), Color("#5b5b5b"), 4)
	for k in 5:
		draw_line(Vector2(FENCE_X - 6, k * 9.0 + 2), Vector2(FENCE_X - 6, H), Color(0.3, 0.3, 0.3, 0.25), 1)
	for k in 80:
		var y := k * 15.0
		draw_line(Vector2(FENCE_X - 10, y), Vector2(FENCE_X + 10, y + 15), Color("#7a7a7a"), 1.5)
		draw_line(Vector2(FENCE_X + 10, y), Vector2(FENCE_X - 10, y + 15), Color("#7a7a7a"), 1.5)

	# 點名廣場與高台
	draw_circle(Vector2(620, 620), 150, Color("#d0d0cc"))
	draw_circle(Vector2(620, 620), 140, Color("#e4e4e1"))
	draw_rect(Rect2(640, 470, 140, 46), Color("#f7f7f5"))
	draw_rect(Rect2(640, 470, 140, 46), Color("#9a9a9a"), false, 3)
	for k in 3:
		draw_rect(Rect2(650 + k * 8, 516 + k * 10, 40, 10), Color("#ececea"))
	_label("點名廣場", Vector2(610, 790), INK)

	# 廣播塔
	draw_rect(Rect2(465, 90, 30, 210), Color("#9a9a9a"))
	draw_line(Vector2(480, 120), Vector2(440, 300), Color("#8a8a8a"), 4)
	draw_line(Vector2(480, 120), Vector2(520, 300), Color("#8a8a8a"), 4)
	for side in [-1, 1]:
		draw_colored_polygon(PackedVector2Array([Vector2(480, 100), Vector2(480 + side * 46, 78), Vector2(480 + side * 46, 122)]), Color("#6e6e6e"))
	_label("廣播塔", Vector2(480, 60), INK)

	# 治療室：白色磁磚、霧面窗戶
	_building(Rect2(640, 170, 190, 120), Color("#f7f7f5"), Color("#bdbdbd"), "治療室", INK)
	for k in 6:
		for j in 3:
			draw_rect(Rect2(644 + k * 31, 174 + j * 22, 30, 21), Color("#e9e9e7"), false, 1)
	for x in [660.0, 776.0]:
		draw_rect(Rect2(x, 196, 36, 30), Color(0.85, 0.85, 0.88, 0.9))

	# 洗衣房：比房子還高的滾筒洗衣機
	_building(Rect2(900, 330, 200, 140), Color("#d6d6d2"), Color("#8a8a8a"), "洗衣房", INK)
	draw_circle(Vector2(1000, 390), 40, Color("#9e9e9a"))
	draw_circle(Vector2(1000, 390), 30, Color("#c4c4c0"))
	draw_arc(Vector2(1000, 390), 20, 0.4, 2.6, 12, Color("#8a8a86"), 3)

	# 教室
	_building(Rect2(240, 190, 220, 140), Color("#d9d9d5"), Color("#7a7a7a"), "教室", INK)

	# 宿舍（剖面）：小布的鐵床在裡面
	draw_rect(Rect2(60, 460, 300, 230), Color("#8f8f8f"))
	draw_rect(Rect2(75, 475, 270, 200), Color("#efefec"))
	draw_rect(Rect2(345, 560, 15, 64), Color("#efefec"))
	draw_colored_polygon(PackedVector2Array([Vector2(40, 460), Vector2(380, 460), Vector2(210, 385)]), Color("#6a6a6a"))
	for k in 6:
		draw_line(Vector2(95 + k * 40, 480), Vector2(95 + k * 40, 670), Color("#e2e2df"), 1)
	_label("宿舍", Vector2(210, 450), Color.WHITE)

	# 食堂
	_building(Rect2(160, 820, 220, 120), Color("#dededa"), Color("#858585"), "食堂", INK)

	# 火車站與鐵軌：月台的時鐘沒有指針
	for k in 46:
		draw_line(Vector2(k * 36, 1058), Vector2(k * 36, 1100), Color("#8f8f8b"), 6)
	draw_line(Vector2(0, 1068), Vector2(W, 1068), Color("#6e6e6e"), 4)
	draw_line(Vector2(0, 1090), Vector2(W, 1090), Color("#6e6e6e"), 4)
	draw_rect(Rect2(540, 1010, 320, 40), Color("#d0d0cc"))
	_building(Rect2(560, 880, 280, 110), Color("#cfcfcb"), Color("#5a5a5a"), "漂白鎮站", INK)
	draw_circle(Vector2(700, 860), 18, Color.WHITE)
	draw_arc(Vector2(700, 860), 18, 0, TAU, 20, Color("#5a5a5a"), 3)


	if banner:
		draw_rect(Rect2(500, 400, 300, 50), Color("#f7f7f5"))
		draw_rect(Rect2(500, 400, 300, 50), Color("#f2a7c3"), false, 3)
		draw_string(GameState.font, Vector2(500, 436), "恭喜畢業！", HORIZONTAL_ALIGNMENT_CENTER, 300, 28, Color("#e05780"))
		for k in 4:
			draw_rect(Rect2(470 + k * 70, 600, 56, 24), Color("#fbfbf9"))
			draw_rect(Rect2(474 + k * 70, 624, 6, 20), Color("#9a9a9a"))
			draw_rect(Rect2(516 + k * 70, 624, 6, 20), Color("#9a9a9a"))
	if train:
		draw_rect(Rect2(260, 1030, 900, 70), Color("#bfb8bd"))
		for k in 8:
			draw_rect(Rect2(290 + k * 108, 1044, 70, 30), Color("#e8e2e6"))
		draw_rect(Rect2(1160, 1020, 80, 80), Color("#a69ea4"))


func _label(text: String, center: Vector2, col: Color) -> void:
	draw_string(GameState.font, center + Vector2(-100, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 200, 18, col)


func _building(r: Rect2, wall: Color, roof: Color, label: String, label_col: Color) -> void:
	draw_rect(r, wall)
	draw_colored_polygon(PackedVector2Array([
		r.position + Vector2(-18, 0), r.position + Vector2(r.size.x + 18, 0),
		r.position + Vector2(r.size.x / 2, -minf(70, r.size.y * 0.6))]), roof)
	draw_rect(Rect2(r.position + Vector2(r.size.x / 2 - 18, r.size.y - 54), Vector2(36, 54)), wall.darkened(0.3))
	if label != "":
		_label(label, r.position + Vector2(r.size.x / 2, -minf(70, r.size.y * 0.6) - 12), label_col)
