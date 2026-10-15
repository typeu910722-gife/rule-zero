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
	# 睡覺 → 夢境 1 → 第二天早上：早餐藏糖果、洗白白留色、放過嘎嘎、舉報鼬鼬
	gs.fast_scrub_keep = true
	await _do("c2_bed", [0, 1, 1, 0])
	await _wait_phase("day2_explore")
	_check(gs.has("c2_sleep_1") and gs.day == 2 and gs.courage == 2, "睡覺 → 夢境 1 → 第二天，膽量回滿")
	_check(gs.checkpoint == "c2_day2_morning", "第二天早上：自動存檔")
	_check(gs.has("kept_white_candy") and gs.has("tiaoma_color_left") and gs.has("tiaoma_1"), "藏起白色糖果；洗白白留下一塊顏色")
	_check(not gs.has("reported_gaga") and gs.has("reported_youyou"), "放過嘎嘎、舉報鼬鼬")
	_check(gs.conduct == 70, "操行：95 -10（留色）-10（放過）+10（舉報）-15（被小棘舉報）= 70（實際 %d）" % gs.conduct)
	await _do("gaga", [0])
	_check(gs.has("photo_1") and gs.has("photo_2") and gs.has("photo_nirvana") and not gs.has("c2_sneak_caught"), "拿回底片：三張照片")
	_check(ch.phase == "day2_explore", "還沒問白面之前不會天黑")
	await _do("baimian", [1])
	_check(gs.has("baimian_tail") and gs.has("baimian_dove_past"), "白面：尾巴（第一章看過）＋和平鴿的過去")
	_check(gs.has("answered_haruka") and gs.courage == 1 and gs.conduct == 60, "點名替「遙」回答（膽量 -1、操行 -10）")
	await _wait_phase("ended")
	_check(not gs.has("night_out_2"), "舉報過鼬鼬：沒有人敲窗戶")
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
	# 第二天：吃糖、刷乾淨、舉報嘎嘎、放過鼬鼬；被和平鴿看到拿底片
	gs.fast_scrub_keep = false
	gs.fast_sneak_caught = true
	await _do("c2_bed", [0, 0, 0, 1])
	await _wait_phase("day2_explore")
	_check(gs.has("c2_ate_white_candy") and not gs.has("tiaoma_color_left"), "吃掉白色糖果；條碼刷乾淨")
	_check(gs.has("reported_gaga") and not gs.has("reported_youyou") and gs.conduct == 75, "舉報嘎嘎、放過鼬鼬（操行上限 100：100 -10 -15 = %d）" % gs.conduct)
	await _do("gaga", [0])
	_check(gs.has("c2_sneak_caught") and gs.conduct == 65, "拿底片被看到（操行 -10）")
	await _do("baimian", [0, 0])
	_check(not gs.has("baimian_tail") and gs.has("baimian_dove_past"), "沒看過狐狸尾巴：白面不提尾巴")
	await _wait_phase("night_out_2")
	_check(gs.has("night_out_2") and gs.courage == 1 and not gs.has("answered_haruka"), "點名不出聲；跟鼬鼬偷溜（膽量 -1）")
	await _do("treatment_window")
	_check(gs.has("saw_silhouette"), "治療室的剪影")
	await _do("office", [0, 1, 2])
	_check(gs.has("youyou_lost_thread") and gs.has("dove_first_page") and gs.has("nirvana_clipboard"), "辦公室：鼬鼬用紅毛線引開機械鳥；愛的日記、涅槃夾板")
	await _do("platform")
	await _wait_phase("ended")
	_check(gs.has("overheard_conductor") and gs.conduct == 45, "月台偷聽 → 被抓到（操行 -20）")
	print("  秘密：", gs.secrets_found(), "　操行：", gs.conduct)

	print("[存檔與繼續]")
	ch.queue_free()
	await process_frame
	gs.reset()
	_check(gs.load_game() and gs.chapter == 2 and gs.checkpoint == "c2_day2_morning", "讀檔：第二章第二天早上")
	gs.auto_choices = [0, 0, 0]
	ch = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)
	await _wait_phase("day2_explore")
	_check(gs.day == 2 and not gs.has("photo_1"), "讀檔回到第二天早上的狀態")
	gs.delete_save()
	gs.chapter = 1

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
