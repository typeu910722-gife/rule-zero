extends SceneTree
## 閒聊輪替：godot --headless -s tests/idle_test.gd
## 每個角色 4 句普通的閒聊輪流出現；驚悚的那段整個存檔只出現一次。

var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _run() -> void:
	var gs := root.get_node("GameState")
	var dlg := root.get_node("Dialogue")
	gs.fast = true
	gs.save_dir = "user://test_saves"
	gs.meta = {"runs": 0, "chapters_done": 0}
	for who in ["lulu", "popo", "fen", "mayor", "mochi", "tama"]:
		gs.reset()
		var got := []
		for i in 8:
			got.append(gs.idle_label(who))
		var labels_ok := got.all(func(l): return dlg.has_label(l))
		_check(labels_ok, "%s：閒聊標籤都存在" % who)
		_check(got.count("idle_%s_x" % who) == 1 and got[2] == "idle_%s_x" % who, "%s：第 3 次是驚悚的，只有一次" % who)
		var normals := got.filter(func(l): return not l.ends_with("_x"))
		_check(normals.slice(0, 4) == ["idle_%s_1" % who, "idle_%s_2" % who, "idle_%s_3" % who, "idle_%s_4" % who],
			"%s：4 句普通的輪流" % who)
		# 下一輪（reset 之後）也不會再出現驚悚的那段
		gs.reset()
		var again := []
		for i in 6:
			again.append(gs.idle_label(who))
		_check(not again.has("idle_%s_x" % who), "%s：驚悚的那段不會再出現" % who)
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
