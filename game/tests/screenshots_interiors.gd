extends SceneTree
## 小屋室內截圖：xvfb-run godot --path . -s tests/screenshots_interiors.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset()
	var rooms: Dictionary = load("res://scripts/world/interiors.gd").ROOMS
	for room in rooms:
		var s = load("res://scripts/ui/interior.gd").new()
		s.room_id = room
		root.add_child(s)
		for i in 5:
			await process_frame
		s._sel = 0
		s._title_a = 1.0
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/int_%s.png" % [out, room])
		print("saved ", room)
		s.queue_free()
		await process_frame
	quit()
