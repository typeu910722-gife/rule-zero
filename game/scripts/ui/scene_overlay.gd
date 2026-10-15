extends CanvasLayer
## 第二章的「畫面」：嘎嘎相機放映的照片、治療室霧面窗戶的剪影。
## 對話腳本用 @event 打開（photo_1 / photo_2 / photo_nirvana / silhouette），@event overlay_close 關掉。
## 畫面在上半部，對話框在下面照常顯示。

var mode := ""
var _area: Control
var _t := 0.0


func _ready() -> void:
	layer = 25
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


const HUM := [523.3, 587.3, 659.3, 784.0, 659.3, 587.3, 523.3, 440.0]
var _hum_t := 0.0
var _hum_i := 0


func _process(delta: float) -> void:
	_t += delta
	if mode == "silhouette":
		_area.queue_redraw()
		# 玻璃後面，和平鴿在哼棉花糖鎮音樂盒的旋律
		_hum_t -= delta
		if _hum_t <= 0 and _t > 2.0:
			_hum_t = 0.7
			Tones.play(self, HUM[_hum_i % HUM.size()] * 0.5, -16.0)
			_hum_i += 1


func _draw_area() -> void:
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
	var frame := Rect2(370, 30, 540, 450)
	if mode == "silhouette":
		_silhouette(frame)
		return
	# 拍立得的白框；照片本身是褪色的灰
	a.draw_rect(frame.grow(14), Color("#f5f3ee"))
	a.draw_rect(frame, Color("#bdb8ad"))
	match mode:
		"photo_1":
			_photo_hallway(frame)
		"photo_2":
			_photo_mailbox(frame)
		"photo_nirvana":
			_photo_nirvana(frame)


func _kid(p: Vector2, h: float, col: Color, curly := false) -> void:
	# 照片裡的人類小孩：看不清楚臉
	var a := _area
	a.draw_rect(Rect2(p + Vector2(-h * 0.18, -h * 0.62), Vector2(h * 0.36, h * 0.5)), col)
	a.draw_rect(Rect2(p + Vector2(-h * 0.14, -h * 0.12), Vector2(h * 0.1, h * 0.12)), col.darkened(0.2))
	a.draw_rect(Rect2(p + Vector2(h * 0.04, -h * 0.12), Vector2(h * 0.1, h * 0.12)), col.darkened(0.2))
	a.draw_circle(p + Vector2(0, -h * 0.76), h * 0.15, Color("#d8cfc4"))
	if curly:
		for k in 7:
			a.draw_circle(p + Vector2(-h * 0.13 + k * h * 0.045, -h * 0.9), h * 0.05, Color("#5a524a"))
	else:
		a.draw_arc(p + Vector2(0, -h * 0.78), h * 0.15, PI, TAU, 10, Color("#3e3a36"), h * 0.06)


func _photo_hallway(r: Rect2) -> void:
	var a := _area
	var f: Font = GameState.font
	# 學校走廊：一排置物櫃
	for k in 6:
		a.draw_rect(Rect2(r.position + Vector2(20 + k * 85, 40), Vector2(70, 200)), Color("#a8a39a"))
		a.draw_rect(Rect2(r.position + Vector2(20 + k * 85, 40), Vector2(70, 200)), Color("#8f8a80"), false, 2)
	a.draw_rect(Rect2(r.position + Vector2(0, 300), Vector2(r.size.x, r.size.y - 300)), Color("#9e998f"))
	# 白臉狐狸把書包倒進垃圾桶
	var fox := r.position + Vector2(170, 380)
	a.draw_set_transform(fox, 0.0, Vector2(2.6, 2.6))
	Critter.draw(a, "fox", Color("#d9d6cf"), 1.0, Vector2(1, 0), true, false, false, {"pale": true})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var bin := r.position + Vector2(300, 330)
	a.draw_rect(Rect2(bin, Vector2(70, 80)), Color("#6e6a64"))
	a.draw_rect(Rect2(bin + Vector2(10, -40), Vector2(50, 36)), Color("#8c7a68"))
	for k in 4:
		a.draw_rect(Rect2(bin + Vector2(6 + k * 14, -14 + (k % 2) * 6), Vector2(12, 16)), Color("#efece6"))
	# 旁邊站著一個人，看不清楚臉，名牌寫著「遙」
	var kid := r.position + Vector2(450, 410)
	_kid(kid, 200, Color("#8d8880"))
	a.draw_rect(Rect2(kid + Vector2(-16, -110), Vector2(32, 18)), Color("#f7f4ee"))
	a.draw_string(f, kid + Vector2(-16, -96), "遙", HORIZONTAL_ALIGNMENT_CENTER, 32, 14, Color("#5a524a"))


func _photo_mailbox(r: Rect2) -> void:
	var a := _area
	var f: Font = GameState.font
	a.draw_rect(Rect2(r.position + Vector2(0, 320), Vector2(r.size.x, r.size.y - 320)), Color("#a19c92"))
	# 一排學校信箱
	for k in 8:
		var p := r.position + Vector2(40 + (k % 4) * 120, 50 + (k / 4) * 90)
		a.draw_rect(Rect2(p, Vector2(100, 70)), Color("#b3ada3"))
		a.draw_rect(Rect2(p + Vector2(20, 26), Vector2(60, 8)), Color("#5f5a54"))
	# 黑色刺蝟拿著一疊信
	var hog := r.position + Vector2(270, 420)
	a.draw_set_transform(hog, 0.0, Vector2(2.8, 2.8))
	Critter.draw(a, "hedgehog", Color("#3a3836"), 1.0, Vector2(-0.5, 0), true, false, false, {"quills": 9})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 4:
		var l := hog + Vector2(50 + k * 6, -90 - k * 6)
		a.draw_rect(Rect2(l, Vector2(90, 54)), Color("#f3efe7"))
		a.draw_rect(Rect2(l, Vector2(90, 54)), Color("#9a948a"), false, 1)
	a.draw_string(f, hog + Vector2(68, -96), "給露露", HORIZONTAL_ALIGNMENT_CENTER, 90, 16, Color("#4a4540"))


func _photo_nirvana(r: Rect2) -> void:
	var a := _area
	var f: Font = GameState.font
	a.draw_rect(r, Color("#c9c6c0"))
	# 很多張床。床上躺著人類的小孩，頭上接著很多條線
	for k in 4:
		var bed := r.position + Vector2(30 + (k % 2) * 250, 70 + (k / 2) * 180)
		a.draw_rect(Rect2(bed, Vector2(210, 70)), Color("#eeeeea"))
		a.draw_rect(Rect2(bed + Vector2(0, 70), Vector2(8, 40)), Color("#8a8a86"))
		a.draw_rect(Rect2(bed + Vector2(202, 70), Vector2(8, 40)), Color("#8a8a86"))
		var head := bed + Vector2(36, 26)
		a.draw_circle(head, 18, Color("#d8cfc4"))
		if k == 3:
			# 其中一張床上的小孩，頭髮是捲的
			for j in 6:
				a.draw_circle(head + Vector2(-16 + j * 6, -14), 6, Color("#5a524a"))
		a.draw_rect(Rect2(bed + Vector2(56, 14), Vector2(140, 40)), Color("#dcdcd6"))
		for j in 5:
			a.draw_line(head + Vector2(-4, -10), head + Vector2(-20 + j * 12, -70), Color("#5f5f5a"), 2)
		a.draw_rect(Rect2(bed + Vector2(150, 76), Vector2(54, 20)), Color("#f7f7f2"))
		a.draw_string(f, bed + Vector2(150, 91), "涅槃", HORIZONTAL_ALIGNMENT_CENTER, 54, 14, Color("#4a4a4a"))
	# 底片燒壞了一半
	var burn := PackedVector2Array([r.position + Vector2(r.size.x * 0.55, 0), r.end - Vector2(0, r.size.y),
		r.end, r.position + Vector2(r.size.x * 0.75, r.size.y), r.position + Vector2(r.size.x * 0.62, r.size.y * 0.6),
		r.position + Vector2(r.size.x * 0.7, r.size.y * 0.3)])
	a.draw_colored_polygon(burn, Color("#2a2420"))
	a.draw_polyline(burn, Color("#6b4a2a"), 6)


func _silhouette(r: Rect2) -> void:
	var a := _area
	# 治療室的霧面玻璃：一個很大的影子，一個很大、但縮成一團的影子
	a.draw_rect(r.grow(20), Color("#e9e9e7"))
	a.draw_rect(r, Color("#d4d6da"))
	var sway := sin(_t * 1.3) * 4.0
	var big := r.position + Vector2(330 + sway, r.size.y)
	a.draw_rect(Rect2(big + Vector2(-50, -330), Vector2(100, 330)), Color(0.35, 0.36, 0.4, 0.55))
	a.draw_circle(big + Vector2(0, -370), 44, Color(0.35, 0.36, 0.4, 0.55))
	var small := r.position + Vector2(190, r.size.y - 60)
	Critter.ellipse(a, small, Vector2(78, 62), Color(0.35, 0.36, 0.4, 0.5))
	a.draw_circle(small + Vector2(-40, -50), 34, Color(0.35, 0.36, 0.4, 0.5))
	# 霧
	for k in 30:
		a.draw_circle(r.position + Vector2(fmod(k * 97.0, r.size.x), fmod(k * 53.0, r.size.y)), 30, Color(1, 1, 1, 0.08))
	a.draw_rect(Rect2(r.position + Vector2(r.size.x / 2 - 4, 0), Vector2(8, r.size.y)), Color("#bdbdbd"))
	a.draw_rect(Rect2(r.position + Vector2(0, r.size.y / 2 - 4), Vector2(r.size.x, 8)), Color("#bdbdbd"))
