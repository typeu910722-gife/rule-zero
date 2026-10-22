extends SceneTree
## 第五章地圖的截圖（實驗室、檔案室、終章 A 的病房、B-1 廣場）。xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_ch5_map.gd -- <資料夾>
func _init() -> void:
	_run.call_deferred()


func _shot(out: String, name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("截圖 ", name)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://shots_ch5map"
	DirAccess.make_dir_recursive_absolute(out)
	var gs := root.get_node("GameState")
	gs.reset()
	gs.chapter = 5
	var shots := [["c5_st_lab", "lab5", "start", "pip", []], ["c5_st_lesson", "records5", "from_hall", "pip", ["lulu", "fen", "baimian"]],
		["c5_st_lesson", "hall5", "from_lab", "pip", ["lulu", "mochi", "popo", "fen", "baimian"]],
		["c5_st_a", "a_ward5", "start", "h_haruka", []], ["c5_st_a", "a_other5", "from_hall", "h_haruka", ["h_hilufei"]],
		["c5_st_b1", "b1_square5", "start", "pip", []]]
	for s in shots:
		gs.flags = {s[0]: true, "with_xiaoji": true, "with_gaga": true}
		var ex = load("res://scripts/explore/explore.gd").new()
		ex.load_level("res://levels/chapter5.json")
		ex.party = s[4]
		root.add_child(ex)
		ex.player.look = s[3]
		await process_frame
		await ex.enter(s[1], s[2])
		ex.busy = false
		await _shot(out, s[1])
		ex.queue_free()
		await process_frame
	quit(0)
