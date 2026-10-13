extends SceneTree
## 模擬玩家用方向鍵（8 個方向）沿著路走到各個地點，找出會被卡住的地方。
## godot --headless -s tests/walk_routes_test.gd -- <routes.json> [forest]

var main: Node
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _press(dir: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	var n := dir.normalized()
	if n.x < -0.38: Input.action_press("move_left")
	if n.x > 0.38: Input.action_press("move_right")
	if n.y < -0.38: Input.action_press("move_up")
	if n.y > 0.38: Input.action_press("move_down")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var forest := args.size() > 1 and args[1] == "forest"
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves"
	gs.meta = {"runs": 0, "chapters_done": 0}
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 300:
		if main.phase == "day1_explore":
			break
		await process_frame
	if forest:
		await main._forest()
	main.busy = true   # 不觸發互動，只測走路
	var p: Node2D = main.player
	p.can_move = true
	var total_stalls := 0
	for name in routes:
		var pts: Array = routes[name]
		p.position = Vector2(pts[0][0], pts[0][1])
		var idx := 1
		var frames := 0
		var stall := 0
		var best := INF
		var stalls := []
		while idx < pts.size() and frames < 60 * 90:
			var tgt := Vector2(pts[idx][0], pts[idx][1])
			var to := tgt - p.position
			if to.length() < 26.0:
				idx += 1
				best = INF
				stall = 0
				continue
			_press(to)
			await process_frame
			frames += 1
			if to.length() < best - 2.0:
				best = to.length()
				stall = 0
			else:
				stall += 1
				if stall > 45:   # 0.75 秒沒有前進：卡住了
					stalls.append(Vector2i(p.position))
					p.position = tgt   # 幫他跳過去，繼續測下一段
					stall = 0
		_press(Vector2.ZERO)
		var ok := stalls.is_empty() and idx >= pts.size()
		total_stalls += stalls.size()
		if not ok:
			failures += 1
		print("%s %s  %.1f 秒%s" % ["ok  " if ok else "STUCK", name, frames / 60.0, ("  卡在 " + str(stalls)) if not stalls.is_empty() else ""])
	print("結果：%d 條路線、%d 條有卡住、共卡 %d 次" % [routes.size(), failures, total_stalls])
	quit(1 if failures > 0 else 0)
