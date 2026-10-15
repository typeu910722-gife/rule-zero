extends CanvasLayer
## 搶椅子（第二章小遊戲 6）：音樂盒一停就搶椅子（按 E／點畫面），最後一個沒椅子的人「去治療」。
## 每一輪少一張椅子，也少一個人。誰被淘汰由劇本決定；小布太慢的話會「差一點」，但還是坐得到。
## players：這一輪還在場的人（id 陣列）；out：這一輪被淘汰的 id；pip_sits：小布有沒有坐下。

signal done

const NAMES := {"pip": "小布", "xiaoji": "小棘", "tiaoma": "條碼", "gaga": "嘎嘎", "zhongzhong": "重重", "youyou": "鼬鼬"}
const SPECIES := {"pip": "sheep", "xiaoji": "hedgehog", "tiaoma": "zebra", "gaga": "crow", "zhongzhong": "hippo", "youyou": "weasel"}
const COLORS := {"pip": Color("#fffdf8"), "xiaoji": Color("#2f2f2f"), "tiaoma": Color("#f4f4f2"),
	"gaga": Color("#4a4a4a"), "zhongzhong": Color("#9c9c9c"), "youyou": Color("#b8b8b4")}
const MELODY := [523.3, 659.3, 784.0, 659.3, 587.3, 523.3, 587.3, 659.3]
const CENTER := Vector2(640, 400)

var players: Array = []
var out := ""
var pip_sits := true
var _phase := "music"     # music / stopped / result
var _t := 0.0
var _stop_at := 3.0
var _note_t := 0.0
var _note_i := 0
var _reacted := -1.0
var _running := false
var _area: Control


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast:
		queue_free()
		return
	_stop_at = randf_range(2.4, 4.2)
	_running = true
	await done
	queue_free()


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	match _phase:
		"music":
			# 音樂盒的速度不固定
			_note_t -= delta
			if _note_t <= 0:
				_note_t = randf_range(0.25, 0.5)
				Tones.play(self, MELODY[_note_i % MELODY.size()], -8.0)
				_note_i += 1
			if _t >= _stop_at:
				_phase = "stopped"
				_t = 0.0
		"stopped":
			if _t > 1.6:
				_phase = "result"
				_t = 0.0
		"result":
			if _t > 1.8:
				_running = false
				done.emit()
	_area.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if _running and _phase == "stopped" and _reacted < 0 and (event.is_action_pressed("interact") or tap):
		get_viewport().set_input_as_handled()
		_reacted = _t


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#dededb"))
	a.draw_string(f, Vector2(0, 50), "搶椅子！音樂停下來的時候，按 E／點畫面坐下", HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#c2558a"))
	var chairs := players.size() - 1
	var radius := 190.0
	for k in chairs:
		var p := CENTER + Vector2.from_angle(TAU * k / chairs) * 90
		a.draw_rect(Rect2(p - Vector2(22, 22), Vector2(44, 44)), Color("#a8a8a4"))
		a.draw_rect(Rect2(p - Vector2(22, 38), Vector2(44, 12)), Color("#8a8a86"))
	var spin := _t * 0.8 if _phase == "music" else 0.0
	for k in players.size():
		var id: String = players[k]
		var ang := TAU * k / players.size() + spin
		var p := CENTER + Vector2.from_angle(ang) * radius
		if _phase != "music" and id != out:
			p = CENTER + Vector2.from_angle(TAU * mini(k, chairs - 1) / maxi(chairs, 1)) * 90
		if _phase == "result" and id == out:
			p = Vector2(1120, 600)
		a.draw_set_transform(p, 0.0, Vector2(1.6, 1.6))
		Critter.draw(a, SPECIES[id], COLORS[id], 1.0, Vector2.ZERO, id != "tiaoma", false, id == "pip",
			{"stripes": 1, "quills": 1 if GameState.has("xiaoji_last_quill") else 0, "sewn": not GameState.has("reported_gaga"),
			"grey_patch": id == "pip" and GameState.has("c2_grey_patch")})
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		a.draw_string(f, p + Vector2(-60, 34), NAMES[id], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color("#444444"))
	# 和平鴿在圓圈中間打拍子
	a.draw_set_transform(Vector2(1000, 640), 0.0, Vector2(1.4, 1.4))
	Critter.draw_dove(a, 1.0)
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _phase == "music":
		a.draw_string(f, Vector2(0, 110), "♪ ～ ♪ ～", HORIZONTAL_ALIGNMENT_CENTER, 1280, 30, Color("#999999"))
	elif _phase == "stopped":
		a.draw_string(f, Vector2(0, 110), "音樂停了！", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color("#e05780"))
	else:
		if _reacted < 0 or _reacted > 0.8:
			a.draw_string(f, Vector2(0, 110), "差一點！", HORIZONTAL_ALIGNMENT_CENTER, 1280, 30, Color("#888888"))
		if out != "":
			a.draw_string(f, Vector2(0, 680), "%s，去治療室。" % NAMES[out], HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#444444"))
