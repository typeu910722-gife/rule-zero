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
	c.queue_free()
	# 第四章（學校的走廊）、第五章（真的醫院、地上的白線）
	for k in [["school", "MAZE_SCHOOL", "LOOK_SCHOOL", Vector2i(3, 2), PI], ["real", "MAZE_REAL_HALL", "LOOK_REAL", Vector2i(2, 1), -PI / 2.0]]:
		var d = load("res://scripts/ch3/chase3d.gd").new()
		d.maze = d.get(k[1]).duplicate()
		d.look = d.get(k[2])
		d.has_enemy = false
		d.breath = k[0] == "real"
		root.add_child(d)
		await process_frame
		d.set_process(false)
		d._pos = d._center(k[3])
		d._yaw = k[4]
		d._place_cam()
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/run3d_%s.png" % k[0])
		print("截圖 run3d_", k[0])
		d.queue_free()
	quit(0)
