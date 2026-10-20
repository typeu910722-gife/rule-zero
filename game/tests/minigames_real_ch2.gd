extends SceneTree
## 第二章小遊戲「真的玩」：不用快速模式，亂按鍵盤、滑鼠、觸控，每個小遊戲都要能自己結束、不出錯。
## （快速模式的整章測試會跳過小遊戲，這支專門補這一塊）
## xvfb-run godot --path . --rendering-driver opengl3 -s tests/minigames_real_ch2.gd

var failures := 0
var gs: Node
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


## 一直亂按，直到小遊戲結束（或逾時）
func _mash(node: Node, seconds: float, style: String) -> void:
	var t := 0.0
	var held := false
	while is_instance_valid(node) and node.is_inside_tree() and t < seconds:
		var r := _rng.randf()
		var ev: InputEvent
		match style:
			"hold":
				# 按住很久、偶爾放開
				if r < 0.05:
					held = not held
				ev = InputEventAction.new()
				ev.action = "interact"
				ev.pressed = held or r < 0.9
			_:
				if r < 0.35:
					ev = InputEventAction.new()
					ev.action = "interact"
					ev.pressed = _rng.randf() < 0.5
				elif r < 0.6:
					ev = InputEventAction.new()
					ev.action = ["move_left", "move_right", "move_up", "move_down"][_rng.randi() % 4]
					ev.pressed = _rng.randf() < 0.6
				else:
					var mb := InputEventMouseButton.new()
					mb.button_index = MOUSE_BUTTON_LEFT
					mb.pressed = _rng.randf() < 0.5
					mb.position = Vector2(_rng.randf_range(100, 1180), _rng.randf_range(100, 680))
					mb.global_position = mb.position
					ev = mb
		Input.parse_input_event(ev)
		await process_frame
		t += 1.0 / 60.0 * Engine.time_scale
	Input.action_release("interact")


func _try(label: String, node: Node, call: Callable, seconds: float, style := "mash") -> void:
	root.add_child(node)
	await process_frame
	var done := [false]
	var runner := func():
		await call.call()
		done[0] = true
	runner.call()
	await _mash(node, seconds, style)
	var waited := 0
	while not done[0] and waited < 600:
		await _mash(node, 2.0, style)
		waited += 1
		if waited > 20:
			break
	_check(done[0], "%s 會自己結束" % label)
	if is_instance_valid(node):
		node.queue_free()
	await process_frame


func _run() -> void:
	_rng.seed = 7
	gs = root.get_node("GameState")
	gs.reset()
	gs.start_chapter2()
	gs.fast = false
	var ch: Node = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)
	for i in 10:
		await process_frame
	ch.set_process(false)
	ch.set_process_unhandled_input(false)
	Engine.time_scale = 3.0
	var A := func(p: String): return load("res://scripts/minigames/%s.gd" % p).new()
	var g = A.call("apology")
	await _try("道歉練習（電重重）", g, func(): await g.play(), 60.0)
	g = A.call("scrub")
	await _try("刷洗", g, func(): await g.play(), 60.0)
	for n in [1, 2, 3]:
		g = A.call("find_odd")
		var gg = g
		await _try("找不同 %d" % n, g, func(): await gg.play(n), 60.0)
	g = A.call("hold_endure")
	g.questions = [["第一題。", 3.0], ["第二題。", 3.0]]
	await _try("按住忍耐", g, func(): await g.play(), 60.0, "hold")
	g = A.call("sneak")
	await _try("偷溜", g, func(): await g.play(), 60.0)
	g = A.call("confession")
	g.cards = ch.CARDS_DONE
	await _try("坦白卡", g, func(): await g.play(), 60.0)
	var Trim: GDScript = load("res://scripts/minigames/trim.gd")
	for pair in [[Trim.TOTAL, 6], [6, 1], [1, 0]]:
		g = Trim.new()
		g.quills = pair[0]
		g.leave = pair[1]
		var tg = g
		await _try("剪刺 %d→%d" % pair, g, func(): await tg.play(), 60.0)
	g = A.call("chairs")
	g.players = ["pip", "xiaoji", "tiaoma", "gaga", "zhongzhong", "youyou"]
	g.out = "tiaoma"
	await _try("搶椅子", g, func(): await g.play(), 60.0)
	for st in [[0, 2], [2, 4]]:
		g = A.call("restuff")
		g.step = st[0]
		g.steps = st[1]
		var rg = g
		await _try("重新填棉花 %d" % st[0], g, func(): await rg.play(), 60.0)
	var rl = load("res://scripts/ui/roll_list.gd").new()
	await _try("點名單", rl, func(): await rl.show_and_wait(), 30.0)
	Engine.time_scale = 1.0
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
