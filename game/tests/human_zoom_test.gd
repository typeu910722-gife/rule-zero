extends SceneTree
## 人類時期（主角是 h_ 開頭的人）地圖鏡頭要拉近，看得到臉；玩偶章節維持原本大小。
## godot --headless --path . -s tests/human_zoom_test.gd

var failures := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	_run.call_deferred()


func _make(look: String) -> Node:
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://levels/chapter4.json")
	root.add_child(ex)
	ex.player.look = look
	return ex


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset()
	gs.fast = true
	# 第四章：遙走在走廊（2400 寬）
	var ex = _make("h_haruka")
	gs.flags["seen_" + str(ex.level.rooms.hall1.get("on_enter", ""))] = true
	await ex.enter("hall1")
	var cam: Camera2D = ex._cam
	_check(cam.zoom.x >= 1.5, "人類時期鏡頭拉近（%.2f 倍）" % cam.zoom.x)
	var view_w := 1280.0 / cam.zoom.x
	_check(cam.limit_right - cam.limit_left >= view_w - 1.0, "鏡頭範圍至少一個畫面寬")
	_check(cam.limit_left >= -1 and cam.limit_right <= 2401, "大房間時鏡頭不會跑出房間（%d～%d）" % [cam.limit_left, cam.limit_right])
	# 拉近後臉的大小：走路圖一格 160px × 縮放 × 鏡頭倍率，角色至少 140px 高
	var art = load("res://scripts/explore/explore_art.gd")
	var sc: float = art.WALK_SCALE.get("h_haruka", 0.5) * art.human_mul
	_check(144.0 * sc * cam.zoom.x >= 160.0, "遙在畫面上至少 160px 高（%.0f）" % (144.0 * sc * cam.zoom.x))
	ex.queue_free()
	# 玩偶（小布）：不拉近
	var ex2 = _make("pip")
	await ex2.enter("office")
	_check(is_equal_approx(ex2._cam.zoom.x, 1.0), "玩偶章節鏡頭維持 1 倍")
	_check(is_equal_approx(load("res://scripts/explore/explore_art.gd").human_mul, 1.0), "玩偶章節人不放大")
	ex2.queue_free()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
