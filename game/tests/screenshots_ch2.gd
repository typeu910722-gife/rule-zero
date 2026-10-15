extends SceneTree
## 第二章畫面截圖：xvfb-run godot --path . -s tests/screenshots_ch2.gd -- <輸出資料夾>

var out := "user://shots"
var ch: Node


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
	gs.save_dir = "user://test_saves"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.fast = true
	gs.reset()
	gs.set_flag("lulu_doubt")
	gs.start_chapter2()
	gs.checkpoint = "c2_start"
	ch = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)
	gs.auto_choices = [3, 4]
	for i in 300:
		if ch.phase == "day1_explore":
			break
		await process_frame
	gs.fast = false

	# 月台：和平鴿
	ch._layout("arrival")
	ch.actors.dove.visible = true
	ch.actors.dove.position = Vector2(560, 935)
	ch.player.position = Vector2(250, 975)
	await _frames(40)
	await _shot("c2_01_arrival")

	# 自由時間：點名廣場
	ch._layout("day")
	ch.player.position = Vector2(790, 500)
	await _frames(40)
	await _shot("c2_02_plaza")

	# 宿舍屋頂的白面、走廊的小棘
	ch.player.position = Vector2(420, 330)
	await _frames(40)
	await _shot("c2_03_dorm")

	# 洗衣房的條碼、鐵絲網的鼬鼬
	ch.player.position = Vector2(1000, 640)
	await _frames(40)
	await _shot("c2_04_fence")

	# 傍晚：對岸的模範生
	ch._set_tint("evening")
	ch._on_event("c2_fence_lineup")
	await _frames(40)
	await _shot("c2_05_evening")
	ch._set_tint("day")

	# 公告欄與成績單
	ch.board.open_report()
	await _frames(5)
	await _shot("c2_06_report")
	ch.board.close()
	ch.board.open()
	await _frames(5)
	await _shot("c2_07_rules")
	ch.board.close()

	# 道歉練習：遊戲中、愛心電量、重重被電
	var A = load("res://scripts/minigames/apology.gd")
	var a = A.new()
	root.add_child(a)
	a._phase = "play"
	a._t = 3.2
	a._meter = 3
	a._wrong(false)
	a.set_process(false)
	a._area.queue_redraw()
	await _shot("c2_08_apology")
	a._phase = "hold"
	a._hold = 0.45
	a.took_shock = true
	a._area.queue_redraw()
	await _shot("c2_09_apology_hold")
	a.queue_free()

	# 點名簿
	var R = load("res://scripts/ui/roll_list.gd")
	var r = R.new()
	root.add_child(r)
	await _shot("c2_10_rollcall")
	r.queue_free()

	# 對話框（漂白鎮的配色）
	ch.player.position = Vector2(790, 500)
	dlg._apply_style()
	dlg._show_portrait("和平鴿")
	dlg._box.visible = true
	dlg._name.text = "和平鴿"
	dlg._text.text = "我會很愛你。愛到你變好為止。"
	dlg._text.visible_characters = -1
	await _shot("c2_11_dialogue")
	dlg._box.visible = false

	# 夜晚的宿舍
	ch._layout("night")
	ch._set_tint("night")
	ch.player.position = Vector2(380, 250)
	await _frames(40)
	await _shot("c2_12_night")
	gs.delete_save()
	quit()
