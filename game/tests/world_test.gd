extends SceneTree
## 美術地圖相關：走路、建築碰撞、小布家的門。godot --headless -s tests/world_test.gd

var main: Node
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	for i in frames:
		await process_frame
	Input.action_release(action)
	await process_frame


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 300:
		if main.phase == "day1_explore":
			break
		await process_frame
	var Town = load("res://scripts/world/town.gd")
	var p: Node2D = main.player

	print("[走路與碰撞]")
	var start := p.position
	await _hold("move_left", 30)
	_check(p.position.x < start.x - 20, "按左會往左走")
	# 從公館正下方往上走：會被公館擋住
	p.position = Vector2(1107, 700)
	await _hold("move_up", 120)
	_check(not Town.blocked(p.position), "不會走進鎮長公館裡")
	_check(p.position.y > 355 * 1.5, "被公館擋住（y=%d）" % p.position.y)
	# 地圖邊界
	p.position = Vector2(100, 1600)
	await _hold("move_down", 60)
	_check(p.position.y <= main.WORLD_BOUNDS.end.y + 0.1, "不會走到鐵軌上")

	print("[小布家的門]")
	await main.interact("home_door")
	_check(p.bounds == main.HOUSE_BOUNDS and p.position == main.HOME_SPOT, "進門 → 房間裡")
	await _hold("move_right", 200)
	_check(p.position.x <= main.HOUSE_BOUNDS.end.x + 0.1, "房間裡走不出牆")
	await main.interact("home_exit")
	_check(p.bounds == main.WORLD_BOUNDS and p.position == main.OUTSIDE_HOME, "出門 → 回到門口")
	_check(not Town.blocked(main.OUTSIDE_HOME), "門口站得住")

	print("[第一天晚上不能出門]")
	main._place_home()
	main._set_phase("day1_night")
	await main.interact("home_exit")
	_check(p.bounds == main.HOUSE_BOUNDS, "第一天晚上：門打不開，還在房間")

	print("[互動點都站得到]")
	var spots := {}
	spots.merge(main.OBJECTS)
	spots.merge(main.ACTORS)
	for id in spots:
		var pos: Vector2 = spots[id].pos
		if id.begins_with("forest_") or id.begins_with("extra") or pos.x > Town.W:
			continue
		var ok := false
		for dx in range(-80, 81, 10):
			for dy in range(-80, 81, 10):
				var q := pos + Vector2(dx, dy)
				if Vector2(dx, dy).length() <= 80 and main.WORLD_BOUNDS.has_point(q) and not Town.blocked(q):
					ok = true
		_check(ok, "站得到：%s" % id)

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
