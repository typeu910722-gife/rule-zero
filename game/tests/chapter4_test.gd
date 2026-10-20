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


## 房間：一個一個按調查點，最後按出口
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


func _play(gs: Node, choices: Array, zz_dead: bool) -> void:
	gs.reset()
	gs.meta.ch2_fates = {"zhongzhong": "dead" if zz_dead else "aboard"}
	gs.meta.ch3_flags = {"with_zhongzhong": not zz_dead, "c3_hairpin": true}
	gs.start_chapter4()
	gs.auto_choices = choices.duplicate()
	ch = load("res://scenes/chapter4.tscn").instantiate()
	root.add_child(ch)
	_auto_rooms()
	for i in 8000:
		if ch._finished:
			break
		await process_frame
	_check(ch._finished, "走到第四章結尾")
	_check(gs.auto_choices.is_empty(), "預設選項剛好用完（剩 %s）" % [gs.auto_choices])


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves_ch4"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()

	# 選項順序：辛禾（拿／不拿）、芬（看窗外／擋）、郡主（看窗外／看著芬）、導師（看窗外／看手）、李恩（說／不說）
	print("[第四章：三個視角都看窗外、不拿信、說出還有一個人]")
	await _play(gs, [1, 0, 0, 0, 1], false)
	_check(gs.has("c4_dove_seen"), "三個視角都看過窗外 → c4_dove_seen")
	_check(gs.has("c4_letter_not_taken") and gs.has("c4_lien_told"), "不拿信、說出口的旗標")
	_check(gs.has("c3_hairpin"), "第三章的旗標帶過來了")
	_check(int(gs.meta.get("chapters_done", 0)) >= 4, "記錄第四章完成")
	_check(gs.meta.get("ch4_flags", {}).has("c4_dove_seen"), "第四章旗標存給第五章")
	ch.queue_free()
	await process_frame

	print("[第四章：重重被處分（白面轉述）、都沒看窗外]")
	await _play(gs, [0, 1, 1, 1, 0], true)
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
