extends SceneTree
## 剪刀場景：一直連點 → 熊一張一張壞掉、最後結束；不點 → 永遠不會結束；停手會退回這一張的開頭。
## godot --headless -s tests/scissors_test.gd

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += root.get_process_delta_time()


func _run() -> void:
	root.get_node("GameState").fast = false
	var S = load("res://scripts/ui/scissors_scene.gd")

	print("[不點]")
	var sc = S.new()
	root.add_child(sc)
	await _wait(3.0)
	_check(sc._state == "play" and sc._stage == 0, "不點 → 還在第一張")
	sc.queue_free()

	print("[點幾下就停]")
	sc = S.new()
	root.add_child(sc)
	for i in 12:
		sc.stab()
	var st: int = sc._stage
	var d: float = sc._dmg
	await _wait(2.0)
	_check(sc._dmg < d, "停手會退（%.1f → %.1f）" % [d, sc._dmg])
	_check(sc._stage == st and st >= 1, "已經壞掉的不會復原（第 %d 張）" % (st + 1))
	sc.queue_free()

	print("[一秒 6 下連點]")
	sc = S.new()
	root.add_child(sc)
	var finished := [false]
	sc.done.connect(func(): finished[0] = true)
	var stages := {}
	var t := 0.0
	while t < 20.0 and sc._state == "play":
		sc.stab()
		stages[sc._stage] = true
		await _wait(1.0 / 6.0)
		t += 1.0 / 6.0
	_check(sc._state == "won", "捅到底（%d 下、%.1f 秒）" % [sc._hits, t])
	_check(sc._hits >= 40, "不是只捅七下（%d 下）" % sc._hits)
	_check(stages.size() == 7, "七張圖都出現過（%s）" % str(stages.keys()))
	await _wait(3.0)
	_check(finished[0], "結束後發出 done")
	sc.queue_free()

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
