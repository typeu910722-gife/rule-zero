class_name ScissorsScene
extends CanvasLayer
## 修理室：鎮長撲過來。連按 E（手機：連點畫面）用剪刀剪斷他胸前的縫線。
## 在他碰到你之前剪斷全部（7 針）就成功；來不及 → 被抓住，再試一次（每次多一點時間）。

signal done

const STITCHES := 7
const BASE_TIME := 4.2

var _area: Control
var _mayor: Texture2D
var _scissors: Texture2D
var _cut := 0
var _t := 0.0
var _limit := BASE_TIME
var _state := "play"     # play / caught / won
var _flash := 0.0
var _jab := 0.0
var _puffs: Array = []
var _tries := 0


func _ready() -> void:
	layer = 51
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mayor = load("res://art/item_stand_mayor_broken.png")
	_scissors = load("res://art/item_scissors.png")
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw)
	add_child(_area)


func play() -> void:
	if GameState.fast:
		done.emit()
		return
	await done


func _unhandled_input(event: InputEvent) -> void:
	if _state != "play":
		return
	var hit: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or \
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not hit:
		return
	get_viewport().set_input_as_handled()
	_cut += 1
	_jab = 1.0
	Sound.sfx("interact")
	for i in 6:
		_puffs.append({"p": _stitch_pos(_cut - 1), "v": Vector2(randf_range(-160, 160), randf_range(-220, 40)), "life": 1.0})
	if _cut >= STITCHES:
		_win()


func _process(delta: float) -> void:
	_jab = maxf(_jab - delta * 6.0, 0.0)
	_flash = maxf(_flash - delta * 2.5, 0.0)
	for p in _puffs:
		p.p += p.v * delta
		p.v.y += 260 * delta
		p.life -= delta * 0.8
	_puffs = _puffs.filter(func(p): return p.life > 0.0)
	if _state == "play":
		_t += delta
		if _t >= _limit:
			_caught()
	_area.queue_redraw()


## 鎮長越來越近（0 → 1）
func _near() -> float:
	return clampf(_t / _limit, 0.0, 1.0) if _state != "won" else 0.85


func _mayor_rect() -> Rect2:
	var k := lerpf(0.75, 1.7, ease(_near(), 1.6))
	var size := Vector2(391, 560) * k
	return Rect2(Vector2(640 - size.x / 2, 720 - size.y * 0.92 + (1.0 - k) * 40), size)


func _stitch_pos(i: int) -> Vector2:
	var r := _mayor_rect()
	var top := r.position + Vector2(r.size.x * 0.5, r.size.y * 0.56)
	return top + Vector2(sin(i * 1.3) * 6.0, i * r.size.y * 0.036)


func _caught() -> void:
	_state = "caught"
	_tries += 1
	_flash = 1.0
	Dialogue.fx.scare()
	await get_tree().create_timer(1.4).timeout
	_cut = 0
	_t = 0.0
	_limit = BASE_TIME + _tries * 1.2
	_state = "play"


func _win() -> void:
	_state = "won"
	Sound.sfx("creepy")
	Dialogue.fx.scare()
	await get_tree().create_timer(1.2).timeout
	done.emit()


func _draw() -> void:
	var c := _area
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.03, 0.06, 0.55 + 0.3 * _near()))
	var r := _mayor_rect()
	var shake := Vector2(randf_range(-4, 4), randf_range(-3, 3)) * _near() if _state == "play" else Vector2.ZERO
	c.draw_texture_rect(_mayor, Rect2(r.position + shake, r.size), false, Color(1, 0.9, 0.9))
	# 胸前的縫線：剪斷的地方裂開、冒出棉花
	for i in STITCHES:
		var p := _stitch_pos(i) + shake
		var w := r.size.x * 0.06
		if i < _cut:
			c.draw_circle(p, w * 0.9, Color(1, 1, 1, 0.95))
			c.draw_circle(p + Vector2(w * 0.5, -w * 0.3), w * 0.6, Color(1, 1, 1, 0.9))
		else:
			c.draw_line(p - Vector2(w, w * 0.4), p + Vector2(w, w * 0.4), Color("#3a1426"), 4)
			c.draw_line(p - Vector2(w, -w * 0.4), p + Vector2(w, -w * 0.4), Color("#3a1426"), 4)
	for pf in _puffs:
		c.draw_circle(pf.p, 10 * pf.life + 4, Color(1, 1, 1, pf.life))
	# 剪刀（在右下角，按一下就往前刺）
	var sp := Vector2(900, 520).lerp(_stitch_pos(mini(_cut, STITCHES - 1)) + Vector2(40, -40), _jab * 0.8)
	c.draw_set_transform(sp, -0.6, Vector2.ONE)
	c.draw_texture_rect(_scissors, Rect2(-120, -120, 240, 240), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var f: Font = GameState.font
	var key := "連點畫面" if DisplayServer.is_touchscreen_available() else "連按 E"
	var msg := ""
	match _state:
		"play": msg = "%s：剪斷縫線！（%d / %d）" % [key, _cut, STITCHES]
		"caught": msg = "……被抓住了。再一次！"
	if msg != "":
		c.draw_string_outline(f, Vector2(0, 80), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, 40, 12, Color("#3a1426"))
		c.draw_string(f, Vector2(0, 80), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, 40, Color("#fff0f5"))
	# 時間：越來越紅的邊框
	if _state == "play":
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.9, 0.1, 0.2, 0.35 * _near()), false, 24)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.6, 0, 0.1, _flash * 0.7))
