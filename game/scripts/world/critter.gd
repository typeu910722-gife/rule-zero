class_name Critter
extends RefCounted
## 用程式繪製的絨毛娃娃角色（原型用，正式版替換為美術素材）。


## opts（第二章）：stripes 斑馬剩下的斑紋數、sewn 嘴被縫起來、thread 紅毛線、
## pale 慘白的臉、no_tail 沒有尾巴、grey_patch 被摸過褪色的地方
static func draw(ci: CanvasItem, species: String, col: Color, s: float, look := Vector2.ZERO,
		smile := true, stitched := false, tag := false, opts := {}) -> void:
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
			if opts.get("no_tail", false):
				# 白面：屁股上只剩一圈縫線
				ci.draw_arc(Vector2(r * 0.9, -10 * s), 4 * s, 0, TAU, 10, Color("#555555"), 1.2 * s)
			else:
				ellipse(ci, Vector2(r * 1.1, -10 * s), Vector2(7, 15) * s, col, -0.9)
				ci.draw_circle(Vector2(r * 1.6, -18 * s), 4 * s, Color.WHITE)
			_tri(ci, head + Vector2(-14, -12) * s, head + Vector2(-4, -20) * s, head + Vector2(-16, -30) * s, col)
			_tri(ci, head + Vector2(14, -12) * s, head + Vector2(4, -20) * s, head + Vector2(16, -30) * s, col)
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(0, 7 * s), Vector2(10, 7) * s, Color("#fff4e6"))
			if opts.get("pale", false):
				# 紙一樣慘白的臉
				ellipse(ci, head + Vector2(0, 1 * s), Vector2(r * 0.85, r * 0.8), Color("#fbfbfb"))
		"hedgehog":
			# 參差不齊、被剪過的刺
			var cut: int = opts.get("quills", 9)
			for k in 9:
				var a := PI + PI * (k + 0.5) / 9.0
				var long := 13.0 if k < cut else 4.0
				if k % 3 == 1 and k < cut:
					long = 8.0
				_tri(ci, head + Vector2.from_angle(a - 0.18) * r * 0.9, head + Vector2.from_angle(a + 0.18) * r * 0.9,
					head + Vector2.from_angle(a) * (r + long * s), col.darkened(0.25))
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(0, 6 * s), Vector2(11, 9) * s, Color("#8f8f8f"))
		"zebra":
			ellipse(ci, head + Vector2(-r * 0.6, -r * 0.95), Vector2(4, 9) * s, col, -0.3)
			ellipse(ci, head + Vector2(r * 0.6, -r * 0.95), Vector2(4, 9) * s, col, 0.3)
			ci.draw_circle(head, r, col)
			# 斑紋：每被修理一次少一條
			var n: int = opts.get("stripes", 3)
			for k in n:
				var y := -12.0 + k * 7.0
				ci.draw_line(head + Vector2(-r * 0.85, y * s), head + Vector2(-r * 0.35, (y + 3) * s), Color("#1f1f1f"), 3 * s)
				ci.draw_line(head + Vector2(r * 0.85, y * s), head + Vector2(r * 0.35, (y + 3) * s), Color("#1f1f1f"), 3 * s)
			ellipse(ci, head + Vector2(0, 8 * s), Vector2(9, 7) * s, Color("#bdbdbd"))
		"crow":
			ellipse(ci, Vector2(-r * 0.9, -10 * s), Vector2(6, 12) * s, col.darkened(0.2), 0.4)
			ellipse(ci, Vector2(r * 0.9, -10 * s), Vector2(6, 12) * s, col.darkened(0.2), -0.4)
			ci.draw_circle(head, r, col)
			_tri(ci, head + Vector2(-5, 3) * s, head + Vector2(5, 3) * s, head + Vector2(0, 13) * s, Color("#6e6e6e"))
			if opts.get("sewn", true):
				for k in 4:
					var x := -3.0 + k * 2.0
					ci.draw_line(head + Vector2(x, 4) * s, head + Vector2(x, 11) * s, Color("#111111"), 1.0 * s)
		"hippo":
			ci.draw_circle(head + Vector2(-r * 0.6, -r * 0.85), r * 0.22, col.darkened(0.15))
			ci.draw_circle(head + Vector2(r * 0.6, -r * 0.85), r * 0.22, col.darkened(0.15))
			ci.draw_circle(head, r, col)
			ellipse(ci, head + Vector2(0, 8 * s), Vector2(r * 0.85, r * 0.55), col.lightened(0.15))
			ci.draw_circle(head + Vector2(-5, 6) * s, 1.5 * s, Color("#3a3a3a"))
			ci.draw_circle(head + Vector2(5, 6) * s, 1.5 * s, Color("#3a3a3a"))
			# 身上最多的縫線
			var st := Color("#3d3d3d")
			for k in 3:
				var p := head + Vector2(-16 + k * 12, -12 + k * 3) * s
				ci.draw_line(p, p + Vector2(6, 2) * s, st, 1.0 * s)
				ci.draw_line(p + Vector2(2, -2) * s, p + Vector2(2, 3) * s, st, 1.0 * s)
				ci.draw_line(p + Vector2(4, -2) * s, p + Vector2(4, 3) * s, st, 1.0 * s)
		"weasel":
			ellipse(ci, Vector2(r * 1.0, -6 * s), Vector2(5, 14) * s, col, -1.2)
			ci.draw_circle(head + Vector2(-r * 0.7, -r * 0.75), r * 0.25, col)
			ci.draw_circle(head + Vector2(r * 0.7, -r * 0.75), r * 0.25, col)
			ellipse(ci, head, Vector2(r * 0.85, r), col)
			ellipse(ci, head + Vector2(0, 7 * s), Vector2(8, 6) * s, Color("#e6e6e6"))
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
	if opts.get("thread", false):
		# 整個漂白鎮唯一的顏色
		ci.draw_arc(head + Vector2(0, 12) * s, 11 * s, 0.2, PI - 0.2, 14, Color("#d1263b"), 3 * s)
		ci.draw_line(head + Vector2(8, 18) * s, head + Vector2(12, 28) * s, Color("#d1263b"), 2.5 * s)
	if opts.get("grey_patch", false):
		# 和平鴿摸過的地方，羊毛褪成灰色
		ci.draw_circle(head + Vector2(-4, -r / s + 3) * s, 7 * s, Color("#9c9c9c"))
		ci.draw_circle(head + Vector2(4, -r / s + 1) * s, 6 * s, Color("#a5a5a5"))
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


## 和平鴿：人類。玩偶只到他的膝蓋。白色長大衣、白手套、陶瓷鴿子面具（嘴喙有裂痕）。
static func draw_dove(ci: CanvasItem, s: float, unmasked := false, crack := 1.0) -> void:
	var coat := Color("#f2f2f0")
	var edge := Color("#c8c8c4")
	ellipse(ci, Vector2(0, 2) * s, Vector2(34, 9) * s, Color(0, 0, 0, 0.15))
	# 腳
	ci.draw_rect(Rect2(Vector2(-14, -40) * s, Vector2(10, 40) * s), Color("#3b3b3b"))
	ci.draw_rect(Rect2(Vector2(4, -40) * s, Vector2(10, 40) * s), Color("#3b3b3b"))
	# 長大衣
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-22, -150) * s, Vector2(22, -150) * s,
		Vector2(32, -34) * s, Vector2(-32, -34) * s]), coat)
	ci.draw_polyline(PackedVector2Array([Vector2(-22, -150) * s, Vector2(-32, -34) * s, Vector2(32, -34) * s,
		Vector2(22, -150) * s]), edge, 1.5 * s)
	ci.draw_line(Vector2(0, -150) * s, Vector2(0, -34) * s, edge, 1.2 * s)
	for k in 4:
		ci.draw_circle(Vector2(4, -132 + k * 22) * s, 1.8 * s, Color("#bdbdbd"))
	# 慈愛組織的徽章：一顆被針穿過的心
	ci.draw_circle(Vector2(-13, -128) * s, 3.2 * s, Color("#d9d9d9"))
	ci.draw_circle(Vector2(-9, -128) * s, 3.2 * s, Color("#d9d9d9"))
	_tri(ci, Vector2(-16, -127) * s, Vector2(-6, -127) * s, Vector2(-11, -121) * s, Color("#d9d9d9"))
	ci.draw_line(Vector2(-18, -133) * s, Vector2(-4, -120) * s, Color("#7a7a7a"), 1.0 * s)
	# 手臂與白手套
	ci.draw_line(Vector2(-22, -146) * s, Vector2(-32, -80) * s, coat.darkened(0.06), 9 * s)
	ci.draw_line(Vector2(22, -146) * s, Vector2(32, -80) * s, coat.darkened(0.06), 9 * s)
	ci.draw_circle(Vector2(-32, -76) * s, 6 * s, Color.WHITE)
	ci.draw_circle(Vector2(32, -76) * s, 6 * s, Color.WHITE)
	# 聽診器
	ci.draw_arc(Vector2(0, -146) * s, 12 * s, 0.3, PI - 0.3, 12, Color("#555555"), 1.5 * s)
	ci.draw_circle(Vector2(-6, -126) * s, 3 * s, Color("#8a8a8a"))
	# 頭
	var head := Vector2(0, -166) * s
	ci.draw_rect(Rect2(Vector2(-4, -156) * s, Vector2(8, 8) * s), Color("#e8d6c8"))
	ellipse(ci, head, Vector2(14, 16) * s, Color("#e8d6c8"))
	ellipse(ci, head + Vector2(0, -10) * s, Vector2(14, 8) * s, Color("#1d1d1d"))
	if unmasked:
		ci.draw_circle(head + Vector2(-5, 0) * s, 1.6 * s, Color("#1d1d1d"))
		ci.draw_circle(head + Vector2(5, 0) * s, 1.6 * s, Color("#1d1d1d"))
		ci.draw_arc(head + Vector2(0, 6) * s, 4 * s, 0.4, PI - 0.4, 8, Color("#5a3a3a"), 1.2 * s)
		return
	# 陶瓷鴿子面具：圓圓的頭、往前凸的嘴喙、兩個黑色的眼洞
	ellipse(ci, head + Vector2(0, -1) * s, Vector2(16, 18) * s, Color("#fbfbf9"))
	ci.draw_arc(head + Vector2(0, -1) * s, 16 * s, 0, TAU, 28, Color("#cfcfca"), 1.0 * s)
	var beak := PackedVector2Array([head + Vector2(-6, 2) * s, head + Vector2(6, 2) * s, head + Vector2(0, 19) * s])
	ci.draw_colored_polygon(beak, Color("#dedbd2"))
	beak.append(beak[0])
	ci.draw_polyline(beak, Color("#8a8a86"), 1.0 * s)
	ellipse(ci, head + Vector2(-7, -4) * s, Vector2(3.4, 2.4) * s, Color("#1d1d1d"))
	ellipse(ci, head + Vector2(7, -4) * s, Vector2(3.4, 2.4) * s, Color("#1d1d1d"))
	# 嘴喙的裂痕（上一任教官留下的）
	var c := Color("#6b6b6b")
	ci.draw_polyline(PackedVector2Array([head + Vector2(1, 5) * s, head + Vector2(-1, 9) * s,
		head + Vector2(2, 12) * s, head + Vector2(0, 15) * s]), c, 1.0 * s)
	if crack > 1.0:
		ci.draw_polyline(PackedVector2Array([head + Vector2(0, 5) * s, head + Vector2(5, 1) * s,
			head + Vector2(9, 4) * s, head + Vector2(12, 0) * s]), c, 1.2 * s)


## 車掌：戴帽子、看不見臉的影子
static func draw_conductor(ci: CanvasItem, s: float) -> void:
	var dark := Color("#2a2a2e")
	ellipse(ci, Vector2(0, 2) * s, Vector2(30, 8) * s, Color(0, 0, 0, 0.15))
	ci.draw_rect(Rect2(Vector2(-12, -40) * s, Vector2(9, 40) * s), dark)
	ci.draw_rect(Rect2(Vector2(3, -40) * s, Vector2(9, 40) * s), dark)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-20, -140) * s, Vector2(20, -140) * s,
		Vector2(24, -38) * s, Vector2(-24, -38) * s]), Color("#34343a"))
	for k in 3:
		ci.draw_circle(Vector2(0, -124 + k * 24) * s, 1.8 * s, Color("#8a7a4a"))
	# 手套上洗不掉的白色污漬
	ci.draw_circle(Vector2(-26, -70) * s, 6 * s, Color("#3a3a40"))
	ci.draw_circle(Vector2(26, -70) * s, 6 * s, Color("#3a3a40"))
	ci.draw_circle(Vector2(-27, -71) * s, 2.5 * s, Color("#e8e8e4"))
	var head := Vector2(0, -156) * s
	ellipse(ci, head, Vector2(13, 15) * s, Color("#1a1a1e"))
	# 帽子
	ci.draw_rect(Rect2(head + Vector2(-16, -10) * s, Vector2(32, 5) * s), Color("#1f1f24"))
	ci.draw_rect(Rect2(head + Vector2(-12, -22) * s, Vector2(24, 13) * s), Color("#26262c"))
	ci.draw_rect(Rect2(head + Vector2(-12, -14) * s, Vector2(24, 3) * s), Color("#8a7a4a"))


## 醫院職員：人類，比玩偶高。淺色外套，臉有，可是笑得很空。
static func draw_staff(ci: CanvasItem, s: float) -> void:
	var coat := Color("#e7f2ec")
	ellipse(ci, Vector2(0, 2) * s, Vector2(28, 8) * s, Color(0, 0, 0, 0.12))
	ci.draw_rect(Rect2(Vector2(-12, -36) * s, Vector2(9, 36) * s), Color("#3d4a46"))
	ci.draw_rect(Rect2(Vector2(3, -36) * s, Vector2(9, 36) * s), Color("#3d4a46"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-18, -130) * s, Vector2(18, -130) * s,
		Vector2(26, -30) * s, Vector2(-26, -30) * s]), coat)
	ci.draw_line(Vector2(0, -130) * s, Vector2(0, -30) * s, Color("#c5d5ce"), 1.2 * s)
	ci.draw_circle(Vector2(-10, -112) * s, 3 * s, Color("#d9d9d9"))
	ci.draw_line(Vector2(-14, -116) * s, Vector2(-6, -108) * s, Color("#7a7a7a"), 1.0 * s)
	var head := Vector2(0, -148) * s
	ellipse(ci, head, Vector2(13, 15) * s, Color("#f0d8c8"))
	ci.draw_circle(head + Vector2(-4, -1) * s, 1.4 * s, Color("#2b2024"))
	ci.draw_circle(head + Vector2(4, -1) * s, 1.4 * s, Color("#2b2024"))
	ci.draw_arc(head + Vector2(0, 5) * s, 3.5 * s, 0.4, PI - 0.4, 8, Color("#c9a090"), 1.1 * s)
	ellipse(ci, head + Vector2(0, -12) * s, Vector2(14, 6) * s, Color("#efe8e2"))


## 鏡中的孩子：男生制服，臉是糊的，手心裡有一點粉紅。不畫眼睛。
static func draw_child(ci: CanvasItem, s: float) -> void:
	ellipse(ci, Vector2(0, 2) * s, Vector2(16, 5) * s, Color(0, 0, 0, 0.12))
	ci.draw_rect(Rect2(Vector2(-8, -28) * s, Vector2(6, 28) * s), Color("#2c3348"))
	ci.draw_rect(Rect2(Vector2(2, -28) * s, Vector2(6, 28) * s), Color("#2c3348"))
	ci.draw_rect(Rect2(Vector2(-14, -62) * s, Vector2(28, 36) * s), Color("#2c3348"))
	ci.draw_rect(Rect2(Vector2(-8, -62) * s, Vector2(16, 8) * s), Color("#f4f1ea"))
	ci.draw_line(Vector2(-16, -48) * s, Vector2(-24, -30) * s, Color("#2c3348"), 4 * s)
	ci.draw_line(Vector2(16, -48) * s, Vector2(22, -34) * s, Color("#2c3348"), 4 * s)
	ci.draw_circle(Vector2(24, -32) * s, 3.2 * s, Color("#f0d8c8"))
	ci.draw_circle(Vector2(25, -33) * s, 1.6 * s, Color("#f4a3c1"))
	var head := Vector2(0, -78) * s
	ellipse(ci, head, Vector2(12, 14) * s, Color("#f3e4d8"))
	ellipse(ci, head + Vector2(0, -8) * s, Vector2(13, 8) * s, Color("#4a372c"))
