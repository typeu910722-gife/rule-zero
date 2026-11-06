extends SceneTree
## 主線引導（第三～五章）：只照引導箭頭玩，每一段都要走得完，而且引導不會找不到下一步。
## godot --headless --path . -s tests/guide_test.gd

var failures := 0
var gs: Node
var ExploreS: GDScript


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _auto_rooms(ch: Node) -> void:
	while is_instance_valid(ch) and not ch._finished:
		var r = ch.room
		if r != null and is_instance_valid(r) and not r.busy:
			var ids: Array = []
			for s in r.spots:
				if s.id != "exit" and (s.get("when", "") == "" or gs.check(s.when)):
					ids.append(s.id)
			var seen: Dictionary = r.get_meta("seen", {})
			var next := "exit"
			for id in ids:
				if not seen.has(id):
					next = id
					break
			seen[next] = true
			r.set_meta("seen", seen)
			r.set_busy(true)
			r.picked.emit(next)
		await process_frame


## 探索時檢查畫面上的引導：有目標文字、有下一步
func _watch(ch: Node) -> void:
	var seen_goal := {}
	while is_instance_valid(ch) and not ch._finished:
		var ex = ch.get("explore")
		if ex != null and is_instance_valid(ex) and ex.goal_cond != "" and not seen_goal.has(ex.goal_cond):
			seen_goal[ex.goal_cond] = true
			_check(ex.GOALS.has(ex.goal_cond), "「%s」這段有主線文字" % ex.goal_cond)
			_check(ex._guide_lbl.text.begins_with("目標："), "畫面上顯示目標：%s" % ex._guide_lbl.text.replace("\n", "／"))
		await process_frame


func _play(scene: String, frames: int, rooms := false) -> Node:
	ExploreS.guide_stuck = 0
	ExploreS.guide_steps = 0
	var ch: Node = load(scene).instantiate()
	root.add_child(ch)
	if rooms:
		_auto_rooms(ch)
	_watch(ch)
	for i in frames:
		if ch._finished:
			break
		await process_frame
	_check(ch._finished, "%s：只照引導走到結尾" % scene.get_file())
	_check(ExploreS.guide_stuck == 0, "%s：引導沒有卡住（卡住 %d 次、照著走了 %d 步）" % [scene.get_file(), ExploreS.guide_stuck, ExploreS.guide_steps])
	return ch


func _run() -> void:
	gs = root.get_node("GameState")
	ExploreS = load("res://scripts/explore/explore.gd")
	gs.fast = true
	gs.save_dir = "user://test_saves_guide"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()
	ExploreS.auto_by_guide = true

	print("[第三章]")
	gs.reset()
	gs.meta.ch2_fates = {"xiaoji": "aboard", "zhongzhong": "aboard", "gaga": "aboard", "youyou": "unknown"}
	gs.meta.ch2_flags = {}
	gs.start_chapter3()
	gs.auto_choices = []
	var ch := await _play("res://scenes/chapter3.tscn", 12000, true)
	ch.queue_free()
	await process_frame

	print("[第四章]")
	gs.reset()
	gs.meta.ch2_fates = {"zhongzhong": "aboard"}
	gs.meta.ch3_flags = {"with_zhongzhong": true}
	gs.start_chapter4()
	gs.auto_choices = [1, 0, 0, 1]
	ch = await _play("res://scenes/chapter4.tscn", 16000)
	ch.queue_free()
	await process_frame

	for route in [["a", {"true_name": true, "c4_dove_seen": true, "c3_chart_pip": true, "with_xiaoji": true, "with_zhongzhong": true, "c3_ecg_saved": true, "c4_lien_told": true, "c3_zhongzhong_innocent": true}, [1, 0]],
			["b1", {}, [0, 1]], ["b2", {"with_xiaoji": true, "with_zhongzhong": true, "c3_ecg_saved": true, "c4_lien_told": true, "c3_zhongzhong_innocent": true}, [0, 0]],
			["b3", {"true_name": true, "c4_dove_seen": true, "c3_chart_pip": true}, [1, 1]]]:
		print("[終章 %s]" % route[0])
		gs.reset()
		gs.meta.ch4_flags = route[1]
		gs.meta.ch2_fates = {}
		gs.start_chapter5()
		gs.auto_choices = route[2].duplicate()
		ch = await _play("res://scenes/chapter5.tscn", 40000)
		_check(ch.route == route[0], "走到終章 %s（實際 %s）" % [route[0], ch.route])
		ch.queue_free()
		await process_frame

	ExploreS.auto_by_guide = false
	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
