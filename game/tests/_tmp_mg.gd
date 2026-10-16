extends SceneTree
var out := ""
func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	_run.call_deferred()
func _shot(n: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])
	print("saved ", n)
func _wait_for(script_name: String) -> Node:
	for i in 900:
		for c in current_scene_children():
			if c.get_script() and c.get_script().resource_path.ends_with(script_name):
				return c
		await process_frame
	return null
func current_scene_children() -> Array:
	var ch = root.get_node_or_null("Ch2")
	return ch.get_children() if ch else []
func _run() -> void:
	var gs := root.get_node("GameState")
	var dlg := root.get_node("Dialogue")
	gs.save_dir = "user://test_saves_mg"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.reset()
	gs.start_chapter2()
	gs.checkpoint = "c2_day1_explore"
	var ch = load("res://scenes/chapter2.tscn").instantiate()
	ch.name = "Ch2"
	root.add_child(ch)
	for i in 30:
		await process_frame
	ch.busy = true
	dlg.run("c2_apology")
	# 點過對話，直到小遊戲出現
	for i in 400:
		if (await _check(ch)) : break
		dlg._advance.emit()
		await process_frame
	await _shot("mg_apology_real")
	quit()
func _check(ch) -> bool:
	for c in ch.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("apology.gd"):
			return true
	return false
