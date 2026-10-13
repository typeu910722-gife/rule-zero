extends Node2D
## 小布。

const SPEED := 230.0

var bounds := Rect2(20, 40, 1560, 1240)
var can_move := true
var _facing := Vector2.DOWN


func _ready() -> void:
	GameState.changed.connect(queue_redraw)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = 1600
	cam.limit_bottom = 1300
	cam.position_smoothing_enabled = true
	add_child(cam)


func _process(delta: float) -> void:
	if not can_move:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_facing = dir
		position += dir * SPEED * delta
		position = position.clamp(bounds.position, bounds.end)
		queue_redraw()


func _draw() -> void:
	Critter.draw(self, "sheep", Color("#fffdf8"), 1.0, _facing * 0.6, true, false, GameState.has("tag_on"))


func nearest(max_dist := -1.0) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if not it.visible:
			continue
		var d := position.distance_to(it.position)
		var limit := it.reach() if max_dist < 0 else max_dist
		if d < limit and d < best_d:
			best = it
			best_d = d
	return best
