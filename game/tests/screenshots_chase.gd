extends SceneTree
## 追逐戰（裸眼 3D 版）截圖：xvfb-run godot --path . -s tests/screenshots_chase.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var c = load("res://scripts/chase/chase.gd").new()
	root.add_child(c)
	await _frames(20)
	await _shot("chase_1_start")
	await _frames(90)
	await _shot("chase_2_run")
	# 換到左邊那一道（鏡頭跟著移：視差）
	c._lane = -1
	await _frames(40)
	await _shot("chase_3_left")
	# 鎮長抽動、地上的紅線預告；一根針已經飛過小布、衝出框外
	c._gap = 5.0
	c._tele = {"kind": "needle", "lane": -1, "t": 99.0}
	c._needles.append({"x": -1.1, "tx": -1.1, "z": 1.25, "z0": 7.5, "y": 1.6, "hit": true})
	await _frames(1)
	await _shot("chase_4_needle")
	c._tele = {}
	c._needles.clear()
	# 被抓住
	c._caught()
	await _frames(6)
	await _shot("chase_5_caught")
	# 終點
	c._state = "door"
	c._state_t = 1.2
	c._door_a = 1.0
	await _frames(3)
	await _shot("chase_6_door")
	quit()
