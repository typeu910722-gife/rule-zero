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
## 在房間裡畫大一點（房間的美術比例比小鎮地圖大）
var draw_scale := 1.0
## 在森林裡：用森林的小徑判斷能不能走
var in_forest := false:
	set(v):
		in_forest = v
		_update_camera()
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
	draw_scale = 1.0
	if bounds.position.x > 2000:
		area = preload("res://scripts/world/town.gd").ROOM_VIEW
		draw_scale = 1.9
	elif in_forest:
		var F := preload("res://scripts/world/forest.gd")
		area = Rect2(0, 0, F.W, F.H)
	else:
		var T := preload("res://scripts/world/town.gd")
		area = Rect2(0, 0, T.W, T.H)
	_cam.limit_left = int(area.position.x)
	_cam.limit_top = int(area.position.y)
	_cam.limit_right = int(area.end.x)
	_cam.limit_bottom = int(area.end.y)
	_cam.reset_smoothing.call_deferred()
	queue_redraw()


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
	var T: GDScript = preload("res://scripts/world/forest.gd") if in_forest else preload("res://scripts/world/town.gd")
	var check: bool = collide and (in_forest or (bounds.position.x < 2000 and bounds.end.x > 1600))
	var move := dir * SPEED * delta
	# 分軸移動：碰到建築時可以沿著牆滑過去
	# 萬一被劇情放在路外面（例如草地上）：先移到最近的路上
	if check and T.blocked(position):
		position = T.nearest_walkable(position)
	var moved_any := false
	for axis in [Vector2(move.x, 0), Vector2(0, move.y)]:
		if axis == Vector2.ZERO:
			continue
		var np: Vector2 = (position + axis).clamp(bounds.position, bounds.end)
		if not (check and T.blocked(np)) and not _bumps_npc(np):
			position = np
			moved_any = true
	# 卡在轉角時：看看旁邊一點點有沒有路，有的話順著滑過去（不用玩家對準縫隙）
	if check and not moved_any:
		var forward := move
		var side := Vector2(-forward.y, forward.x).normalized()
		for k in [6.0, 12.0, 18.0, 24.0]:
			var found := false
			for sgn in [1.0, -1.0]:
				var off: Vector2 = side * k * sgn
				if not T.blocked(position + off) and not T.blocked(position + off + forward) and not _bumps_npc(position + off + forward):
					position += off.normalized() * minf(SPEED * delta, off.length())
					found = true
					break
			if found:
				break
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
	Critter.draw(self, "sheep", Color.WHITE, Critter.WORLD_SCALE * draw_scale, _facing, true, false, GameState.has("tag_on"), _step)


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


## 不要穿過其他角色（只擋「越走越近」的方向，所以永遠不會被卡住）
func _bumps_npc(np: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it.kind != "npc" or not it.visible or (in_forest and it.id == "fen"):
			continue
		var d_new := (np - it.position) * Vector2(1.0, 1.8)
		var d_old := (position - it.position) * Vector2(1.0, 1.8)
		if d_new.length() < 40.0 and d_new.length() < d_old.length():
			return true
	return false
