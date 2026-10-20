extends Ch3Mini
## 追逐（基礎版，之後換成第一章那種裸眼 3D 追逐）：往畫面深處跑的醫院長廊，三條線道。
## 左右鍵／滑動／點畫面左右半邊換線道，閃過病床推車、點滴架、伸出來的手。撞到＝掉棉花。
## rollcall＝true 時：廣播會點名，叫到名字的人要立刻按住「躲」（按住互動鍵／手指壓著）。
## 回傳：撞到（被抓到）的次數。

var rollcall := false
var duration := 35.0
var lane := 1
var lane_x := 1.0
var obstacles: Array = []   # [lane, z(1→0), kind]
var spawn := 0.0
var hits := 0
var hit_flash := 0.0
var call_name := ""
var call_t := 0.0
var call_ok := false
var _swipe_from := Vector2.ZERO
const NAMES := ["希露飛", "銘越", "小滿", "芬", "……沒有名字的那一個", "遙"]
var _call_i := 0
var next_call := 5.0


func _setup() -> void:
	title = "廣播點名" if rollcall else "捉迷藏"
	hint = ("被點到名字的時候，按住不放（躲好）。" if rollcall else "") + "← → 換邊，閃過擋路的東西。"
	fast_result = 0


func _tick(delta: float) -> void:
	lane_x = lerpf(lane_x, float(lane), delta * 12.0)
	hit_flash = maxf(0.0, hit_flash - delta * 2.0)
	var speed := 0.55 + t / duration * 0.5
	spawn -= delta
	if spawn <= 0.0 and t < duration - 2.0:
		spawn = randf_range(0.7, 1.2) / (1.0 + t / duration)
		obstacles.append([randi() % 3, 1.0, randi() % 3])
	for o in obstacles:
		o[1] -= speed * delta
	for o in obstacles.duplicate():
		if o[1] <= 0.08 and o[1] > -0.2 and int(o[0]) == lane and o[1] > 0.0:
			_hit()
			obstacles.erase(o)
		elif o[1] < -0.2:
			obstacles.erase(o)
	if rollcall:
		next_call -= delta
		if call_t > 0.0:
			call_t -= delta
			if call_t <= 0.0:
				if not call_ok:
					_hit()
				call_name = ""
		elif next_call <= 0.0 and _call_i < NAMES.size():
			call_name = NAMES[_call_i]
			_call_i += 1
			call_t = 1.6
			call_ok = false
			next_call = 4.0
			Sfx.play(self, "broadcast", -10.0)
		if call_t > 0.0 and held:
			call_ok = true
	if t >= duration:
		finish(hits)


func _hit() -> void:
	hits += 1
	hit_flash = 1.0
	Tones.buzz(self, 0.3)
	if not GameState.gentle():
		Dialogue.fx.scare()


func _other_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
		lane = maxi(0, lane - 1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
		lane = mini(2, lane + 1)
	elif event is InputEventScreenDrag and absf(event.relative.x) > 12.0:
		lane = clampi(lane + (1 if event.relative.x > 0 else -1), 0, 2)


func _press(down: bool, event: InputEvent) -> void:
	# 點畫面左右半邊也可以換線道（沒有點名的時候）
	if down and not (rollcall and call_t > 0.0) and (event is InputEventMouseButton or event is InputEventScreenTouch):
		var x: float = event.position.x
		if x < 427:
			lane = maxi(0, lane - 1)
		elif x > 853:
			lane = mini(2, lane + 1)


func _proj(l: float, z: float) -> Vector2:
	# 透視：z=1 在遠方的消失點，z=0 在畫面底部
	var depth := 1.0 - z
	var y := 260.0 + 420.0 * depth * depth
	var spread := 60.0 + 380.0 * depth * depth
	return Vector2(640.0 + (l - 1.0) * spread, y)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	# 長廊
	c.draw_rect(Rect2(0, 0, 1280, 720), Color("#2a3133") if rollcall else Color("#dfe6e8"))
	var vp := Vector2(640, 250)
	for side in [-1, 1]:
		c.draw_line(vp, Vector2(640 + side * 900, 720), SOFT, 3.0)
	for k in 8:
		var z := fmod(1.0 - (t * 0.6 + k / 8.0), 1.0)
		var a := _proj(-0.5, z)
		var b := _proj(2.5, z)
		c.draw_line(a, b, Color(SOFT, 0.35), 1.0)
		# 天花板的燈
		var lamp := Vector2(640, 250 - 200 * (1.0 - z) * (1.0 - z))
		c.draw_rect(Rect2(lamp - Vector2(30 * (1.2 - z), 4), Vector2(60 * (1.2 - z), 8)), Color(1, 1, 0.9, 0.7))
	# 障礙物
	obstacles.sort_custom(func(a, b): return a[1] > b[1])
	for o in obstacles:
		var p := _proj(float(o[0]), float(o[1]))
		var s := 0.25 + (1.0 - float(o[1])) * 1.3
		match int(o[2]):
			0:  # 病床推車
				c.draw_rect(Rect2(p - Vector2(60, 40) * s, Vector2(120, 50) * s), Color("#f4f4f2"))
				c.draw_rect(Rect2(p - Vector2(60, 40) * s, Vector2(120, 50) * s), INK, false, 2.0)
			1:  # 點滴架
				c.draw_line(p, p - Vector2(0, 140) * s, INK, 4.0 * s)
				c.draw_rect(Rect2(p - Vector2(18, 150) * s, Vector2(36, 40) * s), Color("#bfe3f0"))
			_:  # 伸出來的手（病人服的袖子）
				c.draw_rect(Rect2(p - Vector2(15, 120) * s, Vector2(30, 90) * s), Color("#c9d6e3"))
				c.draw_circle(p - Vector2(0, 30) * s, 22 * s, Color("#e8c9b0"))
	# 小布
	var me := _proj(lane_x, 0.0) - Vector2(0, 50)
	c.draw_circle(me, 34, Color("#fff8ee"))
	c.draw_circle(me + Vector2(0, 30), 26, Color("#7a9a6a"))
	c.draw_string(f, Vector2(0, 690), "剩下 %d 秒　　撞到 %d" % [int(maxf(0.0, duration - t)), hits], HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, Color.WHITE if rollcall else INK)
	if hit_flash > 0.0:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(RED, hit_flash * 0.35))
	if call_name != "":
		c.draw_rect(Rect2(0, 120, 1280, 70), Color(0, 0, 0, 0.6))
		c.draw_string(f, Vector2(0, 168), "廣播：「%s」" % call_name, HORIZONTAL_ALIGNMENT_CENTER, 1280, 32, GREEN if call_ok else Color.WHITE)
