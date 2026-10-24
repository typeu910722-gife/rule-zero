extends SceneTree
## 第三章巡邏護士：有走路圖、隨機巡邏、近距離追逐，碰到才算抓住。

var failures := 0
var chased := false
var caught := false


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	_run.call_deferred()


func _on_chase(active: bool, _by: String) -> void:
	if active:
		chased = true


func _on_caught(_by: String) -> void:
	caught = true


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset()
	gs.fast = true
	gs.start_chapter3()
	_check(ResourceLoader.exists("res://art/walk4/h_nurse.png"), "巡邏護士有四方向走路圖")
	_check(ResourceLoader.exists("res://art/walk4/h_graduate.png"), "失控區畢業生有四方向走路圖")
	_check(ResourceLoader.exists("res://art/scare_nurse.png"), "護士抓住玩家有突臉圖")
	var level = JSON.parse_string(FileAccess.get_file_as_string("res://levels/chapter3.json"))
	var maps_ok := true
	for room_id in level.rooms:
		var tex: Texture2D = load("res://art/ch3/maps/ch3_map_%s.jpg" % room_id)
		var expected: Array = level.rooms[room_id].get("size", [1280, 720])
		if tex == null or tex.get_width() != int(expected[0]) or tex.get_height() != int(expected[1]):
			maps_ok = false
	_check(maps_ok, "22 個探索房間都有與碰撞座標同尺寸的地圖美術")
	var walk_ok := true
	for char_id in ["lulu", "mochi", "popo", "fen", "baimian", "xiaoji", "zhongzhong", "gaga", "youyou", "staff", "h_nurse", "h_graduate", "conductor", "dove"]:
		var walk: Texture2D = load("res://art/walk4/%s.png" % char_id)
		if walk == null:
			walk_ok = false
			continue
		var image := walk.get_image()
		var neutral := image.get_region(Rect2i(0, 0, 160, 160)).get_data()
		var step_left := image.get_region(Rect2i(160, 0, 160, 160)).get_data()
		var step_right := image.get_region(Rect2i(480, 0, 160, 160)).get_data()
		if neutral == step_left or neutral == step_right or step_left == step_right:
			walk_ok = false
	_check(walk_ok, "配角、護士與畢業生都有左右手腳交替的跨步幀")

	# 執行期才載入：SceneTree 測試腳本編譯時，autoload 名稱尚未註冊給 Explore。
	var ex = load("res://scripts/explore/explore.gd").new()
	ex.load_level("res://levels/chapter3.json")
	root.add_child(ex)
	await ex.enter("corridor", [500, 330])
	ex.busy = false
	var nurse = ex._patrols[0]
	_check(nurse.data.get("char", "") == "h_nurse" and nurse._random_patrol, "護士使用走路圖並隨機巡邏")
	_check(nurse._target != nurse.position, "隨機巡邏會選下一個位置")

	ex.chase_changed.connect(_on_chase)
	ex.caught.connect(_on_caught)
	# 放在護士正後方也要因為距離過近被察覺；先進追逐，不是立刻抓住。
	ex.player.position = nurse.position - nurse.facing * 225.0
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
