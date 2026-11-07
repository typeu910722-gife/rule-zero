extends SceneTree
## 第四、五章的畫面截圖（房間、小遊戲、對話背景）。
## xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_ch45.gd -- <輸出資料夾>

var out := "user://shots_ch45"


func _init() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("截圖 ", name)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var gs := root.get_node("GameState")
	var dlg := root.get_node("Dialogue")
	gs.reset()
	gs.chapter = 4
	# 房間的畫面改用 screenshots_ch4_map.gd／screenshots_ch5_map.gd（第四、五章已經改成探索地圖）
	var hud = load("res://scripts/ch3/hud.gd").new()
	hud.header = "[b]第四章　三年二班[/b]"
	hud.place = "視角：遙"
	root.add_child(hud)
	for m in [["ch4/speech", "ch4_speech"], ["ch4/group_chat", "ch4_chat"], ["ch4/hold_door", "ch4_hold_door"]]:
		var g = load("res://scripts/%s.gd" % m[0]).new()
		root.add_child(g)
		if m[1] == "ch4_speech":
			await process_frame
			g._say(0)
		if m[1] == "ch4_chat":
			for k in 7:
				g._press(true, InputEventAction.new())
		await _shot(m[1])
		g.queue_free()
	for bg in ["c4_toilet_door", "c4_ward"]:
		dlg.set_bg(bg)
		dlg.call("_show_line", "", "（測試）畫面停在門外。") if dlg.has_method("_show_line") else null
		await _shot(bg)
	dlg.set_bg("none")
	gs.chapter = 5
	hud.header = "[b]第五章　終章[/b]"
	hud.place = "終章 A「醒來」"
	hud.refresh()
	for m in [["ch5/breath_walk", "ch5_breath"]]:
		var g = load("res://scripts/%s.gd" % m[0]).new()
		root.add_child(g)
		for k in 40:
			await process_frame
		await _shot(m[1])
		g.queue_free()
	quit(0)
