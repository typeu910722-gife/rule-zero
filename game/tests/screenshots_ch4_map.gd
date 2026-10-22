extends SceneTree
## 第四章學校地圖的截圖（遙的視角、小滿的放學後）。xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_ch4_map.gd -- <資料夾>
func _init() -> void:
	_run.call_deferred()


func _shot(out: String, name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("截圖 ", name)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://shots_ch4map"
	DirAccess.make_dir_recursive_absolute(out)
	var gs := root.get_node("GameState")
	gs.reset()
	gs.chapter = 4
	gs.flags["c4_pov_haruka"] = true
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://levels/chapter4.json")
	root.add_child(ex)
	ex.player.look = "h_haruka"
	await process_frame
	for rid in ["gate", "entrance", "hall1", "classroom"]:
		await ex.enter(rid, "from_hall" if rid == "classroom" else "x")
		ex.busy = false
		await _shot(out, "haruka_" + rid)
	gs.flags.erase("c4_pov_haruka")
	gs.flags["c4_pov_mochi"] = true
	ex.tint = Color(0.95, 0.78, 0.66)
	await ex.enter("classroom", "from_hall")
	ex.busy = false
	await _shot(out, "mochi_classroom")
	quit(0)
