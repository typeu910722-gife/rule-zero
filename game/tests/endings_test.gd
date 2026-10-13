extends SceneTree
## 七個結局與輪迴記憶：godot --headless -s tests/endings_test.gd

var main: Node
var gs: Node
var failures := 0


func _init() -> void:
	_run.call_deferred()


var _seen: Array = []


func _check(cond: bool, msg: String) -> void:
	if gs and str(gs.meta.get("last_ending", "")) != "" and not gs.meta.last_ending in _seen:
		_seen.append(gs.meta.last_ending)
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


func _do(id: String, choices: Array = []) -> void:
	gs.auto_choices = choices.duplicate()
	await main.interact(id)
	if not gs.auto_choices.is_empty():
		_check(false, "%s 的預設選項沒有用完：%s" % [id, gs.auto_choices])


## 開一輪新的。fresh = 清空跨輪記憶（第一輪）
func _new_loop(fresh: bool) -> void:
	if main:
		main.queue_free()
		await process_frame
	if fresh:
		gs.meta = {"runs": 0, "chapters_done": 0}
	else:
		gs.start_next_loop()
		gs.pending_loop_start = false
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase("day1_explore")


## 第一天：拜訪兩個地方 → 睡覺 → 第二天：麵包、送信 → Fen 邀請
func _days_1_2(day1: Array = ["lulu", "popo", "mayor_door", "repair_room"]) -> void:
	for id in day1:
		await _do(id)
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	await _do("lulu")
	await _do("popo")
	await _do("lulu_mailbox")
	await _do("mayor_door")
	await _do("mirror_house")
	await _do("popo")
	await _wait_phase("day2_evening")


func _run() -> void:
	gs = root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves"

	print("[結局①好孩子：不跟 Fen 去森林]")
	await _new_loop(true)
	await _days_1_2()
	await _do("bed", [1])
	await _wait_phase("day3_explore")
	await _do("lulu", [0])
	await _do("fen", [1])
	_check(main.phase == "day3_home", "拒絕去森林 → 回家睡覺")
	await _do("home_door")
	await _do("bed", [0])
	_check(gs.meta.last_ending == "good_kid", "結局①好孩子")
	_check(gs.has("loop_done") and not gs.has("chapter_done"), "好孩子不會結束本章")

	print("[結局②提早修理：鎮長懷疑值太高]")
	await _new_loop(true)
	await _days_1_2()
	gs.suspicion = 65
	await _do("bed")
	_check(gs.meta.last_ending == "early", "結局②提早修理")

	print("[結局⑤露露猶豫：躲著，但露露起了懷疑]")
	await _new_loop(true)
	await _days_1_2()
	await _do("bed", [1])
	await _wait_phase("day3_explore")
	await _do("lulu", [1])
	await _do("fen", [0])
	await _wait_phase("forest")
	await _do("forest_sheep")
	await _do("forest_bow")
	await _do("forest_tags", [1])
	_check(gs.has("lulu_hesitated"), "露露沒有說出你在哪裡")
	_check(gs.meta.last_ending == "hesitate", "結局⑤露露猶豫了")

	print("[下一輪：記得上一輪的事]")
	await _new_loop(false)
	_check(gs.loop_number() == 48, "第 48 個小布")
	_check(gs.remembers("knows_bow") and gs.remembers("knows_47") and gs.remembers("knows_bell"), "記得：黃色蝴蝶結、第幾個、三點的鐘聲")
	var before: int = gs.suspicion
	await _do("lulu", [0])
	_check(gs.has("lulu_doubt") and gs.suspicion > before, "〔記得〕黃色蝴蝶結 → 露露動搖、鎮長懷疑值上升")
	await _do("fen", [0])
	_check(gs.has("fen_trust") and gs.has("fen_knows_you"), "〔記得〕第幾個小布 → Fen 相信你")
	await _do("mayor_door")
	await _do("repair_room")

	print("[結局⑦第零條：用上一輪的記憶結束本章]")
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	await _do("lulu")
	await _do("popo")
	await _do("lulu_mailbox")
	await _do("mayor_door")
	await _do("mirror_house")
	await _do("popo")
	await _wait_phase("day2_evening")
	await _do("bed", [1])
	await _wait_phase("day3_explore")
	await _do("lulu", [0])
	await _do("fen", [2])
	_check(gs.has("got_key"), "〔記得〕三點的鐘聲 → Fen 給鑰匙")
	await _do("clocktower")
	_check(gs.meta.last_ending == "zero" and gs.has("chapter_done"), "結局⑦第零條 → 第一章完")
	_check(int(gs.meta.chapters_done) == 1, "章節完成記錄")

	print("[結局⑥麻糬的名字]")
	await _new_loop(true)
	await _do("lulu")
	await _do("popo")
	await _do("mayor_door")
	await _do("repair_room")
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	await _do("mochi", [0])
	_check(gs.has("q_mochi"), "接下麻糬的委託")
	await _do("tama")
	await _do("fen")
	await _do("mayor", [2])
	_check(int(gs.flags.get("mq_count", 0)) >= 3, "問了三個人以上（小玉、Fen、鎮長）")
	await _do("mochi", [1])
	_check(gs.has("mochi_remembers"), "告訴麻糬：你本來有別的名字")
	await _do("lulu")
	await _do("popo")
	await _do("lulu_mailbox")
	await _do("mayor_door")
	await _do("mirror_house")
	await _do("popo")
	await _wait_phase("day2_evening")
	await _do("bed", [1])
	await _wait_phase("day3_explore")
	_check(not main.actors.mochi.visible, "第三天麻糬不見了")
	await _do("repair_room", [0])
	_check(gs.meta.get("last_ending", "") == "mochi", "結局⑥麻糬的名字")

	print("[看過的結局]")
	_check(_seen.size() == 5, "這次測試看到 5 種結局（勇敢、被出賣在 smoke_test）：%s" % [_seen])

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
