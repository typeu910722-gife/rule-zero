extends SceneTree
## 第三章截圖（房間、小遊戲）：xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_ch3.gd -- <資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String, frames := 30) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset()
	gs.meta.ch2_fates = {"zhongzhong": "aboard", "youyou": "unknown"}
	gs.start_chapter3()
	gs.chapter = 3
	var hud = load("res://scripts/ch3/hud.gd").new()
	hud.party = [["pip", "小布"], ["lulu", "露露"], ["mochi", "麻糬"], ["popo", "波波"], ["fen", "Fen"], ["baimian", "白面"], ["zhongzhong", "重重"]]
	hud.place = "一樓　白色走廊"
	root.add_child(hud)
	var C = load("res://scripts/chapter3.gd")
	for rid in ["hall", "nirvana", "records", "b2"]:
		gs.set_flag("c3_heart_done"); gs.set_flag("c3_haruka_slip")
		var r = load("res://scripts/ch3/room.gd").new()
		r.room_id = rid
		r.spots = C.ROOMS[rid]
		root.add_child(r)
		await _shot("room_" + rid)
		r.queue_free()
	var games := {"heart": "res://scripts/ch3/heart_cards.gd", "thermo": "res://scripts/ch3/thermo.gd", "drip": "res://scripts/ch3/drip.gd",
		"sew": "res://scripts/ch3/sew.gd", "cpr": "res://scripts/ch3/cpr.gd", "runner": "res://scripts/ch3/runner.gd", "rollcall": "res://scripts/ch3/runner.gd"}
	for k in games:
		var g = load(games[k]).new()
		if k == "thermo":
			g.queue = [["mochi", "麻糬"], ["fen", "Fen"]]
		if k == "sew":
			g.patients = [["fen", "Fen"], ["baimian", "白面"]]
		if k == "rollcall":
			g.rollcall = true
			g.next_call = 0.5
		root.add_child(g)
		await _shot("mini_" + k, 90)
		g.queue_free()
	quit()
