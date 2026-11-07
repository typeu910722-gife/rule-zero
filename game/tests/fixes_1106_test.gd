extends SceneTree
## 2026-11-06 使用者回饋的修正：
## ① 碰撞對齊重畫的畫面之後，每個調查點、人物、門旁邊都還站得到人（按得到）
## ② 角色走到家具後面，家具變半透明
## ③ 第三章起沒有膽量（狀態列不顯示、選項不扣）
## ④ 追逐中換房間／地圖結束，追逐的音樂要停
## godot --headless --path . -s tests/fixes_1106_test.gd

var failures := 0
var gs: Node


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


## 這一點附近（REACH 以內）有沒有一個小布站得下的位置
func _reachable(pos: Vector2, reach: float, blockers: Array, size: Vector2) -> bool:
	for rad in [24.0, 36.0, 48.0, 60.0, reach - 6.0]:
		for k in 16:
			var p: Vector2 = pos + Vector2.from_angle(TAU * k / 16.0) * rad
			if p.x < 16 or p.y < 16 or p.x > size.x - 16 or p.y > size.y - 16:
				continue
			var me := Rect2(p - Vector2(16, 9.6), Vector2(32, 19.2))
			var hit := false
			for r in blockers:
				if (r as Rect2).intersects(me):
					hit = true
					break
			if not hit:
				return true
	return false


func _run() -> void:
	gs = root.get_node("GameState")
	var ExS: GDScript = load("res://scripts/explore/explore.gd")

	print("[① 每個調查點、人物、門都按得到]")
	for lv in ["chapter3", "chapter4", "chapter5"]:
		var ex = ExS.new()
		ex.load_level("res://levels/%s.json" % lv)
		var bad: Array = []
		for rid in ex.level.rooms:
			ex.room = ex.level.rooms[rid]
			var blockers: Array = ex._blockers()
			var size: Vector2 = ExS._v(ex.room.get("size", [1280, 720]))
			for g in ["spots", "npcs", "doors"]:
				for s in ex.room.get(g, []):
					var reach := float(s.get("reach", ExS.REACH))
					if g == "doors":
						reach += 40.0   # 門有寬度，站在門口任何地方都算
					if not _reachable(ExS._v(s.pos), reach, blockers, size):
						bad.append("%s/%s" % [rid, s.get("id", "")])
		_check(bad.is_empty(), "%s：所有調查點、人物、門旁邊都站得到人（按不到的：%s）" % [lv, bad])
		ex.free()

	print("[② 走到家具後面，家具變半透明]")
	gs.reset()
	gs.chapter = 3
	var ex2 = ExS.new()
	ex2.load_level("res://levels/chapter3.json")
	root.add_child(ex2)
	await process_frame
	gs.flags["seen_c3_records_intro"] = true
	await ex2.enter("records", "from_hall2")
	_check(not ex2._occluders.is_empty(), "病歷室的櫃子有遮擋圖")
	var occ: Node2D = ex2._occluders[0]
	var r: Rect2 = occ.get_meta("occ")
	# 站在櫃子後面（腳在櫃子的腳上面、身體被遮擋圖蓋住）
	ex2.player.position = Vector2(r.get_center().x, occ.position.y - 20)
	ex2.busy = false
	for i in 40:
		await process_frame
	_check(occ.modulate.a < 0.6, "小布在櫃子後面：櫃子變半透明（%.2f）" % occ.modulate.a)
	ex2.player.position = Vector2(r.get_center().x, occ.position.y + 120)
	for i in 40:
		await process_frame
	_check(occ.modulate.a > 0.95, "走出來：櫃子恢復不透明（%.2f）" % occ.modulate.a)

	print("[④ 追逐中換房間，追逐結束]")
	var got := []
	ex2.chase_changed.connect(func(active, _by): got.append(active))
	ex2.patrol_chase_changed(true, "test_patrol")
	_check(got == [true], "開始追逐")
	gs.flags["seen_c3_hall_intro"] = true
	await ex2.enter("lobby", "from_platform")
	_check(got.size() == 2 and got[1] == false, "換房間：追逐結束（%s）" % [got])
	ex2.patrol_chase_changed(true, "test_patrol")
	ex2.queue_free()
	await process_frame
	_check(got.back() == false, "地圖探索結束：追逐結束（%s）" % [got])

	print("[③ 第三章起沒有膽量]")
	gs.reset()
	gs.chapter = 3
	var hud = load("res://scripts/ch3/hud.gd").new()
	root.add_child(hud)
	await process_frame
	hud.place = "測試"
	hud.refresh()
	_check(not ("膽量" in hud._label.text), "第三章狀態列沒有「膽量」：%s" % hud._label.text.replace("\n", "／"))
	hud.queue_free()
	var dsrc := FileAccess.get_file_as_string("res://scripts/autoload/dialogue.gd")
	_check("picked.cost > 0 and GameState.chapter < 3" in dsrc, "第三章起選項不扣膽量")
	_check("o.cost > 0 and GameState.chapter >= 3" in dsrc, "第三章起花膽量的選項當一般選項（不會變灰）")
	for lv in ["chapter3", "chapter4", "chapter5"]:
		var txt := FileAccess.get_file_as_string("res://dialogue/%s.txt" % lv)
		var re := RegEx.create_from_string("->\\s*\\S+\\s+\\$\\d")
		_check(re.search(txt) == null and not ("@courage" in txt), "%s 的劇本沒有花膽量的選項" % lv)

	print("[⑤ 密碼鎖：找到線索之後，鎖下面幫你記著；監控室的密碼有地方找]")
	var L3: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/chapter3.json"))
	for k in L3.keypads:
		var pd: Dictionary = L3.keypads[k]
		_check(pd.get("hint_when", "") != "" and str(pd.code) in str(pd.get("hint_found", "")) or k != "c3_pad_monitor",
			"%s：找到線索後顯示「%s」" % [k, pd.get("hint_found", "")])
		_check(pd.get("hint", "") != "四個數字。", "%s：沒找到線索時也告訴你往哪裡找（%s）" % [k, pd.get("hint", "")])
	var t3 := FileAccess.get_file_as_string("res://dialogue/chapter3.txt")
	_check("監控室換班密碼：1113" in t3 and "@set c3_b2_saw_roster" in t3, "特別病房的值班表寫著監控室的密碼")
	var esrc := FileAccess.get_file_as_string("res://scripts/explore/explore.gd")
	_check("pd.get(\"hint_found\"" in esrc, "密碼鎖會讀 hint_found")

	print("[⑥ 用過、用不到的道具從「持有」拿掉；⑦ 配電箱修好，舊病棟的燈亮]")
	gs.reset()
	gs.chapter = 3
	var ex3 = ExS.new()
	ex3.load_level("res://levels/chapter3.json")
	root.add_child(ex3)
	await process_frame
	gs.flags["seen_c3_wild_intro"] = true
	gs.set_flag("c3_fuse")
	await ex3.enter("wild_hall", "start")
	_check("保險絲" in ex3._items.text, "拿到保險絲：持有清單有（%s）" % ex3._items.text)
	_check(ex3.is_dark(), "停電時舊病棟是暗的")
	gs.set_flag("c3_power_on")
	await process_frame
	_check(not ("保險絲" in ex3._items.text), "保險絲裝進配電箱之後：持有清單拿掉（%s）" % ex3._items.text)
	_check(not ex3.is_dark() and ex3._dark.color.v > 0.5, "配電箱修好：同一間房間的燈馬上亮（%s）" % ex3._dark.color)
	await ex3.enter("wild_ward_a", "from_hall")
	_check(not ex3.is_dark(), "配電箱修好：舊病棟其他房間也亮")
	for k in L3.items:
		_check(L3.get("items_used", {}).has(k), "第三章道具「%s」有用掉的條件" % L3.items[k])
	ex3.queue_free()
	await process_frame

	print("[⑧ 畫面上的牆比較高的房間：碰撞跟著往下，不會走到牆上]")
	for pair in [["chapter3", "hall2", 250], ["chapter3", "wild_end", 255], ["chapter4", "downstairs", 185]]:
		var ex4 = ExS.new()
		ex4.load_level("res://levels/%s.json" % pair[0])
		ex4.room = ex4.level.rooms[pair[1]]
		var hit := false
		for r2 in ex4._blockers():
			if (r2 as Rect2).has_point(Vector2(640, float(pair[2]) - 10)):
				hit = true
		_check(hit, "%s/%s：y=%d 是牆，站不上去" % [pair[0], pair[1], int(pair[2]) - 10])
		ex4.free()
	var ex5 = ExS.new()
	ex5.load_level("res://levels/chapter3.json")
	ex5.room = ex5.level.rooms["b2_lockers"]
	var lock_r: Rect2 = ExS._r(ex5.room.props[0].rect)
	var fill := false
	for r3 in ex5._blockers():
		if (r3 as Rect2).has_point(Vector2(lock_r.get_center().x, float(ex5.room.get("wall_h", 90)) + 5)):
			fill = true
	_check(fill, "靠牆的置物櫃：櫃子和牆中間的縫也擋住")
	ex5.free()

	print("[⑨ 畢業生：聽話的和失控的分開畫，有立繪、有 CG]")
	var PD := "res://art/ch2/characters/portraits/ch2_graduate_portrait_%s.png"
	_check(ResourceLoader.exists(PD % "default") and ResourceLoader.exists(PD % "wild"), "畢業生有兩種立繪（聽話／失控）")
	var Dsrc := FileAccess.get_file_as_string("res://scripts/autoload/dialogue.gd")
	_check("\"畢業生\": \"graduate\"" in Dsrc, "說話的人是「畢業生」時顯示立繪")
	_check("@face 畢業生 wild" in t3, "被追兵抓到時用失控的立繪")
	_check(ResourceLoader.exists("res://art/ch3/bg/ch3_bg_cg_graduates.jpg") and "@bg c3_cg_graduates" in t3, "舊病棟的畢業生有 CG")
	var talk := []
	var chase := []
	for rid in L3.rooms:
		for np in L3.rooms[rid].get("npcs", []):
			if "grad" in str(np.get("char", "")):
				talk.append(np.char)
		for pt in L3.rooms[rid].get("patrols", []):
			if "grad" in str(pt.get("char", "")):
				chase.append(pt.char)
	_check(not talk.is_empty() and talk.all(func(c): return c == "graduate"), "可以對話的畢業生用「聽話」的走路圖 %s" % [talk])
	_check(not chase.is_empty() and chase.all(func(c): return c == "graduate_wild"), "追人的畢業生用「失控」的走路圖 %s" % [chase])
	var ga: Image = load("res://art/walk4/graduate.png").get_image()
	var gb: Image = load("res://art/walk4/graduate_wild.png").get_image()
	_check(ga.get_width() == 1280 and gb.get_width() == 1280, "兩張走路圖都是 1280×1280")

	print("[⑩ 希露飛的走路圖：腳有在動；⑪ 重畫的房間門口用標記，不貼門的圖]")
	var hl: Image = load("res://art/walk4/h_hilufei.png").get_image()
	var moved := 0
	for row in 3:
		var diff := 0
		for y in range(200, 310, 3):
			for x in range(60, 260, 3):
				var c0 := hl.get_pixel(x, row * 320 + y)
				var c1 := hl.get_pixel(320 + x, row * 320 + y)
				if absf(c0.a - c1.a) > 0.5:
					diff += 1
		if diff > 40:
			moved += 1
	_check(moved == 3, "正面、左、右三個方向的第 1、2 格腳的位置不一樣（%d/3）" % moved)
	_check("_draw_door_marker(n, sz, open, t) if painted" in esrc, "重畫過的房間門口畫標記，不貼門的圖")

	print("[⑬ 教室：坐在桌子後面的同學不會被桌子蓋住；⑭ 圍過來的人、大人都換成 Q 版]")
	gs.reset()
	gs.chapter = 4
	gs.flags["c4_pov_haruka"] = true
	var ex6 = ExS.new()
	ex6.load_level("res://levels/chapter4.json")
	root.add_child(ex6)
	await process_frame
	await ex6.enter("classroom", "from_hall")
	ex6.player.position = Vector2(1500, 860)   # 小布在角落，不在任何桌子後面
	for i in 60:
		await process_frame
	var faded := 0
	for oc in ex6._occluders:
		if is_instance_valid(oc) and oc.modulate.a < 0.6:
			faded += 1
	_check(faded >= 3, "坐在桌子後面的同學：前面的桌子變半透明（%d 張）" % faded)
	ex6.queue_free()
	await process_frame
	for n in ["h_crowd", "h_shadow", "h_shadow_diag", "h_principal", "h_fen_father", "h_nurse", "h_whitecoat"]:
		var im: Image = load("res://art/walk4/%s.png" % n).get_image()
		_check(im.get_width() == 1280, "%s 換成 ChatGPT Q 版走路圖（1280×1280，舊的寫實照片是 640）" % n)

	print("[⑮ 同伴走路：方向和走／停不會每幀亂跳（之前看起來身體像裂開）]")
	gs.reset()
	gs.chapter = 3
	var ex7 = ExS.new()
	ex7.load_level("res://levels/chapter3.json")
	ex7.party = ["lulu", "mochi", "popo", "fen", "baimian"]
	root.add_child(ex7)
	await process_frame
	gs.flags["seen_c3_hall_intro"] = true
	await ex7.enter("lobby", "from_platform")
	ex7.busy = false
	var changes := {}
	var stops := {}
	var last := {}
	for dirs in [["move_right", "move_down"], ["move_right"], ["move_left", "move_down"]]:
		for a in dirs:
			Input.action_press(a)
		for i in 70:
			var ppos: Vector2 = ex7.player.position
			await process_frame
			if i < 25 or ex7.player.position.distance_to(ppos) < 1.0:
				continue   # 剛轉彎（同伴還在轉方向）、或小布撞到牆停住
			for fo in ex7._followers:
				var k: int = fo.get_meta("k")
				var rf: Array = [fo.get_meta("row"), fo.get_meta("frame")]
				if last.has(k) and last[k][0] != rf[0]:
					changes[k] = changes.get(k, 0) + 1
				var mvg: bool = fo.get_meta("moving", false)
				if last.has(k) and last[k].size() > 2 and last[k][2] != mvg:
					stops[k] = stops.get(k, 0) + 1
				rf.append(mvg)
				last[k] = rf
		for a in dirs:
			Input.action_release(a)
	var worst := 0
	for k in changes:
		worst = maxi(worst, changes[k])
	var worst_stop := 0
	for k in stops:
		worst_stop = maxi(worst_stop, stops[k])
	_check(worst <= 4, "走直線時同伴的方向最多換 %d 次（<= 4）" % worst)
	_check(worst_stop <= 4, "走路中同伴不會在「走／站」之間一直切換（最多切換 %d 次，<= 4）" % worst_stop)
	ex7.queue_free()
	await process_frame
	var psrc := FileAccess.get_file_as_string("res://scripts/explore/patrol.gd")
	_check("_cand_t >= 0.15" in psrc, "巡邏的人換方向也要持續一小段時間")

	print("[⑯ 那一天：門外每換一雙鞋都有門外的話和門裡的求救，只用聲音和字，不畫出來]")
	var C4: GDScript = load("res://scripts/chapter4.gd")
	var lines: Array = C4.SHOE_LINES
	_check(lines.size() == 5, "五雙鞋各有一組台詞（%d）" % lines.size())
	var joined := ""
	for ln in lines:
		joined += "".join(ln)
	_check(joined.count("換我了") >= 3 and "救命" in joined and "怪胎" in joined, "有嘲笑、換人、求救")
	_check(ResourceLoader.exists("res://audio/ch4/sob_muffled.wav"), "隔著門的哭聲音效")
	var c4src := FileAccess.get_file_as_string("res://scripts/chapter4.gd")
	_check("門裡面有聲音。你沒有回頭。" in c4src, "減少驚嚇與敏感內容：只留「換了一雙鞋」和一句旁白")
	var c4txt := FileAccess.get_file_as_string("res://dialogue/chapter4.txt")
	_check("[!gentle] > 門裡面在發生什麼事，站在門外的每一個人都知道。" in c4txt, "門外的旁白讓玩家知道發生了什麼")
	_check(load("res://art/walk4/director.png").get_image().get_width() == 1280, "理事換成 ChatGPT 毛氈走路圖")

	print("[⑰ 網頁版 ?dev=ch4_theday：直接從「那一天」開始]")
	var msrc := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check("what.begins_with(\"ch4_\")" in msrc, "main.gd 認得 ?dev=ch4_<段落>")
	gs.reset()
	gs.start_chapter4()
	gs.checkpoint = "c4_theday"
	var ch4n = load("res://scripts/chapter4.gd").new()
	root.add_child(ch4n)
	await process_frame
	_check(ch4n.segment == "theday", "第四章從「那一天」這一段開始（%s）" % ch4n.segment)
	ch4n.queue_free()
	await process_frame

	print("[⑱ 網頁版 ?dev=ch5_<結局>：直接看第五章的每一個結局]")
	_check("what.begins_with(\"ch5_\")" in msrc, "main.gd 認得 ?dev=ch5_<結局>")
	for rr in ["a", "b1", "b2", "b3"]:
		gs.reset()
		gs.start_chapter5()
		gs.checkpoint = "c5_ending"
		gs.set_flag("c5_route", rr)
		var ch5n = load("res://scripts/chapter5.gd").new()
		root.add_child(ch5n)
		await process_frame
		_check(ch5n.segment == "ending" and ch5n.route == rr, "第五章直接進結局 %s（%s／%s）" % [rr, ch5n.segment, ch5n.route])
		ch5n.queue_free()
		await process_frame

	print("[⑲ 床上的人畫出來：第四章第一個晚上（左邊醒著被綁、右邊睡著），第五章還沒叫醒的人]")
	for lv in ["chapter4", "chapter5"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % lv))
		for rid in data.rooms:
			for sl in data.rooms[rid].get("sleepers", []):
				var path := "res://art/beds/%s_%s.png" % [sl.char, sl.get("state", "asleep")]
				_check(ResourceLoader.exists(path), "%s/%s 床上的人有圖（%s）" % [lv, rid, path.get_file()])
	gs.reset()
	gs.chapter = 4
	gs.flags["c4_pov_night"] = true
	var ex8 = ExS.new()
	ex8.load_level("res://levels/chapter4.json")
	root.add_child(ex8)
	await process_frame
	await ex8.enter("ward4", "start")
	var tied := 0
	var asleep := 0
	for n in ex8._sleepers:
		if n.visible:
			var st: String = n.get_meta("sleeper").state
			if st == "tied": tied += 1
			elif st.begins_with("asleep"): asleep += 1
	_check(tied == 6 and asleep == 5, "第四章病房：白線左邊 6 個人醒著被綁、右邊 5 個人睡著（%d／%d）" % [tied, asleep])
	var zz := false
	for n in ex8._ysort.get_children():
		if n.has_meta("thing") and n.get_meta("thing").get("id", "") == "c4_n_zz":
			zz = n.get_meta("thing")._kind == "spots"
	_check(zz, "郡主在床上（不再站在地上）")
	ex8.queue_free()
	await process_frame
	gs.reset()
	gs.chapter = 5
	gs.flags["c5_st_a"] = true
	var ex9 = ExS.new()
	ex9.load_level("res://levels/chapter5.json")
	ex9.party_flags = load("res://scripts/chapter5.gd").WAKE_FOLLOW
	root.add_child(ex9)
	await process_frame
	await ex9.enter("a_ward5", "start")
	var vis := func() -> int:
		var c := 0
		for n in ex9._sleepers:
			if n.visible: c += 1
		return c
	_check(vis.call() == 4 and ex9._followers.size() == 0, "第五章：四個人還在床上睡、沒有人跟著（%d／%d）" % [vis.call(), ex9._followers.size()])
	gs.set_flag("c5_woke_lulu")
	await process_frame
	_check(vis.call() == 3 and ex9._followers.size() == 1, "叫醒希露飛：她從床上起來、跟在後面（床上 %d／跟著 %d）" % [vis.call(), ex9._followers.size()])
	gs.set_flag("c5_woke_popo")
	gs.set_flag("c5_woke_mochi")
	await process_frame
	_check(ex9._followers.size() == 3, "每叫醒一個人就多一個人跟著（%d）" % ex9._followers.size())
	await ex9.enter("a_hall5", "from_ward")
	_check(ex9._followers.size() == 3, "換房間之後還跟著（%d）" % ex9._followers.size())
	ex9.queue_free()
	await process_frame

	print("[⑳ 終章 B-1：交代為什麼變成鎮長；同伴成了居民；Fen 記得]")
	var d5 := FileAccess.get_file_as_string("res://dialogue/chapter5.txt")
	for lb in ["c5_b1_bridge", "c5_b1_forget_names", "c5_b1_lulu", "c5_b1_mochi", "c5_b1_popo", "c5_b1_roll", "c5_b1_fen"]:
		_check(("=== " + lb) in d5, "B-1 有 %s" % lb)
	_check("上一個鎮長，是你親手剪開的" in d5, "理事說明為什麼是小布")
	var c5src := FileAccess.get_file_as_string("res://scripts/chapter5.gd")
	_check(c5src.find("c5_b1_bridge") >= 0 and c5src.find("c5_b1_bridge") < c5src.find("c5_b1_intro"), "B-1 先交代、再到小鎮")
	var lv5 = JSON.parse_string(FileAccess.get_file_as_string("res://levels/chapter5.json"))
	var train_when := ""
	for sp in lv5.rooms.b1_platform5.spots:
		if sp.id == "c5_b1_train": train_when = sp.when
	_check("c5_b1_fen_seen" in train_when, "夜車要先見過 Fen 才會來")

	print("[⑫ 關卡裡會顯示的字（地點、門、道具、密碼鎖提示）內建字型都有]")
	var font: Font = gs.font
	var extra_font: FontFile = load("res://fonts/NotoSansTC-Extra.ttf")
	for lv in ["levels/chapter3.json", "levels/chapter4.json", "levels/chapter5.json", "scripts/chapter4.gd", "dialogue/chapter4.txt", "dialogue/chapter5.txt"]:
		var txt := FileAccess.get_file_as_string("res://" + lv)
		var miss := {}
		for i in txt.length():
			var code := txt.unicode_at(i)
			if code > 0x2000 and not font.has_char(code) and not (extra_font and extra_font.has_char(code)):
				miss[txt[i]] = true
		_check(miss.is_empty(), "%s 的字都有內建字型（缺：%s）" % [lv, "".join(miss.keys())])

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
