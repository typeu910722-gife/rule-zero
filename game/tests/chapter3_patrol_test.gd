extends SceneTree
## 第三章巡邏護士：有走路圖、隨機巡邏、近距離追逐，碰到才算抓住。

var failures := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset()
	gs.fast = true
	gs.start_chapter3()
	_check(ResourceLoader.exists("res://art/walk4/h_nurse.png"), "巡邏護士有四方向走路圖")
	_check(ResourceLoader.exists("res://art/walk4/h_graduate.png"), "失控區畢業生有四方向走路圖")
	_check(ResourceLoader.exists("res://art/scare_nurse.png"), "護士抓住玩家有突臉圖")

	# 執行期才載入：SceneTree 測試腳本編譯時，autoload 名稱尚未註冊給 Explore。
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://levels/chapter3.json")
	root.add_child(ex)
	await ex.enter("corridor", [500, 330])
	ex.busy = false
	var nurse = ex._patrols[0]
	_check(nurse.data.get("char", "") == "h_nurse" and nurse._random_patrol, "護士使用走路圖並隨機巡邏")
	_check(nurse._target != nurse.position, "隨機巡邏會選下一個位置")

	var chased := false
	var caught := false
	ex.chase_changed.connect(func(active: bool, _by: String):
		if active:
			chased = true)
	ex.caught.connect(func(_by: String): caught = true)
	# 放在護士正後方也要因為距離過近被察覺；先進追逐，不是立刻抓住。
	ex.player.position = nurse.position - nurse.facing * 150.0
	for k in 8:
		nurse._process(0.08)
		await process_frame
	_check(chased and not caught, "離太近會開始追逐，但尚未碰到不算被抓")
	for k in 50:
		if caught:
			break
		nurse._process(0.08)
		await process_frame
	_check(caught, "護士追上並碰到玩家後才算抓住")
	ex.queue_free()
	await process_frame
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
