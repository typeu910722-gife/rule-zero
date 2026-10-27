extends SceneTree
## 第三～五章地圖房間美術（tools/art/blender/room.py → game/art/rooms/）與壓迫感的測試：
## 1. 每間房間都有美術、背景圖大小＝房間大小、每件家具（含有 kind 的躲藏點、調查點）都有對得上的圖、圖片讀得到
## 2. 進房間後真的用了美術（_art 有東西）、環境音照主題換
## 3. 巡邏的人靠近時 threat 變大、暗角變重
## 4. 3D 追逐：醫院用畢業生模型（不是內建形狀）、追的人靠近時 threat 變大
## godot --headless --path . -s tests/rooms_art_test.gd

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
	for lv in ["chapter3", "chapter4", "chapter5"]:
		var level = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % lv))
		var missing: Array = []
		var bad: Array = []
		for rid in level.rooms:
			var r: Dictionary = level.rooms[rid]
			var dir := "res://art/rooms/%s/%s/" % [lv, rid]
			if not FileAccess.file_exists(dir + "room.json"):
				missing.append(rid)
				continue
			var art = JSON.parse_string(FileAccess.get_file_as_string(dir + "room.json"))
			var bg: Texture2D = load(dir + art.bg)
			var size: Array = r.get("size", [1280, 720])
			if bg == null or bg.get_width() != int(size[0]) or bg.get_height() != int(size[1]):
				bad.append("%s 背景圖大小" % rid)
			var keys: Array = []
			for p in r.get("props", []):
				if not (p.get("kind", "box") in ["window", "rug", "blackboard"]):
					var rc: Array = p.rect
					keys.append("prop:%s@%d,%d,%d,%d" % [p.get("kind", "box"), int(rc[0]), int(rc[1]), int(rc[2]), int(rc[3])])
			for k in ["hides", "spots"]:
				for s in r.get(k, []):
					if s.has("kind"):
						keys.append("%s:%s" % [k.trim_suffix("s"), s.id])
			for key in keys:
				if not art.props.has(key):
					bad.append("%s 少了 %s" % [rid, key])
				elif load(dir + art.props[key].tex) == null:
					bad.append("%s 讀不到 %s" % [rid, art.props[key].tex])
		_check(missing.is_empty(), "%s：每間房間都有美術 %s" % [lv, str(missing) if missing else ""])
		_check(bad.is_empty(), "%s：背景、家具的圖都對得上 %s" % [lv, str(bad) if bad else ""])

	# 進房間：用了美術、換了環境音；巡邏的人靠近 → threat、暗角
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://levels/chapter3.json")
	root.add_child(ex)
	await process_frame
	gs.flags["seen_c3_corr_enter"] = true
	await ex.enter("corridor", [1000, 500])
	ex.busy = false
	_check(ex._art.has("bg") and ex._art.props.size() > 0, "進房間後用的是房間美術")
	_check(root.get_node("Sound").ambience_name() == "hum", "醫院的房間：日光燈的嗡嗡聲")
	var pt = ex._patrols[0]
	pt.set_process(false)
	pt.position = Vector2(1900, 330)
	for i in 10:
		await process_frame
	var far: float = ex.threat
	pt.position = ex.player.position + Vector2(120, 0)
	for i in 30:
		await process_frame
	_check(ex.threat > far + 0.5, "巡邏的人靠近：threat 變大（%.2f → %.2f）" % [far, ex.threat])
	_check(ex._vig > ex.dread, "巡邏的人靠近：暗角變重")
	ex.queue_free()
	await process_frame

	# 3D 追逐：醫院用畢業生模型
	var c = load("res://scripts/ch3/chase3d.gd").new()
	root.add_child(c)
	await process_frame
	var mesh_count := 0
	for n in c._enemy.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
	_check(c._enemy.get_child_count() > 0 and not (c._enemy.get_child(0) is MeshInstance3D), "3D 追逐：追的人是 Blender 的畢業生模型")
	_check(c._drag != null, "3D 追逐：追的人身上有拖著點滴架的聲音")
	c._t = c.enemy_delay + 1.0
	c._epos = c._pos + Vector2(1.0, 0)
	c._dread(0.016)
	_check(c.threat > 0.8, "3D 追逐：追的人靠近時 threat 變大（%.2f）" % c.threat)
	c.queue_free()
	await process_frame

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
