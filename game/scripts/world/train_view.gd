class_name TrainView
extends Control
## 序章的粉紅車廂（@bg train）：「粉紅色的車廂。窗外是棉花糖一樣的雲。」
## 正式美術到之前的程式繪製版。窗外三層視差：遠雲（慢）、近雲（快）、電線桿（最快）；車廂輕輕搖晃。

const WALL := Color("#f6d6e6")
const WAINSCOT := Color("#e8b4c8")
const TRIM := Color("#fff4e8")
const SEAT := Color("#d98ba8")
const SEAT_DARK := Color("#c27593")
const CURTAIN := Color("#f2a7c3")
const WINDOWS := [Rect2(150, 90, 400, 270), Rect2(730, 90, 400, 270)]

var _t := 0.0
var _windows: Array[Control] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in WINDOWS:
		var w := Control.new()
		w.position = r.position
		w.size = r.size
		w.clip_contents = true
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.draw.connect(_draw_outside.bind(w))
		add_child(w)
		_windows.append(w)
	visibility_changed.connect(func(): set_process(is_visible_in_tree()))
	set_process(is_visible_in_tree())


func _process(delta: float) -> void:
	_t += delta
	var sway := _sway()
	for k in _windows.size():
		_windows[k].position = WINDOWS[k].position + sway
		_windows[k].queue_redraw()
	queue_redraw()


func _sway() -> Vector2:
	return Vector2(0, sin(_t * 2.2) * 2.0 + sin(_t * 7.0) * 0.4)


func _draw() -> void:
	var s := _sway()
	draw_rect(Rect2(0, 0, 1280, 720), WALL)
	# 車頂的弧線與吊燈
	draw_rect(Rect2(0, 0, 1280, 40), WAINSCOT.lightened(0.25))
	for x in [350, 930]:
		draw_line(Vector2(x, 40) + s, Vector2(x, 62) + s, SEAT_DARK, 2)
		draw_circle(Vector2(x, 70) + s, 10, TRIM)
	# 下半部的護牆板
	draw_rect(Rect2(0, 430, 1280, 290), WAINSCOT)
	draw_line(Vector2(0, 430), Vector2(1280, 430), TRIM, 6)
	for x in range(40, 1280, 80):
		draw_line(Vector2(x, 450), Vector2(x, 720), WAINSCOT.darkened(0.06), 2)
	for r in WINDOWS:
		var rr: Rect2 = Rect2(r.position + s, r.size)
		# 窗框（縫線）
		draw_rect(rr.grow(16), TRIM)
		_stitch(rr.grow(9))
		# 綁起來的窗簾
		_curtain(rr.position + Vector2(-34, -10), 1.0)
		_curtain(rr.position + Vector2(rr.size.x + 34, -10), -1.0)
	# 椅背
	for r in WINDOWS:
		var base: Vector2 = Vector2(r.position.x + r.size.x / 2.0, 478) + s * 0.5
		_rounded(Rect2(base - Vector2(230, 40), Vector2(460, 140)), 36, SEAT)
		_rounded(Rect2(base - Vector2(210, 22), Vector2(420, 24)), 12, SEAT_DARK)


## 窗外：天空漸層、遠雲、近雲、電線桿
func _draw_outside(w: Control) -> void:
	var sz := w.size
	var top := Color("#ffd9e8")
	var bottom := Color("#d6ecff")
	for i in 12:
		var y0 := sz.y * i / 12.0
		w.draw_rect(Rect2(0, y0, sz.x, sz.y / 12.0 + 1), top.lerp(bottom, i / 11.0))
	var offset := w.position.x
	_clouds(w, offset, 18.0, 0.55, 90.0, Color(1, 0.94, 0.97, 0.9), 7)
	_clouds(w, offset, 60.0, 1.0, 175.0, Color(1, 1, 1, 0.95), 5)
	# 電線桿：很快地掠過
	var span := 520.0
	var px := fposmod(-(_t * 420.0 + offset), span)
	w.draw_rect(Rect2(px, 0, 10, sz.y), Color("#b8a1c9"))
	w.draw_line(Vector2(px - span, 40), Vector2(px + span, 40), Color("#b8a1c9"), 2)


## 一層棉花糖雲：speed 像素／秒，k_size 雲的大小，y 高度
func _clouds(w: Control, offset: float, speed: float, k_size: float, y: float, color: Color, count: int) -> void:
	var span := 1280.0
	for k in count:
		var n := float(k) * 97.3
		var x := fposmod(n * 3.1 - _t * speed - offset, span) - 200.0
		var cy := y + sin(n) * 40.0 * k_size
		var r := (38.0 + fmod(n, 22.0)) * k_size
		w.draw_circle(Vector2(x, cy), r, color)
		w.draw_circle(Vector2(x + r * 0.9, cy + r * 0.2), r * 0.8, color)
		w.draw_circle(Vector2(x - r * 0.9, cy + r * 0.25), r * 0.7, color)
		w.draw_circle(Vector2(x + r * 0.2, cy - r * 0.5), r * 0.75, color)


func _curtain(top: Vector2, dir: float) -> void:
	var pts := PackedVector2Array([top, top + Vector2(46 * dir, 0), top + Vector2(18 * dir, 150),
		top + Vector2(40 * dir, 300), top + Vector2(0, 300)])
	draw_colored_polygon(pts, CURTAIN)
	draw_circle(top + Vector2(18 * dir, 150), 9, TRIM)


func _stitch(r: Rect2) -> void:
	var c := WAINSCOT.darkened(0.15)
	var x := r.position.x
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x + 8, r.position.y), c, 2)
		draw_line(Vector2(x, r.end.y), Vector2(x + 8, r.end.y), c, 2)
		x += 16
	var y := r.position.y
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x, y + 8), c, 2)
		draw_line(Vector2(r.end.x, y), Vector2(r.end.x, y + 8), c, 2)
		y += 16


func _rounded(r: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	draw_style_box(sb, r)
