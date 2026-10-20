extends SceneTree
## 第五章（終章，基礎版）自動測試：四種終章（A、B-1、B-2、B-3）都走得到、走得完；判定照兩個分數；讀檔從那一段繼續。
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


func _auto_rooms() -> void:
	while is_instance_valid(ch) and not ch._finished:
		var r = ch.room
		if r != null and is_instance_valid(r) and not r.busy:
			var ids: Array = []
			for s in r.spots:
				if s.id != "exit" and (s.get("when", "") == "" or root.get_node("GameState").check(s.when)):
					ids.append(s.id)
			var seen: Dictionary = r.get_meta("seen", {})
			var next := ""
			for id in ids:
				if not seen.has(id):
					next = id
					break
			if next == "":
				next = "exit"
			seen[next] = true
			r.set_meta("seen", seen)
			r.set_busy(true)
			r.picked.emit(next)
		await process_frame


func _play(gs: Node, carry: Dictionary, choices: Array, want: String) -> void:
	gs.reset()
	gs.meta.ch4_flags = carry
	gs.meta.ch2_fates = {}
	gs.start_chapter5()
	gs.auto_choices = choices.duplicate()
	ch = load("res://scenes/chapter5.tscn").instantiate()
	root.add_child(ch)
	_auto_rooms()
	for i in 8000:
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
	_check(int(gs.meta.get("chapters_done", 0)) >= 5, "記錄第五章完成")
	print("[終章 B-1：吃下糖果、不握手、前面什麼都沒有]")
	await _play(gs, {}, [0, 1], "b1")
	print("[終章 B-2：沒有想起來、可是沒有放手]")
	await _play(gs, held, [0, 0], "b2")
	print("[終章 B-3：想起來了、可是放開了手]")
	await _play(gs, remembered, [1, 1], "b3")
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
