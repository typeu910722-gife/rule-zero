class_name Ch3Mini
extends CanvasLayer
## 第三章小遊戲的共用底：白色醫院風格的畫面、標題、提示、輸入（鍵盤／滑鼠／觸控／手把）。
## 子類別覆寫 _setup()、_tick(delta)、_press(pressed)、_paint(c)；用 finish(result) 結束。
## play() 回傳 finish() 給的值。自動測試（GameState.fast）時直接回傳 fast_result。

signal done(result)

var title := ""
var hint := ""
var fast_result: Variant = true
## 底色（第四章用舊照片的暖色）
var bg_color := BG
var _canvas: Control
var _title: Label
var _hint: Label
var _finished := false
var _result: Variant
var t := 0.0
var held := false

const BG := Color("#f3f6f7")
const INK := Color("#3d4a4f")
const SOFT := Color("#9fb3ba")
const PINK := Color("#e98aa0")
const GREEN := Color("#7cc39a")
const RED := Color("#d65a5a")


func _ready() -> void:
	layer = 30
	_setup()
	var bg := ColorRect.new()
	bg.color = bg_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(func(): _paint(_canvas))
	add_child(_canvas)
	_title = _label(Vector2(0, 28), 34, INK)
	_hint = _label(Vector2(0, 660), 20, SOFT)
	_title.text = title
	_hint.text = hint


func _label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(1280, 48)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_hint(s: String) -> void:
	_hint.text = s


func play() -> Variant:
	if GameState.fast:
		await get_tree().process_frame
		queue_free()
		return fast_result
	Motif.play(self, "start")
	var r = await done
	# 回傳 false 才算失敗（有的小遊戲回傳次數、字串）
	Motif.play(self, "fail" if (r is bool and r == false) else "clear")
	await get_tree().create_timer(0.6).timeout
	queue_free()
	return r


func finish(result: Variant = true) -> void:
	if _finished:
		return
	_finished = true
	done.emit(result)


func _process(delta: float) -> void:
	if _finished:
		return
	t += delta
	_tick(delta)
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if _finished or GameState.is_touch_echo(event):
		return
	var p := -1
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		p = 1
	elif event.is_action_released("interact") or event.is_action_released("ui_accept"):
		p = 0
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		p = 1 if event.pressed else 0
	elif event is InputEventScreenTouch:
		p = 1 if event.pressed else 0
	if p == -1:
		_other_input(event)
		return
	get_viewport().set_input_as_handled()
	held = p == 1
	_press(p == 1, event)


## 子類別覆寫
func _setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _press(_down: bool, _event: InputEvent) -> void:
	pass


func _other_input(_event: InputEvent) -> void:
	pass


func _paint(_c: Control) -> void:
	pass


func sfx(path: String, db := -4.0) -> void:
	if GameState.fast:
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db + Audio.sfx_db()
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
