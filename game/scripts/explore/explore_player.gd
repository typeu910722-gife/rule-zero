class_name ExplorePlayer
extends Node2D
## 第三～五章室內探索的小布（人類時期的章節由 look 指定別的樣子）。
## 上下左右（或觸控搖桿）走動；撞到房間的牆、家具會沿著邊滑過去。

const SPEED := 220.0
const RADIUS := 16.0

var can_move := true
var tucked := false   # 躲起來了（看不到、不能走）
var blockers: Array = []          # Array[Rect2]（房間座標）
var bounds := Rect2(0, 0, 1280, 720)
## 外觀："pip"（玩偶小布，用地圖小人圖）或 "human:<顏色>"（第四章人類時期：簡單的人影）
var look := "pip"
var facing := Vector2.DOWN
var moving := false
var _walk_t := 0.0
## 走過的路（給跟在後面的同伴用）
var trail: Array = []


func _process(delta: float) -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down") if can_move and not tucked else Vector2.ZERO
	var was := moving
	moving = dir != Vector2.ZERO
	if moving:
		facing = dir
		_walk_t += delta
		_move(dir * SPEED * delta)
		if trail.is_empty() or (trail[0] as Vector2).distance_to(position) > 6.0:
			trail.push_front(position)
			if trail.size() > 400:
				trail.pop_back()
	if moving or was:
		queue_redraw()


func _move(step: Vector2) -> void:
	for axis in [Vector2(step.x, 0), Vector2(0, step.y)]:
		if axis == Vector2.ZERO:
			continue
		var np: Vector2 = (position + axis).clamp(bounds.position + Vector2(RADIUS, RADIUS), bounds.end - Vector2(RADIUS, RADIUS))
		if not blocked(np):
			position = np


func blocked(p: Vector2) -> bool:
	var me := Rect2(p - Vector2(RADIUS, RADIUS * 0.6), Vector2(RADIUS * 2, RADIUS * 1.2))
	for r in blockers:
		if (r as Rect2).intersects(me):
			return true
	return false


func place(p: Vector2) -> void:
	position = p
	trail.clear()
	# 同伴一開始排在小布後面（往下排成一列）
	for k in 60:
		trail.append(p + Vector2(0, k * 5.0))
	queue_redraw()


func _row() -> int:
	if absf(facing.x) > absf(facing.y):
		return 1 if facing.x < 0 else 2
	return 3 if facing.y < 0 else 0


func _draw() -> void:
	if tucked:
		return
	draw_set_transform(Vector2.ZERO)
	# 影子
	draw_circle(Vector2(0, 2), 14, Color(0, 0, 0, 0.12))
	if look == "pip":
		var col := int(_walk_t * 8.0) % 4 if moving else 0
		var tex := ExploreArt.tex(ExploreArt.PIP_SHEET_MARKS if GameState.day >= 3 else ExploreArt.PIP_SHEET)
		if tex:
			draw_texture_rect_region(tex, Rect2(Vector2(-40, -76), Vector2(80, 80)), Rect2(col * 160, _row() * 160, 160, 160))
			return
	ExploreArt.draw_human(self, Vector2.ZERO, look.trim_prefix("human:") if look.begins_with("human:") else "#6d7f8a", _row(), moving, _walk_t)
