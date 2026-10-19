extends SceneTree
## 存檔安全、音量設定、手把綁定：godot --headless --path game -s tests/save_test.gd

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
	gs.save_dir = "user://test_saves_safe"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	gs.delete_save()
	var path: String = gs._path(gs.SAVE_PATH)

	print("[存檔]")
	gs.reset()
	gs.day = 2
	gs.set_flag("test_a")
	gs.save_game("day2_morning")
	_check(FileAccess.file_exists(path), "寫出 save.json")
	_check(not FileAccess.file_exists(path + ".tmp"), "寫完沒有留下 .tmp")
	gs.day = 3
	gs.save_game("day3_morning")
	_check(FileAccess.file_exists(path + ".bak"), "第二次存檔：上一份留成 .bak")

	# 模擬寫到一半被關掉：主檔變成半截
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"version\": 2, \"checkp")
	f.close()
	gs.reset()
	_check(gs.load_game(), "主檔壞掉時仍然讀得到存檔")
	_check(gs.day == 2 and gs.checkpoint == "day2_morning", "退回上一份存檔（第二天早上）")
	_check(gs.has("test_a"), "旗標還在")

	# 只剩 .bak（主檔不見）
	DirAccess.remove_absolute(path)
	_check(gs.has_save(), "主檔不見、只有 .bak 時，標題畫面仍顯示「繼續」")
	_check(gs.load_game(), "只有 .bak 也讀得到")

	gs.delete_save()
	_check(not gs.has_save(), "刪除存檔會一起清掉 .bak")

	print("[跨周目資料]")
	gs.meta = {"runs": 3, "chapters_done": 1}
	gs.save_meta()
	gs.meta = {"runs": 0, "chapters_done": 0}
	gs.load_meta()
	_check(int(gs.meta.runs) == 3, "meta.json 存讀")
	DirAccess.remove_absolute(gs._path(gs.META_PATH))
	DirAccess.remove_absolute(gs._path(gs.META_PATH) + ".bak")

	print("[聲音]")
	var audio := root.get_node("Audio")
	_check(AudioServer.bus_count == 1, "沒有在執行中新增 bus（Godot 4.3 網頁版新增的 bus 會沒聲音）")
	audio.set_volume("Music", 0.5)
	_check(absf(audio.music_db() - linear_to_db(0.5)) < 0.01, "配樂 50%：音量 -6dB")
	audio.set_volume("SFX", 0.0)
	_check(audio.sfx_db() <= -59.0, "音效 0% ＝ 幾乎無聲")
	audio.set_volume("SFX", 0.5)
	var snd := root.get_node("Sound")
	snd.sfx("interact")
	var hit := false
	for p in snd._sfx_pool:
		if p.playing and absf(p.volume_db - (-4.0 + linear_to_db(0.5))) < 0.01:
			hit = true
	_check(hit, "第一章的音效也套用音量設定")
	gs.meta = {}
	gs.load_meta()
	_check(absf(audio.get_volume("Music") - 0.5) < 0.01, "音量設定存在 meta.json，重開還在")
	audio.set_volume("SFX", 0.9)
	var bgm := "res://audio/ch2/bgm/ch2_bgm01_bleach_town.ogg"
	audio.play_music(bgm)
	for i in 120:
		await process_frame
	_check(audio.music_path() == bgm, "播放配樂")
	audio.stop_music()
	for i in 120:
		await process_frame
	_check(audio.music_path() == "", "淡出後停止")
	DirAccess.remove_absolute(gs._path(gs.META_PATH))
	DirAccess.remove_absolute(gs._path(gs.META_PATH) + ".bak")

	print("[手把]")
	for action in ["interact", "menu", "move_left", "move_right", "move_up", "move_down"]:
		var has_pad := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_pad = true
		_check(has_pad, "%s 有手把綁定" % action)
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	_check(a.is_action("interact"), "手把 A ＝ 互動")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -0.8
	_check(stick.is_action("move_left"), "左搖桿往左 ＝ 往左走")
	gs._input(a)
	_check(gs.interact_key_label() == "A", "用手把後，提示改成「A」")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	gs._input(key)
	_check(gs.interact_key_label() == "E", "改用鍵盤後，提示改回「E」")

	print("[操作說明]")
	var line := "音符碰到圓圈時按 E／空白鍵（手機：點畫面）"
	gs.last_device = "keyboard"
	_check(gs.hint(line) == line, "鍵盤：說明不變")
	gs.last_device = "pad"
	_check(gs.hint(line) == "音符碰到圓圈時按 A", "手把：「按 A」")
	_check(gs.hint("按住 E／空白鍵（手機：按住畫面）前進。") == "按住 A前進。", "手把：「按住 A」")
	gs.last_device = "touch"
	_check(gs.hint(line) == "音符碰到圓圈時點畫面", "觸控：「點畫面」")
	_check(gs.interact_key_label() == "互動", "觸控：互動提示")
	gs.last_device = ""

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
