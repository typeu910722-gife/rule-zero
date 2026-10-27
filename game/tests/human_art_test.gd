extends SceneTree
## 人類時期（第四、五章）的外包美術：走路圖、對話立繪都接上了，而且圖沒有壞掉。
## 2026-10-27 外包包裡 10 張走路圖的頭髮多一根長刺（SVG 數字黏在一起），這裡檢查每一格的人都在格子中間。
## godot --headless --path . -s tests/human_art_test.gd

var failures := 0
const CLASS := ["h_haruka", "h_haruka_dress", "h_haruka_gown", "h_fen", "h_fen_gown", "h_teacher", "h_hilufei", "h_mingyue",
	"h_xiaoman", "h_classrep", "h_duty", "h_xinhe", "h_tiwen", "h_junzhu", "h_qiuge", "h_lien"]


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _init() -> void:
	_run.call_deferred()


## 一格裡不透明的範圍（x0, y0, x1, y1）
func _bounds(img: Image, cx: int, cy: int, cell: int) -> Rect2i:
	var x0 := cell
	var y0 := cell
	var x1 := -1
	var y1 := -1
	for y in range(0, cell, 2):
		for x in range(0, cell, 2):
			if img.get_pixel(cx * cell + x, cy * cell + y).a > 0.1:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


func _run() -> void:
	var gs := root.get_node("GameState")
	gs.reset()
	gs.fast = true
	var art = load("res://scripts/explore/explore_art.gd")
	# 走路圖：每個人都有、4×4 格、每一格的人都在格子中間（沒有往外刺出去的東西）
	for id in CLASS:
		var path := "res://art/walk4/%s.png" % id
		if not ResourceLoader.exists(path):
			_check(false, "%s 有走路圖" % id)
			continue
		var img: Image = load(path).get_image()
		var cell := img.get_width() / 4
		var ok := img.get_width() == img.get_height() and cell == 320
		var worst := ""
		for r in 4:
			for c in 4:
				var b := _bounds(img, c, r, cell)
				# 人在格子正中間（x 約 108～216）；腳底在下緣附近
				if b.position.x < 90 or b.end.x > 235 or b.end.y < 290:
					ok = false
					worst = "第 %d 列第 %d 格 %s" % [r + 1, c + 1, b]
		_check(ok, "%s 走路圖 1280×1280、每一格的人都在中間 %s" % [id, worst])
		_check(art.WALK_SCALE.has(id), "%s 有設定身高" % id)
	# 身高：小滿最矮、郡主最高（外包的身高比較圖）
	_check(art.WALK_SCALE["h_xiaoman"] < art.WALK_SCALE["h_haruka"] and art.WALK_SCALE["h_junzhu"] > art.WALK_SCALE["h_teacher"], "小滿最矮、郡主最高")
	# 第四、五章用到的人類角色都有走路圖
	for ch in [4, 5]:
		var level = JSON.parse_string(FileAccess.get_file_as_string("res://levels/chapter%d.json" % ch))
		for rid in level.rooms:
			for s in level.rooms[rid].get("things", []) + level.rooms[rid].get("npcs", []):
				var who: String = str(s.get("char", ""))
				if who.begins_with("h_"):
					_check(ResourceLoader.exists("res://art/walk4/%s.png" % who), "第%d章 %s 的 %s 有走路圖" % [ch, rid, who])
	_check(load("res://scripts/chapter4.gd").LOOKS["d1"] == "h_haruka_dress", "那一天①：遙穿著喜歡的衣服")
	_check(load("res://scripts/chapter5.gd").HARUKA == "h_haruka_gown", "第五章醒來的遙穿病人服")
	# 對話立繪：第四章制服、第五章病人服；每個有台詞的人類都找得到
	var d := root.get_node("Dialogue")
	gs.chapter = 4
	d.portrait_state = func(id: String) -> String:
		return "dress" if id == "h_haruka" and gs.has("c4_pov_d1") else "uniform"
	for who in d.HUMAN_PORTRAITS:
		var p: String = d.portrait_path("h_" + d.HUMAN_PORTRAITS[who])
		_check(p != "" and "_uniform_" in p or "_teacher_" in p, "第四章 %s 的立繪：%s" % [who, p.get_file()])
	gs.flags["c4_pov_d1"] = true
	var dress: String = d.portrait_path("h_haruka")
	_check("_dress_" in dress, "那一天① 遙的立繪是那件衣服：%s" % dress.get_file())
	gs.flags.erase("c4_pov_d1")
	_check("_afraid" in d.portrait_path("h_haruka", "afraid"), "@face 可以換表情（遙 afraid）")
	gs.chapter = 5
	d.portrait_state = func(_id: String) -> String:
		return "gown"
	_check("_gown_" in d.portrait_path("h_fen"), "第五章 芬穿病人服")
	_check("_uniform_" in d.portrait_path("h_mingyue"), "沒有病人服的人（銘越）退回制服")
	d.portrait_state = Callable()
	# 第二章不受影響：Fen 還是玩偶立繪
	gs.chapter = 2
	d._show_portrait_ch2("芬")
	_check(not d._ch2_portrait.visible, "第二章「芬」不會出現人類立繪")
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
