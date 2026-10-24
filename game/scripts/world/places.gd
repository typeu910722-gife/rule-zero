extends Node2D
## 第三～七章的地圖。跟第一章一樣用程式畫：圓角色塊、縫線、少量高飽和的一點。
## place：ward 醫院、mail 郵務室、mirror 鏡之屋、workshop 鎮長的夜、plaza 拆線的廣場。

const W := 1600.0
const H := 1150.0

var place := "ward"
var full_color := false


func _draw() -> void:
	match place:
		"mail":
			_mail()
		"mirror":
			_mirror()
		"workshop":
			_workshop()
		"plaza":
			_plaza()
		_:
			_ward()


func _label(text: String, at: Vector2, col: Color) -> void:
	draw_string(GameState.font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 160, 16, col)


func _bed(at: Vector2, sheet: Color, clip := false) -> void:
	draw_rect(Rect2(at + Vector2(-46, -8), Vector2(92, 36)), Color("#d9d3cc"))
	draw_rect(Rect2(at + Vector2(-40, -28), Vector2(80, 28)), sheet)
	draw_rect(Rect2(at + Vector2(-34, -40), Vector2(28, 16)), Color("#fbfbfb"))
	draw_line(at + Vector2(10, -36), at + Vector2(10, -120), Color("#c5d5ce"), 2)
	if clip:
		draw_circle(at + Vector2(24, -18), 5, Color("#f4a3c1"))
		draw_arc(at + Vector2(24, -18), 5, -0.6, 2.4, 8, Color("#e7d0dc"), 1.5)


func _ward() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#e4eee8"))
	for x in 16:
		draw_line(Vector2(x * 100, 0), Vector2(x * 100, H), Color(1, 1, 1, 0.25), 1)
	draw_rect(Rect2(0, 0, W, 70), Color("#f7fbf8"))
	draw_line(Vector2(80, 70), Vector2(1500, 70), Color("#b7cdc4"), 3)
	# 天花板上的線軌
	draw_line(Vector2(80, 90), Vector2(1500, 90), Color("#d5e3dc"), 6)
	for i in 6:
		var at := Vector2(200 + i * 180, 360)
		_bed(at, Color("#f4f7f5") if i != 0 else Color("#fffdf8"), i == 0)
		draw_line(Vector2(at.x + 10, 90), at + Vector2(10, -120), Color("#c5d5ce"), 2)
	# 窗
	draw_rect(Rect2(40, 140, 70, 160), Color("#d5e6ea"))
	draw_rect(Rect2(40, 140, 70, 160), Color("#9eb8b0"), false, 3)
	draw_line(Vector2(75, 140), Vector2(75, 300), Color("#9eb8b0"), 2)
	# 病歷櫃
	draw_rect(Rect2(1280, 180, 120, 150), Color("#f7f7f4"))
	draw_rect(Rect2(1280, 180, 120, 150), Color("#b7c4be"), false, 3)
	for k in 4:
		draw_rect(Rect2(1296, 200 + k * 28, 88, 8), Color("#e1e8e4"))
	_label("病歷櫃", Vector2(1260, 360), Color("#5d756c"))
	# 比斯泰德
	draw_rect(Rect2(1288, 430, 100, 150), Color("#cfd8d4"))
	draw_rect(Rect2(1310, 470, 56, 110), Color("#e7eee9"))
	draw_rect(Rect2(1296, 400, 84, 28), Color("#fbfbfb"))
	draw_rect(Rect2(1296, 400, 84, 28), Color("#8aa399"), false, 2)
	draw_string(GameState.font, Vector2(1300, 420), "比斯泰德", HORIZONTAL_ALIGNMENT_CENTER, 76, 14, Color("#3e5c52"))
	_label("N.W.", Vector2(1260, 610), Color("#7f948c"))
	# 玩偶的小床
	draw_rect(Rect2(360, 860, 110, 46), Color("#dfe8e3"))
	draw_rect(Rect2(372, 848, 40, 18), Color("#ffffff"))
	_label("小床", Vector2(330, 930), Color("#5d756c"))
	# 公告欄
	draw_rect(Rect2(820, 150, 90, 60), Color("#f4f7f2"))
	draw_rect(Rect2(820, 150, 90, 60), Color("#8aa399"), false, 3)
	_label("公告欄", Vector2(780, 230), Color("#5d756c"))
	_label("慈愛綜合醫院", Vector2(80, 48), Color("#3e5c52"))


func _mail() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#f3ead7"))
	draw_rect(Rect2(0, 80, W, 220), Color("#e7d3b0"))
	for i in 18:
		var c := Vector2(80 + (i % 9) * 160, 120 + int(i / 9) * 90)
		draw_rect(Rect2(c, Vector2(120, 70)), Color("#fbf6ea"))
		draw_rect(Rect2(c, Vector2(120, 70)), Color("#c4a574"), false, 2)
		draw_line(c + Vector2(16, 28), c + Vector2(90, 28), Color("#e6d3b4"), 2)
		draw_line(c + Vector2(16, 44), c + Vector2(70, 44), Color("#eadcc4"), 2)
	# 給遙的那封，角上露出一點粉
	draw_rect(Rect2(560, 120, 120, 70), Color("#fff8f3"))
	draw_colored_polygon(PackedVector2Array([Vector2(656, 120), Vector2(680, 120), Vector2(680, 144)]), Color("#f4a3c1"))
	draw_rect(Rect2(200, 420, 900, 28), Color("#d8c09a"))
	_label("寄不出去的信", Vector2(80, 48), Color("#8a5a2a"))
	_label("郵務室", Vector2(80, 78), Color("#a67c52"))


func _mirror() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#d7dbe6"))
	draw_circle(Vector2(780, 420), 210, Color(0.9, 0.92, 0.96, 0.9))
	draw_arc(Vector2(780, 420), 210, 0, TAU, 64, Color("#9aa3b5"), 6)
	draw_circle(Vector2(820, 450), 160, Color(1, 1, 1, 0.28))
	for k in 6:
		var a := TAU * k / 6.0
		draw_line(Vector2(780, 420), Vector2(780, 420) + Vector2.from_angle(a) * 210, Color("#c5cad6"), 2)
	# 保險箱
	draw_rect(Rect2(1080, 300, 90, 70), Color("#c5c9d4"))
	draw_rect(Rect2(1080, 300, 90, 70), Color("#6d7588"), false, 3)
	draw_circle(Vector2(1125, 335), 8, Color("#e8eaef"))
	_label("給第＿＿個", Vector2(1040, 400), Color("#4c5670"))
	_label("鏡之屋", Vector2(80, 48), Color("#4c5670"))


func _workshop() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#24302c"))
	draw_circle(Vector2(640, 520), 280, Color(0.95, 0.86, 0.65, 0.16))
	draw_rect(Rect2(480, 300, 320, 36), Color("#6d5344"))
	draw_circle(Vector2(560, 292), 16, Color("#c9847a"))
	draw_line(Vector2(600, 292), Vector2(760, 300), Color("#e7d2c4"), 3)
	# 糖果罐
	draw_rect(Rect2(250, 360, 54, 64), Color("#f6f1e6"))
	draw_rect(Rect2(258, 348, 38, 16), Color("#e7c96a"))
	draw_circle(Vector2(277, 390), 6, Color("#f4a3c1"))
	# 名冊
	draw_rect(Rect2(980, 300, 110, 78), Color("#efe6d4"))
	draw_rect(Rect2(980, 300, 110, 78), Color("#8d6e63"), false, 3)
	for k in 4:
		draw_line(Vector2(996, 322 + k * 12), Vector2(1072, 322 + k * 12), Color("#d9cbb6"), 2)
	_label("名冊", Vector2(960, 400), Color("#e6d7c4"))
	# 窗外的小鎮剪影
	for k in 5:
		var p := Vector2(1280 + k * 40, 180)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -36), p + Vector2(-16, 8), p + Vector2(16, 8)]), Color("#1b2422"))
	_label("鎮長的夜", Vector2(80, 48), Color("#e6d7c4"))


func _plaza() -> void:
	var grass := Color("#dcefd2") if full_color else Color("#c5d0c8")
	var path := Color("#f3e3c3") if full_color else Color("#d9d3c8")
	draw_rect(Rect2(0, 0, W, H), grass)
	if full_color:
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for k in 80:
			draw_circle(Vector2(rng.randf_range(0, W), rng.randf_range(0, H)), rng.randf_range(2, 4),
				[Color("#ffd6e0"), Color("#fff1a8"), Color("#e2d4f7")][k % 3])
	draw_line(Vector2(800, 200), Vector2(640, 780), path, 48)
	draw_circle(Vector2(640, 700), 120, Color("#f8d7e3") if full_color else Color("#ddd4d6"))
	# 鐘塔
	draw_rect(Rect2(660, 80, 90, 200), Color("#efe2d2") if full_color else Color("#d5d0c8"))
	draw_colored_polygon(PackedVector2Array([Vector2(648, 80), Vector2(762, 80), Vector2(705, 16)]), Color("#b5838d") if full_color else Color("#9a8e90"))
	draw_circle(Vector2(705, 140), 26, Color.WHITE)
	draw_arc(Vector2(705, 140), 26, 0, TAU, 24, Color("#6d597a"), 3)
	draw_line(Vector2(705, 140), Vector2(705, 140) + Vector2(0, -16), Color("#6d597a"), 3)
	draw_line(Vector2(705, 140), Vector2(705, 140) + Vector2(10, 6), Color("#6d597a"), 2)
	# 公告欄
	draw_rect(Rect2(560, 360, 100, 64), Color("#fff3e0"))
	draw_rect(Rect2(560, 360, 100, 64), Color("#a1887f"), false, 3)
	if GameState.has("cotton_wind") or full_color:
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = 19
		for k in 30:
			draw_circle(Vector2(rng2.randf_range(200, 1400), rng2.randf_range(80, 1000)), rng2.randf_range(3, 8), Color(1, 1, 1, 0.85))
	_label("守則廣場", Vector2(560, 760), Color("#b56576") if full_color else Color("#7d7378"))
