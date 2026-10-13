extends SceneTree
## 自動跑完第一～二天的主要路線：godot --headless -s tests/smoke_test.gd

var main: Node
var failures := 0


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


func _do(id: String, choices: Array = []) -> void:
	var gs := root.get_node("GameState")
	gs.auto_choices = choices.duplicate()
	await main.interact(id)
	if not gs.auto_choices.is_empty():
		_check(false, "%s 的預設選項沒有用完：%s" % [id, gs.auto_choices])


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)

	print("[第一天]")
	gs.auto_choices = [1]  # 抵達時對露露說「不太好吧」
	await _wait_phase("day1_explore")
	_check(gs.has("lulu_next_time"), "抵達時的選項有作用")
	await _do("fen")
	_check(main.phase == "day1_explore", "拜訪 1 處後仍在探索")
	await _do("clocktower")
	await _wait_phase("day1_night")
	_check(gs.has("lulu_slip"), "傍晚露露叫錯名字")
	await _do("mirror", [1])
	_check(gs.has("mirror_1") and gs.courage == 1, "盯著鏡子：秘密＋膽量 -1")
	await _do("mirror")
	await _do("bed", [0])

	print("[第二天]")
	await _wait_phase("day2_explore")
	_check(gs.day == 2 and gs.courage == 2, "新的一天，膽量回滿")
	main._on_tag_toggle()
	for i in 10:
		await process_frame
	_check(gs.has("tag_off") and not gs.has("tag_on") and gs.courage == 1, "拆下名牌")
	await _do("lulu")
	_check(gs.has("bread_done"), "幫露露做麵包")
	await _do("popo")
	_check(gs.has("letter_done") and gs.has("blank_letter"), "拿到沒有收件人的信")
	_check(gs.has("fen_invited") and main.phase == "day2_evening", "Fen 的邀請")
	await _do("popo", [0])
	_check(gs.has("asked_past") and gs.courage == 0, "問波波「以前」")
	await _do("popo")
	await _do("bed")
	_check(main.phase == "ended" and gs.has("fen_disappointed"), "膽量不足只能乖乖睡覺 → 結尾")
	print("  秘密：", gs.secrets_found(), "　懷疑值：", gs.suspicion)

	print("[第二天晚上：偷溜出門路線]")
	main.queue_free()
	await process_frame
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait_phase("day1_explore")
	await _do("lulu")
	await _do("popo")
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	await _do("lulu")
	await _do("popo")
	await _do("bed", [0])
	await _wait_phase("night_out")
	_check(gs.has("night_out"), "偷溜出門")
	await _do("lulu")
	_check(gs.has("saw_lulu_night") and gs.has("fen_trust"), "夜晚的露露 → Fen 出現")
	_check(main.phase == "ended", "原型結尾")
	for i in 5:
		await process_frame

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
