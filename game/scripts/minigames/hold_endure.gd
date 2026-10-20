extends CanvasLayer
## 治療室：按住「我很乖」撐過去（第二章）。
## 每一題要按住到時間滿；放開的話進度會慢慢掉回去。越撐，畫面越白。
## 用法：var h := HoldEndure.new(); h.questions = [["你為什麼沒有笑？", 3.0], ...]; await h.play()

signal done

var questions: Array = []
var _i := 0
var _hold := 0.0
var _running := false
var _area: Control
var _mouse_down := false
var _flash := 0.0
var _buzz_t := 0.0
## 外包美術（見 art/ch2/minigames/hold_endure/）；檔案不在就退回程式畫的版本
const ART := "res://art/ch2/minigames/hold_endure/ch2_hold_endure_"
const BG := "res://art/ch2/backgrounds/ch2_bg_treatment.jpg"
const PIP_ART := "res://art/ch2/minigames/sneak/ch2_sneak_pip_tiptoe_01.png"
const PIP_SEATED := "res://art/ch2/minigames/hold_endure/ch2_hold_endure_pip_seated.png"
var _tex_cache := {}


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast or questions.is_empty():
		queue_free()
		return
	_running = true
	await done
	queue_free()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_down = event.pressed


func _process(delta: float) -> void:
	if not _running:
		return
	_area.queue_redraw()
	if _flash > 0:
		_flash -= delta
		if _flash <= 0:
			_i += 1
			_hold = 0.0
			if _i >= questions.size():
				_running = false
				done.emit()
		return
	var need: float = questions[_i][1]
	var held := Input.is_action_pressed("interact") or _mouse_down
	_hold = clampf(_hold + (delta / need if held else -delta * 0.15), 0.0, 1.0)
	if held:
		_buzz_t -= delta
		if _buzz_t <= 0:
			_buzz_t = 0.35
			Tones.buzz(self, 0.25)
	if _hold >= 1.0:
		_flash = 0.8


## 讀一張外包圖；找不到就回傳 null（呼叫的地方會改用程式畫的版本）
func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _draw_area() -> void:
	var bg := _tex(BG)
	var chair := _tex(ART + "chair.png")
	var dove := _tex(ART + "dove.png")
	var button := _tex(ART + "good_button_normal.png")
	if bg and chair and dove and button:
		_draw_art(bg, chair, dove)
	else:
		_draw_procedural()


## 外包美術版：治療室背景、左邊的椅子（小布坐在上面，手腕扣著鐵環）、右邊穿白袍的和平鴿
func _draw_art(bg: Texture2D, chair: Texture2D, dove: Texture2D) -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_texture_rect(bg, Rect2(0, 0, 1280, 720), false)
	var held := Input.is_action_pressed("interact") or _mouse_down
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (8.0 if held else 0.0)
	# 牆上的海報：背景裡那塊布告板寫上標語
	a.draw_string(f, Vector2(625, 150), "乖孩子不痛！", HORIZONTAL_ALIGNMENT_CENTER, 230, 24, Color("#e05780"))
	# 外包的「小布坐在小椅子上」（圖裡已經有椅子）
	var seated := _tex(PIP_SEATED)
	if seated:
		var sz := seated.get_size() * 0.9
		a.draw_texture_rect(seated, Rect2(Vector2(352, 650) + shake - Vector2(sz.x * 0.5, sz.y), sz), false)
	else:
		_draw_chair_and_pip(chair, shake)
	# 和平鴿（白袍、聽診器、手上捧著愛心）
	a.draw_texture(dove, Vector2(720, 0))
	_draw_question_and_button(held)


## 沒有「坐姿小布」時：空椅子＋借用潛行小遊戲的小布
func _draw_chair_and_pip(chair: Texture2D, shake: Vector2) -> void:
	var a := _area
	a.draw_texture(chair, Vector2(190, 225))
	# 小布：有外包的小布圖（借用潛行小遊戲的那張）就坐在椅墊上，沒有就用程式畫的羊
	var pip_tex := _tex(PIP_ART)
	var pip := Vector2(352, 470) + shake
	if pip_tex:
		a.draw_texture_rect(pip_tex, Rect2(pip + Vector2(-80, -150), Vector2(160, 180)), false)
	else:
		Ch2Critter.draw_pip(a, pip, 1.0, 0)
	# 手腕上的鐵環
	var ring := _tex(ART + "metal_ring.png")
	for c in [pip + Vector2(-46, -30), pip + Vector2(38, -36)]:
		if ring:
			a.draw_texture_rect(ring, Rect2(c - Vector2(26, 15), Vector2(52, 30)), false)
		else:
			a.draw_arc(c, 9, 0, TAU, 16, Color("#5a5a5a"), 4)


func _draw_question_and_button(held: bool) -> void:
	var f: Font = GameState.font
	var a := _area
	# 題目（底下墊一塊半透明的白，背景太花會看不清楚）
	a.draw_rect(Rect2(0, 168, 1280, 80), Color(1, 1, 1, 0.72))
	if _i < questions.size():
		a.draw_string(f, Vector2(0, 208), "和平鴿：%s" % questions[_i][0], HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#333333"))
	a.draw_string(f, Vector2(0, 238), "第 %d 題 / %d" % [mini(_i + 1, questions.size()), questions.size()], HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#777777"))
	# 「我很乖」按鈕：按住時換成按下去的樣子；圖上已經印了「我很乖」，再補上「（按住）」
	var btn := Rect2(490, 570, 300, 75)
	var state := "pressed" if held else ("hover" if btn.has_point(a.get_local_mouse_position()) else "normal")
	var btex := _tex(ART + "good_button_%s.png" % state)
	if btex == null:
		btex = _tex(ART + "good_button_normal.png")
	a.draw_texture_rect(btex, btn, false)
	a.draw_string(f, Vector2(btn.position.x, btn.position.y + 47), "（按住）", HORIZONTAL_ALIGNMENT_RIGHT, btn.size.x - 22, 22, Color("#8a4b68"))
	# 進度條：空的底圖上，依進度裁一段滿的圖蓋上去
	var bar := Rect2(490, 652, 300, 24)
	var empty := _tex(ART + "hold_progress_00.png")
	var full := _tex(ART + "hold_progress_04.png")
	if empty and full:
		a.draw_texture_rect(empty, bar, false)
		if _hold > 0:
			a.draw_texture_rect_region(full, Rect2(bar.position, Vector2(bar.size.x * _hold, bar.size.y)),
				Rect2(0, 0, full.get_width() * _hold, full.get_height()))
	else:
		a.draw_rect(bar, Color("#ffe1ec"))
		a.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hold, bar.size.y)), Color("#ffb3c9"))
	a.draw_rect(Rect2(0, 680, 1280, 30), Color(1, 1, 1, 0.6))
	a.draw_string(f, Vector2(0, 701), GameState.hint("按住 E／空白鍵（手機：按住畫面）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#777777"))
	# 越撐越白
	var white := _hold * 0.5 + float(_i) / maxf(questions.size(), 1) * 0.3
	var wtex := _tex(ART + "whiteout.png")
	if wtex and _flash <= 0:
		a.draw_texture_rect(wtex, Rect2(0, 0, 1280, 720), false, Color(1, 1, 1, minf(1.0, white * 1.25)))
	else:
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, 1.0 if _flash > 0 else white))


## 沒有外包美術時的備用畫法（原本的佔位圖）
func _draw_procedural() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#f4f4f2"))
	# 白色磁磚
	for x in 20:
		for y in 12:
			a.draw_rect(Rect2(x * 64, y * 64, 64, 64), Color("#e2e2df"), false, 1)
	# 牆上的海報
	a.draw_rect(Rect2(80, 70, 240, 100), Color("#fff3f7"))
	a.draw_rect(Rect2(80, 70, 240, 100), Color("#f2a7c3"), false, 4)
	a.draw_string(f, Vector2(80, 132), "乖孩子不痛！", HORIZONTAL_ALIGNMENT_CENTER, 240, 28, Color("#e05780"))
	# 小小的椅子與小布
	var held := Input.is_action_pressed("interact") or _mouse_down
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * (8.0 if held else 0.0)
	a.draw_rect(Rect2(560, 450, 160, 20), Color("#9a9a9a"))
	a.draw_rect(Rect2(570, 470, 12, 70), Color("#8a8a8a"))
	a.draw_rect(Rect2(698, 470, 12, 70), Color("#8a8a8a"))
	Ch2Critter.draw_pip(a, Vector2(640, 450) + shake, 1.0, 0)
	for side in [-1, 1]:
		a.draw_arc(Vector2(640 + side * 44, 414) + shake, 9, 0, TAU, 16, Color("#5a5a5a"), 4)
	# 和平鴿（只看得到大衣和手套）
	a.draw_set_transform(Vector2(980, 760), 0.0, Vector2(3.2, 3.2))
	Ch2Critter.draw_dove(a, 1.0)
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _i < questions.size():
		a.draw_string(f, Vector2(0, 200), "和平鴿：%s" % questions[_i][0], HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#333333"))
	a.draw_string(f, Vector2(0, 236), "第 %d 題 / %d" % [mini(_i + 1, questions.size()), questions.size()], HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#999999"))
	var btn := Rect2(440, 560, 400, 90)
	a.draw_rect(btn, Color("#ffe1ec"))
	a.draw_rect(Rect2(btn.position, Vector2(btn.size.x * _hold, btn.size.y)), Color("#ffb3c9"))
	a.draw_rect(btn, Color("#e05780"), false, 4)
	a.draw_string(f, Vector2(btn.position.x, btn.position.y + 58), "我很乖（按住）", HORIZONTAL_ALIGNMENT_CENTER, btn.size.x, 34, Color("#8a4b68"))
	a.draw_string(f, Vector2(0, 690), GameState.hint("按住 E／空白鍵（手機：按住畫面）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#888888"))
	# 越撐越白
	var white := _hold * 0.5 + float(_i) / maxf(questions.size(), 1) * 0.3
	if _flash > 0:
		white = 1.0
	a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, white))
