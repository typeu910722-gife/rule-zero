extends Ch3Mini
## 量體溫：輪流替每個人量。按住＝把溫度計放進嘴裡，指針開始跑；在綠色區間放開。
## 每個人的指針跑法不同：麻糬很快、Fen 會亂跳、白面根本不動（他沒有身體：自動跳過）。
## 回傳：量錯（發燒）的人的 id 陣列。

var queue: Array = []      # [[id, 名字]]
var idx := 0
var needle := 0.0          # 0..1
var speed := 0.5
var running := false
var fevers: Array = []
var msg := ""
var msg_t := 0.0
const GREEN_LO := 0.55
const GREEN_HI := 0.68


func _setup() -> void:
	title = "量體溫"
	hint = "按住：放進溫度計。指針到綠色的地方，放開。"
	fast_result = []
	_start_person()


func _start_person() -> void:
	needle = 0.0
	running = false
	if idx >= queue.size():
		finish(fevers)
		return
	var id: String = queue[idx][0]
	speed = {"mochi": 0.9, "fen": 0.55}.get(id, 0.45)
	if id == "baimian":
		msg = "白面：……指針不動。他沒有身體。"
		msg_t = 1.6


func _tick(delta: float) -> void:
	if msg_t > 0.0:
		msg_t -= delta
		if msg_t <= 0.0 and idx < queue.size() and queue[idx][0] == "baimian":
			idx += 1
			_start_person()
		return
	if running:
		var id: String = queue[idx][0]
		needle += speed * delta
		if id == "fen":
			needle += randf_range(-0.6, 0.6) * delta
		needle = clampf(needle, 0.0, 1.05)
		if needle >= 1.0:
			_release()


func _press(down: bool, _e: InputEvent) -> void:
	if msg_t > 0.0 or idx >= queue.size():
		return
	if down:
		running = true
	elif running:
		_release()


func _release() -> void:
	running = false
	var id: String = queue[idx][0]
	if needle >= GREEN_LO and needle <= GREEN_HI:
		msg = "%s：正常。" % queue[idx][1]
		Tones.play(self, 1046.5, -10.0)
	else:
		msg = "%s：……發燒了。" % queue[idx][1]
		fevers.append(id)
		Tones.buzz(self, 0.2)
	msg_t = 0.9
	idx += 1
	await get_tree().create_timer(0.9).timeout
	_start_person()


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	if idx < queue.size():
		c.draw_string(f, Vector2(0, 150), "%s（%d／%d）" % [queue[idx][1], idx + 1, queue.size()], HORIZONTAL_ALIGNMENT_CENTER, 1280, 30, INK)
	# 溫度計
	var x0 := 340.0
	var w := 600.0
	var y := 330.0
	c.draw_rect(Rect2(x0, y, w, 36), Color.WHITE)
	c.draw_rect(Rect2(x0 + w * GREEN_LO, y, w * (GREEN_HI - GREEN_LO), 36), Color(GREEN, 0.7))
	c.draw_rect(Rect2(x0, y, w, 36), INK, false, 2.0)
	c.draw_rect(Rect2(x0, y + 6, w * clampf(needle, 0, 1), 24), Color(RED, 0.75))
	c.draw_circle(Vector2(x0 - 20, y + 18), 26, RED)
	for k in 6:
		var tx := x0 + w * k / 5.0
		c.draw_line(Vector2(tx, y + 40), Vector2(tx, y + 52), SOFT, 2.0)
		c.draw_string(f, Vector2(tx - 30, y + 78), "%d°" % (35 + k), HORIZONTAL_ALIGNMENT_CENTER, 60, 18, SOFT)
	if msg_t > 0.0:
		c.draw_string(f, Vector2(0, 500), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, INK)
