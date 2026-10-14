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
	_check(gs.remembers("story_3"), "火車上想起：廁所門外的狐狸吊飾、發抖的老師")
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
