extends Node2D
## 鐘塔後面的森林：鎮上的「垃圾場」。零件堆在最深處。

const PILE := Vector2(800, 330)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1600, 1150), Color("#3d4a42"))
	# 小徑
	draw_line(Vector2(800, 1150), Vector2(800, 420), Color("#6b6658"), 120)
	draw_circle(PILE, 230, Color("#5d6158"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	# 樹（兩側很密）
	for k in 90:
		var x := rng.randf_range(0, 1600)
		var y := rng.randf_range(0, 1150)
		if absf(x - 800) < 170 and y > 380:
			continue
		if Vector2(x, y).distance_to(PILE) < 250:
			continue
		var p := Vector2(x, y)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -80), p + Vector2(-38, 12), p + Vector2(38, 12)]), Color("#24302a"))
		draw_rect(Rect2(p + Vector2(-6, 12), Vector2(12, 16)), Color("#2b211c"))
	# 零件堆：手臂、耳朵、鈕扣眼睛、散落的棉花
	Critter_ellipse(PILE + Vector2(0, 30), Vector2(190, 90), Color("#7a7268"))
	for k in 70:
		var p := PILE + Vector2(rng.randf_range(-170, 170), rng.randf_range(-40, 90))
		var c: Color = [Color("#c9b8a6"), Color("#e8d8c8"), Color("#b79d8a"), Color("#d8c3c9"), Color("#a7a29a")][k % 5]
		Critter_ellipse(p, Vector2(rng.randf_range(8, 18), rng.randf_range(5, 10)), c.darkened(0.15), rng.randf() * PI)
	for k in 30:
		draw_circle(PILE + Vector2(rng.randf_range(-200, 200), rng.randf_range(-30, 130)), rng.randf_range(4, 9), Color(1, 1, 1, 0.75))
	for k in 12:
		draw_circle(PILE + Vector2(rng.randf_range(-150, 150), rng.randf_range(-20, 80)), 3, Color("#2b2024"))


func Critter_ellipse(c: Vector2, r: Vector2, col: Color, rot := 0.0) -> void:
	Critter.ellipse(self, c, r, col, rot)
