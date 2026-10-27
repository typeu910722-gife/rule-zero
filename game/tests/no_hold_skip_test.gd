extends SceneTree
## 長按互動鍵不能快轉對話（2026-10-24 拿掉；10-27 合併分支時曾經漏掉，加這個測試防止再回來）
## godot --headless --path . -s tests/no_hold_skip_test.gd

var done := false


func _init() -> void:
	_run.call_deferred()


func _say(d: Node) -> void:
	await d._say("小布", "這是一句測試用的台詞。")
	done = true


func _run() -> void:
	await process_frame
	var gs := root.get_node("GameState")
	gs.reset()
	gs.fast = false
	var d := root.get_node("Dialogue")
	d.running = true
	d._box.visible = true
	_say(d)
	# 讓字打完
	for i in 120:
		await process_frame
	# 按住互動鍵兩秒（不放開）
	Input.action_press("interact")
	for i in 20:
		d._process(0.1)
		await process_frame
	Input.action_release("interact")
	var failures := 0
	if done:
		failures += 1
		printerr("  FAIL 按住互動鍵把對話快轉過去了")
	else:
		print("  ok   按住互動鍵不會快轉對話")
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
