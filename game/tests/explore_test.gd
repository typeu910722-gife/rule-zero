extends SceneTree
## 室內探索系統（scripts/explore/）的測試：碰撞、上鎖的門、拿鑰匙、換房間、被巡邏看到會回到入口、躲起來不會被看到、
## 存檔記得房間與位置、快速模式能自己走完。
## godot --headless --path . -s tests/explore_test.gd

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
	gs.fast = true
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://tests/fixtures/explore_test.json")
	_check(ex.level.get("rooms", {}).size() == 2, "讀得到關卡 JSON")
	root.add_child(ex)
	await process_frame
	await ex.enter("a", "start")
	_check(ex.room_id == "a" and ex.player.position == Vector2(200, 400), "進房間、站在出生點")
	# 碰撞：牆（600,90,40,300）擋住
	_check(ex.player.blocked(Vector2(620, 200)), "撞到牆")
	_check(not ex.player.blocked(Vector2(620, 600)), "牆下面可以走")
	_check(ex.player.blocked(Vector2(380, 540)), "撞到床（家具預設是實心的）")
	_check(ex.player.blocked(Vector2(400, 60)), "上面的牆走不過去")
	# 上鎖的門
	var door: Dictionary = ex._things().filter(func(s): return s._kind == "doors")[0]
	_check(not ex._door_open(door), "沒有鑰匙：門鎖著")
	await ex.interact(door)
	_check(ex.room_id == "a", "鎖著的門進不去")
	var spot: Dictionary = ex._things().filter(func(s): return s.get("id", "") == "t_spot_key")[0]
	await ex.interact(spot)
	_check(gs.has("t_key") and gs.has("done_t_spot_key"), "調查抽屜拿到鑰匙")
	_check(ex._items.text.contains("測試鑰匙"), "狀態列顯示持有的東西")
	door = ex._things().filter(func(s): return s._kind == "doors")[0]
	await ex.interact(door)
	_check(ex.room_id == "b" and ex.player.position == Vector2(100, 450), "開門進到 B，站在門口")
	_check(ex._light != null and ex._light.enabled, "暗的房間有手電筒的光")
	# 巡邏：看到就回到入口；躲起來就不會被看到
	gs.set_flag("t_patrol_on")
	await ex.enter("b", "from_a")
	ex.busy = false
	var pt = ex._patrols[0]
	pt.reset()
	pt.facing = Vector2.RIGHT
	ex.player.place(Vector2(900, 450))
	for i in 40:
		await process_frame
	_check(ex.player.position == Vector2(100, 450), "被巡邏看到：回到入口（%s）" % ex.player.position)
	ex.busy = false
	var hide: Dictionary = ex._things().filter(func(s): return s._kind == "hides")[0]
	ex.player.place(Vector2(300, 330))
	await ex.interact(hide)
	_check(ex.hidden_in == "t_locker" and ex.player.tucked, "躲進置物櫃")
	ex.player.position = Vector2(860, 450)
	pt.position = Vector2(800, 450)
	pt.facing = Vector2.RIGHT
	for i in 40:
		await process_frame
	_check(ex.player.position == Vector2(860, 450), "躲著的時候不會被看到")
	ex._unhide()
	_check(not ex.player.tucked, "出來了")
	gs.flags.erase("t_patrol_on")
	# 存檔位置
	ex.player.position = Vector2(500, 500)
	ex.save_state()
	await ex.enter("a", "start")
	await ex.restore_or("a")
	_check(ex.room_id == "b" and ex.player.position == Vector2(500, 500), "讀檔回到同一個房間、同一個位置")
	# 密碼鎖（快速模式直接成功）
	_check(await ex.handle_event("t_pad") and gs.has("t_pad_open"), "密碼鎖事件")
	_check(not await ex.handle_event("not_a_pad"), "不是密碼鎖的事件交回給導演")
	# 條件語法：「或」以前不支援（會被當成一個旗標名稱，永遠是 false）
	gs.flags["t_a"] = true
	_check(gs.check("t_a|t_b") and gs.check("t_b|t_a") and not gs.check("t_b|t_c"), "條件：a|b（或）")
	_check(gs.check("t_a&!t_b|t_c") and not gs.check("t_b&t_a|t_c"), "條件：「且」比「或」優先")
	gs.flags.erase("t_a")
	# 快速模式：自己走到終點
	await ex.until("t_goal")
	_check(gs.has("t_goal"), "快速模式自己調查到終點")
	ex.queue_free()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
