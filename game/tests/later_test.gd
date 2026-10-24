extends SceneTree
## 第三章到第六章自動測試：godot --headless --path game -s tests/later_test.gd
## 衝出森林、留下紙、問過原因，會走到「想起來」。好孩子靠 fast_keep_rule，修理靠把警戒拉高，隱藏結局重問鎮長。

var ch: Node
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _wait_phase(p: String, frames := 2000) -> void:
	for i in frames:
		if ch != null and ch.phase == p:
			return
		await process_frame
	_check(false, "等待 phase=%s 逾時（目前 %s）" % [p, "無" if ch == null else ch.phase])


func _free() -> void:
	if ch != null:
		ch.queue_free()
		ch = null
	await process_frame
	await process_frame


func _boot(gs: Node, keep_rule: bool) -> void:
	gs.reset()
	gs.auto_choices = []
	gs.set_flag("fast_keep_rule", keep_rule)
	gs.set_flag("brave_end", true)
	gs.meta = {
		"runs": 1,
		"chapters_done": 2,
		"threads": 0,
		"ch2_fates": {
			"baimian": "aboard",
			"xiaoji": "aboard",
			"tiaoma": "dead",
			"gaga": "aboard",
			"zhongzhong": "aboard",
			"youyou": "unknown",
		},
	}
	gs.start_chapter(3)
	gs.checkpoint = ""
	gs.delete_save()
	ch = load("res://scenes/later.tscn").instantiate()
	root.add_child(ch)


func _to_plaza(gs: Node) -> void:
	await _wait_phase("c3_day1")
	_check(ch.actors.baimian.visible, "白面在醫院，沒有提早退場")
	await ch.interact("file")
	await ch.interact("bed_self")
	await ch.interact("bed_fen")
	await ch.interact("bed_naiwen")
	await ch.interact("nw")
	_check(gs.has("conductor_kin") and gs.has("chart_haruka") and gs.has("chart_46"), "病歷、遙、編號 46")
	await ch.interact("cot")
	await _wait_phase("c3_day2")
	await ch.interact("cot")
	await _wait_phase("c4_day1")
	_check(ch.actors.baimian.display_name == "", "學校裡，跟著的那一個沒有名字")
	await ch.interact("desk")
	await ch.interact("bag")
	await ch.interact("mirror")
	_check(gs.has("bag_dumped") and gs.has("mirror_said") and gs.has("desk_illegible"), "書包、鏡子、看不清的桌面")
	await ch.interact("cot")
	await _wait_phase("c4_day2")
	await ch.interact("gate")
	await ch.interact("safe")
	_check(gs.has("sent_self_letter") and gs.has("guilt_door") and gs.has("safe_47"), "門口的紙留在身上，鎖是 47")
	await ch.interact("cot")
	await _wait_phase("c5_night")
	_check(gs.has("no_seam") and gs.has("play_as_mayor"), "鎮長縫過，白面沒有縫線")
	await ch.interact("baimian")
	_check(gs.has("fen_why"), "為什麼要保護，以及門口跟書包無關")
	await ch.interact("candy")
	await ch.interact("ledger")
	await _wait_phase("c6_plaza")
	_check(ch.actors.baimian.visible and not gs.has("baimian_unraveled"), "終章之前白面還在")


func _fates(xiaoji: String, zhongzhong: String) -> Dictionary:
	return {
		"baimian": "aboard",
		"xiaoji": xiaoji,
		"tiaoma": "dead",
		"gaga": "aboard",
		"zhongzhong": zhongzhong,
		"youyou": "unknown",
	}


func _ready_remember(gs: Node) -> void:
	gs.suspicion = 10
	gs.set_flag("rewrote_zero", true)
	gs.set_flag("kept_zero", false)
	gs.set_flag("sent_self_letter", true)
	gs.set_flag("fen_why", true)
	gs.set_flag("dream_hospital", true)
	gs.set_flag("dream_door", true)
	gs.set_flag("dream_school", true)
	gs.set_flag("dream_mayor", true)
	gs.set_flag("lulu_betrayal", false)
	gs.set_flag("lulu_comforted", false)
	gs.set_flag("brave_end", true)
	gs.meta["ch2_fates"] = _fates("aboard", "aboard")


func _one(gs: Node, id: String, label: String) -> void:
	_check(gs.finale_id() == id and gs.finale_label() == label, "結局 %s → %s（實際 %s）" % [id, label, gs.finale_id()])


func _router(gs: Node) -> void:
	_ready_remember(gs)
	_one(gs, "remember", "c6_remember")
	gs.set_flag("lulu_betrayal", true)
	_one(gs, "hid", "c6_hid")
	gs.set_flag("lulu_betrayal", false)
	gs.set_flag("lulu_comforted", true)
	_one(gs, "comforted", "c6_comforted")
	gs.set_flag("lulu_comforted", false)
	gs.meta["ch2_fates"] = _fates("dead", "aboard")
	_one(gs, "left_behind", "c6_left")
	gs.meta["ch2_fates"] = _fates("aboard", "dead")
	_one(gs, "left_behind", "c6_left")
	gs.meta["ch2_fates"] = _fates("aboard", "aboard")
	_one(gs, "remember", "c6_remember")
	gs.meta["ch2_fates"] = {}
	_one(gs, "remember", "c6_remember")
	gs.meta["ch2_fates"] = _fates("aboard", "aboard")
	gs.set_flag("brave_end", false)
	_one(gs, "never_ran", "c6_never")
	gs.set_flag("brave_end", true)
	gs.set_flag("sent_self_letter", false)
	_one(gs, "no_letter", "c6_no_letter")
	gs.set_flag("sent_self_letter", true)
	gs.set_flag("fen_why", false)
	_one(gs, "no_why", "c6_no_why")
	gs.set_flag("fen_why", true)
	gs.set_flag("dream_school", false)
	gs.set_flag("dream_mayor", false)
	_check(gs.dream_count() < 3, "少兩個夢")
	_one(gs, "no_why", "c6_no_why")
	gs.set_flag("dream_school", true)
	gs.set_flag("dream_mayor", true)
	gs.set_flag("kept_zero", true)
	_one(gs, "good", "c6_good")
	gs.set_flag("kept_zero", false)
	gs.set_flag("rewrote_zero", false)
	_one(gs, "good", "c6_good")
	gs.suspicion = 90
	gs.set_flag("kept_zero", false)
	_one(gs, "repair", "c6_repair")


func _play_bads(gs: Node) -> void:
	print("[壞結局台詞]")
	gs.set_flag("left_xiaoji", true)
	gs.set_flag("left_zhongzhong", true)
	gs.set_flag("fen_why", false)
	gs.set_flag("dreams_short", true)
	var talk: Node = root.get_node("Dialogue")
	for label in ["c6_hid", "c6_comforted", "c6_left", "c6_never", "c6_no_letter", "c6_no_why"]:
		gs.set_flag("baimian_end", false)
		gs.set_flag("baimian_unraveled", false)
		await talk.run(label)
		_check(gs.has("baimian_end") and not gs.has("baimian_unraveled"), "%s：白面褪色，沒有被拆開" % label)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_later"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()

	print("[想起來]")
	_boot(gs, false)
	await _to_plaza(gs)
	_check(gs.suspicion < 80 and gs.dream_count() >= 3, "懷疑未滿 80、夢至少三個（目前 sus=%d dreams=%d）" % [gs.suspicion, gs.dream_count()])
	await ch.interact("tower")
	await _wait_phase("ended")
	_check(str(gs.meta.get("ending", "")) == "remember", "結局：想起來")
	_check(str(gs.meta.get("ending_kind", "")) == "好", "想起來是好結局")
	_check(gs.has("baimian_unraveled") and not ch.actors.baimian.visible, "白面自己鬆開，不在場上")
	_check(gs.has("rewrote_zero") and gs.meta.get("true_seen", false), "劃掉第零條，標題記得你看過")
	_check(int(gs.meta.get("chapters_done", 0)) >= 6 and not gs.has_save(), "六章完成，當章存檔清掉")
	var seen: bool = gs.meta.get("true_seen", false)

	print("[留下來的人]")
	await _free()
	gs.reset()
	gs.auto_choices = []
	gs.set_flag("ending_remember_done")
	gs.set_flag("replay_mayor")
	gs.checkpoint = "c5_replay"
	gs.chapter = 5
	gs.meta.true_seen = seen
	ch = load("res://scenes/later.tscn").instantiate()
	root.add_child(ch)
	await _wait_phase("c5_night")
	gs.auto_choices = [2]
	await ch.interact("ledger")
	await _wait_phase("ended")
	_check(str(gs.meta.get("ending", "")) == "stay", "結局：留下來的人")
	_check(str(gs.meta.get("ending_kind", "")) == "不好不壞", "留下來的人是不好不壞")
	_check(gs.has("own_choice") and gs.has("baimian_end") and not gs.has("baimian_unraveled"), "空白名牌，沒有再把白面拆一次")
	_check(gs.meta.get("true_seen", false), "看過真結局這件事還在")

	print("[好孩子]")
	await _free()
	_boot(gs, true)
	await _to_plaza(gs)
	await ch.interact("tower")
	await _wait_phase("ended")
	_check(str(gs.meta.get("ending", "")) == "good", "結局：好孩子")
	_check(str(gs.meta.get("ending_kind", "")) == "壞", "好孩子是壞結局")
	_check(gs.has("kept_zero") and not gs.has("rewrote_zero"), "第零條留著")
	_check(gs.has("baimian_end") and not gs.has("baimian_unraveled") and ch.actors.baimian.visible, "白面還在，顏色褪了")
	_check(ch.actors.baimian.modulate.r < 0.9, "月台上的白面是灰的")

	print("[修理]")
	await _free()
	_boot(gs, false)
	await _to_plaza(gs)
	gs.suspicion = 90
	await ch.interact("tower")
	await _wait_phase("ended")
	_check(str(gs.meta.get("ending", "")) == "repair", "結局：修理")
	_check(str(gs.meta.get("ending_kind", "")) == "壞", "修理是壞結局")
	_check(gs.meta.get("stitched", false) and gs.has("stitch_title"), "標題被縫上")
	_check(not gs.has("baimian_unraveled") and not gs.has("rewrote_zero") and ch.actors.baimian.visible, "筆還沒碰到，白面還站著")
	_check(not gs.has_save(), "結局後沒有當章存檔")

	print("[結局分岔]")
	_router(gs)
	await _play_bads(gs)

	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
