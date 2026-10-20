extends Ch3Mini
## 第四章 4-3「群組」（薙文）：手機畫面，訊息一則一則滑上來（內容看不清楚，只看得到讚越來越多）。
## 要按「讚」才會出現下一則——這是薙文的記憶，不是玩家的選擇。
## 最後一則：名字被打上去（「遙」）。這一則可以不按：什麼都不做，訊息框會停很久，然後畫面自己暗下去。
## 回傳：最後一則有沒有按讚（true／false）。

const PHONE := Rect2(440, 80, 400, 550)
const COUNT := 7          # 前面幾則（看不清楚）
const WAIT_LAST := 9.0    # 最後一則停多久

var shown := 0            # 已經出現幾則
var likes: Array = []     # 每一則的讚數
var liked: Array = []     # 每一則有沒有按
var last_wait := 0.0
var _ended := false


func _setup() -> void:
	title = ""
	hint = "按 E／點「讚」，下一則才會出現"
	bg_color = Color("#2b2a2f")
	fast_result = true
	_add()


func _add() -> void:
	shown += 1
	likes.append(randi_range(3, 8) + shown * 2)
	liked.append(false)
	sfx("res://audio/ch4/msg_pop.ogg", -6.0)


func _is_last() -> bool:
	return shown == COUNT + 1


func _tick(delta: float) -> void:
	if _ended:
		return
	# 讚數自己慢慢變多
	for i in likes.size():
		if randf() < delta * 0.6:
			likes[i] += 1
	if _is_last() and not liked[-1]:
		last_wait += delta
		if last_wait > WAIT_LAST:
			_ended = true
			set_hint("")
			get_tree().create_timer(1.5).timeout.connect(func(): finish(false))


func _press(down: bool, _e: InputEvent) -> void:
	if not down or _ended:
		return
	liked[-1] = true
	likes[-1] += 1
	sfx("res://audio/ch4/like_tap.ogg", -4.0)
	if _is_last():
		_ended = true
		get_tree().create_timer(1.2).timeout.connect(func(): finish(true))
		return
	_add()
	if _is_last():
		set_hint("……")


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	c.draw_rect(PHONE.grow(14), Color("#111114"))
	c.draw_rect(PHONE, Color("#eceaf0"))
	c.draw_rect(Rect2(PHONE.position, Vector2(PHONE.size.x, 54)), Color("#7d8fa3"))
	c.draw_string(f, PHONE.position + Vector2(0, 36), "三年二班（30）", HORIZONTAL_ALIGNMENT_CENTER, PHONE.size.x, 22, Color.WHITE)
	# 訊息從下往上疊
	var y := PHONE.end.y - 20.0
	for k in range(shown - 1, -1, -1):
		var last := k == COUNT
		var h := 78.0 if not last else 96.0
		y -= h + 12.0
		if y < PHONE.position.y + 60:
			break
		var left := k % 3 != 1
		var r := Rect2(PHONE.position.x + (16.0 if left else 110.0), y, 274, h)
		c.draw_rect(r, Color.WHITE if left else Color("#d7efc8"))
		if last:
			# 只有這一則看得清楚：一個名字
			c.draw_string(f, r.position + Vector2(14, 40), "那就決定是", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#55505a"))
			c.draw_string(f, r.position + Vector2(130, 44), "遙", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("#2a2730"))
			c.draw_string(f, r.position + Vector2(176, 40), "了。", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#55505a"))
		else:
			# 看不清楚的字：一條一條灰色
			for ln in 2:
				var w := 200.0 - ((k * 37 + ln * 53) % 90)
				c.draw_rect(Rect2(r.position + Vector2(14, 18 + ln * 22), Vector2(w, 12)), Color("#c9c6cf"))
		var lr := Rect2(r.end.x - 86, r.end.y - 26, 80, 22)
		c.draw_string(f, lr.position + Vector2(0, 17), "讚 %d" % likes[k], HORIZONTAL_ALIGNMENT_RIGHT, 76, 16, PINK if liked[k] else Color("#8a8590"))
	# 讚的按鈕
	var btn := Rect2(PHONE.end.x + 40, PHONE.end.y - 70, 150, 56)
	if not _ended:
		c.draw_rect(btn, PINK if not (_is_last() and last_wait > 2.0) else Color("#6b5b62"))
		c.draw_string(f, btn.position + Vector2(0, 31), "讚", HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 24, Color.WHITE)
	if _ended and _is_last() and not liked[-1]:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
		c.draw_string(f, Vector2(0, 360), "（薙文的手指停在那裡。很久。）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#d9d4dc"))
