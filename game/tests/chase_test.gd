extends SceneTree
## 追逐戰：用跟玩家一樣的操作（前進＋左右轉）沿著正確的路跑，
## 確認跑得到修理室、而且正常跑的話不會被鎮長抓到；停下來不動的話會被抓到。
## godot --headless -s tests/chase_test.gd

var failures := 0
var closest := INF


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _release() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


## 開著車跑：朝下一個格子中心轉過去、往前走
func _drive(c, max_time: float) -> float:
	var t := 0.0
	var idx := 1
	while t < max_time and not c._done:
		var route: Array = c._route
		var here: Vector2i = c._cell_of(c._bu.position)
		var k := route.find(here)
		if k >= 0:
			idx = maxi(idx, k + 1)
		idx = mini(idx, route.size() - 1)
		var target: Vector3 = c.cell_center(route[idx])
		var to: Vector3 = target - c._bu.position
		var want := atan2(-to.x, -to.z)
		var diff := wrapf(want - c._heading, -PI, PI)
		_release()
		if diff > 0.08:
			Input.action_press("move_left", clampf(absf(diff) * 2.0, 0.3, 1.0))
		elif diff < -0.08:
			Input.action_press("move_right", clampf(absf(diff) * 2.0, 0.3, 1.0))
		if absf(diff) < 0.7:
			Input.action_press("move_up", 1.0)
		await process_frame
		t += c.get_process_delta_time()
		if c._mayor_on and c._rise <= 0.0:
			closest = minf(closest, c._mayor.position.distance_to(c._bu.position))
	_release()
	return t


func _run() -> void:
	Engine.time_scale = 3.0
	var gs := root.get_node("GameState")
	gs.fast = false
	var Chase = load("res://scripts/chase/chase.gd")

	print("[正常跑]")
	var c = Chase.new()
	root.add_child(c)
	await process_frame
	_check(c._route.size() > 10, "迷宮有路可以到修理室（%d 格）" % c._route.size())
	var t: float = await _drive(c, 90.0)
	_check(c._done, "跑到修理室（%.1f 秒）" % t)
	_check(c._attempts == 0, "一路跑的話，不會被鎮長抓到（被抓 %d 次）" % c._attempts)
	print("       鎮長最近的時候，距離 %.1f 公尺" % closest)
	c.queue_free()
	await process_frame

	print("[站著不動]")
	c = Chase.new()
	root.add_child(c)
	var waited := 0.0
	while waited < 20.0 and c._attempts == 0:
		await process_frame
		waited += c.get_process_delta_time()
	_check(c._attempts >= 1 and waited > 9.0, "站著不動 → 一段時間後被抓到（%.1f 秒）" % waited)
	c.queue_free()
	Engine.time_scale = 1.0
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
