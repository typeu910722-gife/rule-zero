extends SceneTree
## 回歸測試：送信任務在各種順序下都能完成（第三輪回報的 bug）。
## godot --headless --path game -s tests/letters_test.gd

var main: Node
var gs: Node
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _wait_phase(p: String, frames := 600) -> bool:
	for i in frames:
		if main.phase == p:
			return true
		await process_frame
	_check(false, "等待 phase=%s 逾時（目前 %s）" % [p, main.phase])
	return false


func _do(id: String, choices: Array = []) -> void:
	gs.auto_choices = choices.duplicate()
	await main.interact(id)


## 第三輪：跳到第二天、接下送信的任務
func _start_day2_with_letters() -> void:
	if main:
		main.queue_free()
		await process_frame
	gs.meta = {"runs": 3, "chapters_done": 0, "loop": gs.FIRST_LOOP + 2, "loops_done": 2}
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase("day1_explore")
	for id in ["lulu", "popo", "fen", "mayor_door", "repair_room", "mirror_house", "clocktower"]:
		if main.phase != "day1_explore":
			break
		await _do(id, [0, 0, 0, 0])
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	await _do("popo")


func _deliver_all() -> void:
	await _do("lulu_mailbox")
	await _do("mayor_door")
	await _do("mirror_house")


func _run() -> void:
	gs = root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves_letters"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)

	print("[第三輪：接信 → 先回去找波波一次 → 送完 → 回郵局]")
	await _start_day2_with_letters()
	_check(gs.has("q_letters"), "接下送信")
	await _do("popo")   # 還沒送完就回去：「還差一點喔」
	await _deliver_all()
	_check(int(gs.flags.get("letters", 0)) == 3, "三封信都送到")
	await _do("popo")
	_check(gs.has("letter_done"), "回郵局 → 送信完成")

	print("[第三輪：接信 → 問波波「以前」的事 → 送完 → 回郵局]")
	await _start_day2_with_letters()
	await _do("popo", [0])   # 第一個選項：「波波，你以前是做什麼的？」
	_check(gs.has("asked_popo"), "問了波波以前的事")
	await _deliver_all()
	await _do("popo")
	_check(gs.has("letter_done"), "問過以前的事，送完信仍然可以交差")

	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
