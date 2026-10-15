extends SceneTree
## 第二章第二天截圖：xvfb-run godot --path . -s tests/screenshots_ch2_day2.gd -- <輸出資料夾>

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
	gs.chapter = 2
	gs.set_flag("c2_grey_patch")

	var S = load("res://scripts/minigames/scrub.gd").new()
	root.add_child(S)
	S.stripes = [0.3, 0.0, 0.8, 0.5]
	S._brush = Vector2(560, 300)
	S.set_process(false)
	S._area.queue_redraw()
	await _shot("c2_d2_01_scrub")
	S.queue_free()

	var F = load("res://scripts/minigames/find_odd.gd").new()
	root.add_child(F)
	F.round_no = 1
	F._odd = 7
	F._t = 12.0
	F._area.queue_redraw()
	await _shot("c2_d2_02_find")
	F.queue_free()

	var H = load("res://scripts/minigames/hold_endure.gd").new()
	H.questions = [["第三題。你還記得，遙是誰嗎？", 5.0]]
	root.add_child(H)
	H._hold = 0.4
	H._area.queue_redraw()
	await _shot("c2_d2_03_treatment")
	H.queue_free()

	var N = load("res://scripts/minigames/sneak.gd").new()
	root.add_child(N)
	N._p = 0.45
	N._state = "look"
	N._area.queue_redraw()
	await _shot("c2_d2_04_sneak")
	N.queue_free()

	var O = load("res://scripts/ui/scene_overlay.gd").new()
	root.add_child(O)
	for m in ["photo_1", "photo_2", "photo_nirvana", "silhouette"]:
		O.mode = m
		O._t = 3.0
		O.get_child(0).queue_redraw()
		await _shot("c2_d2_05_%s" % m)
	O.queue_free()

	# 月台：沒戴面具的和平鴿與車掌
	gs.fast = true
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
	ch._layout("night_out")
	ch._set_tint("negative")
	await ch._on_event("c2_platform_scene")
	for i in 40:
		await process_frame
	await _shot("c2_d2_06_platform")
	quit()
