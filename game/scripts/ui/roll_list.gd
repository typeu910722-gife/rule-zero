extends CanvasLayer
## 夜間點名的名單（第二章）：閃過 3 秒。第 8 個名字被墨水塗掉了。

const SHOW := 3.0
const NAMES := ["白面", "小棘", "條碼", "嘎嘎", "重重", "鼬鼬", "小布"]

const SHEET_TEX := "res://art/ch2/ui/ch2_ui_04_rollcall.png"
const BLACKOUT_TEX := "res://art/ch2/ui/ch2_ui_04_blackout.png"
## 點名簿底圖在畫面上的縮放（原圖 550×740）
const SHEET_SCALE := 0.85

## 第二晚：第 8 個名字沒有被塗掉，是「遙」
var haruka := false
var _area: Control


func _ready() -> void:
	layer = 45
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)


func show_and_wait() -> void:
	if not GameState.fast:
		await get_tree().create_timer(SHOW).timeout
	queue_free()


func _draw_area() -> void:
	var f: Font = GameState.font
	_area.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.35))
	if GameState.chapter == 2 and ResourceLoader.exists(SHEET_TEX):
		_draw_sheet(f)
		return
	var paper := Rect2(440, 70, 400, 560)
	_area.draw_rect(paper, Color("#f7f7f5"))
	_area.draw_rect(paper, Color("#8a8a8a"), false, 3)
	_area.draw_string(f, paper.position + Vector2(0, 56), "點名簿", HORIZONTAL_ALIGNMENT_CENTER, paper.size.x, 32, Color("#333333"))
	for k in NAMES.size() + 1:
		var y := paper.position.y + 120 + k * 56
		_area.draw_string(f, Vector2(paper.position.x + 60, y), "%d." % (k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#555555"))
		if k < NAMES.size():
			_area.draw_string(f, Vector2(paper.position.x + 120, y), NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#2e2e2e"))
		elif haruka:
			_area.draw_string(f, Vector2(paper.position.x + 120, y), "遙", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#2e2e2e"))
		else:
			# 被塗掉的第 8 個名字
			_area.draw_rect(Rect2(paper.position.x + 112, y - 28, 110, 36), Color("#1a1a1a"))
			_area.draw_circle(Vector2(paper.position.x + 230, y - 6), 7, Color("#1a1a1a"))


## 第二章：外包的點名簿底圖，名字寫在橫線上
func _draw_sheet(f: Font) -> void:
	var tex: Texture2D = _tex(SHEET_TEX)
	var size := tex.get_size() * SHEET_SCALE
	var o := Vector2((1280 - size.x) / 2, (720 - size.y) / 2)
	_area.draw_texture_rect(tex, Rect2(o, size), false)
	var s := SHEET_SCALE
	# 原圖的橫線在 y=110、180、…、670（間隔 70），第一格寫標題
	_area.draw_string(f, o + Vector2(0, 92 * s), "點名簿", HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color("#333333"))
	for k in NAMES.size() + 1:
		var base := o.y + (180 + k * 70 - 14) * s
		var x0 := o.x + 70 * s
		var x1 := o.x + 140 * s
		_area.draw_string(f, Vector2(x0, base), "%d." % (k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#555555"))
		if k < NAMES.size():
			_area.draw_string(f, Vector2(x1, base), NAMES[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#2e2e2e"))
		elif haruka:
			_area.draw_string(f, Vector2(x1, base), "遙", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#2e2e2e"))
		elif ResourceLoader.exists(BLACKOUT_TEX):
			# 被墨水塗掉的第 8 個名字（只取有墨水的部分）
			var ink: Texture2D = _tex(BLACKOUT_TEX)
			var src := Rect2(0, 0, 481, 62)
			var w := 200.0
			_area.draw_texture_rect_region(ink, Rect2(x1 - 12, base - 30, w, w * src.size.y / src.size.x * 1.4), src)
		else:
			_area.draw_rect(Rect2(x1 - 8, base - 28, 110, 36), Color("#1a1a1a"))
			_area.draw_circle(Vector2(x1 + 110, base - 6), 7, Color("#1a1a1a"))


## 畫圖時用到的貼圖要留著參照，不然畫完就被釋放、畫面上只剩白色
var _tex_cache := {}


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]
