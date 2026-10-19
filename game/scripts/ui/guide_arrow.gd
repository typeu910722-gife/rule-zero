class_name GuideArrow
extends CanvasLayer
## 目標方向提示：目前要去的地方不在畫面裡時，畫面邊緣出現一個小箭頭指過去。
## main.gd 每一幀呼叫 point_to(畫面座標, 名字)；沒有目標時 point_to(null)。

const MARGIN := 46.0
## 上面留給狀態欄、下面留給提示文字
const SAFE_DESKTOP := Rect2(46, 96, 1280 - 92, 720 - 96 - 70)
## 手機：再避開左下的搖桿、右下的按鈕
const SAFE_TOUCH := Rect2(46, 96, 1280 - 46 - 175, 720 - 96 - 200)
var SAFE := SAFE_DESKTOP
var touch := false:
	set(v):
		touch = v
		SAFE = SAFE_TOUCH if v else SAFE_DESKTOP

var _node: Node2D
var _has := false
var _pos := Vector2.ZERO
var _dir := Vector2.RIGHT
var _name := ""
var _alpha := 0.0


func _ready() -> void:
	layer = 15
	_node = Node2D.new()
	add_child(_node)
	_node.draw.connect(_draw_arrow)


## screen：目標在畫面上的座標（可能在畫面外）；null = 不顯示
func point_to(screen: Variant, label := "") -> void:
	if screen == null:
		_has = false
		return
	var p: Vector2 = screen
	var view := Rect2(Vector2.ZERO, Vector2(1280, 720)).grow(-30)
	if view.has_point(p):
		# 在畫面裡：頭上的「！」已經看得到，不用箭頭
		_has = false
		return
	var c := SAFE.get_center()
	_dir = (p - c).normalized()
	# 從畫面中心往目標方向，碰到安全範圍的邊為止
	var tx := INF
	var ty := INF
	if absf(_dir.x) > 0.001:
		tx = ((SAFE.end.x if _dir.x > 0 else SAFE.position.x) - c.x) / _dir.x
	if absf(_dir.y) > 0.001:
		ty = ((SAFE.end.y if _dir.y > 0 else SAFE.position.y) - c.y) / _dir.y
	_pos = c + _dir * minf(tx, ty)
	_name = label
	_has = true


func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, 1.0 if _has else 0.0, delta * 4.0)
	_node.visible = _alpha > 0.01
	if _node.visible:
		_node.queue_redraw()


func _draw_arrow() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var bob := sin(t * 5.0) * 5.0
	var p := _pos + _dir * bob
	var a := _alpha
	var side := _dir.orthogonal()
	var tip := p + _dir * 22
	var pts := PackedVector2Array([tip, p - _dir * 10 + side * 16, p - _dir * 2, p - _dir * 10 - side * 16])
	# 外框＋粉紅色箭頭
	var outline := PackedVector2Array()
	for q in pts:
		outline.append(p + (q - p) * 1.28)
	_node.draw_colored_polygon(outline, Color(1, 1, 1, 0.92 * a))
	_node.draw_colored_polygon(pts, Color(0.878, 0.341, 0.502, a))
	if _name == "":
		return
	var f: Font = GameState.font
	var fs := 18
	var w := f.get_string_size(_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# 名字放在箭頭內側，不要超出畫面
	var lp := p - _dir * 44 + Vector2(-w / 2, 6)
	lp.x = clampf(lp.x, 8, 1280 - w - 8)
	lp.y = clampf(lp.y, 30, 700)
	_node.draw_string_outline(f, lp, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(1, 1, 1, 0.9 * a))
	_node.draw_string(f, lp, _name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.427, 0.349, 0.478, a))
