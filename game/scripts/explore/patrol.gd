class_name ExplorePatrol
extends Node2D
## 巡邏的人（巡房護士、畢業生、和平鴿…）。
## 平常沿 path 或 roam 隨機巡邏；小布靠太近或進入視野後會加速追過來，
## 真的碰到才算被抓。躲進躲藏點仍能甩掉追兵。

var data: Dictionary
var explore: Node
var path: Array = []
var speed := 80.0
var view := 210.0
var fov := 0.75            # 半角（弧度）
var _i := 1
var _dir := 1
var facing := Vector2.RIGHT
var _wait := 0.0
var _alert := 0.0          # 看到的累積（0.35 秒才算被看到，擦身而過有機會）
var _chasing := false
var _random_patrol := false
var _roam := Rect2()
var _target := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _chase_speed := 230.0
var _aggro_distance := 250.0
var _lose_distance := 520.0
var _catch_distance := 30.0


func setup(d: Dictionary, ex: Node) -> void:
	data = d
	explore = ex
	for p in d.get("path", []):
		path.append(Vector2(float(p[0]), float(p[1])))
	speed = float(d.get("speed", 80))
	view = float(d.get("view", 210))
	fov = float(d.get("fov", 0.75))
	_chase_speed = float(d.get("chase_speed", maxf(210.0, speed * 2.8)))
	_aggro_distance = float(d.get("aggro_distance", view * 0.9))
	_lose_distance = float(d.get("lose_distance", view * 2.5))
	_catch_distance = float(d.get("catch_distance", 30.0))
	_random_patrol = bool(d.get("random", false))
	var rr: Array = d.get("roam", [])
	if rr.size() == 4:
		_roam = Rect2(float(rr[0]), float(rr[1]), float(rr[2]), float(rr[3]))
	_rng.seed = hash(str(d.get("id", "patrol")))
	reset()


func reset() -> void:
	if path.is_empty():
		return
	position = path[0]
	_i = 1 if path.size() > 1 else 0
	_dir = 1
	_alert = 0.0
	_wait = 0.0
	_set_chasing(false)
	_pick_random_target()


func active() -> bool:
	var w: String = data.get("when", "")
	return w == "" or GameState.check(w)


func _process(delta: float) -> void:
	visible = active()
	if not visible or explore.busy or explore.paused:
		queue_redraw()
		return
	var pl: ExplorePlayer = explore.player
	var hidden: bool = pl.tucked or explore.hidden_in != ""
	var v: Vector2 = pl.position - position
	if _chasing:
		if hidden or v.length() > _lose_distance:
			_set_chasing(false)
			_wait = float(data.get("pause", 0.8))
			_pick_random_target()
		else:
			_move_toward(pl.position, _chase_speed, delta)
			if position.distance_to(pl.position) <= _catch_distance:
				_set_chasing(false)
				explore.on_spotted(data)
			queue_redraw()
			return
	else:
		_patrol(delta)
		v = pl.position - position
		var see := false
		if not hidden:
			# 離太近不需要站在視野正前方；護士會察覺，轉身衝過來。
			see = v.length() < _aggro_distance
			if not see and v.length() < view:
				see = absf(facing.angle_to(v)) < fov
		_alert = _alert + delta if see else maxf(0.0, _alert - delta * 1.7)
		if _alert > 0.28:
			_alert = 0.0
			_set_chasing(true)
	queue_redraw()


func _patrol(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	if _random_patrol and not _roam.has_area():
		_random_patrol = false
	if _random_patrol:
		if position.distance_to(_target) < 8.0:
			_wait = _rng.randf_range(float(data.get("pause", 0.8)) * 0.45, float(data.get("pause", 0.8)) * 1.35)
			_pick_random_target()
		else:
			_move_toward(_target, speed, delta)
	elif path.size() > 1:
		var target: Vector2 = path[_i]
		if position.distance_to(target) < 4.0:
			_wait = float(data.get("pause", 0.8))
			if _i + _dir >= path.size() or _i + _dir < 0:
				_dir = -_dir
			_i += _dir
		else:
			_move_toward(target, speed, delta)


func _pick_random_target() -> void:
	if not _random_patrol or not _roam.has_area() or explore == null or explore.player == null:
		return
	for k in 18:
		var p := Vector2(_rng.randf_range(_roam.position.x, _roam.end.x),
			_rng.randf_range(_roam.position.y, _roam.end.y))
		if not explore.player.blocked(p):
			_target = p
			return
	_target = position


func _move_toward(target: Vector2, move_speed: float, delta: float) -> void:
	var to := target - position
	if to.length() < 0.1:
		return
	facing = to.normalized()
	var step := facing * minf(move_speed * delta, to.length())
	# 跟玩家一樣分軸滑牆，追逐時不會穿過病床與櫃子。
	for axis in [Vector2(step.x, 0), Vector2(0, step.y)]:
		var next: Vector2 = position + axis
		if not explore.player.blocked(next):
			position = next


func _set_chasing(on: bool) -> void:
	if _chasing == on:
		return
	_chasing = on
	if explore and explore.has_method("patrol_chase_changed"):
		explore.patrol_chase_changed(on, str(data.get("id", data.get("char", ""))))


func _draw() -> void:
	if not visible:
		return
	# 視野扇形
	var pts := PackedVector2Array([Vector2.ZERO])
	for k in 13:
		pts.append(Vector2.from_angle(facing.angle() - fov + fov * 2.0 * k / 12.0) * (view if not _chasing else minf(view, 120.0)))
	draw_colored_polygon(pts, Color(1, 0.22, 0.28, 0.34 if _chasing else 0.10 + _alert * 0.5))
	var who: String = data.get("char", "staff")
	if who.begins_with("human:"):
		ExploreArt.draw_human(self, Vector2.ZERO, who.trim_prefix("human:"), 0 if facing.y > 0 else 3, true, Time.get_ticks_msec() / 1000.0)
	else:
		ExploreArt.draw_char(self, who, Vector2.ZERO, facing.x < 0, ExploreArt.walk_row(facing), int(Time.get_ticks_msec() / 140.0) % 4)
