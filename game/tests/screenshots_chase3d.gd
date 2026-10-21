extends SceneTree
## 3D 追逐的截圖。xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_chase3d.gd -- <資料夾>
func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "user://shots_chase3d"
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("GameState").reset()
	var c = load("res://scripts/ch3/chase3d.gd").new()
	root.add_child(c)
	await process_frame
	c.set_process(false)
	# 看向走廊，追的人站在前面幾格
	c._pos = c._center(Vector2i(1, 3))
	c._yaw = 0.0
	c._place_cam()
	c._epos = c._center(Vector2i(1, 1))
	c._place_enemy()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/chase3d.png")
	print("截圖 chase3d")
	quit(0)
