class_name ExplorePatrol
extends Node2D
## 巡邏的人（巡房護士、畢業生、和平鴿…）：沿著 path 來回走，前方有一個扇形視野。
## 小布在視野裡、而且沒有躲起來 → 被看到（Explore.on_spotted）。
## JSON：{"id", "char", "path": [[x,y]...], "speed", "view", "fov", "when", "catch"(被抓到時的對話)}

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


func setup(d: Dictionary, ex: Node) -> void:
	data = d
	explore = ex
	for p in d.get("path", []):
		path.append(Vector2(float(p[0]), float(p[1])))
	speed = float(d.get("speed", 80))
	view = float(d.get("view", 210))
	fov = float(d.get("fov", 0.75))
	reset()


func reset() -> void:
	if path.is_empty():
		return
	position = path[0]
	_i = 1 if path.size() > 1 else 0
	_dir = 1
	_alert = 0.0


func active() -> bool:
	var w: String = data.get("when", "")
	return w == "" or GameState.check(w)


func _process(delta: float) -> void:
	visible = active()
	if not visible or explore.busy or explore.paused:
		queue_redraw()
		return
	if _wait > 0.0:
		_wait -= delta
	elif path.size() > 1:
		var target: Vector2 = path[_i]
		var to := target - position
		if to.length() < 4.0:
			_wait = float(data.get("pause", 0.8))
			if _i + _dir >= path.size() or _i + _dir < 0:
				_dir = -_dir
			_i += _dir
		else:
			facing = to.normalized()
			position += facing * minf(speed * delta, to.length())
	# 視野
	var pl: ExplorePlayer = explore.player
	var see := false
	if not pl.tucked and explore.hidden_in == "":
		var v := pl.position - position
		if v.length() < view and absf(facing.angle_to(v)) < fov:
			see = true
		elif v.length() < 34.0:
			see = true
	_alert = _alert + delta if see else maxf(0.0, _alert - delta)
	if _alert > 0.35:
		_alert = 0.0
		explore.on_spotted(data)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	# 視野扇形
	var pts := PackedVector2Array([Vector2.ZERO])
	for k in 13:
		pts.append(Vector2.from_angle(facing.angle() - fov + fov * 2.0 * k / 12.0) * view)
	draw_colored_polygon(pts, Color(1, 0.35, 0.4, 0.10 + _alert * 0.5))
	var who: String = data.get("char", "staff")
	if who.begins_with("human:"):
		ExploreArt.draw_human(self, Vector2.ZERO, who.trim_prefix("human:"), 0 if facing.y > 0 else 3, true, Time.get_ticks_msec() / 1000.0)
	else:
		ExploreArt.draw_char(self, who, Vector2.ZERO, facing.x < 0, ExploreArt.walk_row(facing), int(Time.get_ticks_msec() / 140.0) % 4)
