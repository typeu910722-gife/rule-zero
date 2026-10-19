extends SceneTree
## 手機版面截圖：xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_mobile.gd -- <輸出資料夾>
## 同一段對話與選項，電腦版與手機版各一張；再加上探索時的觸控按鈕。

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String, frames := 4) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	var dlg := root.get_node("Dialogue")
	gs.save_dir = "user://test_saves"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	var town: Node2D = load("res://scripts/world/town.gd").new()
	root.add_child(town)
	var cam := Camera2D.new()
	cam.position = Vector2(700, 520)
	town.add_child(cam)
	cam.make_current()
	for touch in [false, true]:
		gs.force_touch_ui = touch
		var tag := "touch" if touch else "desktop"
		dlg.run("mirror_day1_night")
		await create_timer(1.0).timeout
		await _shot("m_%s_1_line" % tag)
		# 一直按「下一句」直到出現選項
		for i in 10:
			if dlg._choosing:
				break
			dlg._advance.emit()
			await create_timer(0.5).timeout
		await _shot("m_%s_2_choices" % tag)
		dlg._chosen.emit(2)
		for i in 10:
			if not dlg.running:
				break
			dlg._advance.emit()
			await create_timer(0.4).timeout
	# 探索中的觸控按鈕（浮動搖桿按在左半邊）
	var tc: CanvasLayer = load("res://scripts/ui/touch_controls.gd").new()
	tc.mode_provider = func(): return "explore"
	root.add_child(tc)
	tc.enabled = true
	await process_frame
	await process_frame
	var ev := InputEventScreenTouch.new()
	ev.position = Vector2(330, 470)
	ev.pressed = true
	tc._input(ev)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(400, 440)
	tc._input(drag)
	await _shot("m_touch_3_explore")
	quit()
