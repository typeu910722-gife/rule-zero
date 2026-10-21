extends SceneTree
## 第五章（終章）自動測試：地圖探索（實驗室、最後一堂課之前、四種終章的地圖）都走得完；判定照兩個分數；讀檔從那一段繼續。
## godot --headless --path . -s tests/chapter5_test.gd

var failures := 0
var ch: Node


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _play(gs: Node, carry: Dictionary, choices: Array, want: String) -> void:
	gs.reset()
	gs.meta.ch4_flags = carry
	gs.meta.ch2_fates = {}
	gs.start_chapter5()
	gs.auto_choices = choices.duplicate()
	ch = load("res://scenes/chapter5.tscn").instantiate()
	root.add_child(ch)
	for i in 40000:
		if ch._finished:
			break
		await process_frame
	_check(ch._finished, "走到終章結尾")
	_check(ch.route == want, "進入 %s（實際 %s，分數 %s）" % [want, ch.route, ch.scores(gs.flags)])
	_check(gs.auto_choices.is_empty(), "預設選項剛好用完")
	ch.queue_free()
	await process_frame


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves_ch5"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()
	var remembered := {"true_name": true, "c4_dove_seen": true, "c3_chart_pip": true}
	var held := {"with_xiaoji": true, "with_zhongzhong": true, "c3_ecg_saved": true, "c4_lien_told": true, "c3_zhongzhong_innocent": true}
	var both := remembered.duplicate()
	both.merge(held)
	# 選項：糖果（0 吃／1 丟）、Fen 的手（0 握／1 不握）
	print("[終章 A：都想起來、都沒有放手]")
	await _play(gs, both, [1, 0], "a")
	_check(gs.has("c5_baimian_returned"), "白面把自己還給芬（悲劇收場）")
	_check(gs.has("done_c5_x_wall") and gs.has("done_c5_x_mask") and gs.has("c5_x_done"), "實驗室：牆、面具、車掌")
	var all := true
	for id in ["lulu", "mochi", "popo", "fen", "baimian"]:
		all = all and gs.has("done_c5_x_" + id)
	_check(gs.has("c5_talked_all") == all, "實驗室：看過大家才有「沒有放手 +1」（可選，不強迫）")
	_check(gs.has("c5_read_file") and gs.has("done_c5_l_monitor") and gs.has("c5_l_done"), "最後一堂課之前：檔案室、監視室、回到病床")
	_check(gs.has("c5_l_drawer_open") and gs.has("done_c5_l_drawer_in"), "理事室：照片背面的密碼打開抽屜")
	_check(gs.has("c5_woke_lulu") and gs.has("c5_woke_fen") and gs.has("done_c5_a_xinhe"), "終章 A：叫醒大家、白線的另一邊")
	_check(gs.has("c5_a_done") and not gs.has("c5_st_a"), "終章 A：走出大門，階段旗標清掉")
	_check(int(gs.meta.get("chapters_done", 0)) >= 5, "記錄第五章完成")
	print("[終章 B-1：吃下糖果、不握手、前面什麼都沒有]")
	await _play(gs, {}, [0, 1], "b1")
	_check(gs.has("c5_b1_ruled") and gs.has("c5_b1_repaired") and gs.has("c5_b1_done"), "B-1：公館寫守則 → 修理室 → 月台")
	print("[終章 B-2：沒有想起來、可是沒有放手]")
	await _play(gs, held, [0, 0], "b2")
	_check(gs.has("c5_b2_guarded") and gs.has("c5_b2_done"), "B-2：看過四間病房 → 守住走廊 → 走廊盡頭的床")
	print("[終章 B-3：想起來了、可是放開了手]")
	await _play(gs, remembered, [1, 1], "b3")
	_check(gs.has("c5_b3_seen_fen") and gs.has("c5_b3_done"), "B-3：芬的病房 → 出院 → 校門口")
	print("[翻盤：差一點點想起來，丟掉糖果推過門檻]")
	var almost := {"true_name": true, "with_xiaoji": true, "with_gaga": true, "c3_ecg_saved": true}
	await _play(gs, almost, [1, 0], "a")
	_check(gs.meta.get("finale_routes", []).size() >= 4, "四種終章都記下來了")

	print("[讀檔：從最後的選擇繼續]")
	gs.reset()
	gs.start_chapter5()
	gs.save_game("c5_choice")
	gs.reset()
	gs.load_game()
	_check(gs.chapter == 5 and gs.checkpoint == "c5_choice", "存檔記得第五章、最後的選擇")
	ch = load("res://scenes/chapter5.tscn").instantiate()
	root.add_child(ch)
	_check(ch.segment == "choice", "從最後的選擇開始")
	await process_frame
	ch.queue_free()
	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
