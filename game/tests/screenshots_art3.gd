extends SceneTree
## 新委託美術接入檢查：xvfb-run godot --path . -s tests/screenshots_art3.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.save_dir = "user://shot_saves"
	var dlg := root.get_node("Dialogue")
	for pair in [["mem_toilet", "過了一陣子，換成另一雙。又換了一雙。"], ["nt_popo", "「謝謝你那天，在大家都在笑的時候，沒有笑。」"]]:
		dlg.set_bg(pair[0])
		dlg._say("", pair[1])
		await _shot("a3_" + pair[0])
	dlg.set_bg("glove")
	dlg._say("車掌", "你應該忘記的。")
	await _shot("a3_glove")
	dlg.set_bg("none")
	dlg.show_item("stand_puppy")
	dlg._say("居民", "我什麼都沒有說。一個字都沒有。")
	await _shot("a3_dog")
	dlg.show_item("none")
	dlg._box.visible = false
	dlg._portrait.visible = false
	for m in [{"chapters_done": 0}, {"chapters_done": 0, "loops_done": 3, "loop": 50},
			{"chapters_done": 1, "loops_done": 5, "loop": 52, "memory": {"true_name": true, "story_1": true}}]:
		gs.meta = m
		var t = load("res://scripts/ui/title.gd").new()
		root.add_child(t)
		await _shot("a3_title_%d" % t._heavy)
		t.queue_free()
	var ec = load("res://scripts/ui/ending_card.gd").new()
	ec.ending = "hesitate"
	root.add_child(ec)
	await _shot("a3_ending_card")
	ec.queue_free()
	var sm = load("res://scripts/ui/summary.gd").new()
	root.add_child(sm)
	await _shot("a3_summary")
	sm.queue_free()
	var en = load("res://scripts/ui/end_card.gd").new()
	root.add_child(en)
	await _shot("a3_end_card")
	quit()
