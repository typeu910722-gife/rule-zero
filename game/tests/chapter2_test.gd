extends SceneTree
## 第二章（序章＋第一天）自動測試：godot --headless -s tests/chapter2_test.gd

var ch: Node
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
		if ch.phase == p:
			return
		await process_frame
	_check(false, "等待 phase=%s 逾時（目前 %s）" % [p, ch.phase])


func _do(id: String, choices: Array = []) -> void:
	var gs := root.get_node("GameState")
	gs.auto_choices = choices.duplicate()
	await ch.interact(id)
	if not gs.auto_choices.is_empty():
		_check(false, "%s 的預設選項沒有用完：%s" % [id, gs.auto_choices])


func _start(gs: Node, ch1_flags: Dictionary) -> void:
	gs.reset()
	for k in ch1_flags:
		gs.set_flag(k, ch1_flags[k])
	gs.start_chapter2()
	gs.checkpoint = "c2_start"
	ch = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()

	print("[路線一：替重重受罰、交出鈕扣]")
	# 序章：看露露 → 看胸口（轉介單）→ 等火車停下來
	gs.fast_apology_take = true
	_start(gs, {"lulu_doubt": true, "got_button": true, "found_fox_tail": true})
	gs.auto_choices = [0, 3, 5]
	await _wait_phase("day1_explore")
	_check(gs.chapter == 2 and gs.day == 1, "第二章第一天")
	_check(gs.has("ch2_referral") and gs.has("c2_grey_patch"), "轉介單、和平鴿摸過的地方褪色")
	_check(gs.has("took_shock_for_zhongzhong") and gs.courage == 1 and gs.conduct == 90, "道歉練習：替重重受罰（膽量 -1、操行 -10）")
	_check(gs.has_save() and gs.checkpoint == "c2_day1_explore", "自由時間開始時自動存檔")
	await _do("xiaoji", [1])
	_check(gs.has("xiaoji_mask_crack") and gs.courage == 0, "問小棘為什麼一直笑（膽量 -1）")
	_check(ch.phase == "day1_explore", "認識 1 個居民後仍在自由時間")
	await _do("treatment_door")
	await _do("baimian", [1])
	_check(gs.has("met_baimian"), "白面：「遙。你還活著啊。」")
	await _wait_phase("day1_night")
	_check(not gs.has("saw_eighth_name"), "點名：看著前面")
	await _do("c2_pillow")
	_check(not gs.has("color_shard_1") and gs.has("c2_ate_white_candy") and gs.conduct == 95, "膽量 0：只能把鈕扣交出去（操行 +5）")
	await _do("c2_bed", [0])
	await _wait_phase("ended")
	_check(gs.has("c2_sleep_1"), "睡覺 → 夢境 1 → 第一天結束")
	print("  秘密：", gs.secrets_found(), "　操行：", gs.conduct)

	print("[路線二：不受罰、看第 8 個位置、藏起鈕扣]")
	ch.queue_free()
	await process_frame
	gs.fast_apology_take = false
	_start(gs, {})
	gs.auto_choices = [4, 3, 5]
	await _wait_phase("day1_explore")
	_check(not gs.has("took_shock_for_zhongzhong") and gs.courage == 2 and gs.conduct == 100, "道歉練習：沒有受罰")
	await _do("zhongzhong")
	await _do("youyou")
	_check(gs.has("met_zhongzhong") and gs.has("met_youyou"), "認識重重、鼬鼬")
	await _wait_phase("day1_night")
	_check(gs.has("saw_eighth_name"), "點名：看著第 8 個位置")
	await _do("c2_pillow", [0])
	_check(gs.has("color_shard_1") and gs.courage == 1, "藏起彩色鈕扣（膽量 -1）")
	await _do("c2_bed", [1])
	_check(ch.phase == "day1_night", "「再等一下」不會睡著")
	await _do("c2_bed", [0])
	await _wait_phase("ended")

	print("[存檔與繼續]")
	ch.queue_free()
	await process_frame
	gs.reset()
	_check(gs.load_game() and gs.chapter == 2 and gs.checkpoint == "c2_day1_explore", "讀檔：第二章第一天的自由時間")
	ch = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)
	await _wait_phase("day1_explore")
	_check(not gs.has("met_zhongzhong"), "讀檔回到自由時間開始的狀態")
	gs.delete_save()
	gs.chapter = 1

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
