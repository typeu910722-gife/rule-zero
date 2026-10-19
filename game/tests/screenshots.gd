extends SceneTree
## 產生畫面截圖（需要顯示環境）：xvfb-run godot --path . -s tests/screenshots.gd -- <輸出資料夾>

var out := "user://shots"
var main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
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
	var dlg := root.get_node("Dialogue")
	gs.fast = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 300:
		if main.phase == "day1_explore":
			break
		await process_frame
	gs.fast = false
	main.player.position = Vector2(915, 960)
	await _frames(40)
	await _shot("01_plaza")
	main.player.position = Vector2(1000, 520)
	await _frames(40)
	await _shot("01b_north")
	main.player.position = Vector2(420, 1250)
	await _frames(40)
	await _shot("01c_residents")

	main.player.position = Vector2(1740, 1000)
	await _frames(40)
	dlg.run("fen_d1")
	await _frames(10)
	dlg._advance.emit()
	await _frames(90)
	await _shot("02_dialogue_fen")
	while dlg.running:
		dlg._advance.emit()
		await _frames(2)

	main.board.open()
	await _shot("03_board")
	main.board.close()

	main.player.position = Vector2(450, 640)
	main.actors.lulu.position = Vector2(525, 630)
	await _frames(40)
	gs.courage = 1
	gs.set_flag("bread_done")
	dlg.run("lulu_d2")
	await _frames(5)
	dlg._advance.emit()
	await _frames(60)
	dlg._advance.emit()
	await _frames(10)
	await _shot("04_choice")
	while dlg.running:
		dlg._chosen.emit(2)
		dlg._advance.emit()
		await _frames(2)

	main._place_home()
	main._set_tint("evening")
	await _frames(40)
	await _shot("04b_home")
	main._set_tint("day")
	main.player.bounds = main.WORLD_BOUNDS
	main._layout("arrival")
	main.player.position = main.STATION_SPOT
	await _frames(40)
	await _shot("04c_station")

	main._layout("night")
	main._set_tint("night")
	main.player.position = Vector2(915, 1100)
	await _frames(40)
	await _shot("05_night")

	quit()
