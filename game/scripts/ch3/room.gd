class_name Ch3Room
extends CanvasLayer
## 第三章的「房間」：一張背景（有自製美術就用 art/ch3/bg/ch3_bg_<id>.jpg，沒有就用程式畫的佔位圖）＋可以調查的地方。
## 調查點是按鈕：滑鼠、觸控、鍵盤／手把（方向鍵選、E 確認）都能用。
## spots: [{id, name, rect, when}]；when 是 GameState.check 的條件（空＝一直都在）。
## 按下調查點 → 發出 picked(id)；章節導演跑完對話後呼叫 refresh()。

signal picked(id: String)

var room_id := ""
var spots: Array = []
var _bg_tex: Texture2D
var _draw: Control
var _buttons: Control
var busy := false


func _ready() -> void:
	layer = 10
	var art := "res://art/ch3/bg/ch3_bg_%s.jpg" % room_id
	if ResourceLoader.exists(art):
		_bg_tex = load(art)
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_paint)
	add_child(_draw)
	_buttons = Control.new()
	_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_buttons)
	refresh()


func refresh() -> void:
	for b in _buttons.get_children():
		b.queue_free()
	var first: Button = null
	for s in spots:
		if s.get("when", "") != "" and not GameState.check(s.when):
			continue
		var b := Button.new()
		b.text = s.name
		var r: Rect2 = s.rect
		b.position = r.position
		b.custom_minimum_size = r.size
		b.size = r.size
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color("#2e3a3f"))
		b.add_theme_color_override("font_hover_color", Color("#2e3a3f"))
		b.add_theme_color_override("font_focus_color", Color("#2e3a3f"))
		var exit: bool = s.get("exit", false)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(1, 1, 1, 0.55) if not exit else Color("#f6d0da")
		normal.border_color = Color("#7c98a2") if not exit else Color("#d4788f")
		normal.set_border_width_all(2)
		normal.set_corner_radius_all(10)
		var focus := normal.duplicate()
		focus.bg_color = Color(1, 1, 1, 0.9)
		focus.border_color = Color("#e98aa0")
		focus.set_border_width_all(4)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", focus)
		b.add_theme_stylebox_override("focus", focus)
		b.add_theme_stylebox_override("pressed", focus)
		var id: String = s.id
		b.pressed.connect(func():
			if busy:
				return
			picked.emit(id))
		_buttons.add_child(b)
		if first == null:
			first = b
	_buttons.visible = not busy
	if first and not busy and not GameState.touch_ui():
		first.grab_focus.call_deferred()


func set_busy(on: bool) -> void:
	busy = on
	_buttons.visible = not on
	if not on:
		refresh()


# ───────── 沒有美術時的佔位圖：用簡單的形狀畫出房間 ─────────

func _paint() -> void:
	var c := _draw
	if _bg_tex:
		c.draw_texture_rect(_bg_tex, Rect2(0, 0, 1280, 720), false)
		return
	var wall := Color("#eef2f3")
	var floor_col := Color("#dfe5e7")
	var line := Color("#b9c6cb")
	match room_id:
		"wild":
			wall = Color("#8d9797"); floor_col = Color("#6d7676"); line = Color("#4f5757")
		"b2", "monitor":
			wall = Color("#1f2629"); floor_col = Color("#161b1d"); line = Color("#33403f")
		"records":
			wall = Color("#dcdcd6"); floor_col = Color("#c9c9c2")
		"nirvana":
			wall = Color("#e3eaee"); floor_col = Color("#d3dde2")
	c.draw_rect(Rect2(0, 0, 1280, 720), wall)
	c.draw_rect(Rect2(0, 470, 1280, 250), floor_col)
	c.draw_line(Vector2(0, 470), Vector2(1280, 470), line, 3.0)
	match room_id:
		"hall":
			# 發光的指示線
			for k in 3:
				var col: Color = [Color("#f5a3b8"), Color("#9cc8e6"), Color("#9fd8b0")][k]
				c.draw_line(Vector2(0, 560 + k * 22), Vector2(980, 560 + k * 22), col, 6.0)
				c.draw_line(Vector2(980, 560 + k * 22), Vector2(1240, 480), col, 6.0)
			# 窗與白鴿
			for x in [120, 420, 720]:
				c.draw_rect(Rect2(x, 120, 200, 200), Color("#d6e8f0"))
				c.draw_rect(Rect2(x, 120, 200, 200), line, false, 4.0)
				c.draw_circle(Vector2(x + 100, 312), 20, Color.WHITE)
				c.draw_circle(Vector2(x + 112, 300), 9, Color.WHITE)
				c.draw_circle(Vector2(x + 115, 298), 2.5, Color("#d33"))
			# 護理站
			c.draw_rect(Rect2(960, 330, 300, 150), Color("#ffffff"))
			c.draw_rect(Rect2(960, 330, 300, 150), line, false, 3.0)
		"nirvana":
			for row in 2:
				for k in 6:
					var x := 60.0 + k * 200.0 + row * 40.0
					var y := 300.0 + row * 170.0
					c.draw_rect(Rect2(x, y, 150, 70), Color.WHITE)
					c.draw_rect(Rect2(x, y, 150, 70), line, false, 2.0)
					c.draw_circle(Vector2(x + 30, y + 20), 14, Color("#e8d2c0"))
					c.draw_line(Vector2(x + 30, y + 6), Vector2(x + 30, 0), Color("#9fb3ba"), 1.0)
		"records":
			for k in 7:
				c.draw_rect(Rect2(60 + k * 170, 120, 140, 350), Color("#b8bdb6"))
				for d in 4:
					c.draw_rect(Rect2(70 + k * 170, 140 + d * 80, 120, 60), Color("#c9cec6"))
			c.draw_rect(Rect2(1040, 180, 180, 290), Color("#8d7b66"))
		"wild":
			for k in 5:
				c.draw_rect(Rect2(40 + k * 250, 140, 160, 320), Color("#3e4545"))
				c.draw_rect(Rect2(90 + k * 250, 220, 50, 160), Color("#c9d6e3"))
				c.draw_circle(Vector2(115 + k * 250, 200), 26, Color("#e8c9b0"))
		"b2":
			c.draw_rect(Rect2(1150, 60, 70, 34), Color("#3fa36b"))
			for k in 3:
				c.draw_rect(Rect2(140 + k * 320, 360, 220, 80), Color("#2c3436"))
			c.draw_rect(Rect2(60, 160, 120, 300), Color("#2a3133"))
	# 夜裡的燈一閃一閃
	if room_id == "wild" and fmod(Time.get_ticks_msec() / 1000.0, 3.1) < 0.12:
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))


func _process(_d: float) -> void:
	if room_id == "wild":
		_draw.queue_redraw()
