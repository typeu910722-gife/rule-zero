extends SceneTree
## 第三、四、五章小遊戲「真的玩」：不用快速模式，亂按鍵盤、滑鼠、觸控，每個小遊戲都要能自己結束、不出錯。
## （快速模式的整章測試會跳過小遊戲，這支專門補這一塊）
## xvfb-run godot --path . --rendering-driver opengl3 -s tests/minigames_real_ch345.gd

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
	_rng.seed = 11
	gs = root.get_node("GameState")
	gs.reset()
	gs.fast = false
	gs.chapter = 3
	Engine.time_scale = 3.0
	var A := func(p: String): return load("res://scripts/%s.gd" % p).new()
	var party := [["pip", "小布"], ["lulu", "露露"], ["fen", "Fen"]]
	var h = A.call("ch3/heart_cards")
	await _try("第三章 心臟病", h, func(): await h.play(), 120.0)
	h = A.call("ch3/thermo")
	h.queue = party.duplicate()
	await _try("第三章 量體溫", h, func(): await h.play(), 90.0)
	h = A.call("ch3/drip")
	await _try("第三章 點滴", h, func(): await h.play(), 60.0, "hold")
	h = A.call("ch3/sew")
	h.patients = party.duplicate()
	await _try("第三章 縫合", h, func(): await h.play(), 90.0)
	h = A.call("ch3/cpr")
	await _try("第三章 心臟按壓", h, func(): await h.play(), 90.0)
	h = A.call("ch3/runner")
	await _try("第三章 追逐", h, func(): await h.play(), 90.0)
	gs.chapter = 4
	var g = A.call("ch4/speech")
	await _try("自我介紹", g, func(): await g.play(), 60.0)
	g = A.call("ch4/group_chat")
	await _try("群組", g, func(): await g.play(), 60.0)
	g = A.call("ch4/hold_door")
	await _try("擋在門前", g, func(): await g.play(), 60.0, "hold")
	gs.chapter = 5
	g = A.call("ch5/breath_walk")
	await _try("呼吸（終章 A）", g, func(): await g.play(), 120.0, "hold")
	g = A.call("ch5/guard")
	await _try("守住走廊（終章 B-2）", g, func(): await g.play(), 90.0)
	Engine.time_scale = 1.0
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
