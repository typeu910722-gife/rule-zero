extends Ch3Mini
## 心臟病：大家一起數 1～13，牌翻開；牌和數字一樣時搶先拍下（按鍵／點擊）。
## 三回合，每回合要拍中 3 次；越後面越快。拍錯（牌和數字不同時拍）會讓某一張床的心電圖亂一下。
## 回傳：拍錯的次數（0＝完美）。

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
var round_i := 0
var hits := 0
var misses := 0
var count := 0        # 正在數的數字（0..12）
var card := 0         # 這張牌（0..12）
var step := 0.0
var interval := 1.1
var flash := 0.0
var flash_col := Color.WHITE
var ecg_glitch := 0.0
var _hit_this := false


func _setup() -> void:
	title = "心臟病"
	hint = "數到跟牌一樣的時候，按下去！（E／空白鍵／點畫面）"
	fast_result = 0
	_next()


func _next() -> void:
	count = (count + 1) % 13
	# 大約三張就有一張會對上（不然太久）
	card = count if randf() < 0.34 else randi() % 13
	_hit_this = false
	step = 0.0
	sfx("res://audio/ch3/card.ogg", -8.0)
	Tones.play(self, Motif.NOTES[count % Motif.NOTES.size()] * 0.75, -16.0)


func _tick(delta: float) -> void:
	step += delta
	flash = maxf(0.0, flash - delta * 2.5)
	ecg_glitch = maxf(0.0, ecg_glitch - delta)
	if step >= interval:
		_next()


func _press(down: bool, _e: InputEvent) -> void:
	if not down or _hit_this:
		return
	_hit_this = true
	if card == count:
		hits += 1
		flash = 1.0
		flash_col = GREEN
		Tones.play(self, 1318.5, -10.0)
		if hits >= 3:
			hits = 0
			round_i += 1
			interval = [1.1, 0.85, 0.65][mini(round_i, 2)]
			if round_i >= 3:
				finish(misses)
				return
			set_hint("第 %d 回合。更快了。" % (round_i + 1))
	else:
		misses += 1
		flash = 1.0
		flash_col = RED
		ecg_glitch = 0.8
		Tones.buzz(self, 0.25)
		GameState.set_flag("c3_heart_miss", misses)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	# 數數（大家一起喊）
	c.draw_string(f, Vector2(0, 170), "「%s」" % RANKS[count], HORIZONTAL_ALIGNMENT_CENTER, 1280, 56, INK)
	# 牌
	var r := Rect2(560, 210, 160, 230)
	c.draw_rect(r, Color.WHITE)
	c.draw_rect(r, INK, false, 3.0)
	if flash > 0.0:
		c.draw_rect(r.grow(8), Color(flash_col, flash * 0.6), false, 8.0)
	var red := card % 2 == 0
	c.draw_string(f, r.position + Vector2(0, 140), RANKS[card], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 80, PINK if red else INK)
	c.draw_string(f, r.position + Vector2(10, 34), "♥" if red else "♠", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, PINK if red else INK)
	# 回合
	c.draw_string(f, Vector2(0, 490), "回合 %d／3　　這回合 %d／3" % [round_i + 1, hits], HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, SOFT)
	# 背景的心電圖（拍錯時亂掉）
	var pts := PackedVector2Array()
	for i in 120:
		var x := 160.0 + i * 8.0
		var ph := fmod(t * 1.3 + i / 40.0, 1.0)
		var y := 590.0
		if ph > 0.45 and ph < 0.5:
			y -= 50.0
		elif ph >= 0.5 and ph < 0.53:
			y += 20.0
		if ecg_glitch > 0.0:
			y += randf_range(-30, 30) * ecg_glitch
		pts.append(Vector2(x, y))
	c.draw_polyline(pts, RED if ecg_glitch > 0.0 else GREEN, 2.0)
	c.draw_string(f, Vector2(160, 545), "值班護士：一、二、三～", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, SOFT)
