extends SceneTree
## 揉麵團判定測試：模擬準時按鍵，確認 Perfect 連段與秘密旗標。

func _init() -> void:
	_run.call_deferred()


func _press(game: Node) -> void:
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	game._unhandled_input(ev)


func _run() -> void:
	var gs := root.get_node("GameState")
	var fails := 0
	for case in [["準時", 0.03, true], ["稍微偏掉", 0.16, false]]:
		gs.reset()
		var BK = load("res://scripts/minigames/bread_knead.gd")
		var game = BK.new()
		root.add_child(game)
		game.set_process(false)
		game._running = true
		game._t = 0.0
		var step := 1.0 / 60.0
		var next := 0
		while game._running:
			game._process(step)
			if next < game._notes.size() and game._t >= game._notes[next].time + case[1]:
				_press(game)
				next += 1
		var ok: bool = gs.has("lulu_song") == case[2]
		print("  %s %s：最長連段 %d，lulu_song=%s" % ["ok  " if ok else "FAIL", case[0], game.max_streak, gs.has("lulu_song")])
		if not ok:
			fails += 1
		game.queue_free()
	quit(1 if fails > 0 else 0)
