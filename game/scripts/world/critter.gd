class_name Critter
extends RefCounted
## 用程式繪製的絨毛娃娃角色（原型用，正式版替換為美術素材）。


static func draw(ci: CanvasItem, species: String, col: Color, s: float, look := Vector2.ZERO,
		smile := true, stitched := false, tag := false) -> void:
	var head := Vector2(0, -24) * s
	var r := 20.0 * s
	var dark := col.darkened(0.3)
	ellipse(ci, Vector2(0, 2) * s, Vector2(20, 6) * s, Color(0, 0, 0, 0.13))
	# 腳
	ellipse(ci, Vector2(-8, -2) * s, Vector2(6, 4) * s, dark)
	ellipse(ci, Vector2(8, -2) * s, Vector2(6, 4) * s, dark)
	var face := col
	match species:
		"rabbit":
			ellipse(ci, head + Vector2(-r * 0.95, 2 * s), Vector2(6, 17) * s, col.darkened(0.05), 0.25)
			ellipse(ci, head + Vector2(r * 0.95, 2 * s), Vector2(6, 17) * s, col.darkened(0.05), -0.25)
			ci.draw_circle(head, r, col)
			ci.draw_circle(head + Vector2(-6 * s, -r + 1), 5 * s, Color("#ff8fab"))
			ci.draw_circle(head + Vector2(6 * s, -r + 1), 5 * s, Color("#ff8fab"))
			ci.draw_circle(head + Vector2(0, -r + 1), 2.5 * s, Color("#e05780"))
		"sheep":
			for k in 10:
				var a := TAU * k / 10.0
				ci.draw_circle(head + Vector2(cos(a), sin(a)) * r * 0.85, r * 0.42, col)
			ci.draw_circle(head, r, col)
			face = Color("#f5e3d0")
			ellipse(ci, head + Vector2(0, 3 * s), Vector2(r * 0.72, r * 0.65), face)
		"fox":
			ellipse(ci, Vector2(r * 1.1, -10 * s), Vector2(7, 15) * s, col, -0.9)
			ci.draw_circle(Vector2(r * 1.6, -18 * s), 4 * s, Color.WHITE)
			_tri(ci, head + Vector2(-14, -12) * s, head + Vector2(-4, -20) * s, head + Vector2(-16, -30) * s, col)
			_tri(ci, head + Vector2(14, -12) * s, head + Vector2(4, -20) * s, head + Vector2(16, -30) * s, col)
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(0, 7 * s), Vector2(10, 7) * s, Color("#fff4e6"))
		"bear":
			ci.draw_circle(head + Vector2(-r * 0.75, -r * 0.75), r * 0.35, col)
			ci.draw_circle(head + Vector2(r * 0.75, -r * 0.75), r * 0.35, col)
			ci.draw_circle(head + Vector2(-r * 0.75, -r * 0.75), r * 0.18, col.lightened(0.3))
			ci.draw_circle(head + Vector2(r * 0.75, -r * 0.75), r * 0.18, col.lightened(0.3))
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(0, 7 * s), Vector2(9, 6) * s, col.lightened(0.35))
		"penguin":
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(0, 5 * s), Vector2(r * 0.7, r * 0.75), Color("#fdfdfd"))
			_tri(ci, head + Vector2(-4, 3) * s, head + Vector2(4, 3) * s, head + Vector2(0, 8) * s, Color("#f4a261"))
		"panda":
			ci.draw_circle(head + Vector2(-r * 0.75, -r * 0.75), r * 0.32, Color("#333"))
			ci.draw_circle(head + Vector2(r * 0.75, -r * 0.75), r * 0.32, Color("#333"))
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(-7, -2) * s, Vector2(5, 6) * s, Color("#444"), 0.4)
			ellipse(ci, head + Vector2(7, -2) * s, Vector2(5, 6) * s, Color("#444"), -0.4)
		"cat":
			_tri(ci, head + Vector2(-16, -8) * s, head + Vector2(-4, -18) * s, head + Vector2(-15, -28) * s, col)
			_tri(ci, head + Vector2(16, -8) * s, head + Vector2(4, -18) * s, head + Vector2(15, -28) * s, col)
			ci.draw_circle(head, r, col)
		_:
			ci.draw_circle(head, r, col)
	# 眼睛（鈕扣）
	var eye_off := look.limit_length(1.0) * 2.0 * s
	for side in [-1, 1]:
		ci.draw_circle(head + Vector2(7 * side, -2) * s + eye_off, 2.8 * s, Color("#2b2024"))
		ci.draw_circle(head + Vector2(7 * side - 1, -3) * s + eye_off, 0.9 * s, Color(1, 1, 1, 0.8))
		ci.draw_circle(head + Vector2(12 * side, 5) * s, 3 * s, Color(1, 0.5, 0.6, 0.35))
	# 嘴
	if smile:
		ci.draw_arc(head + Vector2(0, 4) * s, 3.5 * s, 0.3, PI - 0.3, 8, Color("#2b2024"), 1.4 * s)
	else:
		ci.draw_line(head + Vector2(-3, 7) * s, head + Vector2(3, 7) * s, Color("#2b2024"), 1.4 * s)
	# 歪歪的縫線
	if stitched:
		var st := Color("#5c3d2e")
		for k in 4:
			var p := head + Vector2(-12 + k * 6, -14 + (k % 2) * 3) * s
			ci.draw_line(p, p + Vector2(3, 5) * s, st, 1.2 * s)
		ci.draw_line(head + Vector2(-13, -12) * s, head + Vector2(8, -9) * s, st, 1.0 * s)
	# 名牌
	if tag:
		ci.draw_rect(Rect2(head + Vector2(-7, 13) * s, Vector2(14, 7) * s), Color.WHITE)
		ci.draw_rect(Rect2(head + Vector2(-7, 13) * s, Vector2(14, 7) * s), Color("#e8a0bf"), false, 1.0)
		ci.draw_line(head + Vector2(-4, 16.5) * s, head + Vector2(4, 16.5) * s, Color("#999"), 1.0)


static func ellipse(ci: CanvasItem, c: Vector2, rad: Vector2, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y).rotated(rot))
	ci.draw_colored_polygon(pts, col)


static func _tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)
