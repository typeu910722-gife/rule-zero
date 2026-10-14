extends SceneTree
## 森林：每樣東西都走得到、按得到（Fen 跟在旁邊也不會搶走互動），調查完會進入高潮。
## godot --headless -s tests/forest_test.gd

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
	var dlg := root.get_node("Dialogue")
	gs.fast = true
	gs.save_dir = "user://test_saves"
	gs.meta = {"runs": 0, "chapters_done": 0}
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 300:
		if main.phase == "day1_explore":
			break
		await process_frame
	await main._forest()
	var F: GDScript = preload("res://scripts/world/forest.gd")
	var p: Node2D = main.player
	_check(not F.blocked(p.position), "起點在路上")
	# 先調查三樣，最後才是小綿羊（調查到第 3 樣以上又看過小綿羊才會進高潮）
	for id in ["forest_bow", "forest_tags", "forest_tail", "forest_sheep"]:
		var it: Node2D = main.actors[id]
		_check(it.visible, "%s 看得到" % id)
		# 站在離東西最近的路上，等 Fen 跟過來
		var spot: Vector2 = F.nearest_walkable(it.position + Vector2(0, 40))
		_check(spot.distance_to(it.position) < it.reach() - 10.0, "%s 旁邊有路可以站（距離 %d）" % [id, int(spot.distance_to(it.position))])
		p.position = spot
		for i in 90:
			await process_frame
		var got = p.nearest()
		_check(got != null and got.id == id, "%s 按得到（按到的是 %s）" % [id, got.id if got else "沒有"])
		if got == null or got.id != id:
			continue
		await main.interact(id)
	_check(gs.has("found_sheep"), "找到小綿羊")
	_check(main._forest_count() >= 3, "森林的東西調查了 3 樣以上（%d）" % main._forest_count())
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
