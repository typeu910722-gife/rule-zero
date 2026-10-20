extends Ch3Mini
## 第四章「那一天」⑤⑥（芬）：擋在廁所的門前。一直按住＝站穩；放開就被往旁邊推開一點，要再按住站回去。
## 窗外的白鴿一直看著。時間到時白鴿衝進來——那一刻放不放開都一樣（固定的記憶）。
## 回傳：true（固定）。

const DURATION := 12.0
var stand := 0.7          # 0..1：站得多穩
var dove_t := -1.0        # 白鴿衝進來的時間（>=0 時開始）
var _flap_done := false


func _setup() -> void:
	title = "擋在門前"
	hint = "按住 E／按住畫面：站在門前，不要讓開"
	bg_color = Color("#d6ccbb")
	fast_result = true


func _tick(delta: float) -> void:
	if dove_t >= 0.0:
		dove_t += delta
		if dove_t > 0.35 and not _flap_done:
			_flap_done = true
			sfx("res://audio/ch4/door_thud.ogg", -2.0)
		if dove_t > 2.4:
			finish(true)
		return
	stand = clampf(stand + (0.5 if held else -0.7) * delta, 0.0, 1.0)
	if t >= DURATION:
		dove_t = 0.0
		set_hint("")
		sfx("res://audio/ch4/wings.ogg", 0.0)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	# 樓梯口、廁所的門、窗戶
	c.draw_rect(Rect2(520, 120, 240, 360), Color("#8a7f70"))
	c.draw_rect(Rect2(520, 120, 240, 360), Color("#5d5448"), false, 5.0)
	c.draw_rect(Rect2(520, 472, 240, 8), Color("#2a2620"))
	c.draw_rect(Rect2(960, 110, 240, 230), Color("#cfe0e6"))
	c.draw_line(Vector2(960, 300), Vector2(1200, 300), Color("#8f7d64"), 6.0)
	for k in 6:
		c.draw_rect(Rect2(300 - k * 26, 520 + k * 30, 900, 30), Color("#a69378").darkened(k * 0.05))
	# 窗外的白鴿：一直看著
	var dove := Vector2(1080, 292)
	if dove_t >= 0.0:
		dove = dove.lerp(Vector2(660, 330), clampf(dove_t / 0.35, 0.0, 1.0))
	c.draw_circle(dove, 18, Color.WHITE)
	c.draw_circle(dove + Vector2(-12, -10), 9, Color.WHITE)
	c.draw_circle(dove + Vector2(-15, -12), 2.5, Color("#c33"))
	# 芬（剪影）：站在門前；不穩時被推到旁邊
	var off := (1.0 - stand) * 140.0
	var fen := Vector2(640 + off, 470)
	if dove_t > 0.35:
		fen = Vector2(640, 470).lerp(Vector2(560, 700), clampf((dove_t - 0.35) / 0.8, 0.0, 1.0))
	c.draw_rect(Rect2(fen + Vector2(-34, -150), Vector2(68, 150)), Color("#3c3a40"))
	c.draw_circle(fen + Vector2(0, -170), 26, Color("#3c3a40"))
	# 站穩的程度
	if dove_t < 0.0:
		c.draw_rect(Rect2(440, 610, 400, 18), Color(1, 1, 1, 0.5))
		c.draw_rect(Rect2(440, 610, 400 * stand, 18), PINK if stand > 0.35 else RED)
		c.draw_string(f, Vector2(0, 600), "芬" if stand > 0.35 else "……再站回去。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, INK)
	elif dove_t > 0.3 and dove_t < 0.55 and not GameState.gentle():
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 0.8))
