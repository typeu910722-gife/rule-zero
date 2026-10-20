extends Ch3Mini
## 縫合：替棉花最少的人縫回去。針沿著虛線來回走，針到記號時按下＝一針。
## 每個人縫 6 針；按得準的針腳整齊，偏太多就留下歪的縫線（外觀永久改變）。
## 回傳：{id: 歪的針數}。補回的棉花由章節導演處理。

var patients: Array = []   # [[id, 名字]]
var idx := 0
var stitch := 0
var pos := 0.0             # 0..1 針在線上的位置
var dirn := 1.0
var marks := [0.1, 0.26, 0.42, 0.58, 0.74, 0.9]
var crooked := {}
var placed: Array = []     # [位置, 準不準]
var speed := 0.55


func _setup() -> void:
	title = "縫合"
	hint = "針走到紅色記號的時候按下去。棉花一直往外掉，要快一點。"
	fast_result = {}


func _tick(delta: float) -> void:
	if idx >= patients.size():
		finish(crooked)
		return
	pos += dirn * speed * delta
	if pos > 1.0 or pos < 0.0:
		dirn = -dirn
		pos = clampf(pos, 0.0, 1.0)


func _press(down: bool, _e: InputEvent) -> void:
	if not down or idx >= patients.size():
		return
	var target: float = marks[stitch]
	var off := absf(pos - target)
	var good := off < 0.05
	placed.append([pos, good])
	sfx("res://audio/ch3/needle.ogg", -6.0)
	if not good:
		var id: String = patients[idx][0]
		crooked[id] = int(crooked.get(id, 0)) + 1
	stitch += 1
	if stitch >= marks.size():
		stitch = 0
		placed.clear()
		idx += 1
		speed += 0.1
		Tones.play(self, 1046.5, -12.0)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	if idx >= patients.size():
		return
	c.draw_string(f, Vector2(0, 140), "%s（%d／%d）　第 %d 針" % [patients[idx][1], idx + 1, patients.size(), stitch + 1], HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, INK)
	# 布與破洞
	var cloth := Rect2(240, 220, 800, 260)
	c.draw_rect(cloth, Color("#f7e6d6"))
	c.draw_rect(cloth, Color("#c9a98a"), false, 3.0)
	var y := 350.0
	# 掉出來的棉花
	for k in 9:
		var cx := 300.0 + k * 85.0 + sin(t * 2.0 + k) * 6.0
		c.draw_circle(Vector2(cx, y + sin(t * 3.0 + k * 1.7) * 10.0), 18, Color(1, 1, 1, 0.95))
	# 虛線
	var x0 := 280.0
	var w := 720.0
	for k in 36:
		if k % 2 == 0:
			c.draw_line(Vector2(x0 + w * k / 36.0, y), Vector2(x0 + w * (k + 1) / 36.0, y), SOFT, 2.0)
	for k in marks.size():
		var mx: float = x0 + w * marks[k]
		var col := RED if k == stitch else Color(RED, 0.3)
		c.draw_line(Vector2(mx, y - 18), Vector2(mx, y + 18), col, 3.0)
	for p in placed:
		var px: float = x0 + w * float(p[0])
		c.draw_line(Vector2(px - 10, y - (8 if p[1] else 20)), Vector2(px + 10, y + (8 if p[1] else 4)), INK, 4.0)
	# 針
	var nx := x0 + w * pos
	c.draw_line(Vector2(nx, y - 60), Vector2(nx, y - 6), INK, 3.0)
	c.draw_circle(Vector2(nx, y - 62), 5, INK)
