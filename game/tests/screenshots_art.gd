extends SceneTree
## 新美術的畫面截圖：xvfb-run godot --rendering-driver opengl3 -s tests/screenshots_art.gd -- <輸出資料夾>

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
	await _frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	var dlg := root.get_node("Dialogue")
	gs.save_dir = "user://test_saves"
	gs.meta = {"runs": 0, "chapters_done": 0, "loop": 49, "endings": ["brave"]}
	var T = load("res://scripts/ui/title.gd")
	var t = T.new()
	root.add_child(t)
	await _frames(10)
	await _shot("a_title")
	t.queue_free()
	gs.meta = {"runs": 0, "chapters_done": 0}
	gs.fast = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 300:
		if main.phase == "day1_explore":
			break
		await process_frame
	gs.fast = false
	# 序章：車廂背景＋車票
	dlg.set_bg("train")
	dlg.show_item("ticket_stamped")
	dlg._box.visible = true
	dlg._name.text = "車掌"
	dlg._name.visible = true
	dlg._show_face("車掌", "……這次也請好好休息喔。")
	dlg._text.text = "……這次也請好好休息喔。"
	dlg._text.visible_characters = -1
	await _frames(20)
	await _shot("b_train")
	dlg.show_item("none")
	dlg.set_bg("hospital_haruka")
	dlg._name.visible = false
	dlg._portrait.visible = false
	dlg._text.text = "[color=#7a6a78]玩偶的胸前別著一張名牌。上面寫著「遙」。[/color]"
	await _frames(10)
	await _shot("c_dream")
	dlg.set_bg("none")
	dlg._box.visible = false
	# 選項
	dlg.set_bg("bakery")
	dlg.show_item("dough")
	var opts := [{"text": "閉上眼睛，跟著露露的拍子揉。", "cost": 0, "cond": "", "target": ""},
		{"text": "照自己的速度慢慢揉。", "cost": 0, "cond": "", "target": ""},
		{"text": "〔記得〕「露露，你以前的蝴蝶結……是黃色的吧？」", "cost": 0, "cond": "", "target": ""}]
	dlg._choose(opts)
	await _frames(10)
	await _shot("d_choice")
	dlg._chosen.emit(0)
	dlg.show_item("none")
	dlg.set_bg("none")
	# 房間
	main._place_home()
	main.actors.mirror.covered = false
	main.actors.mirror.queue_redraw()
	await _frames(30)
	await _shot("e_room")
	# 公告欄
	main.board.open()
	await _frames(10)
	await _shot("f_board")
	main.board.close()
	# 日記
	main._place_outside()
	main.hud.toggle_menu(true)
	await _frames(10)
	await _shot("g_diary")
	main.hud.toggle_menu(false)
	# 月台：車掌、小狗居民
	gs.day = 2
	main._layout("day")
	main.player.position = Vector2(1200, 1580)
	await _frames(40)
	await _shot("h_station")
	main.player.position = Vector2(1400, 720)
	await _frames(40)
	await _shot("i_puppy")
	# 森林
	gs.fast = true
	await main._forest()
	gs.fast = false
	await _frames(30)
	await _shot("j_forest_start")
	main.player.position = Vector2(1184, 330)
	await _frames(40)
	await _shot("k_forest_deep")
	main.player.position = Vector2(1880, 960)
	await _frames(40)
	await _shot("l_forest_tail")
	# 修理室
	var R = load("res://scripts/ui/repair_scene.gd")
	var r = R.new()
	root.add_child(r)
	await _frames(10)
	await _shot("m_repair")
	quit()
