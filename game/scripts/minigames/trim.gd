extends CanvasLayer
## 修剪（第二章小遊戲 5）：用印著小花的粉紅色剪刀，一根一根剪掉小棘的刺。
## 每剪一根，小棘的笑容計量表往下掉；掉到紅色，和平鴿就按遙控器把它「電」回綠色。
## 操作：點一根刺剪掉；鍵盤按 E 剪下一根。
## leave：剪到剩幾根就停（劇本會在中途停下來演那封信，再決定要不要留下最後一根）。

signal done

const TOTAL := 12
const ORIGIN := Vector2(640, 470)
const SCALE := 5.0

var quills := TOTAL
var leave := 0
var _smile := 1.0
var _zap := 0.0
var _running := false
var _area: Control
var _scissors := Vector2(-100, -100)
var _cotton: Array = []

# ── 外包美術（res://art/ch2/minigames/trim/）。圖不在就退回原本的程序繪圖 ──
const ART := "res://art/ch2/minigames/trim/"
const TABLECLOTH := "res://art/ch2/minigames/restuff/ch2_restuff_tablecloth.png"
const BASE_POS := Vector2(250, 205)          # 躺著的小棘（800×500）左上角
const HEAD := BASE_POS + Vector2(275, 165)   # 小棘頭的中心（刺圍著它排一圈）
const TILT := -0.18                          # 小棘的頭往左歪，整圈刺跟著轉
const ARC := 1.25                            # 刺圍成的扇形張開一點
const ROOT_R := 92.0                         # 刺根離頭中心多遠（藏在頭後面）
const QUILL_SCALE := 0.8
## trimming_spines.json 的刺（交付是 2× 尺寸，這裡已經減半）：中心座標、角度
const QUILL_LAYOUT := [
	[382.5, 295.0, -55], [387.0, 268.5, -45], [401.0, 244.5, -35], [423.0, 225.0, -25],
	[451.0, 210.5, -15], [483.0, 203.0, -5], [516.5, 203.0, 5], [548.5, 210.5, 15],
	[576.5, 225.0, 25], [598.5, 244.5, 35], [612.5, 268.5, 45], [617.5, 295.0, 55]]
const METER_POS := Vector2(790, 150)
## 上一段剪剩的是哪幾根（劇本分三段演，中間會停下來讀信）
static var _carry: Array = []

var _base_tex: Texture2D
var _quill_tex: Array = []
var _bg_tex: Texture2D
var _sc_open: Texture2D
var _sc_closed: Texture2D
var _meter_tex: Texture2D
var _pointer_tex: Texture2D
var _puff_tex: Array = []
var _flash_tex: Texture2D
var _letter_tex: Texture2D
var _alive: Array = []        # 還留著的刺（QUILL_LAYOUT 的索引）
var _start_quills := TOTAL
var _snip := 0.0              # 剪刀合起來的時間
var _letter := false          # 第一段剪完：信從切口掉出來
var _key_cut := false         # 這一刀是按 E 剪的（不看滑鼠位置）


static func _tex(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null


func _ready() -> void:
	layer = 30
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	_base_tex = _tex(ART + "ch2_trim_xiaoji_base.png")
	for k in TOTAL:
		var t := _tex(ART + "ch2_trim_quill_%02d.png" % (k + 1))
		if t == null:
			_base_tex = null   # 少一根就整組退回程序繪圖，免得點的位置對不上
		_quill_tex.append(t)
	_bg_tex = _tex(TABLECLOTH)
	_sc_open = _tex(ART + "ch2_trim_scissors_open.png")
	_sc_closed = _tex(ART + "ch2_trim_scissors_closed.png")
	_meter_tex = _tex(ART + "ch2_trim_smile_meter.png")
	_pointer_tex = _tex(ART + "ch2_trim_pointer.png")
	for k in 2:
		var t := _tex(ART + "ch2_trim_cotton_puff_%02d.png" % (k + 1))
		if t:
			_puff_tex.append(t)
	_flash_tex = _tex(ART + "ch2_trim_remote_flash.png")
	_letter_tex = _tex(ART + "ch2_trim_letter.png")


func _art() -> bool:
	return _base_tex != null


func play() -> void:
	if GameState.fast:
		quills = leave
		queue_free()
		return
	_running = true
	_start_quills = quills
	# 接著上一段剪剩的那幾根；對不上就從左邊數起
	if _carry.size() == quills:
		_alive = _carry.duplicate()
	else:
		_alive = range(clampi(quills, 0, TOTAL))
	if quills <= leave:
		_running = false
		queue_free()
		return
	await done
	queue_free()


func _quill_tip(k: int) -> Vector2:
	var head := ORIGIN + Vector2(0, -24) * SCALE
	var a := PI + PI * (k + 0.5) / TOTAL
	return head + Vector2.from_angle(a) * 34 * SCALE


## 美術版：第 k 根刺（QUILL_LAYOUT 索引）的中心、角度、長度
func _quill_xf(k: int) -> Array:
	# 角度、前後順序照 trimming_spines.json；位置改成「刺根插在頭的外圈」，
	# 因為交付的座標是給另一張頭圖排的，直接用會有幾根浮在半空中
	var q: Array = QUILL_LAYOUT[k]
	var ang := deg_to_rad(q[2]) * ARC + TILT
	var h: float = _quill_tex[k].get_height() * QUILL_SCALE if _quill_tex[k] else 60.0
	var pos := HEAD + Vector2(0, -(ROOT_R + h * 0.5)).rotated(ang)
	return [pos, ang, h]


func _quill_root(k: int) -> Vector2:
	var xf := _quill_xf(k)
	return xf[0] + Vector2(0, xf[2] * 0.5).rotated(xf[1])


func _quill_end(k: int) -> Vector2:
	var xf := _quill_xf(k)
	return xf[0] + Vector2(0, -xf[2] * 0.5).rotated(xf[1])


## 美術版的點擊判定：點在刺的那一段上（從根到尖）
func _hit_quill(pos: Vector2) -> int:
	var best := -1
	var best_d := 34.0
	for k in _alive:
		var d := pos.distance_to(Geometry2D.get_closest_point_to_segment(pos, _quill_root(k), _quill_end(k)))
		if d < best_d:
			best_d = d
			best = k
	return best


func _cut(k: int, close := false) -> void:
	if k >= quills:
		return
	quills -= 1
	_snip = 0.15
	var cut_at := Vector2.ZERO
	if _art() and not _alive.is_empty():
		# 美術版：剪掉點到的那一根（按 E 就剪最右邊那根）
		var hit := -1 if _key_cut else _hit_quill(_scissors)
		var idx := _alive.find(hit)
		if idx < 0:
			idx = _alive.size() - 1
		cut_at = _quill_root(_alive[idx])
		_alive.remove_at(idx)
		_carry = _alive.duplicate()
	_smile -= 0.22
	Tones.play(self, 1567.98, -12.0)
	if close:
		# 剪太靠近皮膚：剪到肉，棉花露出來
		if _art():
			_cotton.append(cut_at)
		else:
			_cotton.append(_quill_tip(k).lerp(ORIGIN + Vector2(0, -24) * SCALE, 0.7))
	if _smile < 0.25:
		_zap = 0.6
		_smile = 0.9
		Tones.buzz(self, 0.4)
	if quills <= leave:
		_running = false
		# 第一段剪完：肚子上的切口掉出一封信（劇本接著演）
		_letter = _start_quills == TOTAL and leave > 0
		_area.queue_redraw()
		await get_tree().create_timer(0.6).timeout
		done.emit()


func _process(delta: float) -> void:
	# 剪完之後還在等 0.6 秒：只讓閃光、剪刀動畫收尾
	if not _running and _zap <= 0.0 and _snip <= 0.0:
		return
	_zap = maxf(0.0, _zap - delta)
	_snip = maxf(0.0, _snip - delta)
	_area.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_scissors = event.position


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _art():
		_scissors = event.position
		var k := _hit_quill(event.position)
		if k >= 0:
			get_viewport().set_input_as_handled()
			# 點在刺根附近＝剪太靠近皮膚
			_key_cut = false
			_cut(quills - 1, event.position.distance_to(_quill_root(k)) < 16)
			return
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_scissors = event.position
		var head := ORIGIN + Vector2(0, -24) * SCALE
		for k in quills:
			var tip := _quill_tip(k)
			var d: float = event.position.distance_to(tip.lerp(head, 0.35))
			if d < 50:
				get_viewport().set_input_as_handled()
				_cut(quills - 1, event.position.distance_to(head) < 120)
				return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_key_cut = true
		_cut(quills - 1)


func _draw_area() -> void:
	if _art():
		_draw_art()
	else:
		_draw_fallback()


## 美術版：格紋桌布上躺著的小棘，刺一根一根是分開的圖層（畫在身體後面）
func _draw_art() -> void:
	var f: Font = GameState.font
	var a := _area
	if _bg_tex:
		a.draw_texture(_bg_tex, Vector2.ZERO)
	else:
		a.draw_rect(Rect2(0, 0, 1280, 720), Color("#f4f4f2"))
	a.draw_rect(Rect2(0, 22, 1280, 76), Color(1, 1, 1, 0.72))
	a.draw_string(f, Vector2(0, 50), GameState.hint("修剪！一根一根剪掉刺（點刺／按 E）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#c2558a"))
	a.draw_string(f, Vector2(0, 84), "注意不要剪到肉喔～　小棘的笑容要保持在綠色！", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#888888"))
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _zap
	# 刺：在身體後面
	for k in _alive:
		var xf := _quill_xf(k)
		var t: Texture2D = _quill_tex[k]
		a.draw_set_transform(xf[0] + shake, xf[1], Vector2(QUILL_SCALE, QUILL_SCALE))
		a.draw_texture(t, -t.get_size() * 0.5)
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 身體（素材右上角黏著一小塊別的東西，切掉）
	var bp := BASE_POS + shake
	a.draw_texture_rect_region(_base_tex, Rect2(bp, Vector2(688, 250)), Rect2(0, 0, 688, 250))
	a.draw_texture_rect_region(_base_tex, Rect2(bp + Vector2(0, 250), Vector2(800, 250)), Rect2(0, 250, 800, 250))
	# 剪到肉：棉花露出來
	for i in _cotton.size():
		var c: Vector2 = _cotton[i] + shake
		if _puff_tex.is_empty():
			a.draw_circle(c, 12, Color("#fbfbfb"))
			a.draw_arc(c, 12, 0, TAU, 12, Color("#c9c9c9"), 2)
		else:
			var pt: Texture2D = _puff_tex[i % _puff_tex.size()]
			a.draw_texture_rect(pt, Rect2(c - pt.get_size() * 0.25, pt.get_size() * 0.5), false)
	# 第一段剪完：肚子上的切口，掉出一封信
	if _letter and _letter_tex:
		_draw_letter(a, Vector2(735, 548))
	# 笑容計量表：綠色在左、紅色在右，指針指著現在的笑容
	if _meter_tex:
		a.draw_texture(_meter_tex, METER_POS)
		var w := _meter_tex.get_width()
		var px := METER_POS.x + w * clampf(1.0 - _smile, 0.0, 1.0)
		if _pointer_tex:
			a.draw_texture(_pointer_tex, Vector2(px - _pointer_tex.get_width() * 0.5, METER_POS.y - 38))
		else:
			a.draw_colored_polygon(PackedVector2Array([Vector2(px - 12, METER_POS.y - 30), Vector2(px + 12, METER_POS.y - 30), Vector2(px, METER_POS.y - 4)]), Color("#555555"))
		a.draw_string(f, METER_POS + Vector2(0, 92), "笑容", HORIZONTAL_ALIGNMENT_CENTER, w, 20, Color("#555555"))
	else:
		var meter := Rect2(METER_POS, Vector2(450, 60))
		a.draw_rect(meter, Color("#eeeeee"))
		a.draw_rect(Rect2(meter.position, Vector2(meter.size.x * _smile, 60)), Color("#7ccf8a") if _smile > 0.4 else Color("#e05780"))
		a.draw_rect(meter, Color("#9a9a9a"), false, 2)
		a.draw_string(f, METER_POS + Vector2(0, 92), "笑容", HORIZONTAL_ALIGNMENT_CENTER, 450, 20, Color("#555555"))
	a.draw_string(f, METER_POS + Vector2(0, 140), "剩下 %d 根" % quills, HORIZONTAL_ALIGNMENT_CENTER, 450, 22, Color("#8a4b68"))
	if _zap > 0:
		# 和平鴿按了遙控器：愛心閃一下，小棘的笑容又回來了
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _zap * 0.4))
		if _flash_tex:
			# 愛心在計量表綠色那一頭跳一下
			var k2 := 0.45 + (0.6 - _zap) * 0.4
			var sz := _flash_tex.get_size() * k2
			a.draw_texture_rect(_flash_tex, Rect2(METER_POS + Vector2(40, 30) - sz * 0.5, sz), false, Color(1, 1, 1, clampf(_zap * 2.5, 0.0, 1.0)))
		a.draw_string(f, Vector2(0, 680), "嗶——", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color("#e05780"))
	# 剪刀（刀尖對著滑鼠）
	if _scissors.x > 0:
		var st: Texture2D = _sc_closed if _snip > 0 and _sc_closed else _sc_open
		if st:
			var s := 0.42
			a.draw_texture_rect(st, Rect2(_scissors - Vector2(130, 14) * s, st.get_size() * s), false)
		else:
			_draw_scissors_fallback(a)


## 信封（外包圖上已經寫好「給希露飛　銘越」）
func _draw_letter(a: Control, at: Vector2) -> void:
	var s := 0.62
	var sz := _letter_tex.get_size() * s
	a.draw_set_transform(at, -0.12, Vector2.ONE)
	a.draw_texture_rect(_letter_tex, Rect2(-sz * 0.5, sz), false)
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_scissors_fallback(a: Control) -> void:
	a.draw_circle(_scissors + Vector2(-10, 14), 9, Color("#ff9ebb"))
	a.draw_circle(_scissors + Vector2(10, 14), 9, Color("#ff9ebb"))
	a.draw_line(_scissors + Vector2(-6, 6), _scissors + Vector2(8, -26), Color("#c0c0c0"), 4)
	a.draw_line(_scissors + Vector2(6, 6), _scissors + Vector2(-8, -26), Color("#c0c0c0"), 4)


## 沒有美術素材時的程序繪圖（原本的佔位畫面）
func _draw_fallback() -> void:
	var f: Font = GameState.font
	var a := _area
	a.draw_rect(Rect2(0, 0, 1280, 720), Color("#f4f4f2"))
	a.draw_string(f, Vector2(0, 50), GameState.hint("修剪！一根一根剪掉刺（點刺／按 E）"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#c2558a"))
	a.draw_string(f, Vector2(0, 84), "注意不要剪到肉喔～　小棘的笑容要保持在綠色！", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#888888"))
	a.draw_rect(Rect2(ORIGIN + Vector2(-200, 10), Vector2(400, 30)), Color("#bdbdbd"))
	var shake := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _zap
	a.draw_set_transform(ORIGIN + shake, 0.0, Vector2(SCALE, SCALE))
	Ch2Critter.draw(a, "hedgehog", Color("#3a3a3a"), 1.0, Vector2.ZERO, _smile > 0.4, false, false, {"quills": 0})
	a.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var head := ORIGIN + Vector2(0, -24) * SCALE + shake
	for k in quills:
		var ang := PI + PI * (k + 0.5) / TOTAL
		var base := head + Vector2.from_angle(ang) * 18 * SCALE
		var tip := head + Vector2.from_angle(ang) * 34 * SCALE
		var side := Vector2.from_angle(ang + PI / 2) * 9
		a.draw_colored_polygon(PackedVector2Array([base - side, base + side, tip]), Color("#2a2a2a"))
	for c in _cotton:
		a.draw_circle(c, 12, Color("#fbfbfb"))
		a.draw_arc(c, 12, 0, TAU, 12, Color("#c9c9c9"), 2)
	# 笑容計量表
	var meter := Rect2(1060, 200, 40, 300)
	a.draw_rect(meter, Color("#eeeeee"))
	a.draw_rect(Rect2(meter.position + Vector2(0, meter.size.y * (1 - _smile)), Vector2(40, meter.size.y * _smile)),
		Color("#7ccf8a") if _smile > 0.4 else Color("#e05780"))
	a.draw_rect(meter, Color("#9a9a9a"), false, 2)
	a.draw_string(f, Vector2(1000, 540), "笑容", HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color("#555555"))
	if _zap > 0:
		a.draw_string(f, Vector2(0, 680), "嗶——", HORIZONTAL_ALIGNMENT_CENTER, 1280, 34, Color("#e05780"))
		a.draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, _zap * 0.4))
	# 剪刀
	if _scissors.x > 0:
		a.draw_circle(_scissors + Vector2(-10, 14), 9, Color("#ff9ebb"))
		a.draw_circle(_scissors + Vector2(10, 14), 9, Color("#ff9ebb"))
		a.draw_line(_scissors + Vector2(-6, 6), _scissors + Vector2(8, -26), Color("#c0c0c0"), 4)
		a.draw_line(_scissors + Vector2(6, 6), _scissors + Vector2(-8, -26), Color("#c0c0c0"), 4)
	a.draw_string(f, Vector2(0, 620), "剩下 %d 根" % quills, HORIZONTAL_ALIGNMENT_CENTER, 1280, 22, Color("#8a4b68"))
