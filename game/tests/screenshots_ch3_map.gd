extends SceneTree
## 第三章地圖探索的截圖：每個房間一張。xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_ch3_map.gd -- <資料夾>
func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://shots_ch3map"
	DirAccess.make_dir_recursive_absolute(out)
	var gs := root.get_node("GameState")
	gs.reset()
	gs.chapter = 3
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://levels/chapter3.json")
	ex.party = ["lulu", "mochi", "popo", "fen", "baimian"]
	root.add_child(ex)
	await process_frame
	for rid in ex.level.rooms:
		gs.flags["seen_" + str(ex.level.rooms[rid].get("on_enter", ""))] = true
		await ex.enter(rid, "x")
		ex.busy = false
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, rid])
		print("截圖 ", rid)
	quit(0)
