extends SceneTree
## 室內探索的畫面截圖（測試關卡）。xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_explore.gd -- <資料夾>
func _init() -> void:
	_run.call_deferred()


func _shot(out: String, name: String) -> void:
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("截圖 ", name)


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://shots_explore"
	DirAccess.make_dir_recursive_absolute(out)
	var gs := root.get_node("GameState")
	gs.reset()
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://tests/fixtures/explore_test.json")
	ex.party = ["lulu", "mochi", "popo", "fen", "baimian"]
	root.add_child(ex)
	await process_frame
	await ex.enter("a", "start")
	ex.busy = false
	await _shot(out, "explore_room_a")
	gs.set_flag("t_patrol_on")
	gs.set_flag("t_key")
	await ex.enter("b", "from_a")
	ex.busy = false
	ex.player.place(Vector2(600, 600))
	await _shot(out, "explore_room_b_dark")
	quit(0)
