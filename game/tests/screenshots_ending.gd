extends SceneTree
## 真結局畫面截圖：xvfb-run godot --path . -s tests/screenshots_ending.gd -- <輸出資料夾>

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
	var dlg := root.get_node("Dialogue")
	dlg.set_bg("repair")
	var sc = load("res://scripts/ui/scissors_scene.gd").new()
	root.add_child(sc)
	for i in 30:
		await process_frame
	sc._cut = 3
	sc._t = 2.6
	sc._jab = 0.8
	await _shot("end_1_scissors")
	sc.queue_free()
	dlg.set_bg("classroom")
	dlg.run("showdown")
	await _shot("end_2_classroom")
	dlg.set_bg("train_night")
	await _shot("end_3_train")
	quit()
