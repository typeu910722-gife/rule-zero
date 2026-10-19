extends SceneTree
## 章節銜接：第一章結尾 → 第二章、讀第二章的存檔、標題的「選擇篇章」。
## godot --headless --path game -s tests/transition_test.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _scene_path() -> String:
	return current_scene.scene_file_path if current_scene else ""


func _wait_scene(path: String, frames := 120) -> bool:
	for i in frames:
		if _scene_path() == path:
			return true
		await process_frame
	return false


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves_transition"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()
	var Main = load("res://scripts/main.gd")

	print("[第一章結尾 → 第二章]")
	gs.reset()
	gs.set_flag("lulu_doubt")
	gs.set_flag("found_fox_tail")
	Main.enter_chapter2(self)
	_check(await _wait_scene("res://scenes/chapter2.tscn"), "切到第二章的場景")
	_check(gs.chapter == 2 and gs.day == 1 and gs.conduct == gs.CONDUCT_START, "第二章從第一天、操行 100 開始")
	_check(gs.has("lulu_doubt") and gs.has("found_fox_tail"), "第一章的選擇帶到第二章（露露、狐狸尾巴）")

	print("[讀第二章的存檔]")
	gs.day = 2
	gs.save_game("c2_day2_morning")
	gs.reset()
	gs.resume_on_start = true
	change_scene_to_file("res://scenes/main.tscn")
	await _wait_scene("res://scenes/main.tscn")
	_check(await _wait_scene("res://scenes/chapter2.tscn"), "標題按「繼續」→ 回到第二章")
	_check(gs.chapter == 2 and gs.day == 2, "第二章第二天的進度還在")
	gs.resume_on_start = false

	print("[標題：選擇篇章]")
	var T = load("res://scripts/ui/title.gd")
	var names: Array = T.CHAPTERS.map(func(c): return c[0])
	_check("第二章　漂白鎮" in names, "篇章清單有「第二章　漂白鎮」")

	gs.delete_save()
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
