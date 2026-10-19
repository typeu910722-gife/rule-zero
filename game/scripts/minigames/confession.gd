extends CanvasLayer
## 反省會（第二章小遊戲 4）：小棘被綁在講台中央。小布要把粉紅色的罪狀卡一張一張翻開念出來。
## 每念一張，全班一起喊「壞孩子！」，小棘的顏色少一點。
## cards：這一段要念的卡片。第 5～8 張（孤兒院大人說過的話）由劇本決定要不要念。
## 操作：點畫面／按 E 翻開下一張。時間到還沒念完，和平鴿會親自念（不影響結果，只是比較痛）。

signal done

const TIME := 14.0

var cards: Array = []
## 小棘剩下的顏色（0..1），由外部傳入、結束時讀回
var color := 1.0
var _i := 0
var _t := TIME
var _shout := 0.0
var _running := false
var _area: Control
## 外包美術（見 art/ch2/minigames/confession/）；檔案不在就退回程式畫的版本
const ART := "res://art/ch2/minigames/confession/ch2_confession_"
const BG := "res://art/ch2/backgrounds/ch2_bg_classroom.jpg"
var _tex_cache := {}


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast:
		color = maxf(0.0, color - 0.12 * cards.size())
		queue_free()
		return
	_running = true
	await done
	queue_free()


func _read() -> void:
	if _i >= cards.size():
		return
	_i += 1
	color = maxf(0.0, color - 0.12)
	_shout = 1.0
	Tones.play(self, 330.0, -8.0)
	if _i >= cards.size():
		_finish.call_deferred()


func _finish() -> void:
	await get_tree().create_timer(1.2).timeout
	_running = false
	done.emit()


func _process(delta: float) -> void:
	if not _running:
		return
	_t -= delta
	_shout = maxf(0.0, _shout - delta * 1.5)
	if _t <= 0 and _i < cards.size():
		# 時間到：和平鴿親自念
		_t = 0.6
		_read()
	_area.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if _running and (event.is_action_pressed("interact") or tap):
		get_viewport().set_input_as_handled()
		_read()


## 讀一張外包圖；找不到就回傳 null（呼叫的地方會改用程式畫的版本）
func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _draw_area() -> void:
	var bg := _tex(BG)
	# 小棘的顏色分 5 段（fade_01 最深、fade_05 最淡），每念一張卡淡一段
	var step := clampi(roundi((1.0 - color) / 0.12), 0, 4) + 1
	var hog := _tex(ART + "xiaoji_fade_%02d.png" % step)
	var front := _tex(ART + "card_front.png")
	var back := _tex(ART + "card_back.png")
	if bg and hog and front and back:
		_draw_art(bg, hog, front, back)
	else:
		_draw_procedural()


## 外包美術版：教室講台中央綁在椅子上的小棘、右邊翻開的卡、左邊還沒念的卡堆、全班的喊聲
func _draw_art(bg: Texture2D, hog: Texture2D, front: Texture2D, back: Texture2D) -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_texture_rect(bg, Rect2(0, 0, 1280, 720), false)
	# 標題（底下墊一塊半透明的白，背景太花會看不清楚）
	a.draw_rect(Rect2(0, 18, 1280, 50), Color(1, 1, 1, 0.75))
	a.draw_string(f, Vector2(0, 52), GameState.hint("反省會：把卡片翻開，大聲念出來！（點畫面／按 E）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#c2558a"))
	var frac := clampf(_t / TIME, 0.0, 1.0)
	a.draw_rect(Rect2(440, 78, 400, 10), Color(1, 1, 1, 0.6))
	a.draw_rect(Rect2(440, 78, 400 * frac, 10), Color("#e05780"))
	# 講台中央的小棘：被綁在椅子上，顏色越來越淡
	a.draw_texture(hog, Vector2(390, 120))
	# 還沒念的卡（背面朝上疊在左邊）
	var left := cards.size() - _i
	for k in left:
		a.draw_texture_rect(back, Rect2(60 + k * 8, 120 + k * 8, 160, 215), false)
	a.draw_rect(Rect2(52, 350 + left * 8, 190, 34), Color(1, 1, 1, 0.75))
	a.draw_string(f, Vector2(60, 374 + left * 8), "還有 %d 張" % left, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#8a4b68"))
	# 貼紙：念得越快，星星越多！
	var sticker := _tex(ART + "sticker_01_blank.png")
	var srect := Rect2(30, 430, 300, 56)
	if sticker:
		a.draw_texture_rect(sticker, srect, false)
	a.draw_string(f, Vector2(srect.position.x, srect.position.y + 36), "念得越快，星星越多！", HORIZONTAL_ALIGNMENT_CENTER, srect.size.x, 20, Color("#8a4b68"))
	# 翻開的卡：剛念的那一下先翻面，再看到正面的字
	var card := Rect2(900, 140, 304, 408)
	if _i > 0:
		var flip := _tex(ART + "card_flip.png")
		if flip and _shout > 0.85:
			a.draw_texture_rect(flip, Rect2(card.position.x + card.size.x / 2 - 20, card.position.y, 40, card.size.y), false)
		else:
			a.draw_texture_rect(front, card, false)
			a.draw_multiline_string(f, card.position + Vector2(32, 150), cards[_i - 1], HORIZONTAL_ALIGNMENT_CENTER,
				card.size.x - 64, 32, -1, Color("#5a2a3a"))
	# 全班的喊聲：壞孩子！（三種字樣輪流，喊完慢慢淡掉）
	if _shout > 0:
		for k in 6:
			var p := Vector2(140 + k * 200, 615 + (k % 2) * 50)
			var chant := _tex(ART + "chant_%02d.png" % (k % 3 + 1))
			if chant:
				# 圖的字只在左邊那一段，只取那一段放大
				var src := Rect2(0, 0, 190, 85)
				var size := src.size * (1.0 + 0.25 * _shout)
				# 圖上的字是淺灰，壓暗一點才讀得到
				a.draw_texture_rect_region(chant, Rect2(p - size / 2, size), src, Color(0.5, 0.5, 0.5, _shout))
			else:
				a.draw_string(f, p - Vector2(100, 0), "壞孩子！", HORIZONTAL_ALIGNMENT_CENTER, 200, 30, Color(0.3, 0.3, 0.3, _shout))


## 沒有外包美術時的備用畫法（原本的佔位圖）
func _draw_procedural() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#e3e3e0"))
	a.draw_string(f, Vector2(0, 50), GameState.hint("反省會：把卡片翻開，大聲念出來！（點畫面／按 E）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color("#c2558a"))
	a.draw_string(f, Vector2(0, 84), "念得越快，星星越多！", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#888888"))
	# 講台中央的小棘：被綁在椅子上，顏色越來越淡
	var hog := Vector2(640, 420)
	a.draw_rect(Rect2(hog + Vector2(-90, 0), Vector2(180, 24)), Color("#9a9a9a"))
	a.draw_set_transform(hog, 0.0, Vector2(4.0, 4.0))
	var c := Color("#2f2f2f").lerp(Color("#d6d6d2"), 1.0 - color)
	Critter.draw(a, "hedgehog", c, 1.0, Vector2.ZERO, _i < 5, false, false, {"quills": 5})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 3:
		a.draw_line(hog + Vector2(-80, -60 + k * 22), hog + Vector2(80, -60 + k * 22), Color("#7a6a5a"), 4)
	# 全班的喊聲
	if _shout > 0:
		for k in 6:
			var p := Vector2(120 + k * 210, 640 + (k % 2) * 30)
			a.draw_string(f, p - Vector2(100, 0), "壞孩子！", HORIZONTAL_ALIGNMENT_CENTER, 200, 30, Color(0.3, 0.3, 0.3, _shout))
	# 卡片
	if _i > 0:
		var card := Rect2(840, 140, 380, 160)
		a.draw_rect(card, Color("#ffe1ec"))
		a.draw_rect(card, Color("#e05780"), false, 4)
		a.draw_string(f, card.position + Vector2(20, 90), cards[_i - 1], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 40, 26, Color("#5a2a3a"))
	for k in cards.size() - _i:
		a.draw_rect(Rect2(60 + k * 8, 160 + k * 8, 220, 120), Color("#ffd1dc"))
		a.draw_rect(Rect2(60 + k * 8, 160 + k * 8, 220, 120), Color("#f2a7c3"), false, 2)
	a.draw_string(f, Vector2(60, 330 + (cards.size() - _i) * 8), "還有 %d 張" % (cards.size() - _i), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#8a4b68"))
	var frac := clampf(_t / TIME, 0.0, 1.0)
	a.draw_rect(Rect2(440, 110, 400 * frac, 10), Color("#e05780"))
