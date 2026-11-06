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

	print("[⑫ 關卡裡會顯示的字（地點、門、道具、密碼鎖提示）內建字型都有]")
	var font: Font = gs.font
	for lv in ["chapter3", "chapter4", "chapter5"]:
		var txt := FileAccess.get_file_as_string("res://levels/%s.json" % lv)
		var miss := {}
		for i in txt.length():
			var code := txt.unicode_at(i)
			if code > 0x2000 and not font.has_char(code):
				miss[txt[i]] = true
		_check(miss.is_empty(), "%s.json 的字都有字型（缺：%s）" % [lv, "".join(miss.keys())])

	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures else 0)
