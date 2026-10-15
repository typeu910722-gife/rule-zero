class_name ScissorsScene
extends CanvasLayer
## 修理室：用剪刀捅鎮長。連按 E／空白鍵，或連點畫面（手機）。
## 每捅一下畫面抖一下、噴出棉花；鎮長一張一張越來越破（art/scissors/mayor_1..7）。
## 他一直在掙扎、把自己「縫回去」：越接近越拚命（進度一直在退，停手退得更快，壞掉的地方也會縫回來），
## 所以要用力一直連點（大約每秒 6 下以上才捅得到底）。

signal done

const MAX_HITS := 70.0       # 進度條的長度（一下 +1）
const RESIST := 1.5          # 他一直在掙扎：每秒退這麼多
const RESIST_MORE := 3.5     # 越接近底，掙扎得越兇（×進度）
const DECAY := 3.0           # 停手後再多退這麼多
const DECAY_DELAY := 0.3     # 停手多久算「停手」
const STAGES := 7

var _area: Control
var _imgs: Array[Texture2D] = []
var _scissors: Texture2D
var _dmg := 0.0
var _idle := 0.0
var _stage := 0
var _state := "play"         # play / won
var _shake := 0.0
var _flash := 0.0
var _stage_flash := 0.0
var _jab := 0.0
var _jab_pos := Vector2(640, 380)
var _puffs: Array = []
var _hits := 0
var _mend := 0.0
var _t := 0.0


func _ready() -> void:
	layer = 51
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in STAGES:
		_imgs.append(load("res://art/scissors/mayor_%d.jpg" % (i + 1)))
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
	var pos := Vector2(-1, -1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif not (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		return
	get_viewport().set_input_as_handled()
	stab(pos)


## 捅一下（pos < 0 → 鍵盤，捅在胸口附近）
func stab(pos: Vector2 = Vector2(-1, -1)) -> void:
	if _state != "play":
		return
	if pos.x < 0:
		pos = Vector2(640, 360) + Vector2(randf_range(-90, 90), randf_range(-60, 90))
	_hits += 1
	_dmg = minf(_dmg + 1.0, MAX_HITS)
	_idle = 0.0
	_jab = 1.0
	_jab_pos = pos
	_shake = 1.0
	_flash = 0.35
	Sound.sfx("stab")
	for i in 7:
		_puffs.append({"p": pos, "v": Vector2(randf_range(-260, 260), randf_range(-320, 60)),
			"life": 1.0, "r": randf_range(6, 16)})
	var st := _stage_of(_dmg)
	if st > _stage:
		_stage = st
		_stage_flash = 1.0
		_shake = 1.8
		Sound.sfx("tear")
		Dialogue.fx.scare()
	if _dmg >= MAX_HITS:
		_win()


func _stage_of(d: float) -> int:
	return clampi(int(d / MAX_HITS * (STAGES - 1)), 0, STAGES - 1)


## 這一張圖的起點（進度條上的白線）
func _stage_floor() -> float:
	return ceilf(_stage * MAX_HITS / (STAGES - 1))


func progress() -> float:
	return _dmg / MAX_HITS


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(_shake - delta * 5.0, 0.0)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	_stage_flash = maxf(_stage_flash - delta * 1.6, 0.0)
	_jab = maxf(_jab - delta * 7.0, 0.0)
	_mend = maxf(_mend - delta * 1.5, 0.0)
	for p in _puffs:
		p.p += p.v * delta
		p.v.y += 420 * delta
		p.life -= delta * 0.9
	_puffs = _puffs.filter(func(p): return p.life > 0.0)
	if _state == "play":
		_idle += delta
		var drain := RESIST + RESIST_MORE * progress()
		if _idle > DECAY_DELAY:
			drain += DECAY
		_dmg = maxf(_dmg - drain * delta, 0.0)
		# 縫回去了：圖退回上一張
		var st := _stage_of(_dmg)
		if st < _stage:
			_stage = st
			_mend = 1.0
	_area.queue_redraw()


func _win() -> void:
	_state = "won"
	_stage = STAGES - 1
	_shake = 2.5
	_stage_flash = 1.0
	Sound.sfx("boom")
	Dialogue.fx.scare()
	await get_tree().create_timer(2.6).timeout
	done.emit()


func _draw() -> void:
	var c := _area
	c.draw_rect(Rect2(0, 0, 1280, 720), Color.BLACK)
	# 抖動：隨機位移＋一點放大；越破越抖
	var amp := 22.0 * _shake * (1.0 + _stage * 0.12)
	var off := Vector2(randf_range(-amp, amp), randf_range(-amp, amp) * 0.7)
	var zoom := 1.06 + 0.035 * _shake
	var size := Vector2(1280, 720) * zoom
	var rect := Rect2(Vector2(640, 360) - size / 2 + off, size)
	var tint := Color(1, 1 - 0.25 * _flash, 1 - 0.3 * _flash)
	c.draw_texture_rect(_imgs[_stage], rect, false, tint)
	# 換到下一張的瞬間：白一下
	if _stage_flash > 0.0:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0.95, 0.95, _stage_flash * 0.55))
	for pf in _puffs:
		c.draw_circle(pf.p + off, pf.r * pf.life + 3, Color(1, 0.98, 0.95, pf.life))
	# 剪刀：捅下去再拉回來
	if _state == "play" or _jab > 0.0:
		var sp := _jab_pos + Vector2(70, 70) * (1.0 - _jab) + off * 0.5
		c.draw_set_transform(sp, -0.7, Vector2.ONE * (1.0 - 0.15 * _jab))
		c.draw_texture_rect(_scissors, Rect2(-40, -200, 200, 200), false)
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# 暗角＋紅色邊框（越接近越紅）
	var p := progress()
	c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.6, 0.0, 0.08, 0.15 + 0.35 * p), false, 30)
	if _flash > 0.0:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.7, 0, 0.1, _flash * 0.35))
	if _state != "play":
		return
	var f: Font = GameState.font
	var key := "連點畫面" if DisplayServer.is_touchscreen_available() else "連點滑鼠／連按 E"
	var pulse := 1.0 + 0.06 * sin(_t * 12.0)
	var msg := "%s！不要停！" % key
	c.draw_string_outline(f, Vector2(0, 70), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, int(38 * pulse), 12, Color("#3a1426"))
	c.draw_string(f, Vector2(0, 70), msg, HORIZONTAL_ALIGNMENT_CENTER, 1280, int(38 * pulse), Color("#fff0f5"))
	# 進度條
	var bar := Rect2(340, 660, 600, 18)
	c.draw_rect(bar.grow(3), Color(0.1, 0.02, 0.05, 0.85))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * p, bar.size.y)), Color("#d23a5a"))
	var fl := _stage_floor() / MAX_HITS
	c.draw_line(Vector2(bar.position.x + bar.size.x * fl, bar.position.y - 4), Vector2(bar.position.x + bar.size.x * fl, bar.end.y + 4), Color(1, 1, 1, 0.6), 2)
	if _mend > 0.0 or _idle > DECAY_DELAY:
		var m2 := "……他在把自己縫回去！"
		c.draw_string_outline(f, Vector2(0, 640), m2, HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, 8, Color("#3a1426"))
		c.draw_string(f, Vector2(0, 640), m2, HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#ffd0dc"))
