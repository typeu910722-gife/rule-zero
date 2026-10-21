extends SceneTree
## 3D 追逐（scripts/ch3/chase3d.gd）：迷宮從起點走得到出口、追的人找得到路；
## 模擬：不用快速模式，真的按「往前」＋轉向，沿著路走到出口（會被追，最多被抓 3 次也會結束）。
## xvfb-run godot --path . --rendering-driver opengl3 -s tests/chase3d_test.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset()
	gs.fast = false
	var c = load("res://scripts/ch3/chase3d.gd").new()
	root.add_child(c)
	await process_frame
	# 這台測試機沒有顯示卡（軟體算圖很慢）：畫面縮小，邏輯一樣
	c._vp.size = Vector2i(64, 36)
	_check(c.walkable(c._start) and c.walkable(c._exit), "起點、出口都可以走")
	_check(not c._bfs(c._start, c._exit).is_empty(), "起點走得到出口")
	_check(not c._bfs(c._enemy_start, c._start).is_empty(), "追的人走得到起點")
	_check(not c._bfs(c._start, c._check).is_empty(), "檢查點在路上")
	var result := [-1]
	c.done.connect(func(n): result[0] = n)
	# 模擬操作：每一格算出下一格的方向，轉過去再按住「往前」
	var frames := 0
	while result[0] == -1 and frames < 60 * 60:
		var path: Array = c._bfs(c._cell(c._pos), c._exit)
		var target: Vector2 = c._center(path[0]) if not path.is_empty() else c._center(c._exit)
		var to: Vector2 = target - c._pos
		var want := atan2(-to.x, -to.y)
		var diff := wrapf(want - c._yaw, -PI, PI)
		Input.action_release("move_left")
		Input.action_release("move_right")
		Input.action_release("move_up")
		if absf(diff) > 0.15:
			Input.action_press("move_left" if diff > 0 else "move_right")
		else:
			Input.action_press("move_up")
			Input.action_press("interact")
		await process_frame
		frames += 1
	for a in ["move_left", "move_right", "move_up", "interact"]:
		Input.action_release(a)
	_check(result[0] >= 0 and c._cell(c._pos) == c._exit, "按方向鍵真的走到出口（被抓 %d 次，%d 幀）" % [result[0], frames])
	_check(result[0] <= 1, "沿著正確的路走，追的人追不太上（被抓 %d 次）" % result[0])
	# 迷宮每一格都連得到（不會有走不到的死角讓人以為有路）
	var total := 0
	var reach := 0
	for y in c.maze.size():
		for x in c.maze[y].length():
			if c.walkable(Vector2i(x, y)):
				total += 1
				if not c._bfs(c._start, Vector2i(x, y)).is_empty() or Vector2i(x, y) == c._start:
					reach += 1
	_check(reach == total, "迷宮每一格都走得到（%d / %d）" % [reach, total])
	# 第二段（點名）的迷宮也要每一格都連得到、走得到出口
	var c3 = load("res://scripts/ch3/chase3d.gd").new()
	c3.maze = c3.MAZE_ROLLCALL.duplicate()
	root.add_child(c3)
	await process_frame
	var t3 := 0
	var r3 := 0
	for y in c3.maze.size():
		for x in c3.maze[y].length():
			if c3.walkable(Vector2i(x, y)):
				t3 += 1
				if Vector2i(x, y) == c3._start or not c3._bfs(c3._start, Vector2i(x, y)).is_empty():
					r3 += 1
	_check(r3 == t3 and not c3._bfs(c3._start, c3._exit).is_empty(), "點名的迷宮：走得到出口、每一格都連得到（%d / %d）" % [r3, t3])
	c3.queue_free()
	# 站著不動：追的人要追得到（不然沒有威脅）
	var c2 = load("res://scripts/ch3/chase3d.gd").new()
	root.add_child(c2)
	await process_frame
	c2._vp.size = Vector2i(64, 36)
	var f2 := 0
	while c2._caught == 0 and f2 < 1500:
		await process_frame
		f2 += 1
	_check(c2._caught >= 1, "站著不動會被追上（%d 幀）" % f2)
	c2.queue_free()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
