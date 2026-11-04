extends SceneTree
## 人類時期（第四、五章）的外包美術：走路圖、對話立繪都接上了，而且圖沒有壞掉。
## 2026-10-27 外包包裡 10 張走路圖的頭髮多一根長刺（SVG 數字黏在一起），這裡檢查每一格的人都在格子中間。
## godot --headless --path . -s tests/human_art_test.gd

var failures := 0
const CLASS := ["h_haruka", "h_haruka_dress", "h_haruka_gown", "h_fen", "h_fen_gown", "h_teacher", "h_hilufei", "h_mingyue",
	"h_xiaoman", "h_classrep", "h_duty", "h_xinhe", "h_tiwen", "h_junzhu", "h_qiuge", "h_lien",
	# 2026-11-04 第五章醒來的四個人改穿病人服
	"h_xinhe_gown", "h_junzhu_gown", "h_qiuge_gown", "h_lien_gown"]


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
				# 人在格子正中間、腳底在下緣附近。2026-11-03 換成 ChatGPT 的 Q 版大頭（頭髮比外包的寬，約 x 62～258），
				# 範圍放寬到 50～270；外包那次往外刺的頭髮會碰到格子邊，還是抓得到
				if b.position.x < 50 or b.end.x > 270 or b.end.y < 290:
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
	# 2026-11-03 ChatGPT 補畫了銘越的病人服（之前沒有，會退回制服）
	_check("_gown_" in d.portrait_path("h_mingyue"), "第五章 銘越穿病人服")
	_check("_uniform_" in d.portrait_path("h_classrep"), "沒有病人服的人（班長）退回制服")
	# 2026-11-04 大人的立繪：第五章（病人服狀態）的護理師退回她自己的那一套
	_check("h_nurse_portrait_teacher_smile" in d.portrait_path("h_nurse"), "第五章 護理師有立繪")
	for who in ["穿白大衣的人", "芬的父親", "護理師"]:
		_check(d.HUMAN_PORTRAITS.has(who) and d.portrait_path("h_" + d.HUMAN_PORTRAITS[who]) != "", "%s 有立繪" % who)
	# 理事是玩偶世界的真人：布料質感、沒有臉（CLAUDE.md 1-5），用第二章那一套立繪
	_check(d.PORTRAITS.get("理事", "") == "director" and d.portrait_path("director") != "", "理事 有立繪")
	d.portrait_state = Callable()
	# 給畫師的表情對照表（docs/vendor/expression_dictionary.csv）要和遊戲一致：
	# 現有的立繪都在表上、表上的★預設表情就是遊戲用的預設臉（2026-10-28 畫師說少了這張表）
	var csv := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../docs/vendor/expression_dictionary.csv"), FileAccess.READ)
	_check(csv != null, "有表情對照表 expression_dictionary.csv")
	if csv:
		var names := {}
		var defaults_ok := true
		csv.get_csv_line()
		while not csv.eof_reached():
			var r := csv.get_csv_line()
			if r.size() < 9:
				continue
			names[r[8]] = true
			if r[7] == "★" and d.HUMAN_DEFAULT_FACE.get(r[2], {}).get(r[4], "") != r[5]:
				defaults_ok = false
				printerr("    預設表情不一致：", r[2], " ", r[4], " ", r[5])
		# 78 張外包立繪＋校長（2026-11-03 ChatGPT 出圖）＋穿白大衣的人、芬的父親、護理師（2026-11-04）
		_check(names.size() == 82, "表上 82 張立繪（%d）" % names.size())
		_check(defaults_ok, "表上的★預設表情 = 遊戲的預設臉")
		var missing := []
		for f in DirAccess.get_files_at("res://art/human/portraits"):
			if f.ends_with(".png") and not names.has(f):
				missing.append(f)
		_check(missing.is_empty(), "現有的立繪檔名都在表上 %s" % [missing])
	# CG 10 張（2026-11-04 ChatGPT）：檔案都在、2560×1440、劇本裡都用到；顯示 CG 時不疊立繪
	var scripts := FileAccess.get_file_as_string("res://dialogue/chapter4.txt") + FileAccess.get_file_as_string("res://dialogue/chapter5.txt")
	for cg in ["c4_cg01_speech", "c4_cg02_mirror", "c4_cg03_mailbox", "c4_cg04_teacher_night", "c4_cg05_practice",
			"c4_cg06_dove", "c4_cg07_hairclip", "c4_cg08_first_night", "c5_cg09_waking", "c5_cg10_outside"]:
		var p: String = d.HUMAN_CG % cg.substr(3)
		var ok := ResourceLoader.exists(p)
		if ok:
			var t: Texture2D = load(p)
			ok = t.get_width() == 2560 and t.get_height() == 1440
		_check(ok, "CG %s 有圖、2560×1440" % cg)
		_check(("@bg %s" % cg) in scripts, "CG %s 在劇本裡" % cg)
	# 追逐戰全身圖 3 套 × 12 張（2026-11-04 ChatGPT）：512×512、腳底在 y≈488、人在格子中間
	var C3 = load("res://scripts/ch3/chase3d.gd")
	for pre in ["h_haruka_chase_uniform", "h_haruka_chase_gown", "h_fen_chase_uniform"]:
		var bad := []
		for pose in C3.RUNNER_POSES:
			var p: String = C3.RUNNER_DIR + "%s_%s.png" % [pre, pose]
			if not ResourceLoader.exists(p):
				bad.append(pose + " 沒有圖")
				continue
			var img: Image = load(p).get_image()
			var r := img.get_used_rect()
			if img.get_width() != 512 or img.get_height() != 512 or absi(r.end.y - 488) > 3 or r.position.y < 24 or r.position.x < 0:
				bad.append("%s %s" % [pose, r])
		_check(bad.is_empty(), "%s 12 張都在、512×512、腳底對齊 %s" % [pre, bad])
	_check('r.runner = "h_fen_chase_uniform"' in FileAccess.get_file_as_string("res://scripts/chapter4.gd"), "第四章 芬跑過走廊：左下角是芬")
	_check('r.runner = "h_haruka_chase_gown"' in FileAccess.get_file_as_string("res://scripts/chapter5.gd"), "第五章 走出醫院：左下角是遙（病人服）")
	# 小玉（2026-11-04 ChatGPT 布偶）：第五章有台詞，要有第二章那種立繪；@face 用到的表情都有圖；走路圖換成布偶
	_check(d.PORTRAITS.get("小玉", "") == "tama", "小玉 有布偶立繪")
	for f in ["default", "smile_hard", "bow"]:
		_check(ResourceLoader.exists(d.PORTRAIT_DIR % "tama" + f + ".png"), "小玉 立繪 %s" % f)
	var ch5txt := FileAccess.get_file_as_string("res://dialogue/chapter5.txt")
	_check("@face 小玉 bow" in ch5txt and "@face 小玉 smile_hard" in ch5txt, "第五章 小玉鞠躬、笑得很用力")
	var tama: Texture2D = load("res://art/walk4/tama.png")
	_check(tama.get_width() == 1280 and tama.get_height() == 1280, "小玉 走路圖是新的布偶版（1280×1280）")
	# 門（2026-11-04 ChatGPT）：第三～五章地圖上每一種房間主題的門，正面／俯視、鎖著／開著都找得到圖
	var EA = load("res://scripts/explore/explore_art.gd")
	var themes := {}
	for chn in [3, 4, 5]:
		var lv = JSON.parse_string(FileAccess.get_file_as_string("res://levels/chapter%d.json" % chn))
		for rid in lv.rooms:
			if not lv.rooms[rid].get("doors", []).is_empty():
				themes[lv.rooms[rid].get("theme", "hospital")] = true
	var miss := []
	for th in themes:
		for view in ["front", "side"]:
			for o in [true, false]:
				if EA.door_art(th, view, o).is_empty():
					miss.append("%s/%s/%s" % [th, view, o])
	_check(miss.is_empty() and themes.size() >= 8, "%d 種房間主題的門都有圖 %s" % [themes.size(), miss])
	# 第三章小遊戲零件（2026-11-05 ChatGPT）：每一種都找得到圖；圖要被快取住（只在 draw 裡 load 會被釋放，畫成一塊白色）
	var MB = load("res://scripts/ch3/mini_base.gd")
	var parts := ["cpr_heart", "cpr_heart_press", "cpr_monitor", "drip_bag", "drip_drop", "card_back", "card_front",
		"thermo", "sew_cloth", "sew_needle", "sew_cotton", "rules_board", "corridor",
		"run_gurney", "run_pole", "run_hand", "run_wheelchair", "run_bu_01", "run_bu_02"]
	var no_part := []
	for pn in parts:
		if MB.art(pn) == null:
			no_part.append(pn)
	_check(no_part.is_empty(), "第三章小遊戲 %d 個零件都有圖 %s" % [parts.size(), no_part])
	_check(MB.art("cpr_heart") == MB.art("cpr_heart") and MB._art_cache.has(MB.ART_DIR + "cpr_heart"), "零件圖有快取（不會畫成白色方塊）")
	_check(MB.art("no_such_part") == null, "沒有的零件回傳 null（退回原本的色塊）")
	var was_fast: bool = gs.fast
	gs.fast = false
	for gp in ["cpr", "drip", "heart_cards", "sew", "thermo", "runner"]:
		var mg = load("res://scripts/ch3/%s.gd" % gp).new()
		if gp == "sew":
			mg.patients = [["lulu", "露露"]]
		if gp == "thermo":
			mg.queue = [["lulu", "露露"]]
		root.add_child(mg)
		for k in 3:
			await process_frame
		_check(not mg._finished, "%s 用零件圖畫得出來" % gp)
		mg.queue_free()
	gs.fast = was_fast
	# 第四、五章小遊戲與演出（2026-11-05 ChatGPT）：game/art/ch4/mini/
	var parts4 := ["bg_toilet_door", "bg_podium", "bg_hospital_side", "phone", "dove", "fen_stand", "fen_push", "staff_01", "staff_02"]
	for k in 6:
		parts4.append("shoes_%d" % k)
	var no4 := []
	for pn in parts4:
		if MB.art4(pn) == null:
			no4.append(pn)
	_check(no4.is_empty(), "第四、五章 %d 個零件都有圖 %s" % [parts4.size(), no4])
	_check(MB.art4("phone") != MB.art("phone"), "第三章和第四章的零件分開放（同名不會拿錯）")
	var ch4src := FileAccess.get_file_as_string("res://scripts/chapter4.gd")
	_check("Ch3Mini.art4(\"phone\")" in ch4src and "Ch3Mini.art4(\"shoes_%d\"" in ch4src, "第四章 手機取景、門縫的鞋子用圖")
	was_fast = gs.fast
	gs.fast = false
	for gp in ["ch4/speech", "ch4/group_chat", "ch4/hold_door", "ch5/breath_walk", "ch5/guard"]:
		var mg = load("res://scripts/%s.gd" % gp).new()
		root.add_child(mg)
		for k in 3:
			await process_frame
		_check(not mg._finished, "%s 用圖畫得出來" % gp)
		mg.queue_free()
	gs.fast = was_fast
	var bw = load("res://scripts/ch5/breath_walk.gd").new()
	bw.held = true
	_check(bw._haruka_frame(false) != null and bw._haruka_frame(true) == MB.art("h_haruka_chase_gown_breath", "res://art/human/chase/"), "終章 醒來走路：遙用病人服的全身圖，跌坐時喘氣")
	bw.free()
	# 地圖上的小道具與條碼的走路圖（2026-11-05 ChatGPT）
	var IA = load("res://scripts/world/interactable.gd")
	var no_prop := []
	for pn in ["candy_0", "candy_1", "candy_2", "note", "mailbox", "pillow"]:
		if IA.prop_tex(pn) == null:
			no_prop.append(pn)
	_check(no_prop.is_empty() and IA._props.has("candy_0"), "糖果、紙條、信箱、枕頭都有圖，而且有快取 %s" % [no_prop])
	var zebra_ok := true
	for k in 4:
		var zt: Texture2D = load("res://art/ch2/minigames/chairs/ch2_chairs_tiaoma_walk_%02d.png" % (k + 1))
		zebra_ok = zebra_ok and zt != null and zt.get_width() == 80 and zt.get_height() == 80
	_check(zebra_ok and "\"youyou\", \"tiaoma\"]" in FileAccess.get_file_as_string("res://scripts/minigames/chairs.gd"), "搶椅子：條碼有 4 格走路圖（80×80）")
	# 每一章的對話框與名牌（第二章外包圖、第三～五章 ChatGPT，2026-11-05）
	_check(d.chapter_skin(1).is_empty(), "第一章維持原本的布料對話框")
	for chn in [2, 3, 4, 5]:
		var sk: Array = d.chapter_skin(chn)
		_check(sk.size() == 3 and sk[0] is StyleBoxTexture and sk[1] is StyleBoxTexture, "第 %d 章有自己的對話框和名牌" % chn)
	_check(d.chapter_skin(4)[0].texture == d.chapter_skin(5)[0].texture, "第四、五章（人類時期）用同一套")
	var was_ch: int = gs.chapter
	gs.chapter = 3
	d._apply_style()
	d._say("露露", "測試")
	_check(d._name.get_theme_stylebox("normal") is StyleBoxTexture, "說話的人有名牌")
	d._say("", "旁白")
	_check(d._name.get_theme_stylebox("normal") is StyleBoxEmpty, "旁白不顯示名牌")
	_check(d._name.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN, "名牌只包住名字，不撐滿整條")
	d._box.visible = false
	gs.chapter = was_ch
	d._apply_style()
	# 密碼鎖、狀態列（2026-11-05 ChatGPT）：第三章毛氈、第五章金屬；狀態列第三章毛氈、第四五章筆記本紙
	var no_ui := []
	for pn in ["kp3_panel", "kp3_key", "kp3_key_sel", "kp5_panel", "kp5_key", "kp5_key_sel", "hud3_bar", "hud4_bar"]:
		if MB.art(pn) == null:
			no_ui.append(pn)
	_check(no_ui.is_empty(), "密碼鎖、狀態列的圖都在 %s" % [no_ui])
	for pn in ["hud3_bar", "hud4_bar"]:
		_check(MB.art(pn).get_height() <= 66, "%s 高度不超過狀態列（九宮格邊不會溢出）" % pn)
	var was_ch2: int = gs.chapter
	var kp3 = load("res://scripts/explore/keypad.gd").new()
	gs.chapter = 5
	_check(kp3._skin() == "kp5", "第五章的密碼鎖是金屬的")
	gs.chapter = 3
	_check(kp3._skin() == "kp3", "第三章的密碼鎖是毛氈的")
	kp3.free()
	_check(load("res://scripts/ch3/hud.gd").bar_style() is StyleBoxTexture, "狀態列用底條圖")
	gs.chapter = was_ch2
	# 3D 走廊：門用地圖那套圖、逃生燈牌與天花板燈有貼圖；第三、四章的章末卡片有背景（2026-11-05）
	var C3d = load("res://scripts/ch3/chase3d.gd")
	for kit in ["hosp", "school", "real"]:
		_check(C3d.door_texture(kit) != null, "3D 走廊的門有圖（%s）" % kit)
	for tn in ["exit_sign", "exit_sign_felt", "ceiling_lamp"]:
		_check(ResourceLoader.exists("res://art/3d/tex/%s.png" % tn), "3D 的 %s 有圖" % tn)
	for pair in [["chapter3", "res://art/ch3/bg/ch3_end_card.jpg"], ["chapter4", "res://art/ch4/bg/ch4_end_card.jpg"]]:
		_check(ResourceLoader.exists(pair[1]) and pair[1] in FileAccess.get_file_as_string("res://scripts/%s.gd" % pair[0]), "%s 章末卡片有背景圖" % pair[0])
	_check("Ch3Mini.art(\"rules_board\")" in FileAccess.get_file_as_string("res://scripts/chapter3.gd"), "醫院守則貼在告示板上")
	# 小人跟著玩家的狀態換動作
	var ch = C3.new()
	ch.maze = C3.MAZE_REAL_HALL.duplicate()
	ch.look = C3.LOOK_REAL
	ch.has_enemy = false
	ch.breath = true
	ch.runner = "h_haruka_chase_gown"
	root.add_child(ch)
	await process_frame
	ch._vp.size = Vector2i(64, 36)
	ch.set_process(false)
	_check(ch._runner != null and ch.runner_pose == "idle", "一開始站著（idle）")
	ch._look_cd = 99.0
	ch._update_runner(0.2, 1.0, false, false)
	_check(ch.runner_pose.begins_with("run_"), "往前走：播走路的格子（%s）" % ch.runner_pose)
	ch._update_runner(0.05, 1.0, false, true)
	_check(ch.runner_pose == "stumble", "撞到牆：踉蹌")
	ch._stop_t = 1.0
	ch._update_runner(0.05, 0.0, false, false)
	_check(ch.runner_pose == "breath", "喘不過氣、停下來：撐膝蓋喘氣")
	ch._stop_t = 0.0
	ch._stumble_t = 0.0
	ch._look_cd = 0.0
	ch._update_runner(0.05, 1.0, false, false)
	_check(ch.runner_pose == "look_back", "偶爾回頭看")
	ch.queue_free()
	var ch3 = C3.new()
	root.add_child(ch3)
	await process_frame
	ch3._vp.size = Vector2i(64, 36)
	_check(ch3._runner == null, "第三章（玩偶）的 3D 追逐不顯示人類小人")
	ch3.queue_free()
	await process_frame
	gs.chapter = 4
	d.set_bg("c4_cg01_speech")
	_check(d._bg_img.visible and d._cg_shown, "@bg c4_cg01_speech 顯示 CG")
	d._show_portrait_ch2("遙")
	_check(not d._ch2_portrait.visible, "CG 上不疊立繪")
	d.set_bg("none")
	# 第二章不受影響：Fen 還是玩偶立繪
	gs.chapter = 2
	d._show_portrait_ch2("芬")
	_check(not d._ch2_portrait.visible, "第二章「芬」不會出現人類立繪")
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
