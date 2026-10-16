extends CanvasLayer
## 畢業：重新塞棉花（第二章小遊戲 8）。和平鴿把針交到小布手上。
## ① 拉開縫線 ② 把黑色的棉花拿出來 ③ 塞進白色的棉花 ④ 縫好！（溫馨的手作風格）
## 每一步按 E／點畫面幾下完成。steps：這一段要做到第幾步（劇本會在中途停下來讓玩家選擇）。
## 拿出第一團黑色棉花的時候，畫面閃過一張孤兒院的照片——麻糬在門口揮手。

signal done

const STEP_NAMES := ["① 拉開縫線", "② 把黑色的棉花拿出來", "③ 塞進白色的棉花", "④ 縫好！"]
const TAPS := 4

var step := 0
var steps := 4
var target := "xiaoji"
var _taps := 0
var _flash := 0.0
var _running := false
var _area: Control

# ── 外包美術（res://art/ch2/minigames/restuff/）。圖不在就退回原本的程序繪圖 ──
const ART := "res://art/ch2/minigames/restuff/"
const BODY_POS := Vector2(125, 160)    # 打開肚子的小棘（800×500）左上角
const BELLY := BODY_POS + Vector2(440, 372)   # 肚子切口的中心
const PANEL_POS := Vector2(925, 150)   # 步驟板（330×500）
const NEEDLE_POS := Vector2(420, 495)

var _bg_tex: Texture2D
var _body_tex: Texture2D
var _black: Array = []
var _white: Array = []
var _needle_tex: Texture2D
var _panel_tex: Texture2D
var _memory_tex: Texture2D
var _glow: Control   # 小棘的身體：用著色器一步一步漂白
var _glow_mat: ShaderMaterial
## 黑色的布慢慢變成白色（保留一點明暗，看得出縫線和布紋）
const BLEACH := """shader_type canvas_item;
uniform float k = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 white = vec3(0.96, 0.955, 0.94) * (0.8 + 0.45 * l);
	COLOR = vec4(mix(c.rgb, min(white, vec3(1.0)), k), c.a);
}
"""
var _top: Control    # 棉花、針、步驟板、回憶照片：畫在亮光上面


static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	_bg_tex = _tex(ART + "ch2_restuff_tablecloth.png")
	_body_tex = _tex(ART + "ch2_restuff_xiaoji_open.png")
	for k in 3:
		var b := _tex(ART + "ch2_restuff_cotton_black_%02d.png" % (k + 1))
		if b:
			_black.append(b)
		var w := _tex(ART + "ch2_restuff_cotton_white_%02d.png" % (k + 1))
		if w:
			_white.append(w)
	_needle_tex = _tex(ART + "ch2_restuff_needle_thread.png")
	_panel_tex = _tex(ART + "ch2_restuff_steps_blank.png")
	_memory_tex = _tex(ART + "ch2_restuff_memory.png")
	if _body_tex:
		_glow = Control.new()
		_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sh := Shader.new()
		sh.code = BLEACH
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = sh
		_glow.material = _glow_mat
		_glow.draw.connect(_draw_glow)
		_area.add_child(_glow)
		_top = Control.new()
		_top.set_anchors_preset(Control.PRESET_FULL_RECT)
		_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_top.draw.connect(_draw_top)
		_area.add_child(_top)


func play() -> void:
	if GameState.fast or step >= steps:
		step = steps
		queue_free()
		return
	_running = true
	await done
	queue_free()


func _tap() -> void:
	_taps += 1
	Tones.play(self, [523.3, 659.3, 784.0, 1046.5][step], -10.0)
	if step == 1 and _taps == 1:
		_flash = 1.2
	if _taps >= TAPS:
		_taps = 0
		step += 1
		if step >= steps:
			_running = false
			await get_tree().create_timer(0.8).timeout
			done.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	_flash = maxf(0.0, _flash - delta)
	_area.queue_redraw()
	if _glow:
		_glow.queue_redraw()
		_top.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if _running and (event.is_action_pressed("interact") or tap):
		get_viewport().set_input_as_handled()
		_tap()


func _draw_area() -> void:
	if _body_tex:
		_draw_art()
	else:
		_draw_fallback()


## 小棘的身體（素材左下角黏著一小塊別的東西，切掉）
func _draw_body(a: Control, mod := Color.WHITE) -> void:
	a.draw_texture_rect_region(_body_tex, Rect2(BODY_POS, Vector2(800, 300)), Rect2(0, 0, 800, 300), mod)
	a.draw_texture_rect_region(_body_tex, Rect2(BODY_POS + Vector2(108, 300), Vector2(692, 200)), Rect2(108, 300, 692, 200), mod)


## 美術版第一層：格紋桌布
func _draw_art() -> void:
	var a := _area
	if _bg_tex:
		a.draw_texture(_bg_tex, Vector2.ZERO)
	else:
		a.draw_rect(Rect2(0, 0, 1280, 720), Color("#fbf3ea"))


## 第二層：打開肚子的小棘，一步一步變白（跟原本一樣：黑色慢慢變成 #f4f4f2）
func _draw_glow() -> void:
	_glow_mat.set_shader_parameter("k", clampf(step / 3.0, 0.0, 1.0) * 0.85)
	_draw_body(_glow)


func _puff(a: Control, list: Array, i: int, c: Vector2, size: float) -> void:
	var t: Texture2D = list[i % list.size()]
	a.draw_texture_rect(t, Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size)), false)


## 第三層：棉花、針線、步驟板、回憶照片
func _draw_top() -> void:
	var f: Font = GameState.font
	var a := _top
	a.draw_rect(Rect2(0, 22, 1280, 40), Color(1, 1, 1, 0.7))
	a.draw_string(f, Vector2(0, 50), "畢業手作時間！（按 E／點畫面）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#c2558a"))
	# 步驟板
	if _panel_tex:
		a.draw_texture(_panel_tex, PANEL_POS)
	else:
		a.draw_rect(Rect2(PANEL_POS, Vector2(330, 500)), Color("#f4c6d3"))
	for k in STEP_NAMES.size():
		var col := Color("#e05780") if k == step else (Color("#5aa86a") if k < step else Color("#9a8f94"))
		a.draw_string(f, PANEL_POS + Vector2(26, 92 + k * 110), STEP_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, 290, 24, col)
		if k == step:
			# 現在這一步：按了幾下
			for t in TAPS:
				var dot := PANEL_POS + Vector2(44 + t * 26, 116 + k * 110)
				a.draw_circle(dot, 7, Color("#e05780") if t < _taps else Color(1, 1, 1, 0.8))
	var has_b := not _black.is_empty()
	var has_w := not _white.is_empty()
	if step >= 1 and step < 3 and has_b:
		# 拉開的肚子：黑色的棉花鼓出來
		for k in 5 - step * 2:
			_puff(a, _black, k, BELLY + Vector2(-50 + k * 25, -18 + (k % 2) * 22), 70)
	if step == 2 and has_w:
		# 塞白色的棉花：按一下塞一團
		for k in _taps:
			_puff(a, _white, k, BELLY + Vector2(-46 + k * 30, 10 - (k % 2) * 26), 72)
	if step >= 3 and has_w:
		for k in 5:
			_puff(a, _white, k, BELLY + Vector2(-56 + k * 28, -6 + (k % 2) * 24), 74)
	# 桌上：拿出來的黑色棉花堆在左下角
	if step >= 1 and has_b:
		for k in mini(step, 2) * 3:
			_puff(a, _black, k + 1, Vector2(70 + (k % 3) * 62, 640 - (k / 3) * 46 - (k % 2) * 14), 84)
	# 等著塞進去的白色棉花（步驟板下面）
	if step >= 2 and step < 3 and has_w:
		for k in TAPS - _taps:
			_puff(a, _white, k + 2, Vector2(990 + k * 58, 676), 76)
	# 針線（縫好之前一直在肚子旁邊）
	if _needle_tex:
		a.draw_texture(_needle_tex, NEEDLE_POS)
	if _flash > 0:
		# 孤兒院的照片：麻糬在門口揮手
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(0.9, 0.88, 0.84, _flash * 0.8))
		if _memory_tex:
			var al := clampf(_flash, 0.0, 1.0)
			a.draw_texture(_memory_tex, Vector2(340, 170), Color(1, 1, 1, al))
		else:
			a.draw_rect(Rect2(440, 160, 400, 300), Color(0.75, 0.72, 0.66, _flash))


## 沒有美術素材時的程序繪圖（原本的佔位畫面）
func _draw_fallback() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#fbf3ea"))
	# 手作風格的格紋桌布
	for k in 16:
		a.draw_line(Vector2(k * 80, 0), Vector2(k * 80, 720), Color(0.95, 0.75, 0.8, 0.25), 18)
		a.draw_line(Vector2(0, k * 80), Vector2(1280, k * 80), Color(0.95, 0.75, 0.8, 0.25), 18)
	a.draw_string(f, Vector2(0, 50), "畢業手作時間！（按 E／點畫面）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#c2558a"))
	for k in STEP_NAMES.size():
		var col := Color("#e05780") if k == step else (Color("#7ccf8a") if k < step else Color("#bbbbbb"))
		a.draw_string(f, Vector2(60, 140 + k * 46), STEP_NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)
	var body := Vector2(700, 480)
	a.draw_rect(Rect2(body + Vector2(-260, 30), Vector2(520, 40)), Color("#f7f7f5"))
	a.draw_set_transform(body, 0.0, Vector2(5.0, 5.0))
	var hog_q := 1 if GameState.has("xiaoji_last_quill") else 0
	var c := Color("#2f2f2f").lerp(Color("#f4f4f2"), clampf(step / 3.0, 0.0, 1.0))
	Critter.draw(a, "hedgehog", c, 1.0, Vector2.ZERO, true, step >= 3, false, {"quills": hog_q})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if step >= 1 and step < 3:
		# 拉開的肚子
		Critter.ellipse(a, body + Vector2(0, -70), Vector2(60, 30), Color("#3a3030"))
		for k in 5 - step * 2:
			a.draw_circle(body + Vector2(-40 + k * 20, -70), 12, Color("#1a1a1a"))
	if step >= 2:
		for k in 4:
			a.draw_circle(Vector2(1080 + (k % 2) * 30, 200 + k * 26), 16, Color("#ffffff"))
	if step >= 1:
		for k in mini(step, 2) * 3:
			a.draw_circle(Vector2(320 + k * 26, 600), 14, Color("#1d1d1d"))
	# 針
	a.draw_line(Vector2(980, 560), Vector2(1120, 470), Color("#bdbdbd"), 4)
	a.draw_circle(Vector2(1120, 470), 4, Color("#888888"))
	if _flash > 0:
		# 孤兒院的照片：麻糬在門口揮手
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(0.9, 0.88, 0.84, _flash * 0.8))
		a.draw_rect(Rect2(440, 160, 400, 300), Color(0.75, 0.72, 0.66, _flash))
		a.draw_rect(Rect2(600, 220, 90, 200), Color(0.55, 0.5, 0.45, _flash))
		a.draw_set_transform(Vector2(560, 420), 0.0, Vector2(2.2, 2.2))
		Critter.draw(a, "hamster", Color(0.98, 0.95, 0.9, _flash), 1.0, Vector2.ZERO, true)
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
