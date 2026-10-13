extends SceneTree
## 第三天畫面截圖：xvfb-run godot --path . -s tests/screenshots_day3.gd -- <輸出資料夾>

var out := "user://shots"
var main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 300:
		if main.phase == "day1_explore":
			break
		await process_frame
	gs.day = 3
	await main._forest()
	gs.fast = false
	main.player.position = Vector2(800, 900)
	await _frames(60)
	await _shot("10_forest_path")
	main.player.position = Vector2(800, 420)
	await _frames(80)
	await _shot("11_forest_pile")

	main.actors.mayor.visible = true
	main.actors.mayor.position = Vector2(800, 560)
	main.player.position = Vector2(800, 430)
	await _frames(30)
	await _shot("12_bell")

	var r = main.RepairScene.new()
	main.add_child(r)
	await _shot("13_repair")
	r._sew = 0.6
	r._area.queue_redraw()
	await _shot("14_sewing")
	r.queue_free()

	main.forest.visible = false
	main.town.visible = true
	main.player.bounds = main.WORLD_BOUNDS
	gs.set_flag("chapter2")
	gs.fast = true
	main._on_event("ch2_arrival")
	gs.fast = false
	await _frames(30)
	await _shot("15_ch2_arrival")
	main.board.open()
	await _shot("16_ch2_board")
	main.board.close()
	main.add_child(main.EndCard.new())
	await _shot("17_end_card")
	quit()
