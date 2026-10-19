extends CanvasLayer
## 洗白白（第二章小遊戲 2）：洗衣房裡，用刷子把條碼身上的斑紋刷乾淨。
## 刷越乾淨星星越多。刷的時候條碼小聲說話，越刷越聽不清楚。
## 隱藏選擇：斑紋還剩一點點（5%～35%）的時候按「完成」→ 條碼保住一段記憶（操行 -10）。
## 操作：滑鼠／手指在斑紋上來回拖；鍵盤按住 E／空白鍵自動刷；「完成」：點按鈕或按 Tab。

signal done

const POS := Vector2(640, 400)
const SCALE := 6.0
const STRIPES := 2
const KEEP_MIN := 0.05
const KEEP_MAX := 0.35
## 斑紋剩下多少時，條碼說什麼
const LINES := [
	[1.0, "欸你們知道嗎，三班的那個誰，他媽媽在夜市賣……"],
	[0.7, "欸你們知道嗎……那個誰……大家都不要跟他……"],
	[0.4, "欸你們……群組……是我開的……是我……"],
	[0.15, "……我其實……"],
	[0.0, "今天的天氣，很好。"],
]
const DONE_BTN := Rect2(1040, 600, 200, 70)
## 外包美術（game/art/ch2/minigames/scrub/）；檔案不在時退回程式畫的版本
const ART := "res://art/ch2/minigames/scrub/ch2_scrub_%s.png"
const BG := "res://art/ch2/backgrounds/ch2_bg_laundry.jpg"
## 美術版：條碼圖層（700×425，斑紋 stripe_01..03 各自一層）畫在這裡
const TIAOMA_ORIGIN := Vector2(290, 112)
## 美術版每條斑紋分上下（條碼躺著，就是左右兩側）兩半
## 洗白白的時候條碼身上剩 2 條斑紋（劇本 2-1）：外包的 3 條斑紋圖層只用前 2 條
const ART_STRIPES := 2
## 每條斑紋在圖層裡的位置：x 中心、半寬（圖層像素）；上下兩半以身體中線切開
const ART_STRIPE_X := [Vector2(357, 40), Vector2(403, 32), Vector2(470, 32)]
const ART_STRIPE_Y := [87.0, 198.0, 309.0]
## 美術版的「完成」按鈕（300×75）
const DONE_BTN_ART := Rect2(960, 612, 300, 75)

## 每條斑紋（左右各一）剩下的黑色 0..1
var stripes: Array = []
var kept_color := false
var _area: Control
var _running := false
var _brush := Vector2(-100, -100)
var _last_brush := Vector2.ZERO
var _mouse_down := false
var _popups: Array = []
var _bubbles: Array = []
var _holes: Array = []
var _too_dirty_t := 0.0
var _auto := 0
var _tex := {}               # 名稱 → Texture2D（缺檔就沒有這個 key）
var _panel: StyleBoxTexture  # 空白貼紙（九宮格）


## 安全載入：檔案不存在就回傳 null，讓呼叫的地方退回程式畫的版本
static func tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _load_art() -> void:
	var names := ["tiaoma_base", "washboard", "brush", "peg", "star_bright", "star_dark",
		"done_button_normal", "done_button_hover", "done_button_pressed", "sticker_01_blank", "sticker_02",
		"cotton_01", "cotton_02"]
	for k in 3:
		names.append("stripe_%02d" % (k + 1))
		names.append("hole_%02d" % (k + 1))
	for k in 4:
		names.append("bubble_%02d" % (k + 1))
	for n in names:
		var t := tex(ART % n)
		if t:
			_tex[n] = t
	var bg := tex(BG)
	if bg:
		_tex["bg"] = bg
	if _tex.has("sticker_01_blank"):
		_panel = StyleBoxTexture.new()
		_panel.texture = _tex.sticker_01_blank
		_panel.set_texture_margin_all(20)


## 條碼本體與三層斑紋都在，才用美術版的斑紋（判定框也跟著換）
func _art_tiaoma() -> bool:
	return _tex.has("tiaoma_base") and _tex.has("stripe_01") and _tex.has("stripe_02") and _tex.has("stripe_03")


func _art_done() -> bool:
	return _tex.has("done_button_normal") and _tex.has("done_button_hover") and _tex.has("done_button_pressed")


func _done_rect() -> Rect2:
	return DONE_BTN_ART if _art_done() else DONE_BTN


func _ready() -> void:
	layer = 30
	_load_art()
	for k in (ART_STRIPES if _art_tiaoma() else STRIPES) * 2:
		stripes.append(1.0)
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func play() -> void:
	if GameState.fast:
		if GameState.fast_scrub_keep:
			kept_color = true
		_finish()
		queue_free()
		return
	_running = true
	await done
	queue_free()


func remaining() -> float:
	var t := 0.0
	for v in stripes:
		t += v
	return t / stripes.size()


func _finish() -> void:
	if kept_color:
		GameState.set_flag("tiaoma_color_left")
		GameState.add_conduct(-10)
	else:
		GameState.add_conduct(10)
	_running = false
	done.emit()


## 斑紋在畫面上的位置（對應 Critter.draw 的 zebra）
func _stripe_rect(k: int) -> Rect2:
	if _art_tiaoma():
		# 美術版：k / 2 是第幾條斑紋（stripe_01..03），k % 2 是上半／下半
		var sx: Vector2 = ART_STRIPE_X[mini(k / 2, ART_STRIPES - 1)]
		var y0: float = ART_STRIPE_Y[k % 2]
		var y1: float = ART_STRIPE_Y[k % 2 + 1]
		return Rect2(TIAOMA_ORIGIN + Vector2(sx.x - sx.y, y0), Vector2(sx.y * 2.0, y1 - y0))
	var side := -1 if k % 2 == 0 else 1
	var row := k / 2
	var head := POS + Vector2(0, -24) * SCALE
	var y := -12.0 + row * 7.0
	var cx := head.x + side * 12.0 * SCALE
	return Rect2(Vector2(cx - 9 * SCALE, head.y + (y - 2) * SCALE), Vector2(18 * SCALE, 8 * SCALE))


func _scrub_at(p: Vector2, amount: float) -> void:
	for k in stripes.size():
		if stripes[k] > 0 and _stripe_rect(k).grow(10).has_point(p):
			stripes[k] = maxf(0.0, stripes[k] - amount)
			if randf() < 0.4:
				_bubbles.append({"pos": p + Vector2(randf_range(-20, 20), randf_range(-10, 10)), "t": 0.0})
				Tones.play(self, 1046.5 + randf() * 300.0, -22.0)


func _process(delta: float) -> void:
	if not _running:
		return
	for b in _bubbles:
		b.t += delta
		b.pos += Vector2(0, -30) * delta
	_bubbles = _bubbles.filter(func(b): return b.t < 0.8)
	for p in _popups:
		p.t += delta
	_popups = _popups.filter(func(p): return p.t < 1.0)
	_too_dirty_t = maxf(0.0, _too_dirty_t - delta)
	if _mouse_down:
		var speed := _brush.distance_to(_last_brush) / maxf(delta, 0.001)
		if _brush.distance_to(_last_brush) > 1.0:
			_scrub_at(_brush, delta * 0.9)
		if speed > 2600.0 and randf() < 0.05 and _holes.size() < 6:
			# 刷太用力：刷出一個小破洞，棉花冒出來
			_holes.append(_brush)
			_popups.append({"text": "哎呀～輕一點點！", "t": 0.0})
		_last_brush = _brush
	elif Input.is_action_pressed("interact"):
		# 鍵盤：自動刷下一條還有顏色的斑紋
		var left := []
		for k in stripes.size():
			if stripes[k] > 0:
				left.append(k)
		if not left.is_empty():
			var r := _stripe_rect(left[0])
			_brush = r.get_center() + Vector2(sin(Time.get_ticks_msec() / 60.0) * r.size.x * 0.4, 0)
			_scrub_at(_brush, delta * 0.55)
	if remaining() <= 0.0:
		_finish()
	_area.queue_redraw()


func _try_done() -> void:
	var r := remaining()
	if r > KEEP_MAX:
		_too_dirty_t = 2.0
		return
	kept_color = r >= KEEP_MIN
	_finish()


func _input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _done_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
			_try_done()
			return
		_mouse_down = event.pressed
		_brush = event.position
		_last_brush = event.position
	elif event is InputEventMouseMotion:
		_brush = event.position
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_try_done()


func _current_line() -> String:
	var r := remaining()
	var line := ""
	for l in LINES:
		if r <= l[0] + 0.001:
			line = l[1]
	return line


func _draw_area() -> void:
	var f: Font = GameState.font
	var a := _area
	if not _tex.has("bg") and not _art_tiaoma():
		_draw_fallback()
		return
	# 洗衣房背景
	if _tex.has("bg"):
		a.draw_texture_rect(_tex.bg, Rect2(0, 0, 1280, 720), false)
	else:
		a.draw_rect(Rect2(0, 0, 1280, 720), Color("#e8e8e6"))
	# 牆上的海報（空白貼紙＋遊戲自己的字）
	if _panel:
		_panel.modulate_color = Color.WHITE
		a.draw_style_box(_panel, Rect2(40, 70, 230, 110))
	else:
		a.draw_rect(Rect2(40, 70, 230, 110), Color("#fff3f7"))
	a.draw_string(f, Vector2(40, 118), "白白的，", HORIZONTAL_ALIGNMENT_CENTER, 230, 30, Color("#e05780"))
	a.draw_string(f, Vector2(40, 156), "最乾淨！", HORIZONTAL_ALIGNMENT_CENTER, 230, 30, Color("#e05780"))
	_label(Vector2(0, 42), GameState.hint("洗白白！把黑色的地方刷乾淨（拖曳刷子／按住 E）"), 1280, 24, Color("#c2558a"))
	# 洗衣板
	if _tex.has("washboard"):
		var wb: Texture2D = _tex.washboard
		a.draw_texture(wb, Vector2(640, 322) - wb.get_size() * 0.5)
	else:
		a.draw_rect(Rect2(POS.x - 230, POS.y - 300, 460, 340), Color("#cfc6b8"))
	# 條碼：本體一層，斑紋三層；每條斑紋上下兩半各自的黑色 → 那一半的透明度
	if _art_tiaoma():
		a.draw_texture(_tex.tiaoma_base, TIAOMA_ORIGIN)
		for k in ART_STRIPES * 2:
			var v: float = stripes[k] if k < stripes.size() else 0.0
			if v <= 0.0:
				continue
			var y0: float = ART_STRIPE_Y[k % 2]
			var y1: float = ART_STRIPE_Y[k % 2 + 1]
			# 上半從圖層頂端開始、下半畫到圖層底部，避免切掉斑紋的毛邊
			if k % 2 == 0:
				y0 = 0.0
			else:
				y1 = 425.0
			var src := Rect2(0, y0, 700, y1 - y0)
			a.draw_texture_rect_region(_tex["stripe_%02d" % (k / 2 + 1)], Rect2(TIAOMA_ORIGIN + src.position, src.size), src, Color(1, 1, 1, v))
	else:
		a.draw_set_transform(POS, 0.0, Vector2(SCALE, SCALE))
		Critter.draw(a, "zebra", Color("#f4f4f2"), 1.0, Vector2.ZERO, false, false, false, {"stripes": 0})
		a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_fallback_stripes()
	# 曬衣夾：把條碼夾在洗衣板上
	if _tex.has("peg"):
		var pg: Texture2D = _tex.peg
		for c in [Vector2(470, 150), Vector2(820, 150)]:
			a.draw_texture_rect(pg, Rect2(c - pg.get_size() * 0.25, pg.get_size() * 0.5), false)
	# 刷太用力的破洞，棉花冒出來
	for i in _holes.size():
		var h: Vector2 = _holes[i]
		var ht: Texture2D = _tex.get("hole_%02d" % (i % 3 + 1))
		var ct: Texture2D = _tex.get("cotton_%02d" % (i % 2 + 1))
		if ht:
			a.draw_texture_rect(ht, Rect2(h - ht.get_size() * 0.3, ht.get_size() * 0.6), false)
		else:
			a.draw_circle(h, 9, Color("#fbfbfb"))
			a.draw_arc(h, 9, 0, TAU, 12, Color("#bdbdbd"), 2)
		if ct:
			a.draw_texture_rect(ct, Rect2(h + Vector2(-ct.get_size().x * 0.2, -ct.get_size().y * 0.42), ct.get_size() * 0.4), false)
	# 泡泡：越飄越大、越淡
	for i in _bubbles.size():
		var b: Dictionary = _bubbles[i]
		var bt: Texture2D = _tex.get("bubble_%02d" % (i % 4 + 1))
		var alpha: float = 1.0 - b.t / 0.8
		if bt:
			var d: float = (24.0 + b.t * 16.0) * (1.0 + (i % 4) * 0.35)
			a.draw_texture_rect(bt, Rect2(b.pos - Vector2(d, d) * 0.5, Vector2(d, d)), false, Color(1, 1, 1, alpha))
		else:
			a.draw_arc(b.pos, 8 + b.t * 6, 0, TAU, 14, Color(0.7, 0.85, 1.0, alpha), 2)
	# 刷子（刷毛對準刷的位置）
	if _brush.x > 0:
		if _tex.has("brush"):
			var br: Texture2D = _tex.brush
			a.draw_texture_rect(br, Rect2(_brush - Vector2(55, 140) * 0.6, br.get_size() * 0.6), false)
		else:
			_draw_fallback_brush()
	# 條碼說的話
	_label(Vector2(0, 586), "條碼：%s" % _current_line(), 1280, 24,
		Color(0.25, 0.25, 0.25, clampf(0.35 + remaining(), 0.35, 1.0)))
	# 星星
	var stars := 3 - int(ceil(remaining() * 3.0))
	for k in 3:
		var c := Vector2(560 + k * 80, 655)
		var st: Texture2D = _tex.get("star_bright" if k < stars else "star_dark")
		if st:
			a.draw_texture_rect(st, Rect2(c - Vector2(34, 34), Vector2(68, 68)), false)
		else:
			_star(c, 22, Color("#ffd166") if k < stars else Color("#dddddd"))
	# 完成按鈕：圖上只寫「完成」，後面補上「（Tab）」
	if _art_done():
		var r := DONE_BTN_ART
		var state := "normal"
		if r.has_point(a.get_local_mouse_position()):
			state = "pressed" if _mouse_down else "hover"
		a.draw_texture(_tex["done_button_" + state], r.position)
		a.draw_string(f, r.position + Vector2(63, 46), GameState.hint("（Tab）"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#5f5962"))
	else:
		_draw_fallback_done()
	if _too_dirty_t > 0:
		_label(Vector2(0, 540), "和平鴿：還很髒喔。", 1280, 24, Color("#555555"))
	for p in _popups:
		var c := Color(0.88, 0.34, 0.5, 1.0 - p.t)
		var pos := Vector2(640, 480 - p.t * 30)
		if p.text == "哎呀～輕一點點！" and _tex.has("sticker_02"):
			# 貼紙上的字跟遊戲的字一模一樣，直接用
			var sk: Texture2D = _tex.sticker_02
			a.draw_texture_rect(sk, Rect2(pos - sk.get_size() * 0.4 - Vector2(0, 10), sk.get_size() * 0.8), false, Color(1, 1, 1, c.a))
		else:
			_label(pos + Vector2(-640, 0), p.text, 1280, 26, c)


## 有背景圖時，文字底下墊一張空白貼紙，才看得清楚
func _label(pos: Vector2, text: String, width: float, size: int, col: Color) -> void:
	var f: Font = GameState.font
	if _panel:
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 44
		_panel.modulate_color = Color(1, 1, 1, 0.92 * col.a)
		_area.draw_style_box(_panel, Rect2(pos.x + width * 0.5 - w * 0.5, pos.y - size - 8, w, size + 26))
	_area.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size, col)


## 以下是外包美術還沒到時的程式畫版本（保留當備用）
func _draw_fallback() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#e8e8e6"))
	# 牆上的海報
	a.draw_rect(Rect2(60, 60, 260, 120), Color("#fff3f7"))
	a.draw_rect(Rect2(60, 60, 260, 120), Color("#f2a7c3"), false, 4)
	a.draw_string(f, Vector2(60, 115), "白白的，", HORIZONTAL_ALIGNMENT_CENTER, 260, 30, Color("#e05780"))
	a.draw_string(f, Vector2(60, 155), "最乾淨！", HORIZONTAL_ALIGNMENT_CENTER, 260, 30, Color("#e05780"))
	a.draw_string(f, Vector2(0, 40), GameState.hint("洗白白！把黑色的地方刷乾淨（拖曳刷子／按住 E）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Color("#c2558a"))
	# 洗衣板與曬衣夾
	a.draw_rect(Rect2(POS.x - 230, POS.y - 300, 460, 340), Color("#cfc6b8"))
	for k in 14:
		a.draw_line(Vector2(POS.x - 220, POS.y - 290 + k * 23), Vector2(POS.x + 220, POS.y - 290 + k * 23), Color("#b9ae9e"), 3)
	a.draw_set_transform(POS, 0.0, Vector2(SCALE, SCALE))
	Critter.draw(a, "zebra", Color("#f4f4f2"), 1.0, Vector2.ZERO, false, false, false, {"stripes": 0})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_fallback_stripes()
	for side in [-1, 1]:
		var c := POS + Vector2(side * 150, -60)
		a.draw_rect(Rect2(c - Vector2(10, 28), Vector2(20, 56)), Color("#f6bd60"))
	for h in _holes:
		a.draw_circle(h, 9, Color("#fbfbfb"))
		a.draw_arc(h, 9, 0, TAU, 12, Color("#bdbdbd"), 2)
	for b in _bubbles:
		a.draw_arc(b.pos, 8 + b.t * 6, 0, TAU, 14, Color(0.7, 0.85, 1.0, 1.0 - b.t / 0.8), 2)
	# 刷子
	if _brush.x > 0:
		_draw_fallback_brush()
	# 條碼說的話
	a.draw_string(f, Vector2(0, 560), "條碼：%s" % _current_line(), HORIZONTAL_ALIGNMENT_CENTER, 1280, 24,
		Color(0.25, 0.25, 0.25, clampf(0.35 + remaining(), 0.35, 1.0)))
	# 星星
	var stars := 3 - int(ceil(remaining() * 3.0))
	for k in 3:
		_star(Vector2(560 + k * 80, 640), 22, Color("#ffd166") if k < stars else Color("#dddddd"))
	# 完成按鈕
	_draw_fallback_done()
	if _too_dirty_t > 0:
		a.draw_string(f, Vector2(0, 520), "和平鴿：還很髒喔。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Color("#555555"))
	for p in _popups:
		a.draw_string(f, Vector2(0, 480 - p.t * 30), p.text, HORIZONTAL_ALIGNMENT_CENTER, 1280, 26, Color(0.88, 0.34, 0.5, 1.0 - p.t))


func _draw_fallback_stripes() -> void:
	var a := _area
	for k in stripes.size():
		if stripes[k] <= 0:
			continue
		var r := _stripe_rect(k)
		var side := -1 if k % 2 == 0 else 1
		var p1 := Vector2(r.get_center().x + side * 4 * SCALE, r.position.y + 2 * SCALE)
		var p2 := Vector2(r.get_center().x - side * 6 * SCALE, r.position.y + 5 * SCALE)
		a.draw_line(p1, p2, Color(0.12, 0.12, 0.12, stripes[k]), 3 * SCALE)


func _draw_fallback_brush() -> void:
	var a := _area
	a.draw_rect(Rect2(_brush - Vector2(30, 10), Vector2(60, 20)), Color("#ff9ebb"))
	a.draw_rect(Rect2(_brush - Vector2(8, 50), Vector2(16, 42)), Color("#ffc8d8"))
	a.draw_circle(_brush + Vector2(0, -34), 6, Color("#e05780"))


func _draw_fallback_done() -> void:
	var a := _area
	var f: Font = GameState.font
	a.draw_rect(DONE_BTN, Color("#fff8f0"))
	a.draw_rect(DONE_BTN, Color("#e8a0bf"), false, 3)
	a.draw_string(f, DONE_BTN.position + Vector2(0, 46), GameState.hint("完成（Tab）"), HORIZONTAL_ALIGNMENT_CENTER, DONE_BTN.size.x, 24, Color("#8a4b68"))


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2 + i * PI / 5) * rad)
	_area.draw_colored_polygon(pts, col)
