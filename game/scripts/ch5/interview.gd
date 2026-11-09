extends Ch3Mini
## 終章 B-3 的 BOSS「出院面談」：測謊。
## 按住（E／空白鍵／按住畫面空白處）＝深呼吸，心跳往下；放開，心跳會慢慢往上爬。每個問題一出來，心跳會跳一下。
## 回答：← →（A／D）選、↑（W）回答；或直接點選項。要在時間內、而且心跳在綠色的範圍裡回答「不會被留下來」的話。
## 答錯、心跳太快、來不及回答：醫生的懷疑多一格。三格滿了，他拿出針筒——從第一題重來。
## 每重來一次，綠色的範圍放寬一點、回答的時間多一秒（最多三次）——一直卡住的人也過得去。
## 回傳：重來的次數（0＝一次就過）。

## [問題, 心跳跳多少, [[回答, 是不是安全的回答], ...], 特別效果]
const QUESTIONS := [
	["名字？", 10.0, [["遙。", true], ["……不知道。", false]], ""],
	["你在這裡睡了很久。做了夢嗎？", 18.0, [["做了很長的夢。醒來就忘了。", true], ["全部都記得。", false]], ""],
	["夢裡，有一隻綿羊嗎？", 24.0, [["……綿羊？", true], ["有。", false]], ""],
	["這張照片裡，你認得誰？", 34.0, [["只認得我自己。", true], ["芬。", false], ["全部的人。", false]], "photo"],
	["你為什麼一直看門口？", 16.0, [["我想回家。", true], ["我想逃走。", false]], ""],
	["你剛剛說你忘了。那你怎麼知道這裡是醫院？", 26.0, [["護理師說的。", true], ["我記得這裡。", false]], ""],
	["隔壁床的孩子，叫什麼名字？", 30.0, [["不知道。", true], ["希露飛。", false], ["……小滿？", false]], ""],
	["你聽過這首歌嗎？", 40.0, [["沒有。", true], ["……那是口哨。", false]], "whistle"],
]
const BAND_LO := 70.0
const BAND_HI := 105.0
const MAX_SUSPECT := 3

var heart := 80.0
var qi := 0
var q_t := 0.0           # 這一題剩下的時間
var pick := 0
var opts: Array = []     # 這一題（打亂順序之後）的選項
var suspect := 0
var retries := 0
var said := ""           # 醫生的反應
var said_t := 0.0
var _pause := 0.0        # 回答完、醫生說話的時候停一下
var _ecg: Array = []
var _rng := RandomNumberGenerator.new()


func _setup() -> void:
	title = "BOSS　出院面談"
	hint = "按住：深呼吸　← →：選　↑：回答（或點選項）　心跳要在綠色的範圍裡"
	bg_color = Color("#eef0ee")
	fast_result = 0
	_rng.seed = 1107
	_ask(0)


func _q_time() -> float:
	return 8.0 - qi * 0.4 + mini(retries, 3)   # 越後面越短：8 秒 → 5.2 秒；重來一次多一秒


func _lo() -> float:
	return BAND_LO - mini(retries, 3) * 5.0


func _hi() -> float:
	return BAND_HI + mini(retries, 3) * 5.0


func _ask(i: int) -> void:
	qi = i
	var q: Array = QUESTIONS[i]
	heart = minf(heart + float(q[1]), 170.0)
	opts = (q[2] as Array).duplicate()
	# 選項順序打亂（安全的回答不一定在左邊）
	for k in range(opts.size() - 1, 0, -1):
		var j := _rng.randi_range(0, k)
		var tmp = opts[k]
		opts[k] = opts[j]
		opts[j] = tmp
	pick = 0
	q_t = _q_time()
	if str(q[3]) == "whistle" and is_inside_tree():
		Motif.play(self, "whistle", -6.0)
	elif is_inside_tree():
		Sfx.play(self, "paper", -10.0)


func _answer(i: int) -> void:
	if _pause > 0.0 or i < 0 or i >= opts.size():
		return
	var good: bool = opts[i][1]
	var calm := heart >= _lo() and heart <= _hi()
	if good and calm:
		said = "……很好。"
		Sfx.play(self, "cursor", -8.0)
	else:
		suspect += 1
		said = "……你的心跳很快呢。" if good else "……這樣啊。"
		Sfx.play(self, "wrong", -6.0)
	_after()


func _after() -> void:
	said_t = 1.6
	_pause = 1.6
	if suspect >= MAX_SUSPECT:
		said = "那我們，再多住一陣子吧。"
		said_t = 2.6
		_pause = 2.6


func _tick(delta: float) -> void:
	# 心跳：按住往下，放開往上爬（越後面的問題爬得越快）
	if held:
		heart -= 15.0 * delta
	else:
		heart += (5.0 + qi * 0.6) * delta
	heart = clampf(heart, 48.0, 170.0)
	_ecg.append(heart)
	if _ecg.size() > 260:
		_ecg.pop_front()
	said_t -= delta
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			if suspect >= MAX_SUSPECT:
				# 針筒：從頭再來
				retries += 1
				suspect = 0
				heart = 90.0
				_ask(0)
			elif qi + 1 >= QUESTIONS.size():
				finish(retries)
			else:
				_ask(qi + 1)
		return
	q_t -= delta
	if q_t <= 0.0:
		suspect += 1
		said = "……為什麼不回答？"
		Sfx.play(self, "wrong", -6.0)
		_after()


func _opt_rect(i: int) -> Rect2:
	var w := 330.0
	var gap := 24.0
	var total := opts.size() * w + (opts.size() - 1) * gap
	return Rect2(640.0 - total / 2.0 + i * (w + gap), 452, w, 64)


func _press(down: bool, event: InputEvent) -> void:
	# 點到選項＝回答；點其他地方（按住）＝深呼吸
	if down and (event is InputEventMouseButton or event is InputEventScreenTouch):
		for i in opts.size():
			if _opt_rect(i).has_point(event.position):
				held = false
				_answer(i)
				return


func _other_input(e: InputEvent) -> void:
	if e.is_action_pressed("move_left") or e.is_action_pressed("ui_left"):
		pick = maxi(pick - 1, 0)
	elif e.is_action_pressed("move_right") or e.is_action_pressed("ui_right"):
		pick = mini(pick + 1, opts.size() - 1)
	elif e.is_action_pressed("move_up") or e.is_action_pressed("ui_up"):
		_answer(pick)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	# 醫生：沒有臉的大人（走路圖第一格放大）
	var doc := ExploreArt.tex(ExploreArt.WALK_DIR % "h_whitecoat")
	if doc:
		var cell := doc.get_width() / 4.0
		c.draw_texture_rect_region(doc, Rect2(Vector2(520, 70), Vector2(240, 240)), Rect2(0, 0, cell, cell))
	c.draw_rect(Rect2(380, 300, 520, 26), Color("#c9b79a"))   # 桌子
	var q: Array = QUESTIONS[qi]
	if str(q[3]) == "photo":
		var ph := Rect2(870, 120, 200, 140)
		c.draw_rect(ph, Color("#d8cfbf"))
		c.draw_rect(ph, Color("#7a7062"), false, 3.0)
		c.draw_string(f, ph.position + Vector2(0, 80), "三年二班", HORIZONTAL_ALIGNMENT_CENTER, ph.size.x, 22, Color("#5a5246"))
	c.draw_string(f, Vector2(0, 370), "醫生：" + str(q[0]), HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, INK)
	if said_t > 0.0:
		c.draw_string(f, Vector2(0, 412), "醫生：" + said, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, RED if suspect > 0 else SOFT)
	# 選項
	for i in opts.size():
		var r := _opt_rect(i)
		var sel := i == pick
		c.draw_rect(r, Color("#ffffff") if sel else Color("#f6f7f6"))
		c.draw_rect(r, PINK if sel else SOFT, false, 3.0 if sel else 1.5)
		c.draw_string(f, r.position + Vector2(0, 42), str(opts[i][0]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, INK)
	# 時間
	if _pause <= 0.0:
		var frac := clampf(q_t / _q_time(), 0.0, 1.0)
		c.draw_rect(Rect2(400, 530, 480 * frac, 6), PINK)
	# 心電圖：綠色的範圍
	var box := Rect2(160, 556, 960, 88)
	c.draw_rect(box, Color("#20302a"))
	var y_of := func(h: float) -> float: return box.end.y - (h - 48.0) / (170.0 - 48.0) * box.size.y
	c.draw_rect(Rect2(box.position.x, y_of.call(_hi()), box.size.x, y_of.call(_lo()) - y_of.call(_hi())), Color(0.49, 0.76, 0.6, 0.25))
	var pts := PackedVector2Array()
	for k in _ecg.size():
		var x := box.position.x + k * (box.size.x / 260.0)
		var spike := 0.0
		if (k + int(t * 60.0)) % 40 == 0:
			spike = -18.0
		pts.append(Vector2(x, y_of.call(_ecg[k]) + spike))
	if pts.size() > 1:
		c.draw_polyline(pts, GREEN if heart >= _lo() and heart <= _hi() else RED, 2.5)
	c.draw_string(f, box.position + Vector2(10, 24), "心跳 %d" % int(heart), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#cfe8d8"))
	# 懷疑：針筒
	for i in MAX_SUSPECT:
		var on := i < suspect
		var p := Vector2(1010 + i * 50, 380)
		c.draw_rect(Rect2(p, Vector2(34, 10)), RED if on else Color("#c9cfcf"))
		c.draw_line(p + Vector2(34, 5), p + Vector2(48, 5), RED if on else Color("#c9cfcf"), 2.0)
	c.draw_string(f, Vector2(1010, 368), "懷疑", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, SOFT)
	c.draw_string(f, Vector2(160, 370), "%d／%d" % [qi + 1, QUESTIONS.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, SOFT)
