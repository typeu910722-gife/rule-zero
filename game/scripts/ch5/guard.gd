extends Ch3Mini
## 第五章 終章 B-2：守住醫院的走廊，等大家的心電圖一個一個亮起來。
## 白色的影子（職員）從走廊另一頭走過來；走到你面前的圈圈裡時按一下，把他推回去。
## 被碰到就會停一下、心電圖亮得慢一點。四個人都亮起來就結束（結局不會變）。回傳：推回去的次數。

const ZONE_X := 330.0
var shadows: Array = []   # 每個影子的 x
var spawn := 1.2
var lit := 0.0            # 0..4：亮起來的心電圖
var pushes := 0
var stun := 0.0
var flash := 0.0


func _setup() -> void:
	title = "守住走廊"
	hint = "影子走進圈圈的時候按一下（E／空白鍵／點畫面），把他推回去"
	bg_color = Color("#dfe3e1")
	fast_result = 0


func _tick(delta: float) -> void:
	stun = maxf(0.0, stun - delta)
	flash = maxf(0.0, flash - delta * 3.0)
	lit = minf(4.0, lit + delta * (0.05 if stun > 0.0 else 0.16))
	spawn -= delta
	if spawn <= 0.0:
		shadows.append(1300.0)
		spawn = randf_range(1.3, 2.2) - lit * 0.15
	for i in range(shadows.size() - 1, -1, -1):
		shadows[i] -= delta * (150.0 + lit * 25.0)
		if shadows[i] < ZONE_X - 70.0:
			shadows.remove_at(i)
			stun = 1.2
			sfx("res://audio/ch4/door_thud.ogg", -10.0)
	if lit >= 4.0:
		finish(pushes)


func _press(down: bool, _e: InputEvent) -> void:
	if not down:
		return
	for i in shadows.size():
		if absf(shadows[i] - ZONE_X) < 70.0:
			shadows.remove_at(i)
			pushes += 1
			flash = 1.0
			sfx("res://audio/ch3/card.ogg", -6.0)
			return


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	var bg := art4("bg_hospital_side")
	var walk_a := art4("staff_01")
	var walk_b := art4("staff_02")
	var use_art := bg != null and walk_a != null and walk_b != null
	if use_art:
		c.draw_texture_rect(bg, Rect2(0, 0, 1280, 720), false)
	else:
		c.draw_rect(Rect2(0, 200, 1280, 320), Color("#e9ece9"))
		c.draw_rect(Rect2(0, 520, 1280, 100), Color("#c9cec8"))
	# 四間病房的心電圖
	# 有壁掛監視器的圖（art/ch4/mini/wall_monitor.png，260×104，螢幕在 (20, 32) 起 220×52）就畫在牆上，波形畫在螢幕裡
	var mon := art4("wall_monitor")
	for k in 4:
		var on := lit >= k + 1
		var r := Rect2(60 + k * 300, 110, 220, 70)
		var base := 40.0
		var peak := -24.0
		if mon != null:
			c.draw_texture_rect(mon, Rect2(r.position + Vector2(-20, -24), Vector2(260, 104)), false)
			r = Rect2(r.position + Vector2(0, 8), Vector2(220, 52))
			base = 34.0
			peak = -20.0
		else:
			c.draw_rect(r, Color("#1c2622"))
		var col := GREEN if on else Color("#3a4a42")
		var pts := PackedVector2Array()
		for x in 22:
			var y := 0.0
			if on and (x + int(t * 10.0)) % 11 == 5:
				y = peak
			pts.append(r.position + Vector2(10 + x * 9.5, base + y))
		c.draw_polyline(pts, col, 2.0)
	# 小布（玩偶）站在病房門前
	var floor_y := 650.0 if use_art else 520.0
	Ch2Critter.draw_pip(c, Vector2(ZONE_X - 120, floor_y), 0.9, 2)
	c.draw_arc(Vector2(ZONE_X, floor_y - 50), 60, 0, TAU, 32, PINK if flash > 0.0 else SOFT, 4.0)
	for i in shadows.size():
		var x: float = shadows[i]
		if use_art:
			# 白色的影子（職員）：沒有臉，一步一步往左走過來
			var frame := walk_a if int(t * 3.0 + i) % 2 == 0 else walk_b
			Ch3Mini.draw_art_h(c, frame, Vector2(x, floor_y), 300, Color(1, 1, 1, 0.92))
		else:
			c.draw_rect(Rect2(Vector2(x - 26, 360), Vector2(52, 160)), Color(1, 1, 1, 0.9))
			c.draw_circle(Vector2(x, 340), 26, Color(1, 1, 1, 0.9))
	if stun > 0.0:
		c.draw_string(f, Vector2(0, 600), "……被推倒了。爬起來。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, RED)
