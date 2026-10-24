extends SceneTree
## 第三～七章自動測試：godot --headless --path game -s tests/later_test.gd
## 預設選項會走到「想起來」。好孩子靠 fast_keep_rule，修理靠把警戒拉高，隱藏結局重問鎮長。

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
	_check(gs.has("own_choice") and gs.has("baimian_end") and not gs.has("baimian_unraveled"), "空白名牌，沒有再把白面拆一次")
	_check(gs.meta.get("true_seen", false), "看過真結局這件事還在")

	print("[好孩子]")
	await _free()
	_boot(gs, true)
	await _to_plaza(gs)
	await ch.interact("tower")
	await _wait_phase("ended")
	_check(str(gs.meta.get("ending", "")) == "good", "結局：好孩子")
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
	_check(gs.meta.get("stitched", false) and gs.has("stitch_title"), "標題被縫上")
	_check(not gs.has("baimian_unraveled") and not gs.has("rewrote_zero") and ch.actors.baimian.visible, "筆還沒碰到，白面還站著")
	_check(not gs.has_save(), "結局後沒有當章存檔")

	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
