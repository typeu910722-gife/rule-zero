extends SceneTree
## 記憶深度畫面截圖：xvfb-run godot --path . -s tests/screenshots_memory.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.save_dir = "user://shot_saves"
	gs.meta = {"runs": 3, "loop": 50, "loops_done": 3, "last_ending": "hesitate",
		"memory": {"story_1": true, "story_2": true, "story_3": true, "knows_47": true, "knows_bow": true},
		"tufts": ["tuft_0", "tuft_3", "tuft_4"], "fresh": ["knows_bow", "tuft_3"]}
	var dlg := root.get_node("Dialogue")
	# 火車上想起的一段（第三層：廁所門外）
	dlg.set_bg("black")
	dlg._say("", "過了一陣子，換成另一雙。又換了一雙。")
	await _shot("mem_1_story3")
	dlg._box.visible = false
	dlg.set_bg("none")
	var main = load("res://scenes/main.tscn").instantiate()
	gs.fast = true
	root.add_child(main)
	for i in 400:
		if main.phase == "day1_explore":
			break
		await process_frame
	gs.fast = false
	main.hud.toggle_menu(false)
	await _shot("mem_2_diary")
	main.hud._menu_text.scroll_to_line(main.hud._menu_text.get_line_count())
	await _shot("mem_3_diary_end")
	quit()
