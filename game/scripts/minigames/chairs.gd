extends CanvasLayer
## 搶椅子（第二章小遊戲 6）：音樂盒一停就搶椅子（按 E／點畫面），最後一個沒椅子的人「去治療」。
## 每一輪少一張椅子，也少一個人。誰被淘汰由劇本決定；小布太慢的話會「差一點」，但還是坐得到。
## players：這一輪還在場的人（id 陣列）；out：這一輪被淘汰的 id；pip_sits：小布有沒有坐下。

signal done

const NAMES := {"pip": "小布", "xiaoji": "小棘", "tiaoma": "條碼", "gaga": "嘎嘎", "zhongzhong": "重重", "youyou": "鼬鼬"}
const SPECIES := {"pip": "sheep", "xiaoji": "hedgehog", "tiaoma": "zebra", "gaga": "crow", "zhongzhong": "hippo", "youyou": "weasel"}
## 走路圖是「走路動畫 4 格」而不是「四個方向」的角色
const WALK_CYCLE := ["xiaoji", "zhongzhong"]
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

# ── 外包美術（res://art/ch2/minigames/chairs/）。圖不在就退回原本的程序繪圖 ──
const ART := "res://art/ch2/minigames/chairs/"
const SP := "res://art/ch2/characters/sprites/ch2_"
## 搶椅子在點名廣場玩（不是教室）
const BG := "res://art/ch2/backgrounds/ch2_bg_graduation.jpg"
const RING := Vector2(600, 455)        # 美術版的圓圈中心
const WALK_R := Vector2(340, 165)      # 大家繞圈走的橢圓
const CHAIR_R := Vector2(235, 112)     # 椅子排的橢圓
const CHAIR_SCALE := 0.5
const CHAIR_SEAT := Vector2(100, 135)  # 椅墊在椅子圖上的位置
const KID_SCALE := 1.6                 # 走路圖 80×80（重重 104×104）
const DOVE_POS := Vector2(1185, 706)   # 和平鴿腳底
const OUT_POS := Vector2(1050, 650)    # 被淘汰的人走到和平鴿旁邊

var _bg_tex: Texture2D
var _chair_tex: Texture2D
var _dove_tex: Array = []
var _sticker_top: Texture2D
var _sticker_bottom: Texture2D
var _walk: Dictionary = {}     # id → [正面, 朝右, 背面, 朝左]
var _still: Dictionary = {}    # id → 只有一張正面（小棘剪過刺、條碼、拆了線的嘎嘎）


static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	_bg_tex = _tex(BG)
	_chair_tex = _tex(ART + "ch2_chairs_chair.png")
	for k in 2:
		var t := _tex(ART + "ch2_chairs_dove_musicbox_%02d.png" % (k + 1))
		if t:
			_dove_tex.append(t)
	_sticker_top = _tex(ART + "ch2_chairs_sticker_01_blank.png")
	_sticker_bottom = _tex(ART + "ch2_chairs_sticker_02_blank.png")
	for id in ["pip", "gaga", "zhongzhong", "youyou"]:
		var frames: Array = []
		for k in 4:
			var t := _tex(ART + "ch2_chairs_%s_walk_%02d.png" % [id, k + 1])
			if t == null:
				frames = []
				break
			frames.append(t)
		if not frames.is_empty():
			_walk[id] = frames
	# 小棘這時候已經被剪過刺了：剪光／留一根刺的走路圖（4 格走路動畫）
	var hog_state := "onequill" if GameState.has("xiaoji_last_quill") else "bald"
	var hog_frames: Array = []
	for k in 4:
		var t := _tex(ART + "ch2_chairs_xiaoji_%s_walk_%02d.png" % [hog_state, k + 1])
		if t:
			hog_frames.append(t)
	if hog_frames.size() == 4:
		_walk["xiaoji"] = hog_frames
	else:
		var hog := _tex(SP + "xiaoji_sprite_%s_sheet.png" % hog_state)
		if hog:
			_still["xiaoji"] = hog
	# 條碼沒有走路圖：用只剩一條斑紋的站姿（跟原本畫的 stripes: 1 一樣）
	var zebra := _tex(SP + "tiaoma_sprite_s1_sheet.png")
	if zebra:
		_still["tiaoma"] = zebra
	# 嘎嘎被舉報過，嘴上的線拆了
	if GameState.has("reported_gaga"):
		_walk.erase("gaga")
		var crow := _tex(SP + "gaga_sprite_unsewn_sheet.png")
		if crow:
			_still["gaga"] = crow


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
	if _chair_tex:
		_draw_art()
	else:
		_draw_fallback()


func _chair_pos(k: int, chairs: int) -> Vector2:
	if chairs <= 1:
		return RING
	return RING + Vector2.from_angle(TAU * k / maxi(chairs, 1) - PI / 2) * CHAIR_R


## 美術版：點名廣場上排一圈椅子，大家繞著走，和平鴿抱著音樂盒站在旁邊
func _draw_art() -> void:
	var f: Font = GameState.font
	var a := _area
	if _bg_tex:
		a.draw_texture(_bg_tex, Vector2.ZERO)
		# 背景很熱鬧，蓋一層霧，讓椅子和大家看得清楚
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(0.93, 0.92, 0.9, 0.62))
	else:
		a.draw_rect(Rect2(0, 0, 1280, 720), Color("#dededb"))
	a.draw_rect(Rect2(0, 18, 1280, 46), Color(1, 1, 1, 0.7))
	a.draw_string(f, Vector2(0, 50), GameState.hint("搶椅子！音樂停下來的時候，按 E／點畫面坐下"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#c2558a"))
	var chairs := players.size() - 1
	var chair_sz := _chair_tex.get_size() * CHAIR_SCALE
	for k in chairs:
		a.draw_texture_rect(_chair_tex, Rect2(_chair_pos(k, chairs) - CHAIR_SEAT * CHAIR_SCALE, chair_sz), false)
	# 每個人的位置（腳底）跟面向；之後照 y 排序，前面的蓋住後面的
	var spin := _t * 0.8 if _phase == "music" else 0.0
	var kids: Array = []
	var seat := 0   # 美術版：照順序一人一張椅子（沒被淘汰的人）
	for k in players.size():
		var id: String = players[k]
		var ang := TAU * k / players.size() + spin
		var p := RING + Vector2.from_angle(ang) * WALK_R
		var vel := Vector2(-sin(ang) * WALK_R.x, cos(ang) * WALK_R.y)
		var dir := 0
		if _phase == "music":
			dir = (1 if vel.x > 0 else 3) if absf(vel.x) > absf(vel.y) else (0 if vel.y > 0 else 2)
			p.y -= absf(sin(_t * 9.0 + k)) * 5.0
		var seated := false
		if _phase != "music" and id != out:
			if seat < chairs:
				p = _chair_pos(seat, chairs) + Vector2(0, 14)
			else:
				# 椅子不夠：站在最後一張椅子旁邊
				p = _chair_pos(maxi(chairs - 1, 0), chairs) + Vector2(80 * (seat - chairs + 1), 40)
			seat += 1
			seated = true
		if _phase == "result" and id == out:
			p = OUT_POS
		kids.append([p, id, dir, seated])
	kids.sort_custom(func(x, y): return x[0].y < y[0].y)
	for kid in kids:
		_draw_kid(a, kid[0], kid[1], kid[2])
	# 名字最後畫，才不會被別人擋住
	for kid in kids:
		a.draw_string(f, kid[0] + Vector2(-60, 22), NAMES[kid[1]], HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color("#444444"))
	# 和平鴿抱著音樂盒，轉發條打拍子
	if not _dove_tex.is_empty():
		var di := (int(_t * 2.5) % _dove_tex.size()) if _phase == "music" else 0
		var dt: Texture2D = _dove_tex[di]
		var ds := 0.78
		a.draw_texture_rect(dt, Rect2(DOVE_POS - Vector2(dt.get_width() * 0.5, dt.get_height() - 6) * ds, dt.get_size() * ds), false)
	else:
		a.draw_set_transform(Vector2(1000, 640), 0.0, Vector2(1.4, 1.4))
		Critter.draw_dove(a, 1.0)
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _phase == "music":
		_sticker(a, _sticker_top, Vector2(640, 108), "♪ ～ ♪ ～", 30, Color("#999999"))
	elif _phase == "stopped":
		_sticker(a, _sticker_top, Vector2(640, 108), "音樂停了！", 34, Color("#e05780"))
	else:
		if _reacted < 0 or _reacted > 0.8:
			_sticker(a, _sticker_top, Vector2(640, 108), "差一點！", 30, Color("#888888"))
		if out != "":
			_sticker(a, _sticker_bottom, Vector2(640, 672), "%s，去治療室。" % NAMES[out], 26, Color("#444444"))


## 一個人：有走路圖用走路圖（四個方向），沒有就用站姿，再沒有就程序繪圖
func _draw_kid(a: Control, p: Vector2, id: String, dir: int) -> void:
	if _walk.has(id):
		# 小棘、重重的 4 格是走路動畫；其他人的 4 格是四個方向
		var i := (int(_t * 6.0) % 4) if id in WALK_CYCLE else dir
		var t: Texture2D = _walk[id][i]
		# 腳底大約在圖的 95%
		var src := Rect2(Vector2.ZERO, t.get_size())
		var sz := src.size * KID_SCALE
		a.draw_texture_rect_region(t, Rect2(p - Vector2(sz.x * 0.5, sz.y - 4 * KID_SCALE), sz), src)
	elif _still.has(id):
		var t: Texture2D = _still[id]
		var s := 0.8   # 160×160 的站姿，腳底在 (80, 152)
		a.draw_texture_rect(t, Rect2(p - Vector2(80, 152) * s, t.get_size() * s), false)
	else:
		a.draw_set_transform(p + Vector2(0, -26), 0.0, Vector2(1.6, 1.6))
		Critter.draw(a, SPECIES[id], COLORS[id], 1.0, Vector2.ZERO, id != "tiaoma", false, id == "pip",
			{"stripes": 1, "quills": 1 if GameState.has("xiaoji_last_quill") else 0, "sewn": not GameState.has("reported_gaga"),
			"grey_patch": id == "pip" and GameState.has("c2_grey_patch")})
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 貼紙（空白的那張）＋遊戲裡的字
func _sticker(a: Control, tex: Texture2D, center: Vector2, text: String, size: int, col: Color) -> void:
	var f: Font = GameState.font
	if tex:
		a.draw_texture(tex, center - tex.get_size() * 0.5)
	a.draw_string(f, Vector2(center.x - 640, center.y + size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, 1280, size, col)


## 沒有美術素材時的程序繪圖（原本的佔位畫面）
func _draw_fallback() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#dededb"))
	a.draw_string(f, Vector2(0, 50), GameState.hint("搶椅子！音樂停下來的時候，按 E／點畫面坐下"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#c2558a"))
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
