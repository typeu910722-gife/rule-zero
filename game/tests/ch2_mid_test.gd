extends SceneTree
## 標題「第二章後半」會從第二天早上開始：godot --headless --path game -s tests/ch2_mid_test.gd

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


func _wait_phase(p: String, frames := 4000) -> void:
	for i in frames:
		if ch != null and ch.phase == p:
			return
		await process_frame
	_check(false, "等待 phase=%s 逾時（目前 %s）" % [p, "無" if ch == null else ch.phase])


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_ch2_mid"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()
	gs.reset()
	var main := load("res://scripts/main.gd")
	main.enter_chapter2_mid(self)
	_check(gs.chapter == 2 and gs.day == 2, "進入時是第二章第二天")
	_check(gs.checkpoint == "c2_day2_morning" and gs.has("tiaoma_2"), "從第二天早上開始，條碼剩下兩條")
	_check(gs.has_save(), "這個起點有存檔，繼續會回到這裡")
	for i in 60:
		await process_frame
		if current_scene != null and current_scene.name == "Chapter2":
			ch = current_scene
			break
	_check(ch != null, "標題的入口會打開第二章")
	await _wait_phase("day2_explore")
	_check(ch.phase == "day2_explore", "早上的公告、早餐、洗白白、找出壞孩子跑完，進到自由時間")
	_check(gs.day == 2, "還在第二天")
	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
