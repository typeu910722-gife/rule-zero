extends Node2D
## 小布。

const SPEED := 260.0
const STEP_TIME := 0.14      # 每一步動畫的時間
const FOOTSTEP_TIME := 0.32  # 腳步聲間隔

var bounds := Rect2(40, 110, 1800, 1540):
	set(v):
		bounds = v
		_update_camera()
var can_move := true
## 是否套用小鎮的建築碰撞
var collide := true
var _facing := Vector2.DOWN
var _step := -1
var _step_t := 0.0
var _foot_t := 0.0
var _cam: Camera2D


func _ready() -> void:
	GameState.changed.connect(queue_redraw)
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	add_child(_cam)
	_update_camera()


## 鏡頭範圍：小鎮、森林、小布的房間各自不同
func _update_camera() -> void:
	if _cam == null:
		return
	var area: Rect2
	if bounds.position.x > 2000:
		area = preload("res://scripts/world/town.gd").ROOM_VIEW
	elif bounds.end.y < 1200 and bounds.end.x < 1600:
		area = Rect2(0, 0, 1600, 1150)   # 森林
	else:
		var T := preload("res://scripts/world/town.gd")
		area = Rect2(0, 0, T.W, T.H - 120)
	_cam.limit_left = int(area.position.x)
	_cam.limit_top = int(area.position.y)
	_cam.limit_right = int(area.end.x)
	_cam.limit_bottom = int(area.end.y)
	_cam.reset_smoothing.call_deferred()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if can_move:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		if _step != -1:
			_step = -1
			queue_redraw()
		return
	_facing = dir
	var T := preload("res://scripts/world/town.gd")
	var check: bool = collide and bounds.position.x < 2000 and bounds.end.x > 1600
	var move := dir * SPEED * delta
	# 分軸移動：碰到建築時可以沿著牆滑過去
	for axis in [Vector2(move.x, 0), Vector2(0, move.y)]:
		var np: Vector2 = (position + axis).clamp(bounds.position, bounds.end)
		if not (check and T.blocked(np)):
			position = np
	_step_t += delta
	if _step < 0 or _step_t >= STEP_TIME:
		_step_t = 0.0
		_step = (_step + 1) % 4
	_foot_t -= delta
	if _foot_t <= 0.0:
		_foot_t = FOOTSTEP_TIME
		Sound.sfx("step")
	queue_redraw()


func _draw() -> void:
	Critter.draw(self, "sheep", Color.WHITE, Critter.WORLD_SCALE, _facing, true, false, GameState.has("tag_on"), _step)


func face(dir: Vector2) -> void:
	_facing = dir
	queue_redraw()


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
