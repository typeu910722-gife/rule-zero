extends SceneTree
## 標題畫面截圖（越接近真相越沉重）：xvfb-run godot --path . -s tests/screenshots_title.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _title(meta: Dictionary) -> Node:
	var gs := root.get_node("GameState")
	gs.meta = meta
	var t = load("res://scripts/ui/title.gd").new()
	root.add_child(t)
	return t


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.save_dir = "user://shot_saves"
	var t := _title({"runs": 1, "chapters_done": 0})
	await _shot("title_0")
	t.queue_free()
	t = _title({"runs": 3, "chapters_done": 0, "loops_done": 3, "loop": 50, "endings": ["good_kid", "hesitate"],
		"memory": {"story_1": true, "story_2": true, "story_3": true, "knows_47": true, "knows_bow": true, "knows_bell": true},
		"tufts": ["tuft_0", "tuft_3"], "collected": ["got_button", "gift_bread", "gift_leaf", "found_lulu_bow"]})
	await _shot("title_3")
	t._open_panel("mystery")
	await _shot("title_3_mystery")
	t._show_tab("items")
	await _shot("title_3_items")
	t._show_tab("endings")
	await _shot("title_3_endings")
	t.queue_free()
	t = _title({"runs": 6, "chapters_done": 1, "loops_done": 5, "loop": 52, "endings": ["good_kid", "hesitate", "truth"],
		"memory": {"story_1": true, "story_2": true, "story_3": true, "story_4": true, "true_name": true, "end_truth": true}})
	await _shot("title_5")
	t._open_chapters()
	await _shot("title_5_chapters")
	quit()
