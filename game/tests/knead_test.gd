extends SceneTree
## 揉麵團：每一種揉法、每一個隨機版本都走得完（godot --headless -s tests/knead_test.gd）
var fails := 0
func _init():
	_run.call_deferred()
func _run():
	var gs = root.get_node("GameState")
	var dlg = root.get_node("Dialogue")
	gs.fast = true
	var paths := [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1], [3, 0, 0], [3, 1, 1], [3, 2, 0], [3, 3, 1]]
	for depth in [0, 3]:
		for roll in 3:
			for p in paths:
				gs.reset()
				gs.meta = {"loops_done": depth, "memory": {}}
				gs.day = 2
				var choices: Array = p.duplicate()
				if depth < 3 and choices.size() == 3 and choices[1] == 3:
					continue
				gs.auto_choices = choices
				gs.set_flag("bread_done")
				# 固定隨機數：先跑一次 roll，再覆寫
				seed(roll * 7 + 1)
				await dlg.run("l2_again")
				if not gs.auto_choices.is_empty():
					fails += 1
					printerr("FAIL 選項沒用完 depth=%d path=%s left=%s" % [depth, p, gs.auto_choices])
	print("knead paths ok, fails=", fails)
	quit(1 if fails else 0)
