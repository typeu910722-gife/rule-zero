class_name InteriorScene
extends CanvasLayer
## 小屋室內：點一下（或用方向鍵選、按 E）調查房間裡的東西。右下角「離開」回到小鎮。
## 房間資料：scripts/world/interiors.gd。有美術（art/int_<房間>.jpg）就用美術，沒有就用程式畫。

signal closed

const TALK_COOLDOWN_MS := 300
const EXIT_RECT := Rect2(1096, 636, 168, 64)
const INK := Color("#6d597a")

var room_id := ""
var room: Dictionary
var _area: Control
var _hot: Array = []
var _sel := -1            # 目前選中的熱點；_hot.size() = 離開
var _busy := false
var _end_ms := 0
var _bg: Texture2D
var _title_a := 1.0
var _seen := {}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	room = Interiors.ROOMS[room_id]
	var art := "res://art/int_%s.jpg" % room_id
	if ResourceLoader.exists(art):
		_bg = load(art)
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_room)
	add_child(_area)
	_refresh()
	_end_ms = Time.get_ticks_msec()


func _refresh() -> void:
	_hot = room.hotspots.filter(func(h): return GameState.check(h.get("when", "")))
	if _sel > _hot.size():
		_sel = -1
	_area.queue_redraw()


func _process(delta: float) -> void:
	_title_a = maxf(_title_a - delta * 0.35, 0.0)
	_area.queue_redraw()


# ───────── 輸入 ─────────

func _unhandled_input(event: InputEvent) -> void:
	if _busy or Dialogue.running:
		return
	if event is InputEventMouseMotion:
		_sel = _hit(event.position)
		return
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if Time.get_ticks_msec() - _end_ms < TALK_COOLDOWN_MS:
		if click or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
		return
	if click:
		get_viewport().set_input_as_handled()
		var i := _hit(event.position)
		if i >= 0:
			_sel = i
			_activate(i)
		return
	if event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		get_viewport().set_input_as_handled()
		_sel = (_sel + 1) % (_hot.size() + 1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		get_viewport().set_input_as_handled()
		_sel = (_sel - 1 + _hot.size() + 1) % (_hot.size() + 1) if _sel >= 0 else _hot.size()
	elif event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _sel < 0:
			_sel = 0
			return
		_activate(_sel)
	elif event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		leave()


## 畫面座標 → 第幾個熱點（離開按鈕 = _hot.size()；沒點到 = -1）
func _hit(p: Vector2) -> int:
	if EXIT_RECT.grow(6).has_point(p):
		return _hot.size()
	# 小的東西優先（樹洞、老鼠洞不會被大的家具蓋過去）
	var best := -1
	var best_area := INF
	for i in _hot.size():
		var r: Rect2 = _hot[i].rect
		var grow := 14.0 if r.size.x < 60 else 4.0
		if r.grow(grow).has_point(p) and r.get_area() < best_area:
			best = i
			best_area = r.get_area()
	return best


func _activate(i: int) -> void:
	if i == _hot.size():
		leave()
		return
	inspect(_hot[i].id)


func inspect(label: String) -> void:
	_busy = true
	_seen[label] = true
	Sound.sfx("interact")
	await Dialogue.run(label)
	_busy = false
	_end_ms = Time.get_ticks_msec()
	_refresh()
	if GameState.has("leave_room"):
		GameState.set_flag("leave_room", false)
		leave()


func leave() -> void:
	if _busy:
		return
	_busy = true
	Sound.sfx("door")
	closed.emit()


# ───────── 畫面 ─────────

func _draw_room() -> void:
	var c := _area
	if _bg:
		c.draw_texture_rect(_bg, Rect2(0, 0, 1280, 720), false)
	else:
		_draw_shell(c)
		for d in room.get("decor", []):
			_draw_prop(c, d.prop, d.rect)
		for h in _hot:
			_draw_prop(c, h.prop, h.rect)
		var dark: float = room.get("dark", 0.0)
		if dark > 0.0:
			c.draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.03, 0.08, dark))
	var t := Time.get_ticks_msec() / 1000.0
	# 可以調查的東西：一點點閃光（不起眼的那種不閃）
	for i in _hot.size():
		var h: Dictionary = _hot[i]
		if h.get("hidden", false) or _seen.has(h.id):
			continue
		var r: Rect2 = h.rect
		var p := r.position + Vector2(r.size.x * 0.82, r.size.y * 0.18)
		var a := 0.45 + 0.4 * sin(t * 2.6 + r.position.x * 0.02)
		c.draw_circle(p, 4.5, Color(1, 1, 1, a))
		c.draw_arc(p, 9 + 2 * sin(t * 2.6), 0, TAU, 16, Color(1, 0.82, 0.9, a), 2)
	# 選中的東西：外框＋名字
	if _sel >= 0 and _sel < _hot.size() and not _busy and not Dialogue.running:
		var h: Dictionary = _hot[_sel]
		var r: Rect2 = h.rect.grow(8)
		var pulse := 0.6 + 0.3 * sin(t * 5.0)
		c.draw_rect(r, Color(1, 0.9, 0.95, 0.12 * pulse))
		c.draw_rect(r, Color(1, 0.75, 0.86, pulse), false, 3)
		# 名字放在東西上面；太靠上面（會被房間名字擋住）就放下面
		var ly := r.position.y - 12 if r.position.y > 96 else r.end.y + 36
		_label(c, h.name, Vector2(r.get_center().x, ly))
	# 離開
	var ex := EXIT_RECT
	var on: bool = _sel == _hot.size() and not Dialogue.running
	c.draw_rect(ex, Color("#fff4f7") if not on else Color("#ffd9e6"))
	c.draw_rect(ex, Color("#c27a8c"), false, 3)
	var f: Font = GameState.font
	c.draw_string(f, ex.position + Vector2(0, 42), "離開", HORIZONTAL_ALIGNMENT_CENTER, ex.size.x, 26, INK)
	# 房間名字（進來時顯示一下）
	if _title_a > 0.0 and not Dialogue.running:
		var a := minf(_title_a * 1.5, 1.0)
		c.draw_string_outline(f, Vector2(0, 52), room.name, HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, 8, Color(1, 1, 1, 0.9 * a))
		c.draw_string(f, Vector2(0, 52), room.name, HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color(INK, a))
	# 操作提示
	if not Dialogue.running:
		var hint := "點一下東西來調查" if DisplayServer.is_touchscreen_available() else "滑鼠點一下，或用方向鍵選、按 E 調查　·　Tab 離開"
		c.draw_string_outline(f, Vector2(20, 700), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(1, 1, 1, 0.8))
		c.draw_string(f, Vector2(20, 700), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)


func _label(c: Control, text: String, at: Vector2) -> void:
	var f: Font = GameState.font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var x := clampf(at.x - w / 2, 10, 1270 - w)
	var y := maxf(at.y, 30)
	c.draw_rect(Rect2(x - 12, y - 26, w + 24, 36), Color(1, 1, 1, 0.92))
	c.draw_rect(Rect2(x - 12, y - 26, w + 24, 36), Color("#e8a0bf"), false, 2)
	c.draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)


## 牆、地板、踢腳板
func _draw_shell(c: Control) -> void:
	var wall: Color = room.wall
	var wall2: Color = room.wall2
	var floor_y := 470.0
	c.draw_rect(Rect2(0, 0, 1280, floor_y), wall)
	match room.get("pattern", ""):
		"stripes":
			for x in range(0, 1280, 64):
				c.draw_rect(Rect2(x, 0, 26, floor_y), wall2)
		"dots":
			for y in range(30, int(floor_y), 60):
				for x in range(30 + (y / 60 % 2) * 30, 1280, 60):
					c.draw_circle(Vector2(x, y), 6, wall2)
		"planks":
			for y in range(0, int(floor_y), 46):
				c.draw_line(Vector2(0, y), Vector2(1280, y), wall2, 3)
				var off := (y / 46 % 2) * 120
				for x in range(off, 1280, 240):
					c.draw_line(Vector2(x, y), Vector2(x, y + 46), wall2, 2)
		"diamond":
			for y in range(0, int(floor_y) + 60, 60):
				for x in range(0, 1300, 60):
					var p := Vector2(x + (y / 60 % 2) * 30, y)
					c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -12), p + Vector2(10, 0), p + Vector2(0, 12), p + Vector2(-10, 0)]), wall2)
	# 地板（往前變寬的木板）
	c.draw_rect(Rect2(0, floor_y, 1280, 720 - floor_y), room.floor)
	for k in range(1, 7):
		var y := floor_y + (720 - floor_y) * pow(k / 7.0, 1.3)
		c.draw_line(Vector2(0, y), Vector2(1280, y), room.floor2, 2)
	for k in range(-8, 9):
		c.draw_line(Vector2(640 + k * 70, floor_y), Vector2(640 + k * 170, 720), room.floor2, 2)
	c.draw_rect(Rect2(0, floor_y - 14, 1280, 18), room.trim)
	# 角落的陰影
	for i in 6:
		c.draw_rect(Rect2(0, 0, 1280, 6 + i * 6), Color(0, 0, 0, 0.025))


func _outline(c: Control, r: Rect2, fill: Color, w := 3.0) -> void:
	c.draw_rect(r, fill)
	c.draw_rect(r, INK.darkened(0.2), false, w)


func _poly(c: Control, pts: Array, fill: Color) -> void:
	var p := PackedVector2Array(pts)
	c.draw_colored_polygon(p, fill)
	p.append(pts[0])
	c.draw_polyline(p, INK.darkened(0.2), 2.5)


## 沒有美術時，用簡單的形狀畫出每樣東西
func _draw_prop(c: Control, prop: String, r: Rect2) -> void:
	var p := r.position
	var s := r.size
	var ctr := r.get_center()
	match prop:
		"mirror_cloth", "mirror_sewn":
			# 鏡之屋：蓋著碎花布的鏡子（被縫起來的那一面有一排縫線）
			_outline(c, r, Color("#7d6a5a"), 6)
			c.draw_rect(r.grow(-8), Color("#dfe7ee"))
			var cloth := Rect2(p + Vector2(4, 20), Vector2(s.x - 8, s.y - 16))
			c.draw_rect(cloth, Color("#f3d9e1"))
			for i in 9:
				c.draw_circle(cloth.position + Vector2(18 + (i % 3) * (cloth.size.x - 36) / 2.0, 30 + (i / 3) * cloth.size.y / 3.2), 6, Color("#e2a7b8"))
			if prop == "mirror_sewn":
				for i in 12:
					var y := cloth.position.y + 12 + i * (cloth.size.y - 24) / 11.0
					c.draw_line(Vector2(ctr.x - 10, y), Vector2(ctr.x + 10, y + 6), Color("#5a3a46"), 3)
		"mirror_chair":
			# 唯一沒有蓋布的鏡子，和對著它的小椅子
			_outline(c, Rect2(p + Vector2(30, 0), Vector2(s.x - 60, s.y * 0.62)), Color("#7d6a5a"), 6)
			c.draw_rect(Rect2(p + Vector2(38, 8), Vector2(s.x - 76, s.y * 0.62 - 16)), Color("#e9f0f5"))
			c.draw_circle(p + Vector2(s.x / 2, s.y * 0.3), 26, Color(0.75, 0.78, 0.84, 0.6))
			var seat := Rect2(p + Vector2(s.x * 0.25, s.y * 0.72), Vector2(s.x * 0.5, 20))
			c.draw_rect(seat, Color("#9a6b4b"))
			c.draw_rect(Rect2(seat.position + Vector2(0, -60), Vector2(14, 60)), Color("#8a5d40"))
			c.draw_rect(Rect2(seat.end + Vector2(-14, -80), Vector2(14, 60)), Color("#8a5d40"))
			for x in [seat.position.x + 4, seat.end.x - 14]:
				c.draw_rect(Rect2(Vector2(x, seat.end.y), Vector2(10, s.y * 0.24)), Color("#7a4f36"))
		"window", "window_round":
			var night := GameState.has("night_out")
			var sky := Color("#bfe3f5") if not night else Color("#2b2f55")
			if prop == "window_round":
				c.draw_circle(ctr, s.x / 2, Color("#5a4030"))
				c.draw_circle(ctr, s.x / 2 - 12, sky)
				c.draw_line(ctr - Vector2(s.x / 2 - 12, 0), ctr + Vector2(s.x / 2 - 12, 0), Color("#5a4030"), 6)
				c.draw_line(ctr - Vector2(0, s.y / 2 - 12), ctr + Vector2(0, s.y / 2 - 12), Color("#5a4030"), 6)
				for i in 4:
					c.draw_circle(ctr + Vector2(-30 + i * 22, 20 - (i % 2) * 14), 14, Color("#6f8f5a"))
			else:
				_outline(c, r, Color("#fffaf2"), 4)
				c.draw_rect(r.grow(-12), sky)
				c.draw_circle(p + Vector2(s.x * 0.3, s.y * 0.35), 18, Color(1, 1, 1, 0.9))
				c.draw_circle(p + Vector2(s.x * 0.42, s.y * 0.33), 22, Color(1, 1, 1, 0.9))
				c.draw_line(Vector2(ctr.x, p.y + 12), Vector2(ctr.x, r.end.y - 12), Color("#fffaf2"), 6)
				c.draw_line(Vector2(p.x + 12, ctr.y), Vector2(r.end.x - 12, ctr.y), Color("#fffaf2"), 6)
				_poly(c, [p + Vector2(-26, -10), p + Vector2(40, -10), p + Vector2(10, s.y + 20), p + Vector2(-26, s.y + 30)], Color("#f4b6c2"))
				_poly(c, [r.end - Vector2(40, s.y + 10), r.end + Vector2(26, -s.y - 10), r.end + Vector2(26, 30), r.end + Vector2(-10, 20)], Color("#f4b6c2"))
		"rug":
			c.draw_set_transform(ctr, 0, Vector2(1, s.y / s.x))
			c.draw_circle(Vector2.ZERO, s.x / 2, Color("#e9c7cf"))
			c.draw_arc(Vector2.ZERO, s.x / 2 - 14, 0, TAU, 48, Color("#fff4f7"), 6)
			c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"lamp":
			c.draw_line(Vector2(ctr.x, 0), Vector2(ctr.x, r.end.y - 40), INK, 3)
			_poly(c, [Vector2(p.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(ctr.x + 18, r.end.y - 44), Vector2(ctr.x - 18, r.end.y - 44)], Color("#ffe8a8"))
			c.draw_circle(Vector2(ctr.x, r.end.y + 30), 90, Color(1, 0.95, 0.7, 0.08))
		"table":
			c.draw_rect(Rect2(p.x + 20, p.y, 16, s.y), Color("#8a5a3c"))
			c.draw_rect(Rect2(r.end.x - 36, p.y, 16, s.y), Color("#8a5a3c"))
			_outline(c, Rect2(p.x, p.y - 8, s.x, 22), Color("#c08a5e"))
		"counter":
			_outline(c, r, Color("#b88a64"))
			c.draw_rect(Rect2(p.x - 10, p.y - 12, s.x + 20, 16), Color("#d4a57c"))
			c.draw_rect(Rect2(p.x - 10, p.y - 12, s.x + 20, 16), INK.darkened(0.2), false, 2.5)
		"hammock":
			c.draw_line(p, p + Vector2(0, 30), INK, 3)
			c.draw_line(r.end - Vector2(0, s.y), r.end - Vector2(0, s.y - 30), INK, 3)
			var pts := []
			for i in 13:
				var x := float(i) / 12.0
				pts.append(p + Vector2(s.x * x, 30 + sin(x * PI) * (s.y - 40)))
			for i in 12:
				c.draw_line(pts[i], pts[i + 1], Color("#c8642b"), 10)
		"mirror_broken":
			c.draw_set_transform(ctr, 0, Vector2(1, s.y / s.x))
			c.draw_circle(Vector2.ZERO, s.x / 2, Color("#d8b25a"))
			c.draw_circle(Vector2.ZERO, s.x / 2 - 12, Color("#8c7f86"))
			c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			# 碎片被翻過去，背面朝外，用膠帶貼著
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for i in 9:
				var a := TAU * i / 9.0
				var q := ctr + Vector2(cos(a), sin(a) * s.y / s.x) * s.x * 0.18
				var q2 := ctr + Vector2(cos(a + 0.6), sin(a + 0.6) * s.y / s.x) * s.x * 0.38
				var q3 := ctr + Vector2(cos(a + 0.2), sin(a + 0.2) * s.y / s.x) * s.x * 0.42
				_poly(c, [q, q2, q3], Color("#6e6168").lightened(rng.randf() * 0.15))
			c.draw_line(ctr + Vector2(-50, -30), ctr + Vector2(40, 20), Color("#f2e6b8"), 8)
			c.draw_line(ctr + Vector2(-30, 50), ctr + Vector2(20, -60), Color("#f2e6b8"), 8)
		"sill":
			_outline(c, Rect2(p.x - 10, p.y + 26, s.x + 20, 16), Color("#fffaf2"))
			for i in 5:
				var x := p.x + 20 + i * 44
				if i % 2 == 0:
					c.draw_circle(Vector2(x, p.y + 16), 9, Color("#9c6b3e"))
					c.draw_rect(Rect2(x - 8, p.y + 2, 16, 6), Color("#6b4a2b"))
				else:
					c.draw_line(Vector2(x - 10, p.y + 24), Vector2(x + 8, p.y - 4), Color("#ffffff"), 4)
					c.draw_line(Vector2(x - 10, p.y + 24), Vector2(x + 8, p.y - 4), Color("#b7c9d8"), 2)
		"sketchbook":
			_poly(c, [p + Vector2(0, 10), p + Vector2(s.x / 2, 0), p + Vector2(s.x / 2, s.y), p + Vector2(0, s.y)], Color("#fffaf2"))
			_poly(c, [p + Vector2(s.x / 2, 0), p + Vector2(s.x, 10), p + Vector2(s.x, s.y), p + Vector2(s.x / 2, s.y)], Color("#fffaf2"))
			c.draw_circle(p + Vector2(s.x * 0.25, s.y * 0.5), 14, Color("#f4b6c2"))
			c.draw_line(p + Vector2(s.x * 0.6, s.y * 0.3), p + Vector2(s.x * 0.9, s.y * 0.7), Color("#3a3036"), 5)
			c.draw_line(p + Vector2(s.x * 0.9, s.y * 0.3), p + Vector2(s.x * 0.6, s.y * 0.7), Color("#3a3036"), 5)
		"desk_letter":
			_outline(c, Rect2(p.x, p.y + 50, s.x, 22), Color("#e6c39e"))
			c.draw_rect(Rect2(p.x + 10, p.y + 72, 12, 70), Color("#b88a64"))
			c.draw_rect(Rect2(r.end.x - 22, p.y + 72, 12, 70), Color("#b88a64"))
			_poly(c, [p + Vector2(30, 10), p + Vector2(120, 4), p + Vector2(126, 54), p + Vector2(36, 58)], Color("#ffe4ec"))
			for i in 3:
				c.draw_line(p + Vector2(44, 20 + i * 10), p + Vector2(110, 16 + i * 10), Color("#c27a8c"), 2)
			c.draw_circle(p + Vector2(140, 44), 10, Color("#fffaf2"))
		"wardrobe":
			_outline(c, r, Color("#f0d2b8"))
			c.draw_line(Vector2(ctr.x, p.y + 10), Vector2(ctr.x, r.end.y - 10), INK, 3)
			c.draw_circle(Vector2(ctr.x - 14, ctr.y), 6, Color("#d8b25a"))
			c.draw_circle(Vector2(ctr.x + 14, ctr.y), 6, Color("#d8b25a"))
			c.draw_rect(Rect2(p.x - 8, p.y - 16, s.x + 16, 18), Color("#e6c39e"))
		"slots":
			_outline(c, r, Color("#8a6a4f"))
			for y in 4:
				for x in 6:
					var cell := Rect2(p.x + 12 + x * (s.x - 24) / 6, p.y + 12 + y * (s.y - 24) / 4, (s.x - 24) / 6 - 8, (s.y - 24) / 4 - 8)
					c.draw_rect(cell, Color("#4d3828"))
					if (x + y * 3) % 4 != 0 or y == 3:
						c.draw_rect(Rect2(cell.position + Vector2(6, 6), Vector2(cell.size.x - 12, cell.size.y * 0.5)), Color("#fffaf2"))
		"pink_letter":
			_poly(c, [p + Vector2(10, 10), p + Vector2(s.x - 10, 4), p + Vector2(s.x - 4, s.y - 8), p + Vector2(14, s.y - 4)], Color("#ffc4d6"))
			c.draw_line(p + Vector2(12, 10), ctr + Vector2(0, 6), Color("#c27a8c"), 2)
			c.draw_line(p + Vector2(s.x - 10, 4), ctr + Vector2(0, 6), Color("#c27a8c"), 2)
			c.draw_circle(ctr + Vector2(0, 10), 9, Color("#ffffff"))
		"photos_board":
			_outline(c, r, Color("#c9a27a"))
			for i in 6:
				var cell := Rect2(p.x + 16 + (i % 3) * 80, p.y + 18 + (i / 3) * 100, 66, 80)
				c.draw_rect(cell, Color("#ffffff"))
				c.draw_rect(Rect2(cell.position + Vector2(5, 5), Vector2(56, 52)), Color("#9cc5d8"))
				c.draw_circle(cell.position + Vector2(33, 30), 10, Color("#2f3352"))
				c.draw_rect(Rect2(cell.position + Vector2(0, 30), Vector2(8, 34)), Color("#c9a27a"))
		"stamp_book":
			_outline(c, r, Color("#7aa8c7"))
			for i in 6:
				c.draw_rect(Rect2(p.x + 10 + (i % 3) * 38, p.y + 8 + (i / 3) * 26, 28, 20), Color("#fffaf2"))
		"scale":
			_outline(c, Rect2(p.x + 20, p.y + 60, s.x - 40, s.y - 60), Color("#c7ccd6"))
			c.draw_circle(Vector2(ctr.x, p.y + 40), 36, Color("#fffaf2"))
			c.draw_arc(Vector2(ctr.x, p.y + 40), 36, 0, TAU, 32, INK, 3)
			c.draw_line(Vector2(ctr.x, p.y + 40), Vector2(ctr.x + 22, p.y + 20), Color("#e05780"), 3)
		"tally":
			var rng := RandomNumberGenerator.new()
			rng.seed = 47
			for i in 34:
				var q := p + Vector2(rng.randf() * (s.x - 40), rng.randf() * (s.y - 30))
				for k in 4:
					c.draw_line(q + Vector2(k * 7, 0), q + Vector2(k * 7 + 2, 24), Color("#3b2a1e"), 2)
				c.draw_line(q + Vector2(-3, 18), q + Vector2(26, 4), Color("#3b2a1e"), 2)
		"class_photo":
			c.draw_rect(r, Color("#efe6d2"))
			c.draw_rect(r, INK, false, 2)
			for i in 6:
				var hp := p + Vector2(14 + i * 16, 40)
				c.draw_circle(hp, 6, Color("#e3c6a8"))
				c.draw_rect(Rect2(hp + Vector2(-6, 6), Vector2(12, 18)), Color("#3e4a6e"))
			for k in 6:
				c.draw_line(p + Vector2(54 + k, 26), p + Vector2(64 - k, 44), Color("#5a4030"), 1.5)
			c.draw_circle(p + Vector2(s.x / 2, 4), 4, Color("#888888"))
		"notebook":
			_outline(c, r, Color("#a47148"))
			c.draw_rect(Rect2(p.x + 10, p.y + 8, s.x - 20, s.y - 16), Color("#fffaf2"))
			for i in 4:
				c.draw_line(p + Vector2(18, 20 + i * 12), p + Vector2(s.x - 18, 20 + i * 12), Color("#9b8b7a"), 1.5)
		"plank":
			c.draw_rect(r, Color("#7a5c43"))
			_poly(c, [p + Vector2(0, s.y), p + Vector2(s.x, s.y), p + Vector2(s.x, 6), p + Vector2(0, s.y - 10)], Color("#8f6c50"))
			c.draw_circle(p + Vector2(12, s.y - 6), 3, Color("#c0c0c0"))
		"slingshot":
			c.draw_line(p + Vector2(30, s.y), p + Vector2(30, 40), Color("#6b4a2b"), 6)
			c.draw_line(p + Vector2(30, 40), p + Vector2(14, 10), Color("#6b4a2b"), 6)
			c.draw_line(p + Vector2(30, 40), p + Vector2(46, 10), Color("#6b4a2b"), 6)
			c.draw_line(p + Vector2(14, 10), p + Vector2(46, 10), Color("#c8642b"), 2)
			for i in 4:
				c.draw_circle(p + Vector2(76 + i * 18, s.y - 14 - (i % 2) * 10), 8, [Color("#ffb3c7"), Color("#b5e8d5"), Color("#ffe08a")][i % 3])
		"knothole":
			c.draw_set_transform(ctr, 0, Vector2(1, 0.8))
			c.draw_circle(Vector2.ZERO, s.x / 2 + 4, Color("#6a4c36"))
			c.draw_circle(Vector2.ZERO, s.x / 2 - 3, Color("#140c08"))
			c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"mousehole":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, s.y), p + Vector2(0, s.y * 0.45), p + Vector2(s.x * 0.5, 0), p + Vector2(s.x, s.y * 0.45), p + Vector2(s.x, s.y)]), Color("#0d0907"))
		"portrait_bear":
			_outline(c, r, Color("#d8b25a"), 5)
			c.draw_rect(r.grow(-14), Color("#e9dcc0"))
			c.draw_circle(ctr + Vector2(0, 10), 56, Color("#c4894f"))
			c.draw_circle(ctr + Vector2(-46, -36), 20, Color("#c4894f"))
			c.draw_circle(ctr + Vector2(46, -36), 20, Color("#c4894f"))
			c.draw_circle(ctr + Vector2(-20, 0), 7, Color("#2a2027"))
			c.draw_circle(ctr + Vector2(20, 0), 7, Color("#2a2027"))
			c.draw_arc(ctr + Vector2(0, 26), 16, 0.2, PI - 0.2, 12, Color("#2a2027"), 3)
		"jars":
			c.draw_rect(Rect2(p.x - 10, r.end.y - 10, s.x + 20, 14), Color("#8a5a3c"))
			for i in 4:
				var jx := p.x + 10 + i * (s.x - 20) / 4
				var jr := Rect2(jx, p.y + 20, (s.x - 20) / 4 - 14, s.y - 30)
				c.draw_rect(jr, Color(1, 1, 1, 0.55))
				c.draw_rect(jr, INK, false, 2)
				for k in 5:
					c.draw_circle(jr.position + Vector2(10 + (k % 3) * 14, jr.size.y - 12 - (k / 3) * 14), 6, [Color("#ffb3c7"), Color("#b5e8d5"), Color("#ffe08a")][(i + k) % 3])
				c.draw_rect(Rect2(jx + 6, p.y + 40, jr.size.x - 12, 18), Color("#fffaf2"))
		"cabinet":
			_outline(c, r, Color("#6a432e"))
			for i in 2:
				var dr := Rect2(p.x + 14, p.y + 14 + i * (s.y - 14) / 2, s.x - 28, (s.y - 14) / 2 - 14)
				c.draw_rect(dr, Color("#7d5238"))
				c.draw_rect(dr, Color("#c9a24a"), false, 2)
				c.draw_circle(dr.get_center(), 6, Color("#c9a24a"))
		"rollbook":
			_outline(c, r, Color("#2f4a6e"))
			c.draw_rect(Rect2(p.x + 8, p.y + 6, s.x - 16, 20), Color("#fffaf2"))
		"chalk_box":
			_outline(c, r, Color("#7a1e2e"))
			c.draw_rect(Rect2(p.x + 14, p.y + 22, 50, 10), Color("#fffaf2"))
			c.draw_circle(p + Vector2(s.x - 30, 34), 12, Color("#c0c0c0"))
		"coat":
			c.draw_line(Vector2(ctr.x, p.y), Vector2(ctr.x, r.end.y), Color("#5a3a26"), 8)
			c.draw_line(Vector2(ctr.x - 40, r.end.y), Vector2(ctr.x + 40, r.end.y), Color("#5a3a26"), 8)
			_poly(c, [Vector2(ctr.x - 60, p.y + 70), Vector2(ctr.x + 60, p.y + 70), Vector2(ctr.x + 50, p.y + 250), Vector2(ctr.x - 50, p.y + 250)], Color("#3e4a6e"))
			c.draw_line(Vector2(ctr.x, p.y + 70), Vector2(ctr.x, p.y + 250), Color("#2b3450"), 3)
		"family_drawing":
			c.draw_rect(r, Color("#fffaf2"))
			c.draw_rect(r, INK, false, 2)
			for i in 6:
				var hx := p.x + 24 + i * 38
				var col: Color = [Color("#f28c8c"), Color("#8cb8f2"), Color("#9ad48c"), Color("#f2c46e"), Color("#c49af2"), Color("#f28cc4")][i]
				c.draw_circle(Vector2(hx, p.y + 70), 14, col)
				c.draw_line(Vector2(hx, p.y + 84), Vector2(hx, p.y + 130), col, 4)
				c.draw_line(Vector2(hx - 18, p.y + 100), Vector2(hx + 18, p.y + 100), col, 4)
			c.draw_circle(Vector2(p.x + 24 + 2.5 * 38, p.y + 140), 12, Color("#fbf3e6"))
			c.draw_circle(Vector2(p.x + 20 + 2.5 * 38, p.y + 138), 2, INK)
			c.draw_circle(Vector2(p.x + 28 + 2.5 * 38, p.y + 138), 2, INK)
		"lockers":
			for i in 8:
				var lr := Rect2(p.x + (i % 4) * s.x / 4 + 4, p.y + (i / 4) * s.y / 2 + 4, s.x / 4 - 8, s.y / 2 - 8)
				_outline(c, lr, Color("#9cc5d8") if i != 6 else Color("#ffd27a"))
				c.draw_string(GameState.font, lr.position + Vector2(0, 40), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 26, INK)
		"pillow_bed":
			_outline(c, Rect2(p.x, p.y + 60, s.x, s.y - 60), Color("#f6dcb8"))
			for i in 10:
				c.draw_circle(p + Vector2(30 + (i % 5) * 80, 54 + (i / 5) * 40), 26, Color("#ffffff"))
				c.draw_arc(p + Vector2(30 + (i % 5) * 80, 54 + (i / 5) * 40), 26, 0, TAU, 20, Color("#e6c39e"), 2)
		"zhuyin_paper", "test_paper", "paper":
			_poly(c, [p, p + Vector2(s.x, 6), p + Vector2(s.x - 4, s.y), p + Vector2(4, s.y - 4)], Color("#fffaf2"))
			for i in 5:
				c.draw_line(p + Vector2(14, 14 + i * 12), p + Vector2(s.x - 18, 16 + i * 12), Color("#9b8b7a"), 1.5)
			if prop == "test_paper":
				c.draw_string(GameState.font, p + Vector2(s.x - 70, 36), "100", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#e05780"))
		"drawer":
			_outline(c, r, Color("#e6c39e"))
			c.draw_rect(Rect2(p.x + 20, p.y + 20, s.x - 40, s.y - 40), Color("#d4a57c"))
			c.draw_circle(ctr, 6, Color("#8a5a3c"))
		"awards":
			for i in 8:
				var ar := Rect2(p.x + (i % 4) * s.x / 4 + 8, p.y + (i / 4) * s.y / 2 + 8, s.x / 4 - 16, s.y / 2 - 16)
				_outline(c, ar, Color("#fffaf2"), 2)
				c.draw_rect(ar.grow(-6), Color("#d8b25a"), false, 2)
				c.draw_rect(Rect2(ar.position + Vector2(20, 24), Vector2(ar.size.x - 40, 10)), Color("#5f5a8a"))
				c.draw_circle(ar.end - Vector2(20, 20), 9, Color("#e05780"))
		"pencils":
			for i in 6:
				var ln := 120.0 - i * 16
				c.draw_rect(Rect2(p.x + 10, p.y + 8 + i * 10, ln, 7), Color("#ffd27a"))
				c.draw_rect(Rect2(p.x + 10 + ln, p.y + 8 + i * 10, 10, 7), Color("#3a3036"))
		"trash_stars":
			_poly(c, [p + Vector2(10, 20), p + Vector2(s.x - 10, 20), p + Vector2(s.x - 22, s.y), p + Vector2(22, s.y)], Color("#c4cad6"))
			for i in 5:
				var sp := p + Vector2(26 + i * 14, 14 - (i % 2) * 8)
				c.draw_circle(sp, 6, [Color("#ffb3c7"), Color("#b5e8d5"), Color("#ffe08a")][i % 3])
		"badge":
			c.draw_circle(ctr, s.x / 2, Color("#e05780"))
			c.draw_circle(ctr, s.x / 2 - 8, Color("#fff4f7"))
			c.draw_string(GameState.font, ctr + Vector2(-s.x / 2, 8), "班長", HORIZONTAL_ALIGNMENT_CENTER, s.x, 20, Color("#e05780"))
		"timetable":
			_outline(c, r, Color("#2b2f3a"))
			c.draw_string(GameState.font, p + Vector2(0, 46), "時刻表", HORIZONTAL_ALIGNMENT_CENTER, s.x, 26, Color("#fffaf2"))
			c.draw_string(GameState.font, p + Vector2(20, 100), "抵達　・・・・", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffe08a"))
			c.draw_rect(Rect2(p.x + 20, p.y + 130, s.x - 40, 20), Color("#000000"))
		"tickets":
			for i in 5:
				c.draw_rect(Rect2(p.x + i * 3, p.y + 20 - i * 4, s.x - 20, s.y - 30), Color("#efe2c4"))
				c.draw_rect(Rect2(p.x + i * 3, p.y + 20 - i * 4, s.x - 20, s.y - 30), INK, false, 1.5)
		"documents":
			_outline(c, r, Color("#e8d6a8"))
			c.draw_circle(p + Vector2(s.x - 34, 30), 14, Color("#e05780"))
			for i in 4:
				c.draw_rect(Rect2(p.x + 14, p.y + 22 + i * 14, s.x - 70, 7), Color("#2a2027"))
		"lunchbox":
			_outline(c, r, Color("#9ad4c4"))
			c.draw_circle(p + Vector2(36, 40), 18, Color("#ffffff"))
			c.draw_circle(p + Vector2(86, 40), 18, Color("#ffffff"))
			c.draw_rect(Rect2(p.x + 70, p.y + 36, 32, 10), Color("#2a3a2a"))
		"cap":
			c.draw_circle(p + Vector2(s.x / 2, 6), 5, INK)
			_poly(c, [p + Vector2(10, 70), p + Vector2(s.x - 10, 70), p + Vector2(s.x - 24, 22), p + Vector2(24, 22)], Color("#4a2a32"))
			c.draw_rect(Rect2(p.x, p.y + 66, s.x, 14), Color("#2a1a1e"))
			c.draw_circle(p + Vector2(s.x / 2, 44), 8, Color("#d8b25a"))
		_:
			_outline(c, r, Color("#fffaf2"))
