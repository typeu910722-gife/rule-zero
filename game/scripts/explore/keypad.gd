extends Ch3Mini
## 密碼鎖：用數字鍵、上下左右＋E、或點按鈕輸入。對了回傳 true；按「放棄」回傳 false。
## 線索都在房間裡（劇本寫在調查點的對話裡）。

var code := "0000"
var hint_text := ""
var entered := ""
var cursor := 0
var wrong_t := 0.0
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "←", "0", "放棄"]


func _setup() -> void:
	if title == "":
		title = "密碼鎖"
	hint = "數字鍵、或方向鍵選＋E、或點按鈕"
	fast_result = true


func _key_rect(i: int) -> Rect2:
	return Rect2(520 + (i % 3) * 84, 250 + (i / 3) * 84, 76, 76)


func _type(k: String) -> void:
	if k == "放棄":
		finish(false)
		return
	if k == "←":
		entered = entered.left(maxi(0, entered.length() - 1))
		return
	if entered.length() >= code.length():
		return
	entered += k
	sfx("res://audio/ch4/like_tap.ogg", -10.0)
	if entered.length() == code.length():
		if entered == code:
			sfx("res://audio/ch3/light_on.ogg", -6.0)
			get_tree().create_timer(0.4).timeout.connect(func(): finish(true))
		else:
			wrong_t = 0.8
			Sfx.play(self, "wrong", -8.0)
			get_tree().create_timer(0.5).timeout.connect(func(): entered = "")


func _other_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		var c := OS.get_keycode_string(e.keycode)
		if c.length() == 1 and c >= "0" and c <= "9":
			_type(c)
			return
		if e.keycode == KEY_KP_0 + 0 or (e.keycode >= KEY_KP_0 and e.keycode <= KEY_KP_9):
			_type(str(e.keycode - KEY_KP_0))
			return
		if e.keycode == KEY_BACKSPACE:
			_type("←")
			return
	if e.is_action_pressed("move_right") or e.is_action_pressed("ui_right"):
		cursor = (cursor + 1) % KEYS.size()
	elif e.is_action_pressed("move_left") or e.is_action_pressed("ui_left"):
		cursor = (cursor - 1 + KEYS.size()) % KEYS.size()
	elif e.is_action_pressed("move_down") or e.is_action_pressed("ui_down"):
		cursor = (cursor + 3) % KEYS.size()
	elif e.is_action_pressed("move_up") or e.is_action_pressed("ui_up"):
		cursor = (cursor - 3 + KEYS.size()) % KEYS.size()


func _press(down: bool, e: InputEvent) -> void:
	if not down:
		return
	if e is InputEventMouseButton or e is InputEventScreenTouch:
		for i in KEYS.size():
			if _key_rect(i).has_point(e.position):
				cursor = i
				_type(KEYS[i])
				return
		return
	_type(KEYS[cursor])


func _tick(delta: float) -> void:
	wrong_t = maxf(0.0, wrong_t - delta)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	var shake := Vector2(sin(t * 60.0) * 8.0 * wrong_t, 0)
	var disp := Rect2(500 + shake.x, 150, 280, 70)
	c.draw_rect(disp, Color("#1c2622"))
	var s := ""
	for i in code.length():
		s += (entered[i] if i < entered.length() else "＿") + " "
	c.draw_string(f, disp.position + Vector2(0, 48), s, HORIZONTAL_ALIGNMENT_CENTER, disp.size.x, 34, RED if wrong_t > 0.0 else GREEN)
	for i in KEYS.size():
		var r := _key_rect(i)
		c.draw_rect(r, Color.WHITE)
		c.draw_rect(r, PINK if i == cursor else SOFT, false, 4.0 if i == cursor else 2.0)
		c.draw_string(f, r.position + Vector2(0, 50), KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22 if KEYS[i].length() > 1 else 30, INK)
	if hint_text != "":
		c.draw_string(f, Vector2(0, 610), hint_text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, SOFT)
