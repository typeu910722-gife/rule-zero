extends SceneTree
## 記憶深度：每走完一輪，火車上會想起新的一段過去；第三輪起記得順序（搶先說台詞）、
## 第四輪起 Fen 主動找你、第五輪起想起最後一段。
## godot --headless -s tests/memory_test.gd

var failures := 0
var gs: Node
var main: Node


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


## 用指定的「走完幾輪」開一輪新的
func _loop(done: int, extra := {}) -> void:
	if main:
		main.queue_free()
		await process_frame
	var memory: Dictionary = gs.meta.get("memory", {}) if done > 0 else {}
	gs.meta = {"runs": 0, "chapters_done": 0, "loop": 47 + done, "loops_done": done,
		"memory": memory, "last_ending": "hesitate" if done > 0 else "", "endings": [], "tufts": []}
	for k in extra:
		gs.meta[k] = extra[k]
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase("day1_explore")


func _run() -> void:
	gs = root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves"

	print("[一輪結束：記下「才剛想起來」的事]")
	gs.meta = {"runs": 0, "memory": {"knows_47": true}, "tufts": []}
	gs.reset()
	gs.set_flag("found_lulu_bow")
	gs.set_flag("heard_47")
	gs.collect_tuft("tuft_3")
	gs.finish_loop("hesitate")
	_check("knows_bow" in gs.meta.fresh and "tuft_3" in gs.meta.fresh, "新的記憶＋這輪撿的棉花 → fresh：%s" % [gs.meta.fresh])
	_check(not "knows_47" in gs.meta.fresh, "以前就記得的，不算新的")
	_check(gs.memory_depth() == 1, "走完一輪 → 記憶深度 1")

	print("[第二輪：想起第一段]")
	await _loop(1, {"fresh": ["knows_bow", "tuft_3"]})
	_check(gs.remembers("story_1") and not gs.remembers("story_2"), "火車上想起：我叫遙")

	print("[第三輪：記得順序]")
	await _loop(2)
	_check(gs.remembers("story_2") and not gs.remembers("story_3"), "火車上想起：三年二班的班規")
	_check(gs.has("said_lulu"), "〔記得〕搶先叫出露露的名字")
	_check(gs.has("said_name"), "〔記得〕搶先說出名牌上的名字")
	_check(gs.has("got_button"), "第一天就撿到鈕扣")

	print("[第四輪：記得大家]")
	await _loop(3)
	_check(gs.remembers("story_3"), "火車上想起：廁所門外輪流把風的鞋子、發抖的老師")
	gs.auto_choices = [0]
	await main.interact("fen")
	_check(gs.has("fen_knows_you") and gs.has("fen_trust"), "Fen 第一天就主動找你")
	_check(gs.has("q_notes") and gs.has("gift_leaf"), "Fen 的筆記委託、葉子照樣拿到")

	print("[第五輪：記得自己]")
	await _loop(5)
	_check(gs.memory_depth() == 4, "記憶深度最多 4")
	_check(gs.remembers("story_4"), "火車上想起：醫院、第一個戳章")
	var pages: Array = gs.STORY_TEXT.keys().filter(func(k): return gs.remembers(k))
	_check(pages.size() == 4, "日記：想起來的事 4 / 4")

	print("[舊存檔一次跳到很多輪：一段一段補想起來]")
	await _loop(6, {"memory": {}})
	_check(gs.remembers("story_1") and gs.remembers("story_4"), "四段都想起來了")

	print("[小狗居民＝旁觀者]")
	await _loop(1)
	var dlg := root.get_node("Dialogue")
	gs.day = 2
	await dlg.run("extra1_d2")
	_check(gs.has("dog_d2_done"), "第二天：走廊盡頭是廁所")
	gs.day = 3
	gs.auto_choices = [0]
	await dlg.run("extra1_d3")
	_check(gs.has("dog_confessed"), "第三天：「我那天坐在窗戶旁邊，都看到了」")

	print("[夜車：每個人的小結局＋拿回名字]")
	for f in ["lulu_mirror_seen", "saw_pink", "tama_done", "mochi_remembers"]:
		gs.set_flag(f)
	gs.auto_choices = [0, 0]
	await dlg.run("nt_lulu")
	_check(gs.auto_choices.is_empty(), "小狗居民的選項＋名字的選項都出現了")
	_check(gs.has("true_name") and gs.remembers("true_name"), "拆下名牌：「我叫遙。」（跨輪記住）")
	gs.finish_loop("truth")
	_check("true_name" in gs.meta.collected and gs.remembers("knows_dog"), "蒐藏：「小布」的名牌；謎團：小狗居民在掃什麼")
	_check(gs.heaviness() >= 2, "標題畫面變沉重（%d）" % gs.heaviness())

	print("[車掌：懷疑 → 困惑 → 不敢置信 → 加油（一輪前進一段）]")
	for k in [1, 2, 3, 4]:
		await _loop(k + 1)
		gs.day = 2
		await dlg.run("conductor")
		_check(gs.remembers("conductor_%d" % k) and not gs.remembers("conductor_%d" % (k + 1)), "第 %d 段" % k)
		await dlg.run("conductor")
		_check(not gs.remembers("conductor_%d" % (k + 1)), "同一輪再聊，不會跳下一段")
	_check(gs.has("conductor_glove"), "收到車掌的白手套")
	await _loop(6)
	gs.day = 2
	await dlg.run("conductor")
	_check(gs.has("co_cheer"), "之後的輪：「……加油。」")

	print("[送信、丟小石頭：每一輪不一樣]")
	for k in [0, 1, 2, 3, 4]:
		await _loop(k)
		gs.day = 2
		gs.flags.erase("q_letters")
		await dlg.run("popo_d2")
		for id in ["lulu_mailbox", "mayor_door_day2_explore", "mirror_house_day2_explore"]:
			await dlg.run(id)
		await dlg.run("popo_d2")
		await dlg.run("fen_invite")
		_check(gs.has("blank_letter") and int(gs.flags.get("letters", 0)) == 3 and gs.has("mirror_letter") and gs.has("letter_done") and gs.has("fen_invited"),
			"記憶深度 %d：拿信 → 送三封 → 回報 → Fen 的邀請" % k)

	print("[露露的蝴蝶結：每一輪懷疑得更深]")
	for k in [1, 2, 3, 4]:
		await _loop(k)
		gs.meta.memory["knows_bow"] = true
		gs.set_flag("visited_lulu")
		gs.auto_choices = [0]
		await dlg.run("lulu_d1")
		_check(gs.has("lulu_doubt"), "第 %d 層：第一天〔記得〕黃色蝴蝶結" % k)
		gs.day = 3
		gs.auto_choices = [1]
		await dlg.run("lulu_d3")
		_check(gs.has("lulu_d3_done") and gs.auto_choices.is_empty(), "第 %d 層：第三天的夢／拆開的蝴蝶結" % k)

	print("[麻糬：被拒絕一次，就不會再問了]")
	await _loop(1)
	gs.day = 2
	gs.auto_choices = [1]
	await dlg.run("mochi_d2")
	_check(gs.remembers("mochi_refused") and not gs.has("q_mochi"), "拒絕 → 記住了")
	await dlg.run("mochi_d2")
	_check(not gs.has("q_mochi"), "同一輪再找他：不會再開口問")
	await _loop(2)
	gs.day = 2
	await dlg.run("mochi_d2")
	_check(not gs.has("q_mochi"), "下一輪也不會再問（委託、麻糬的結局都拿不到了）")

	print("[鏡之屋：被邀請之後敲門進去]")
	await _loop(3)
	await dlg.run("mirror_house")
	_check(gs.remembers("mirror_invite"), "第四輪：倒影從裡面敲門 → 被邀請")
	gs.auto_choices = [0]
	await dlg.run("mirror_house")
	_check(gs.has("want_enter_mirror") and gs.has("mirror_opened"), "敲門 → 門自己打開")
	gs.meta.memory["story_1"] = true
	gs.auto_choices = [0]
	await dlg.run("int_mirror_chair")
	_check(gs.remembers("knows_mirror_self"), "椅子對著的鏡子：穿醫院衣服的你（謎團：鏡之屋裡住著誰？）")

	print("[鎮長公館：送完信就發現門沒鎖]")
	await _loop(0)
	gs.day = 2
	gs.set_flag("q_letters")
	gs.auto_choices = [0]
	await dlg.run("mayor_door_day2_explore")
	_check(gs.has("mayor_mail_done") and gs.has("want_enter_mayor"), "送信 →「門沒有關緊」→ 進去")

	print("[選擇篇章 → 第一章：空白的紀錄]")
	gs.meta = {"runs": 9, "chapters_done": 1, "loop": 55, "loops_done": 8, "endings": ["truth", "good_kid"],
		"memory": {"story_1": true, "true_name": true, "knows_47": true}, "tufts": ["tuft_0", "tuft_1"], "collected": ["got_key"]}
	gs.restart_chapter1()
	_check(gs.loop_number() == 47 and gs.memory_depth() == 0 and not gs.remembers("story_1") and gs.tuft_count() == 0, "從第一輪、第一天開始（沒有記憶、沒有棉花）")
	_check(gs.ever("story_1") and gs.ever("true_name") and gs.ever_tufts().size() == 2 and gs.has_collected("got_key"), "標題畫面的謎團、蒐藏還在")
	_check(gs.chapter1_cleared() and "truth" in gs.meta.endings, "看過的結局還在，選擇篇章還看得到")

	print("[開頭的固定任務：每三輪換一版，越來越短]")
	_check(gs.OPENINGS.size() == 10, "一共 10 版")
	await _loop(3)
	_check(gs.opening_index() == 1 and gs.objective.contains("今天的功課") and gs.objective.contains("/ 3"), "第四輪：第 2 版（去三個地方）")
	await _loop(18)
	_check(gs.opening_index() == 6, "第十九輪：第 7 版（只去麵包店）")
	await main.interact("lulu")
	await _wait_phase("day1_night")
	_check(main.phase == "day1_night", "去完麵包店 → 第一天就結束")
	await main.interact("bed")
	await _wait_phase("day2_explore")
	_check(gs.has("letter_done") and gs.has("skip_letter") and not gs.has("bread_done"), "第二天只要做麵包")
	await _loop(99)
	_check(gs.opening_index() == 9, "再多輪也停在第 10 版")

	main.queue_free()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
