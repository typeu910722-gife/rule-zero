extends SceneTree
## 第二章小遊戲「實際玩到時」的畫面：背景上有 CG／場景圖時開小遊戲，確認沒有被蓋住。
## xvfb-run godot --path . --rendering-driver opengl3 -s tests/screenshots_ch2_minigames.gd -- <輸出資料夾>

var out := "user://shots"
const EVENTS := [
	["apology", "dining"], ["scrub", "laundry"], ["find_1", "classroom"], ["treatment_hold", "treatment"],
	["sneak", "dorm_night"], ["confession_1", "classroom"], ["trim_1", "treatment"], ["chairs_1", "graduation"],
	["restuff_1", "incinerator"], ["long_hold", "graduation"], ["roll_list", "dorm_night"], ["photo_1", "dorm_night"],
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _run() -> void:
	var gs := root.get_node("GameState")
	var dlg := root.get_node("Dialogue")
	gs.reset()
	gs.start_chapter2()
	gs.checkpoint = "c2_start"
	var ch: Node = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)
	for i in 30:
		await process_frame
	var bad := []
	for e in EVENTS:
		var before := ch.get_children()
		dlg.set_bg(e[1])
		dlg._command("event", [e[0]])     # 跟腳本裡的 @event 走同一條路
		for i in 45:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("%s/%s.png" % [out, e[0]])
		var covered: bool = dlg._bg.visible or dlg._bg_img.visible
		if e[0].begins_with("photo"):
			covered = dlg._bg_img.visible
		print("%-16s 背景=%-12s %s" % [e[0], e[1], "被蓋住！" if covered else "ok"])
		if covered:
			bad.append(e[0])
		# 收掉這次加的節點，讓對話層的事件結束
		for c in ch.get_children():
			if not c in before:
				c.queue_free()
		if ch.get("overlay") != null:
			ch.set("overlay", null)
		dlg.event_done.emit()
		for i in 5:
			await process_frame
	print("結果：", "通過" if bad.is_empty() else "被蓋住：" + ", ".join(bad))
	quit(0 if bad.is_empty() else 1)
