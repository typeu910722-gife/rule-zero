extends SceneTree
## 八方向走路（2026-11-06 使用者：第四章沒有左上、右上、左下、右下）：
## 斜著走要換斜向那一列；第四、五章能操作的人都要有 <id>_diag.png，每一格都有人、腳底對齊。
## godot --headless --path . -s tests/walk8_test.gd

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
	var Art = load("res://scripts/explore/explore_art.gd")
	print("[方向 → 列]")
	var cases := {Vector2(0, 1): 0, Vector2(-1, 0): 1, Vector2(1, 0): 2, Vector2(0, -1): 3,
		Vector2(-1, 1): 4, Vector2(-1, -1): 5, Vector2(1, 1): 6, Vector2(1, -1): 7,
		Vector2(-1, 0.2): 1, Vector2(0.2, 1): 0}
	for d in cases:
		_check(Art.walk_row(d) == cases[d], "方向 %s → 第 %d 列（實際 %d）" % [d, cases[d], Art.walk_row(d)])

	print("[第四、五章能操作的人都有斜向走路圖]")
	var ids: Array = load("res://scripts/chapter4.gd").LOOKS.values()
	ids.append(load("res://scripts/chapter5.gd").HARUKA)
	var seen := {}
	for id in ids:
		if seen.has(id):
			continue
		seen[id] = true
		var path := "res://art/walk4/%s_diag.png" % id
		_check(ResourceLoader.exists(path), "%s 有斜向圖" % id)
		if not ResourceLoader.exists(path):
			continue
		var img: Image = (load(path) as Texture2D).get_image()
		var base: Image = (load("res://art/walk4/%s.png" % id) as Texture2D).get_image()
		_check(img.get_width() == base.get_width() and img.get_height() == base.get_height(), "%s 斜向圖和四方向圖一樣大" % id)
		var cell := img.get_width() / 4
		var ok := true
		for r in 4:
			for c in 4:
				var used := img.get_region(Rect2i(c * cell, r * cell, cell, cell)).get_used_rect()
				# 每格有人，腳底在格子下緣附近（和四方向圖一樣是 304/320）
				if used.size.y < cell * 0.4 or absf(float(used.end.y) / cell - 0.95) > 0.06:
					ok = false
		_check(ok, "%s 斜向圖 16 格都有人、腳底對齊" % id)

	print("[剛進房間：同伴擠在小布身後一小團，不排成一長列]")
	var gs := root.get_node("GameState")
	gs.reset()
	gs.chapter = 3
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://levels/chapter3.json")
	ex.party = ["lulu", "mochi", "popo", "fen", "baimian"]
	root.add_child(ex)
	await process_frame
	gs.flags["seen_c3_hall_intro"] = true
	await ex.enter("platform", "start")
	for i in 10:
		await process_frame
	var far := 0.0
	for fo in ex._followers:
		far = maxf(far, fo.position.distance_to(ex.player.position))
	_check(far < 100.0, "同伴離小布最遠 %.0f px（< 100）" % far)
	var spread := 0.0
	for a in ex._followers:
		for b in ex._followers:
			spread = maxf(spread, a.position.distance_to(b.position))
	_check(spread > 30.0, "同伴沒有疊在同一點（散開 %.0f px）" % spread)
	print("[月台：ChatGPT 重畫的房間]")
	_check(ex._art.get("painted", false) and ResourceLoader.exists(ex._art.dir + "bg_paint.jpg"), "月台用重畫的背景")
	# 第三章 22 間全部重畫：每間的背景、每件家具的遮擋圖都在
	for lv in ["chapter3", "chapter4", "chapter5"]:
		ex.load_level("res://levels/%s.json" % lv)
		var missing: Array = []
		for rid in ex.level.rooms:
			var art: Dictionary = ex._room_art(rid)
			if not art.get("painted", false) or not ResourceLoader.exists(art.dir + str(art.bg)):
				missing.append(rid)
				continue
			for key in art.get("props", {}):
				if not ResourceLoader.exists(art.dir + str(art.props[key].tex)):
					missing.append("%s/%s" % [rid, key])
		_check(missing.is_empty(), "%s 每間房間都用重畫的圖（缺：%s）" % [lv, missing])
	ex.queue_free()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
