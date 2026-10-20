extends Ch3Mini
## 點滴：上下鍵（或按住／放開）調整滴速，讓液面停在刻度裡，撐到時間到；
## 走廊盡頭有腳步聲靠近時（畫面變暗、出現「……」），要完全不動，動了就被聽見。
## 回傳：true＝畢業生睡著了；false＝被聽見（要進 2D 追逐）。

var level := 0.5           # 0..1，刻度 0.35～0.65
var rate := 0.0
var steps_near := 0.0      # 腳步聲：>0 時不能動
var next_steps := 4.0
var duration := 22.0
var moved_while_steps := false
var out_time := 0.0


func _setup() -> void:
	title = "點滴"
	hint = "按住讓點滴變快、放開變慢。液面要一直在刻度裡。腳步聲靠近時，不要動。"
	fast_result = true


func _tick(delta: float) -> void:
	next_steps -= delta
	if next_steps <= 0.0 and steps_near <= 0.0:
		steps_near = 2.5
		next_steps = randf_range(4.0, 6.0)
		Sfx.play(self, "dove_step", -10.0)
	if steps_near > 0.0:
		steps_near -= delta
	rate = lerpf(rate, 0.35 if held else -0.3, delta * 3.0)
	level = clampf(level + rate * delta * 0.5 + sin(t * 1.7) * 0.02 * delta, 0.0, 1.0)
	if level < 0.35 or level > 0.65:
		out_time += delta
		if out_time > 2.5:
			finish(false)
			return
	else:
		out_time = maxf(0.0, out_time - delta)
	if t >= duration:
		finish(not moved_while_steps)


func _press(_down: bool, _e: InputEvent) -> void:
	if steps_near > 0.0:
		moved_while_steps = true
		finish(false)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	var dark := steps_near > 0.0
	if dark:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.45))
		c.draw_string(f, Vector2(0, 140), "……腳步聲。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color.WHITE)
	# 點滴袋
	var bag := Rect2(560, 170, 160, 260)
	c.draw_rect(bag, Color(1, 1, 1, 0.85))
	c.draw_rect(bag, INK, false, 2.0)
	c.draw_rect(Rect2(bag.position.x + 4, bag.position.y + bag.size.y * (1.0 - level), bag.size.x - 8, bag.size.y * level), Color("#bfe3f0"))
	for lv: float in [0.35, 0.65]:
		var y := bag.position.y + bag.size.y * (1.0 - lv)
		c.draw_line(Vector2(bag.position.x - 20, y), Vector2(bag.end.x + 20, y), GREEN, 3.0)
	c.draw_line(Vector2(640, bag.end.y), Vector2(640, 560), SOFT, 2.0)
	# 滴下來的水滴
	var drop_y := 450.0 + fmod(t * (60.0 + rate * 120.0), 100.0)
	c.draw_circle(Vector2(640, drop_y), 5, Color("#8cc8de"))
	c.draw_string(f, Vector2(0, 610), "剩下 %d 秒" % int(maxf(0.0, duration - t)), HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color.WHITE if dark else SOFT)
