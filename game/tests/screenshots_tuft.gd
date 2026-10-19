extends SceneTree
## 棉花（記憶碎片）截圖：xvfb-run godot --path . -s tests/screenshots_tuft.gd -- <輸出資料夾>

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


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.save_dir = "user://shot_saves"
	gs.meta = {"runs": 1, "loop": 2, "loops_done": 1, "tufts": ["tuft_0"]}
	var main = load("res://scenes/main.tscn").instantiate()
	gs.fast = true
	root.add_child(main)
	for i in 400:
		if main.phase == "day1_explore":
			break
		await process_frame
	gs.fast = false
	var vis := []
	for id in main.actors:
		if id.begins_with("tuft_") and main.actors[id].visible:
			vis.append(id)
	print("visible tufts: ", vis)
	if vis.size() > 0:
		main.player.position = main.actors[vis[0]].position + Vector2(-120, 40)
	await _shot("tuft_1_near")
	quit()
