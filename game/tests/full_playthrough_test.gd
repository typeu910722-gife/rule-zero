extends SceneTree
## 從頭玩到尾（快速模式）：第一章真結局 → 按章末的按鈕進第二章 → 第二章跑完 → 第三章 → 第四章 → 終章。
## 和各章自己的測試不同：這支不手動塞旗標，每一章都從上一章「真的」結束的地方接過去，
## 檢查章與章之間的銜接（按鈕、場景切換、旗標和居民去向有沒有帶過去、存檔）。
## godot --headless --path . -s tests/full_playthrough_test.gd

var failures := 0
var gs: Node


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _wait(cond: Callable, frames: int, what: String) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	_check(false, "等待逾時：" + what)
	return false


func _wait_phase(n: Node, p: String, frames := 900) -> void:
	await _wait(func(): return is_instance_valid(n) and n.phase == p, frames, "phase=%s" % p)


func _do(n: Node, id: String, choices: Array = []) -> void:
	gs.auto_choices = choices.duplicate()
	await n.interact(id)
	if not gs.auto_choices.is_empty():
		_check(false, "%s 的預設選項沒有用完：%s" % [id, gs.auto_choices])
		gs.auto_choices = []


## 在整棵樹裡找文字含 text 的按鈕
func _find_button(n: Node, text: String) -> Button:
	if n is Button and text in (n as Button).text and n.is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b:
			return b
	return null


## 按章末卡片上的按鈕（和玩家點下去一樣），等新的場景出來
func _press_and_switch(text: String, scene_path: String) -> Node:
	# GDScript 的 lambda 抓外面的變數是複製一份，所以用陣列裝結果
	var hold: Array = [null]
	await _wait(func():
		hold[0] = _find_button(root, text)
		return hold[0] != null, 1200, "按鈕「%s」出現" % text)
	var btn: Button = hold[0]
	_check(btn != null, "章末出現「%s」" % text)
	if btn == null:
		return null
	btn.pressed.emit()
	await _wait(func(): return current_scene != null and current_scene.scene_file_path == scene_path, 600, "切換到 " + scene_path)
	var scene: Node = current_scene
	_check(scene != null and scene.scene_file_path == scene_path, "進入 " + scene_path.get_file())
	return scene


## 清掉測試時直接掛在 root 底下、不是 current_scene 的節點（第一章的 main）
func _drop(n: Node) -> void:
	if is_instance_valid(n) and n != current_scene:
		n.queue_free()
		await process_frame


## 第三章的房間：一個一個按調查點，最後按出口（同 chapter3_test）
func _auto_rooms(ch: Node) -> void:
	while is_instance_valid(ch) and not ch._finished:
		var r = ch.room
		if r != null and is_instance_valid(r) and not r.busy:
			var ids: Array = []
			for s in r.spots:
				if s.id != "exit" and (s.get("when", "") == "" or gs.check(s.when)):
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


func _chapter1() -> Node:
	print("[第一章：先一輪露露猶豫（留下記憶），再一輪真結局]")
	gs.meta = {"runs": 0, "chapters_done": 0}
	gs.reset()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase(main, "day1_explore")
	for id in ["lulu", "popo", "mayor_door", "repair_room"]:
		await _do(main, id)
	await _wait_phase(main, "day1_night")
	await _do(main, "bed", [0])
	await _wait_phase(main, "day2_explore")
	for id in ["lulu", "popo", "lulu_mailbox", "mayor_door", "mirror_house", "popo"]:
		await _do(main, id)
	await _wait_phase(main, "day2_evening")
	await _do(main, "bed", [1])
	await _wait_phase(main, "day3_explore")
	await _do(main, "lulu", [1])
	await _do(main, "fen", [0])
	await _wait_phase(main, "forest")
	await _do(main, "forest_sheep")
	await _do(main, "forest_bow")
	await _do(main, "forest_tags", [1])
	_check(gs.meta.get("last_ending", "") == "hesitate", "第一輪：露露猶豫了")

	main.queue_free()
	await process_frame
	gs.start_next_loop()
	gs.pending_loop_start = false
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase(main, "day1_explore")
	gs.meta.tufts = ["tuft_0", "tuft_1", "tuft_2", "tuft_3", "tuft_4", "tuft_5"]
	await _do(main, "lulu", [0])
	await _do(main, "fen", [0])
	await _do(main, "mayor_door")
	await _do(main, "repair_room")
	await _wait_phase(main, "day1_night")
	await _do(main, "bed", [0])
	await _wait_phase(main, "day2_explore")
	for id in ["lulu", "popo", "lulu_mailbox", "mayor_door"]:
		await _do(main, id)
	main.hold_interior = true
	await _do(main, "mayor_door", [0])
	if main.interior:
		await main.interior.inspect("int_mayor_rules")
		await main._exit_interior()
	main.hold_interior = false
	await _do(main, "mirror_house")
	await _do(main, "popo")
	await _wait_phase(main, "day2_evening")
	await _do(main, "bed", [1])
	await _wait_phase(main, "day3_explore")
	await _do(main, "lulu", [0])
	await _do(main, "fen", [2])
	main.hold_interior = true
	await _do(main, "fen_tree")
	if main.interior:
		gs.auto_choices = [0]
		await main.interior.inspect("int_fen_plank")
		await main._exit_interior()
	main.hold_interior = false
	await _do(main, "fen")
	await _wait_phase(main, "forest")
	await _do(main, "forest_sheep")
	await _do(main, "forest_bow")
	await _do(main, "forest_tags")
	_check(gs.meta.get("last_ending", "") == "truth" and gs.has("chapter_done"), "第一章真結局（老師）")
	_check(gs.has("got_key") and gs.has("found_class_rules"), "第一章的旗標：鑰匙、班規")
	return main


func _chapter2(ch: Node) -> void:
	print("[第二章：從第一章真結局接過來，跑到畢業典禮]")
	_check(gs.chapter == 2 and gs.day == 1, "第二章第一天")
	_check(gs.has("got_key") and gs.has("chapter2"), "第一章的旗標帶進第二章")
	gs.fast_apology_take = true
	gs.fast_scrub_keep = true
	# 序章的選項數量依第一章的旗標而定：先給夠，結束後清掉
	gs.auto_choices = [0, 2, 3]
	await _wait_phase(ch, "day1_explore", 3000)
	gs.auto_choices = []
	_check(gs.has("ch2_referral"), "序章：轉介單")
	await _do(ch, "xiaoji", [1])
	await _do(ch, "treatment_door")
	await _do(ch, "baimian", [2, 1])
	await _wait_phase(ch, "day1_night")
	await _do(ch, "c2_pillow")
	gs.auto_choices = [0, 1, 1, 0, 0, 0]
	await ch.interact("c2_bed")
	gs.auto_choices = []
	await _wait_phase(ch, "day2_explore", 3000)
	_check(gs.day == 2, "第二章第二天")
	await _do(ch, "gaga", [0])
	gs.auto_choices = [1, 1, 1, 0, 0, 0]
	await ch.interact("baimian")
	gs.auto_choices = []
	await _wait_phase(ch, "day3_explore", 3000)
	_check(gs.day == 3, "第二章第三天")
	gs.auto_choices = [1, 1, 0, 2, 0, 0, 0]
	await ch.interact("xiaoji")
	gs.auto_choices = []
	await _wait_phase(ch, "ended", 6000)
	_check(gs.meta.has("ch2_fates") and gs.meta.has("ch2_flags"), "第二章結束：記下居民去向與旗標")
	_check(gs.meta.get("ch2_flags", {}).has("got_key"), "第二章存下的旗標裡還有第一章的")
	gs.fast_apology_take = false
	gs.fast_scrub_keep = false


func _run() -> void:
	gs = root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves_full"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()

	# 網頁版的章節連結：?dev=ch2～ch5 都要能直接進該章（2026-11-05 補上 ch2）
	var msrc := FileAccess.get_file_as_string("res://scripts/main.gd")
	for c in ["ch2", "ch3", "ch4", "ch5"]:
		var at := msrc.find('"%s":' % c, msrc.find("func _run_dev_preview"))
		_check(at > 0 and msrc.find("enter_chapter%s(get_tree())" % c.substr(2), at) - at < 60, "網址 ?dev=%s 直接進第 %s 章" % [c, c.substr(2)])

	var main := await _chapter1()
	var ch2 := await _press_and_switch("前往第二章", "res://scenes/chapter2.tscn")
	await _drop(main)
	if ch2 == null:
		return _finish()
	await _chapter2(ch2)

	print("[第三章：按「繼續第三章」]")
	var ch3 := await _press_and_switch("繼續第三章", "res://scenes/chapter3.tscn")
	if ch3 == null:
		return _finish()
	var fates: Dictionary = gs.meta.get("ch2_fates", {})
	_check(gs.has("with_zhongzhong") == (fates.get("zhongzhong", "") == "aboard"), "重重在不在隊伍裡，照第二章的去向（%s）" % fates.get("zhongzhong", "?"))
	_check(gs.has("got_key"), "第一章的旗標帶進第三章")
	_auto_rooms(ch3)
	await _wait(func(): return is_instance_valid(ch3) and ch3._finished, 12000, "第三章結尾")
	_check(gs.meta.has("ch3_flags"), "第三章結束：存下旗標")

	print("[第四章：按「繼續第四章」]")
	gs.auto_choices = [1, 0, 0, 1]
	var ch4 := await _press_and_switch("繼續第四章", "res://scenes/chapter4.tscn")
	if ch4 == null:
		return _finish()
	_check(gs.chapter == 4 and gs.has("c3_hairpin"), "第三章的旗標（髮夾）帶進第四章")
	await _wait(func(): return is_instance_valid(ch4) and ch4._finished, 16000, "第四章結尾")
	_check(gs.auto_choices.is_empty(), "第四章的選項剛好用完（剩 %s）" % [gs.auto_choices])
	_check(gs.meta.has("ch4_flags"), "第四章結束：存下旗標")

	print("[終章：按「繼續第五章」]")
	gs.auto_choices = [1, 0]
	var ch5 := await _press_and_switch("終章", "res://scenes/chapter5.tscn")
	if ch5 == null:
		return _finish()
	_check(gs.chapter == 5 and gs.has("got_key") and gs.has("c3_hairpin"), "第一、三章的旗標都帶進終章")
	await _wait(func(): return is_instance_valid(ch5) and ch5._finished, 60000, "終章結尾")
	_check(ch5.route in ["a", "b1", "b2", "b3"], "走到一個終章（%s，分數 %s）" % [ch5.route, ch5.scores(gs.flags)])
	_check(int(gs.meta.get("chapters_done", 0)) >= 5, "五章都記下完成")
	_finish()


func _finish() -> void:
	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
