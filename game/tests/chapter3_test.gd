extends SceneTree
## 第三章（基礎版）自動測試：從第二章結束的狀態進入，房間調查、小遊戲、結尾都走得完。
## godot --headless --path . -s tests/chapter3_test.gd

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


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves_ch3"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()

	for case in [{"fates": {"xiaoji": "aboard", "zhongzhong": "aboard", "gaga": "aboard", "youyou": "unknown"}, "flags": {"letter_to_lulu": true, "tiaoma_color_left": true}},
			{"fates": {"xiaoji": "graduated", "zhongzhong": "dead", "gaga": "graduated", "youyou": "aboard"}, "flags": {}}]:
		print("[第三章：", case.fates, "]")
		gs.reset()
		gs.meta.ch2_fates = case.fates
		gs.meta.ch2_flags = case.flags
		gs.start_chapter3()
		gs.auto_choices = []
		ch = load("res://scenes/chapter3.tscn").instantiate()
		root.add_child(ch)
		_auto_rooms()
		for i in 6000:
			if ch._finished:
				break
			await process_frame
		_check(ch._finished, "走到第三章結尾")
		_check(gs.has("c3_heart_done") and gs.has("c3_haruka_slip") and gs.has("c3_chart_pip") and gs.has("c3_hairpin"), "心臟病、找遙的床、轉介單、實驗室的髮夾都經過了")
		_check(int(gs.meta.get("chapters_done", 0)) >= 3, "記錄第三章完成")
		# 一樓地圖探索：鑷子 → 號碼牌 → 心臟病 → 鑰匙卡 → 電梯（自動玩家要能自己解開，不會卡在按電梯）
		_check(gs.has("c3_tweezers") and gs.has("c3_ticket") and gs.has("c3_took_elevator"), "一樓的謎題串都解開了（鑷子、號碼牌、電梯）")
		_check(gs.has("c3_pharmacy_open") and gs.has("c3_ph_ledger"), "藥局支線：密碼鎖、處方簿")
		# 二樓：轉床的紙 → 量體溫 → 被服室的小鑰匙 → 鑰匙箱 → 病歷室 → 理事室密碼 → 連通道
		_check(gs.has("c3_thermo_done") and gs.has("c3_small_key") and gs.has("c3_key_records"), "二樓：量體溫、小鑰匙、病歷室的鑰匙")
		_check(gs.has("c3_director_open") and gs.has("c3_director_done") and gs.has("c3_to_wild"), "二樓：理事室密碼、理事室、往舊病棟")
		_check(gs.has("with_zhongzhong") == (case.fates.zhongzhong == "aboard"), "重重在不在隊伍裡，照第二章的去向")
		var cotton_ok := true
		for p in ch.party:
			var v := int(gs.flags.get("c3_cotton_%s" % p[0], -1))
			if v < 1 or v > 10:
				cotton_ok = false
		_check(cotton_ok, "棉花在 1～10 之間（不會有人提早退場）")
		ch.queue_free()
		await process_frame

	print("[讀檔：從病歷室繼續]")
	gs.reset()
	gs.meta.ch2_fates = {}
	gs.start_chapter3()
	gs.save_game("c3_records")
	gs.reset()
	gs.load_game()
	_check(gs.chapter == 3 and gs.checkpoint == "c3_records", "存檔記得第三章、病歷室（舊檢查點）")
	ch = load("res://scenes/chapter3.tscn").instantiate()
	root.add_child(ch)
	await process_frame
	_check(ch.segment == "floor2", "舊存檔的病歷室 → 從二樓那一段開始")
	ch.queue_free()
	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
