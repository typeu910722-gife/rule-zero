extends SceneTree
## 追逐戰（裸眼 3D 版）：
##   會躲的玩家（看到紅線預告就換到別的道、一直按住 ↑ 衝刺）→ 跑得到修理室、不會被抓；
##   不動的玩家 → 會被抓住，然後重跑。
## godot --headless -s tests/chase_test.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _tap(action: String) -> void:
	Input.action_press(action)
	for i in 3:
		await process_frame
	Input.action_release(action)


func _run() -> void:
	Engine.time_scale = 3.0
	var gs := root.get_node("GameState")
	gs.fast = false
	var Chase = load("res://scripts/chase/chase.gd")

	print("[會躲的玩家]")
	var c = Chase.new()
	root.add_child(c)
	var t := 0.0
	var dodged := 0
	var last_tele := {}
	Input.action_press("move_up")
	while t < 120.0 and not c._done:
		await process_frame
		t += c.get_process_delta_time()
		if c._state != "run":
			continue
		var threat := -99
		if not c._tele.is_empty():
			threat = int(c._tele.lane)
			if c._tele != last_tele:
				dodged += 1
				last_tele = c._tele
		elif not c._lunge.is_empty():
			threat = int(c._lunge.lane)
		if threat != -99 and c._lane == threat:
			var go := 1 if threat <= 0 else -1
			await _tap("move_right" if go > 0 else "move_left")
	Input.action_release("move_up")
	_check(c._done, "跑到修理室（%.1f 秒）" % t)
	_check(c._attempts == 0, "看到預告就換道：不會被抓（被抓 %d 次）" % c._attempts)
	_check(c._hits <= 1, "被針打中 %d 次" % c._hits)
	_check(dodged >= 3, "鎮長真的有出招（%d 次預告）" % dodged)
	c.queue_free()
	await process_frame

	print("[不動的玩家]")
	c = Chase.new()
	root.add_child(c)
	t = 0.0
	while t < 60.0 and c._attempts == 0:
		await process_frame
		t += c.get_process_delta_time()
	_check(c._attempts >= 1 and c._hits >= 1, "一直站在同一道 → 被針打中、被抓住（%.1f 秒，中了 %d 針）" % [t, c._hits])
	c.queue_free()
	Engine.time_scale = 1.0
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
