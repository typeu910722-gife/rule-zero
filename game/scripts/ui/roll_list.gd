extends CanvasLayer
## 夜間點名的名單（第二章）：閃過 3 秒。第 8 個名字被墨水塗掉了。

const SHOW := 3.0
const NAMES := ["白面", "小棘", "條碼", "嘎嘎", "重重", "鼬鼬", "小布"]

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
