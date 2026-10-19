extends SceneTree
## 第二章第三天、畢業典禮、結算、標題畫面名牌截圖：xvfb-run godot --path . -s tests/screenshots_ch2_day3.gd -- <輸出資料夾>

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
	var gs := root.get_node("GameState")
	gs.save_dir = "user://test_saves"
	gs.chapter = 2
	gs.set_flag("c2_grey_patch")

	var C = load("res://scripts/minigames/confession.gd").new()
	C.cards = ["偷拿別人的信。", "在班上說波波偷東西。", "舉報同學換糖果。", "說謊。一直說謊。"]
	root.add_child(C)
	C._running = true
	C._i = 2
	C.color = 0.75
	C._shout = 0.8
	C.set_process(false)
	C._area.queue_redraw()
	await _shot("c2_d3_01_confession")
	C.queue_free()

	var T = load("res://scripts/minigames/trim.gd").new()
	root.add_child(T)
	T.quills = 7
	T._smile = 0.35
	T._scissors = Vector2(560, 260)
	T._cotton = [Vector2(600, 330)]
	T._area.queue_redraw()
	await _shot("c2_d3_02_trim")
	T.queue_free()

	var H = load("res://scripts/minigames/chairs.gd").new()
	H.players = ["pip", "xiaoji", "gaga", "zhongzhong", "youyou"]
	H.out = "youyou"
	root.add_child(H)
	H._phase = "result"
	H.set_process(false)
	H._area.queue_redraw()
	await _shot("c2_d3_03_chairs")
	H.queue_free()

	var R = load("res://scripts/minigames/restuff.gd").new()
	root.add_child(R)
	R.step = 1
	R._flash = 0.6
	R.set_process(false)
	R._area.queue_redraw()
	await _shot("c2_d3_04_restuff")
	R.queue_free()

	# 畢業典禮：布條、工作台、高台上的模範生、火車
	gs.fast = true
	gs.reset()
	gs.start_chapter2()
	gs.checkpoint = "c2_start"
	var ch = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)
	gs.auto_choices = [3, 4]
	for i in 300:
		if ch.phase == "day1_explore":
			break
		await process_frame
	gs.fast = false
	gs.set_flag("c2_trimmed")
	gs.set_flag("xiaoji_last_quill")
	ch._layout("graduation")
	ch.town.train = true
	ch._set_tint("evening")
	ch.player.position = Vector2(950, 560)
	for i in 40:
		await process_frame
	await _shot("c2_d3_05_graduation")

	# 結算
	gs.meta = {"runs": 1, "chapters_done": 2, "ch2_fates": {"baimian": "aboard", "xiaoji": "graduated", "tiaoma": "dead",
		"gaga": "aboard", "zhongzhong": "dead", "youyou": "unknown"}}
	var E = load("res://scripts/ch2/end_card.gd").new()
	E.mode = "c2_done"
	root.add_child(E)
	await _shot("c2_d3_06_summary")
	E.queue_free()
	ch.queue_free()

	var Ti = load("res://scripts/ui/title.gd").new()
	root.add_child(Ti)
	await _shot("c2_d3_07_title")
	quit()
