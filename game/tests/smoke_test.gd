extends SceneTree
## 自動跑完第一～二天的主要路線：godot --headless -s tests/smoke_test.gd

var main: Node
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _wait_phase(p: String, frames := 600) -> void:
	for i in frames:
		if main.phase == p:
			return
		await process_frame
	_check(false, "等待 phase=%s 逾時（目前 %s）" % [p, main.phase])


func _do(id: String, choices: Array = []) -> void:
	var gs := root.get_node("GameState")
	gs.auto_choices = choices.duplicate()
	await main.interact(id)
	if not gs.auto_choices.is_empty():
		_check(false, "%s 的預設選項沒有用完：%s" % [id, gs.auto_choices])


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	# 測試用的存檔資料夾，不影響玩家的存檔
	gs.save_dir = "user://test_saves"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()
	gs.meta = {"runs": 0, "chapters_done": 0}
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

	print("[第一天]")
	gs.auto_choices = [1]  # 抵達時對露露說「不太好吧」
	await _wait_phase("day1_explore")
	_check(gs.has("lulu_next_time"), "抵達時的選項有作用")
	await _do("fen")
	_check(main.phase == "day1_explore", "拜訪 1 處後仍在探索")
	await _do("clocktower")
	_check(main.phase == "day1_explore", "拜訪 2 處還不夠（要 4 處）")
	await _do("mayor_door")
	await _do("repair_room")
	await _wait_phase("day1_night")
	_check(gs.has("lulu_slip"), "傍晚露露叫錯名字")
	await _do("mirror", [1])
	_check(gs.has("mirror_1") and gs.courage == 1, "盯著鏡子：秘密＋膽量 -1")
	await _do("mirror")
	await _do("bed", [0])

	print("[第二天]")
	await _wait_phase("day2_explore")
	_check(gs.day == 2 and gs.courage == 2, "新的一天，膽量回滿")
	main._on_tag_toggle()
	for i in 10:
		await process_frame
	_check(gs.has("tag_off") and not gs.has("tag_on") and gs.courage == 1, "拆下名牌")
	await _do("lulu", [1])
	_check(gs.has("bread_done") and not gs.has("lulu_song"), "揉麵團（照自己的速度 → 沒有哼歌）")
	await _do("popo")
	_check(gs.has("q_letters") and gs.has("blank_letter") and not gs.has("letter_done"), "波波給三封信＋一封沒有收件人的信")
	await _do("lulu_mailbox")
	await _do("mayor_door")
	await _do("mirror_house")
	await _do("popo")
	_check(gs.has("letter_done") and gs.has("mirror_letter"), "三封信送完，鏡之屋回信了")
	_check(gs.has("fen_invited") and main.phase == "day2_evening", "Fen 的邀請")
	await _do("popo", [0])
	_check(gs.has("asked_past") and gs.courage == 0, "問波波「以前」")
	await _do("popo")
	await _do("bed")
	_check(gs.has("fen_disappointed"), "膽量不足只能乖乖睡覺")

	print("[第三天：衝出去路線]")
	await _wait_phase("day3_explore")
	_check(gs.day == 3 and gs.courage == 2, "第三天，膽量回滿")
	await _do("fen")
	_check(not gs.has("go_forest"), "沒去找露露之前，Fen 不會出發")
	await _do("lulu", [1])
	_check(gs.has("lulu_doubt"), "對露露說「我不知道」")
	await _do("fen")
	await _wait_phase("forest")
	_check(gs.courage == 1, "進森林：膽量 -1")
	await _do("forest_sheep")
	await _do("forest_bow")
	_check(main.phase == "forest", "只調查 2 個還不會觸發鐘聲")
	await _do("forest_tags", [0])
	_check(gs.has("heard_47") and gs.has("brave_end"), "Fen：這是第幾次了 → 衝出去")
	_check(main.phase == "ended" and gs.has("loop_done") and gs.meta.last_ending == "brave", "修理 → 結局③勇敢 → 這一輪結束")
	_check(not gs.has_save() and int(gs.meta.loops_done) == 1 and gs.remembers("knows_47"), "輪迴：刪除當輪存檔、記得「第幾次了」")
	_check(gs.has("found_sheep") and gs.has("found_lulu_bow"), "線索記進日記")
	print("  秘密：", gs.secrets_found(), "　懷疑值：", gs.suspicion)

	print("[第二天晚上：偷溜出門路線]")
	main.queue_free()
	await process_frame
	gs.meta = {"runs": 0, "chapters_done": 0}
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase("day1_explore")
	await _do("lulu")
	await _do("popo")
	await _do("mayor_door")
	await _do("repair_room")
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	await _do("lulu")
	await _do("popo")
	await _do("lulu_mailbox")
	await _do("mayor_door")
	await _do("mirror_house")
	await _do("popo")
	await _do("bed", [0])
	await _wait_phase("night_out")
	_check(gs.has("night_out"), "偷溜出門")
	await _do("lulu")
	_check(gs.has("saw_lulu_night") and gs.has("fen_trust"), "夜晚的露露 → Fen 出現")
	await _wait_phase("day3_explore")
	_check(gs.courage == 2, "第三天膽量回滿")
	await _do("lulu", [0])
	await _do("fen")
	await _wait_phase("forest")
	await _do("forest_tail")
	await _do("forest_tags")
	await _do("fen")
	_check(main.phase == "forest", "沒看到小綿羊之前不會觸發鐘聲")
	await _do("forest_sheep", [1])
	_check(gs.has("lulu_betrayal") and not gs.has("brave_end"), "躲著不動 → 露露告發")
	_check(main.phase == "ended" and gs.meta.last_ending == "betrayed", "結局④被出賣")
	for i in 5:
		await process_frame

	print("[存檔與繼續、揉麵團秘密]")
	main.queue_free()
	await process_frame
	gs.meta = {"runs": 0, "chapters_done": 0}
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase("day1_explore")
	_check(gs.has_save() and gs.checkpoint == "day1_explore", "第一天：自動存檔")
	await _do("lulu")
	await _do("popo")
	await _do("mayor_door")
	await _do("repair_room")
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	_check(gs.checkpoint == "day2_explore", "第二天早上：自動存檔")
	main.queue_free()
	await process_frame
	gs.meta = {"runs": 0, "chapters_done": 0}
	gs.reset()
	gs.resume_on_start = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase("day2_explore")
	gs.resume_on_start = false
	_check(gs.day == 2 and gs.has("visited_lulu") and gs.has("lulu_slip"), "讀檔：回到第二天早上，旗標都還在")
	await _do("lulu", [0])
	_check(gs.has("lulu_song"), "跟著露露的拍子揉 → 露露哼另一首歌（秘密）")
	gs.delete_save()

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
