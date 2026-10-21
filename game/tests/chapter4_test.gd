extends SceneTree
## 第四章（基礎版）自動測試：每個視角、房間、小遊戲、那一天、結尾都走得完；旗標照選擇設定；讀檔從那一段繼續。
## godot --headless --path . -s tests/chapter4_test.gd

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




func _play(gs: Node, choices: Array, zz_dead: bool) -> void:
	gs.reset()
	gs.meta.ch2_fates = {"zhongzhong": "dead" if zz_dead else "aboard"}
	gs.meta.ch3_flags = {"with_zhongzhong": not zz_dead, "c3_hairpin": true}
	gs.start_chapter4()
	gs.auto_choices = choices.duplicate()
	ch = load("res://scenes/chapter4.tscn").instantiate()
	root.add_child(ch)
	for i in 8000:
		if ch._finished:
			break
		await process_frame
	_check(ch._finished, "走到第四章結尾")
	_check(gs.auto_choices.is_empty(), "預設選項剛好用完（剩 %s）" % [gs.auto_choices])


func GameState_pov_clear(gs: Node) -> bool:
	for k in gs.flags:
		if str(k).begins_with("c4_pov_"):
			return false
	return true


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves_ch4"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()

	# 選項順序：辛禾（拿／不拿）、郡主（看窗外／看著芬）、導師（看窗外／看手）、李恩（不說／說）
	# （芬的「看窗外」現在是地圖上的調查點，自動玩家會去看）
	print("[第四章：三個視角都看窗外、不拿信、說出還有一個人]")
	await _play(gs, [1, 0, 0, 1], false)
	_check(gs.has("c4_dove_seen"), "三個視角都看過窗外 → c4_dove_seen")
	_check(gs.has("c4_letter_not_taken") and gs.has("c4_lien_told"), "不拿信、說出口的旗標")
	_check(gs.has("c3_hairpin"), "第三章的旗標帶過來了")
	# 地圖探索：遙的第一天（看班規 → 自我介紹）、小滿放學後（書包、鞋子、校門口）
	_check(gs.has("c4_saw_rules") and gs.has("c4_h_spoke"), "遙：看了班規、上台自我介紹")
	_check(gs.has("c4_m_bag_done") and gs.has("c4_m_found_shoes") and gs.has("c4_m_done"), "小滿：書包、鞋子、等到辛禾")
	_check(gs.has("c4_t_done") and gs.has("c4_l_done") and gs.has("c4_x_done") and gs.has("c4_p_done"), "薙文、希露飛、辛禾、銘越的地圖都走完了")
	_check(gs.has("c4_d1_done") and gs.has("c4_d2_done") and gs.has("c4_d5_called") and gs.has("c4_d5_done") and gs.has("c4_d8_done"), "那一天：遙、值日生、芬（找老師、擋在門前）、李恩的地圖都走完")
	_check(gs.has("c4_o_done") and gs.has("done_c4_org_board") and gs.has("done_c4_org_father"), "那一天之後：校長室、黑板、醫院、月台")
	_check(gs.has("done_c4_n_left") and gs.has("done_c4_n_right") and gs.has("done_c4_n_haruka") and gs.has("c4_n_done"), "第一個晚上：看過兩邊的床、電閘")
	_check(gs.has("c4_te_night") and gs.has("c4_te_done"), "導師：留到晚上、重寫班規")
	_check(gs.has("done_c4_fen_desk") and gs.has("done_c4_fen_trash") and gs.has("c4_f_done"), "芬：桌子、垃圾桶、走廊盡頭")
	_check(gs.has("done_c4_l_shard1") and gs.has("done_c4_l_shard2") and gs.has("done_c4_l_shard3"), "希露飛：三片鏡子碎片都翻過去了")
	_check(GameState_pov_clear(gs), "視角旗標用完就清掉")
	_check(int(gs.meta.get("chapters_done", 0)) >= 4, "記錄第四章完成")
	_check(gs.meta.get("ch4_flags", {}).has("c4_dove_seen"), "第四章旗標存給第五章")
	ch.queue_free()
	await process_frame

	print("[第四章：重重被處分（白面轉述）、都沒看窗外]")
	await _play(gs, [0, 1, 1, 0], true)
	_check(gs.has("zz_dead"), "重重被處分的旗標")
	_check(not gs.has("c4_dove_seen") and not gs.has("c4_lien_told"), "沒看窗外、沒說")
	ch.queue_free()
	await process_frame

	print("[讀檔：從那一天繼續]")
	gs.reset()
	gs.start_chapter4()
	gs.save_game("c4_theday")
	gs.reset()
	gs.load_game()
	_check(gs.chapter == 4 and gs.checkpoint == "c4_theday", "存檔記得第四章、那一天")
	ch = load("res://scenes/chapter4.tscn").instantiate()
	root.add_child(ch)
	await process_frame
	_check(ch.segment == "theday", "從那一天開始")
	ch.queue_free()
	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
