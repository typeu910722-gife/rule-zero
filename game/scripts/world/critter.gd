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
			# 薄荷綠蝴蝶結（森林裡舊耳朵上的是黃色）
			ci.draw_circle(head + Vector2(-6 * s, -r + 1), 5 * s, Color("#9fd8c4"))
			ci.draw_circle(head + Vector2(6 * s, -r + 1), 5 * s, Color("#9fd8c4"))
			ci.draw_circle(head + Vector2(0, -r + 1), 2.5 * s, Color("#5fa891"))
		"sheep":
			# 綠色斗篷與皮革小背包
			ellipse(ci, Vector2(0, -7) * s, Vector2(19, 8) * s, Color("#7d9471"))
			ci.draw_rect(Rect2(Vector2(12, -14) * s, Vector2(9, 8) * s), Color("#b9853f"))
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
			# 高禮帽
			ci.draw_rect(Rect2(head + Vector2(-13 * s, -r - 2), Vector2(26 * s, 4 * s)), Color("#2f3a2f"))
			ci.draw_rect(Rect2(head + Vector2(-8 * s, -r - 2 - 12 * s), Vector2(16 * s, 12 * s)), Color("#2f3a2f"))
			ci.draw_rect(Rect2(head + Vector2(-8 * s, -r - 2 - 4 * s), Vector2(16 * s, 2.5 * s)), Color("#8a6d3b"))
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
		"hamster":
			ci.draw_circle(head + Vector2(-r * 0.7, -r * 0.8), r * 0.28, Color("#f6c6c0"))
			ci.draw_circle(head + Vector2(r * 0.7, -r * 0.8), r * 0.28, Color("#f6c6c0"))
			ellipse(ci, head + Vector2(0, 4 * s), Vector2(r * 1.15, r * 1.05), col)
			ci.draw_circle(head + Vector2(-13, 6) * s, 6 * s, Color("#f3d2a8"))
			ci.draw_circle(head + Vector2(13, 6) * s, 6 * s, Color("#f3d2a8"))
			# 空白的名牌：全鎮只有他的名牌是空的
			ci.draw_rect(Rect2(head + Vector2(-7, 15) * s, Vector2(14, 7) * s), Color("#fffdf6"))
			ci.draw_rect(Rect2(head + Vector2(-7, 15) * s, Vector2(14, 7) * s), Color("#c9b79c"), false, 1.0)
		"calico":
			_tri(ci, head + Vector2(-16, -8) * s, head + Vector2(-4, -18) * s, head + Vector2(-15, -28) * s, Color("#e8a77d"))
			_tri(ci, head + Vector2(16, -8) * s, head + Vector2(4, -18) * s, head + Vector2(15, -28) * s, Color("#9a9aa6"))
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(-9, -9) * s, Vector2(8, 7) * s, Color("#e8a77d"), 0.3)
			ellipse(ci, head + Vector2(10, -11) * s, Vector2(7, 6) * s, Color("#9a9aa6"), -0.3)
			ellipse(ci, head + Vector2(0, 15) * s, Vector2(9, 3) * s, Color("#f5e17a"))
		"puppy":
			ellipse(ci, head + Vector2(-r * 0.9, -2 * s), Vector2(6, 11) * s, col.darkened(0.15), 0.3)
			ellipse(ci, head + Vector2(r * 0.9, -2 * s), Vector2(6, 11) * s, col.darkened(0.15), -0.3)
			ci.draw_circle(head, r, col)
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
