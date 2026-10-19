extends Node2D
## 小布。

const SPEED := 230.0

var bounds := Rect2(20, 40, 1560, 1000)
## 走不進去的區域（第二章：鐵絲網另一邊的河與模範生宿舍）
var blocked := PackedVector2Array()
var can_move := true
var _facing := Vector2.DOWN
## 第二章：外包的小布小人（4 方向 × 4 格；由上到下：下、左、右、上）
const SHEET := "res://art/ch2/characters/sprites/ch2_pip_sprite_walk_sheet.png"
const SHEET_MARKS := "res://art/ch2/characters/sprites/ch2_pip_sprite_walk_marks_sheet.png"
var _sheets := {}
var _walk_t := 0.0
var _moving := false


func _ready() -> void:
	GameState.changed.connect(queue_redraw)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 1600
	cam.limit_bottom = 1150
	cam.position_smoothing_enabled = true
	add_child(cam)


func _process(delta: float) -> void:
	if not can_move:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if (dir != Vector2.ZERO) != _moving:
		_moving = dir != Vector2.ZERO
		queue_redraw()
	if dir != Vector2.ZERO:
		_walk_t += delta
		_facing = dir
		var before := position
		position += dir * SPEED * delta
		position = position.clamp(bounds.position, bounds.end)
		if not blocked.is_empty() and Geometry2D.is_point_in_polygon(position, blocked):
			position = before
		queue_redraw()


func _sheet() -> Texture2D:
	if GameState.chapter != 2:
		return null
	# 第二天夜晚的治療室之後，手腕上有兩圈紅痕
	var path := SHEET_MARKS if GameState.day >= 3 else SHEET
	if not _sheets.has(path):
		_sheets[path] = load(path) if ResourceLoader.exists(path) else null
	return _sheets[path]


func _draw() -> void:
	var tex := _sheet()
	if tex:
		var row := 0
		if absf(_facing.x) > absf(_facing.y):
			row = 1 if _facing.x < 0 else 2
		elif _facing.y < 0:
			row = 3
		var col := int(_walk_t * 8.0) % 4 if _moving else 0
		draw_texture_rect_region(tex, Rect2(Vector2(-40, -76), Vector2(80, 80)), Rect2(col * 160, row * 160, 160, 160))
		return
	Ch2Critter.draw(self, "sheep", Color("#fffdf8"), 1.0, _facing * 0.6, true, false, GameState.has("tag_on"),
		{"grey_patch": GameState.has("c2_grey_patch")})


func nearest(max_dist := -1.0) -> Ch2Interactable:
	var best: Ch2Interactable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Ch2Interactable
		if not it.visible:
			continue
		var d := position.distance_to(it.position)
		var limit := it.reach() if max_dist < 0 else max_dist
		if d < limit and d < best_d:
			best = it
			best_d = d
	return best
