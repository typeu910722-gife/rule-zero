extends SceneTree
## 支線：小玉的糖果、波波的信、Fen 的筆記、棉花（記憶碎片）。godot --headless -s tests/quests_test.gd

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


func _run() -> void:
	gs = root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves"

	print("[第一天：Fen 的筆記、棉花]")
	await _new_loop(true)
	_check(not main.actors.note_1.visible, "還沒接委託，筆記不會出現")
	await _do("fen")
	_check(gs.has("q_notes") and main.actors.note_1.visible, "Fen 拜託撿筆記 → 筆記出現")
	await _do("note_1", [1])
	await _do("note_2", [0])
	await _do("note_3", [0])
	_check(gs.has("read_note_2") and gs.has("read_notes") and not main.actors.note_2.visible, "偷看了第二張（鑰匙＝熊頭）")
	await _do("fen")
	_check(gs.has("notes_returned") and not gs.has("fen_trust"), "偷看過 → Fen 不信任你")
	await _do("tuft_0")
	await _do("tuft_5")
	_check(gs.tuft_count() == 2 and not main.actors.tuft_0.visible, "撿到兩團棉花")
	_check(main.phase == "day1_explore", "只拜訪 1 處（Fen），還在第一天")
	await _do("lulu")
	await _do("popo")
	await _do("clocktower")
	await _wait_phase("day1_night")
	_check(true, "拜訪 4 處 → 傍晚")
	await _do("bed", [0])

	print("[第二天：波波的信、小玉的糖果]")
	await _wait_phase("day2_explore")
	await _do("popo")
	_check(gs.has("q_letters") and main.actors.lulu_mailbox.visible, "接下送信 → 信箱出現")
	await _do("lulu_mailbox")
	await _do("mayor_door")
	await _do("mirror_house")
	_check(int(gs.flags.letters) == 3 and gs.has("mirror_letter"), "三封信都送到，鏡之屋回信")
	await _do("tama", [0])
	_check(gs.has("q_tama") and main.actors.candy_1.visible, "小玉的糖果罐 → 糖果出現")
	await _do("candy_1")
	await _do("candy_2")
	await _do("candy_3")
	await _do("tama", [1])
	_check(gs.has("kept_candy") and gs.has("tama_done"), "把糖果收進口袋")
	await _do("lulu")
	await _do("popo")
	_check(gs.has("letter_done") and gs.has("fen_invited"), "回郵局 → 送信完成 → Fen 邀請")
	await _do("bed", [1])
	await _wait_phase("day3_explore")
	_check(gs.has("candy_button"), "第三天：糖果裡包著鈕扣（秘密）")
	await _do("mayor_door")
	_check(not gs.has("got_key"), "第一輪：沒聽過三點的鐘聲，熊頭裡拿不到鑰匙")
	await _do("lulu", [0])
	await _do("fen", [0])
	await _wait_phase("forest")
	await _do("forest_sheep")
	await _do("forest_bow")
	await _do("forest_tags", [0])
	_check(gs.meta.last_ending == "brave", "結局③勇敢")

	print("[下一輪：棉花保留、熊頭裡的鑰匙]")
	await _new_loop(false)
	_check(gs.tuft_count() == 2 and not main.actors.tuft_0.visible and main.actors.tuft_1.visible, "撿過的棉花不會再出現")
	_check(gs.remembers("knows_key_spot") and gs.remembers("knows_bell"), "記得：鑰匙在熊頭、三點的鐘聲")
	for id in ["lulu", "popo", "mayor_door", "repair_room"]:
		await _do(id)
	await _wait_phase("day1_night")
	await _do("bed", [0])
	await _wait_phase("day2_explore")
	await _do("tama", [0])
	await _do("candy_1")
	await _do("candy_2")
	await _do("candy_3")
	await _do("tama", [3])
	_check(gs.has("refused_candy") and gs.suspicion >= 15, "〔記得〕吃糖會忘記 → 拒絕糖果")
	await _do("lulu")
	await _do("popo")
	for id in ["lulu_mailbox", "mayor_door", "mirror_house", "popo"]:
		await _do(id)
	await _wait_phase("day2_evening")
	await _do("bed", [1])
	await _wait_phase("day3_explore")
	await _do("mayor_door")
	_check(gs.has("got_key"), "記得鑰匙在熊頭 → 第三天拿到鐘塔鑰匙（不靠 Fen）")
	await _do("clocktower")
	_check(gs.meta.last_ending == "zero", "結局⑦第零條")

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
