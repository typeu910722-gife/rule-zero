extends Ch3Mini
## 終章 B-1 的 BOSS「鏡子裡的孩子」：三年二班的座位表（邏輯解謎）。
## 九個人、九個位子、八條線索，答案只有一種（docs/script/chapter5.md）。
## 操作：方向鍵移動、互動鍵（E／空白鍵／點一下）換名字；右鍵／退格清掉；選到「交卷」按互動鍵。
## 交卷錯了會說對了幾個，用掉一條線；三條線都用完，位子全部清空重來（線索不變），
## 而且鏡子裡的孩子會幫你放好一個人（固定，不能改）——一直卡住的人也不會永遠過不去。
## 回傳：交卷錯的次數（0＝一次就對）。

const NAMES := ["遙", "芬", "希露飛", "銘越", "小滿", "辛禾", "薙文", "李恩", "郡主"]
## 答案：ANSWER[列][欄]；第一列在講台前面，第一欄靠窗
const ANSWER := [["小滿", "薙文", "銘越"], ["希露飛", "李恩", "辛禾"], ["遙", "芬", "郡主"]]
const CLUES := [
	"一、遙坐在窗邊，而且他的後面沒有人。",
	"二、芬坐在遙的隔壁。",
	"三、希露飛坐在遙的正前方。",
	"四、郡主和芬坐在同一排。",
	"五、小滿坐在第一排。他的正後方是女生。",
	"六、薙文的正後方，是李恩。",
	"七、辛禾坐在靠門的那一欄。",
	"八、銘越沒有坐在李恩的旁邊。",
]
const LIVES := 3

var seats := []          # 3×3，"" 或名字
var cur := Vector2i(0, 0)   # y＝3 是「交卷」
var lives := LIVES
var wrong := 0
var msg := ""
var msg_t := 0.0
var _win_t := -1.0
var locked: Array = []   # 幫你放好的位子 [Vector2i]

const GRID_X := 640.0
const GRID_Y := 170.0
const CELL_W := 150.0
const CELL_H := 96.0


func _setup() -> void:
	title = "BOSS　鏡子裡的孩子"
	hint = "方向鍵移動　E／點一下：換名字　右鍵／Backspace：清掉　選「交卷」按 E"
	bg_color = Color("#2a2730")
	fast_result = 0
	for y in 3:
		seats.append(["", "", ""])


func _ready() -> void:
	super()
	# 深色的鏡子：標題、提示改成淺色字＋深色描邊
	for l in [_title, _hint]:
		l.add_theme_color_override("font_color", Color("#ece6ef") if l == _title else Color("#a59cb0"))
		l.add_theme_color_override("font_outline_color", Color(0.1, 0.09, 0.12, 0.9))


func _cell_rect(x: int, y: int) -> Rect2:
	return Rect2(GRID_X + x * (CELL_W + 14), GRID_Y + 70 + y * (CELL_H + 14), CELL_W, CELL_H)


func _submit_rect() -> Rect2:
	return Rect2(GRID_X + CELL_W * 0.5 + 14, GRID_Y + 70 + 3 * (CELL_H + 14) + 6, CELL_W * 2.0, 52)


func _used() -> Array:
	var u: Array = []
	for row in seats:
		for n in row:
			if n != "":
				u.append(n)
	return u


## 這個位子換成下一個還沒坐的人（空白也算一個選項）
func _cycle(x: int, y: int) -> void:
	var used := _used()
	var opts: Array = [""]
	for n in NAMES:
		if n == seats[y][x] or not (n in used):
			opts.append(n)
	if Vector2i(x, y) in locked:
		return
	var i := opts.find(seats[y][x])
	seats[y][x] = opts[(i + 1) % opts.size()]
	Sfx.play(self, "cursor", -10.0)


func _submit() -> void:
	var ok := 0
	for y in 3:
		for x in 3:
			if seats[y][x] == ANSWER[y][x]:
				ok += 1
	if ok == 9:
		msg = "……對。這就是我們的教室。"
		msg_t = 99.0
		_win_t = 2.4
		return
	wrong += 1
	lives -= 1
	Sfx.play(self, "wrong", -4.0)
	if lives <= 0:
		lives = LIVES
		# 幫你放好一個人：依序從遙開始（最有把握的線索先）
		for p in [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 1), Vector2i(2, 2), Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]:
			if not (p in locked):
				locked.append(p)
				break
		for y in 3:
			seats[y] = ["", "", ""]
		for p in locked:
			seats[p.y][p.x] = ANSWER[p.y][p.x]
		msg = "對了 %d 個。……線斷了。鏡子裡的孩子替你放好了一個人。" % ok
	else:
		msg = "對了 %d 個。還剩 %d 條線。" % [ok, lives]
	msg_t = 3.5


func _tick(delta: float) -> void:
	msg_t -= delta
	if _win_t > 0.0:
		_win_t -= delta
		if _win_t <= 0.0:
			finish(wrong)


func _press(down: bool, event: InputEvent) -> void:
	if not down or _win_t > 0.0:
		return
	# 滑鼠／觸控：點到哪一格就是哪一格
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		pos = event.position
		if _submit_rect().has_point(pos):
			cur = Vector2i(1, 3)
			_submit()
			return
		for y in 3:
			for x in 3:
				if _cell_rect(x, y).has_point(pos):
					cur = Vector2i(x, y)
					_cycle(x, y)
		return
	if cur.y == 3:
		_submit()
	else:
		_cycle(cur.x, cur.y)


func _other_input(e: InputEvent) -> void:
	if _win_t > 0.0:
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
		for y in 3:
			for x in 3:
				if _cell_rect(x, y).has_point(e.position) and not (Vector2i(x, y) in locked):
					seats[y][x] = ""
		return
	if e.is_action_pressed("move_left") or e.is_action_pressed("ui_left"):
		cur.x = maxi(cur.x - 1, 0)
	elif e.is_action_pressed("move_right") or e.is_action_pressed("ui_right"):
		cur.x = mini(cur.x + 1, 2)
	elif e.is_action_pressed("move_up") or e.is_action_pressed("ui_up"):
		cur.y = maxi(cur.y - 1, 0)
	elif e.is_action_pressed("move_down") or e.is_action_pressed("ui_down"):
		cur.y = mini(cur.y + 1, 3)
	elif e is InputEventKey and e.pressed and (e.keycode == KEY_BACKSPACE or e.keycode == KEY_DELETE) and cur.y < 3 and not (cur in locked):
		seats[cur.y][cur.x] = ""


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	var ink := Color("#ece6ef")
	var soft := Color("#a59cb0")
	# 左邊：鏡子裡的孩子給的線索
	c.draw_string(f, Vector2(60, 120), "鏡子裡的孩子說：", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, soft)
	for i in CLUES.size():
		c.draw_string(f, Vector2(60, 160 + i * 44), CLUES[i], HORIZONTAL_ALIGNMENT_LEFT, 540, 21, ink)
	c.draw_string(f, Vector2(60, 160 + CLUES.size() * 44 + 10), "（這九個人裡，女生是希露飛和薙文。）", HORIZONTAL_ALIGNMENT_LEFT, 540, 18, soft)
	# 右邊：教室
	var board := Rect2(GRID_X, GRID_Y, CELL_W * 3 + 28, 40)
	c.draw_rect(board, Color("#3f5a4a"))
	c.draw_string(f, board.position + Vector2(0, 28), "講台", HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 20, ink)
	c.draw_string(f, Vector2(GRID_X - 52, GRID_Y + 70 + CELL_H * 1.5 + 14), "窗", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#9cc3d9"))
	c.draw_string(f, Vector2(GRID_X + CELL_W * 3 + 44, GRID_Y + 70 + CELL_H * 1.5 + 14), "門", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#d9b48c"))
	for y in 3:
		for x in 3:
			var r := _cell_rect(x, y)
			var sel := cur == Vector2i(x, y)
			c.draw_rect(r, Color("#4a4452") if not sel else Color("#6b5f78"))
			c.draw_rect(r, Color("#e98aa0") if sel else Color("#7a6f86"), false, 3.0 if sel else 1.5)
			var n: String = seats[y][x]
			c.draw_string(f, r.position + Vector2(0, r.size.y * 0.5 + 10), n if n != "" else "・", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, (Color("#f2c2cf") if Vector2i(x, y) in locked else ink) if n != "" else soft)
	var sr := _submit_rect()
	var ssel := cur.y == 3
	c.draw_rect(sr, Color("#6b5f78") if ssel else Color("#4a4452"))
	c.draw_rect(sr, Color("#e98aa0") if ssel else Color("#7a6f86"), false, 3.0 if ssel else 1.5)
	c.draw_string(f, sr.position + Vector2(0, 35), "交卷", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 24, ink)
	# 線（命）
	for i in LIVES:
		var on := i < lives
		c.draw_line(Vector2(60 + i * 40, 590), Vector2(60 + i * 40 + 28, 578), Color("#e98aa0") if on else Color("#5a5262"), 4.0)
	c.draw_string(f, Vector2(190, 592), "剩下的線", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, soft)
	if msg_t > 0.0:
		c.draw_string(f, Vector2(60, 630), msg, HORIZONTAL_ALIGNMENT_LEFT, 540, 21, Color("#f2c2cf"))
