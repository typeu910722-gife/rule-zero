extends SceneTree
## 標題畫面與揉麵團截圖：xvfb-run godot --path . -s tests/screenshots_ui.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.save_dir = "user://test_saves"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.meta = {"runs": 1, "chapters_done": 0}
	var T = load("res://scripts/ui/title.gd")
	var t = T.new()
	root.add_child(t)
	await _shot("20_title_first")
	t.queue_free()
	gs.meta = {"runs": 2, "chapters_done": 1}
	t = T.new()
	root.add_child(t)
	await _shot("21_title_after_ch1")
	t.queue_free()

	var B = load("res://scripts/minigames/bread_knead.gd")
	var b = B.new()
	root.add_child(b)
	b._running = true
	b._t = 0.0
	b.max_streak = 8
	b._streak = 9
	await create_timer(4.4).timeout
	await _shot("22_bread")
	quit()
