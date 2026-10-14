extends SceneTree
## 新演出的截圖：方向箭頭、NPC 轉頭、第三天盯著看、森林暗角、驚悚閃爍
## xvfb-run godot --path . -s tests/screenshots_fx.gd -- <輸出資料夾>

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
	var dlg := root.get_node("Dialogue")
	gs.fast = true
	gs.save_dir = "user://test_saves"
	gs.meta = {"runs": 0, "chapters_done": 0}
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 300:
		if main.phase == "day1_explore":
			break
		await process_frame
	gs.fast = false
	main.busy = false
	main.player.can_move = true
	# 1. 第一天：站在車站，目標在畫面外 → 箭頭
	main.player.position = Vector2(1017, 1500)
	await _frames(40)
	await _shot("fx1_arrow")
	# 2. 走近露露：她轉頭看小布
	main.player.position = main.actors.lulu.position + Vector2(140, 40)
	await _frames(40)
	await _shot("fx2_lulu_looks")
	# 2b. 對話框：名字在布標正中間
	dlg.run("chat_lulu")
	await _frames(90)
	await _shot("fx2b_dialogue")
	dlg._advance.emit()
	for i in 200:
		if not dlg.running:
			break
		dlg._advance.emit()
		await process_frame
	# 3. 驚悚閃爍
	dlg.fx.scare()
	print("scare visible=", dlg.fx._scare.visible, " t=", dlg.fx._t, " inside=", dlg.fx._scare.is_visible_in_tree(), " size=", dlg.fx._scare.size)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/fx3_scare.png" % out)
	print("after t=", dlg.fx._t)
	await _frames(40)
	# 4. 第三天：居民盯著小布
	gs.day = 3
	main._layout("day")
	main.player.position = main.actors.tama.position + Vector2(-260, -120)
	await _frames(40)
	await _shot("fx4_day3_stare")
	# 5. 森林深處：暗角＋淡色
	gs.fast = true
	await main._forest()
	gs.fast = false
	main.busy = false
	main._set_phase("forest")
	main.player.position = Vector2(1200, 500)
	await _frames(90)
	await _shot("fx5_forest_deep")
	quit()
