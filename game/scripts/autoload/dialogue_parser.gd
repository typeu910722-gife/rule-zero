class_name DialogueParser
extends RefCounted
## 解析 res://dialogue/*.txt 的對話腳本。語法見 docs/dialogue-format.md。

const KNOWN_OPS := ["roll", "mem", "set", "unset", "add", "sus", "courage", "goto", "if", "end", "wait", "bg", "event", "idle", "sfx", "show", "scare",
	# 第二章
	"conduct", "bgm", "face",
	# 角色的小聲音（嘆氣、笑…）：@voice 名字 種類
	"voice"]
const KNOWN_BG := ["none", "black", "train", "dream", "platform", "plaza", "bakery", "repair", "clocktower", "room_night", "hospital_child", "hospital_empty", "hospital_haruka", "classroom", "train_night", "town2", "mem_sea", "mem_class", "mem_toilet", "mem_hospital", "nt_lulu", "nt_popo", "nt_tama", "nt_mochi", "nt_dog", "glove", "mayor_broken",
	# 第二章：室內背景與 CG（見 dialogue.gd 的 BG_ART／CG_ART）
	"grey_train", "white",
	"dining", "laundry", "treatment", "treatment_window", "dorm_night", "office",
	"platform_negative", "fence", "incinerator", "graduation", "ending_grey", "ending_color",
	"cg01_referral", "cg01_referral_stitch_04", "cg02_ticket", "cg02_ticket_ending", "cg03_arrival_pat",
	"cg04_photo_hallway", "cg05_photo_mailbox", "cg06_photo_nirvana", "cg07_silhouette", "cg08_diary",
	"cg09_clipboard", "cg10_platform_two", "cg11_popo_fence", "cg12_mochi_hug", "cg13_paper_plane",
	"cg14_tiaoma_last", "cg15_mask_break", "cg16_conductor_photo", "cg17_dream_orphanage",
	"cg18_dream_classroom", "cg18_dream_classroom_faceless", "cg19_bad_end", "cg20_ending_all",
	# 第三章（dialogue.gd 的 BG_ART_3／BG_COLORS_3）
	"c3_platform", "c3_hall", "c3_nurse", "c3_nirvana", "c3_records", "c3_director", "c3_wild", "c3_b2", "c3_monitor", "c3_lab",
	"c3_cg_arrival", "c3_cg_nirvana", "c3_cg_records", "c3_cg_crow", "c3_cg_monitor", "c3_cg_ending",
	# 第四、五章（dialogue.gd 的 BG_COLORS_45）
	"c4_classroom", "c4_hallway", "c4_toilet_door", "c4_stairs", "c4_gate", "c4_window", "c4_phone", "c4_home",
	"c4_mailbox", "c4_orphanage", "c4_office", "c4_downstairs", "c4_principal", "c4_hospital", "c4_ward", "c4_ward_dark",
	"c4_platform", "c5_lab", "c5_lab_dark", "c5_real_ward", "c5_real_hall", "c5_outside", "c5_town", "c5_town_office",
	"c5_ward_empty", "c5_school_gate"]

var cmds: Array = []
var labels := {}
var errors: Array = []


func parse_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("找不到檔案：%s" % path)
		return
	parse_text(f.get_as_text(), path.get_file())


func parse_text(text: String, source := "") -> void:
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("//"):
			continue
		var where := "%s:%d" % [source, n]
		if line.begins_with("==="):
			cmds.append({"t": "end"})
			_add_label(line.substr(3).strip_edges(), where)
			continue
		if line.begins_with("# "):
			_add_label(line.substr(2).strip_edges(), where)
			continue
		var cond := ""
		if line.begins_with("["):
			var close := line.find("]")
			if close < 0:
				errors.append("%s 條件缺少 ]" % where)
				continue
			cond = line.substr(1, close - 1)
			line = line.substr(close + 1).strip_edges()
		var c: Dictionary
		if line.begins_with("* "):
			c = _parse_choice(line.substr(2), where)
		elif line.begins_with("@"):
			var parts := line.substr(1).split(" ", false)
			c = {"t": "cmd", "op": parts[0], "args": Array(parts.slice(1))}
			if not parts[0] in KNOWN_OPS:
				errors.append("%s 未知指令 @%s" % [where, parts[0]])
		elif line.begins_with(">"):
			c = {"t": "say", "who": "", "text": line.substr(1).strip_edges()}
		else:
			var i := line.find("：")
			if i > 0 and i <= 10:
				c = {"t": "say", "who": line.left(i), "text": line.substr(i + 1).strip_edges()}
			else:
				c = {"t": "say", "who": "", "text": line}
		c["cond"] = cond
		c["where"] = where
		cmds.append(c)
	cmds.append({"t": "end"})


func _parse_choice(body: String, where: String) -> Dictionary:
	var c := {"t": "choice", "text": body, "target": "", "cost": 0}
	var arrow := body.find("->")
	if arrow < 0:
		errors.append("%s 選項缺少 -> 目標" % where)
		return c
	c.text = body.left(arrow).strip_edges()
	for token in body.substr(arrow + 2).split(" ", false):
		if token.begins_with("$"):
			c.cost = int(token.substr(1))
		else:
			c.target = token
	return c


func _add_label(label: String, where: String) -> void:
	if labels.has(label):
		errors.append("%s 標籤重複：%s" % [where, label])
	labels[label] = cmds.size()


## 檢查所有跳轉目標與指令參數
func validate(known_events: Array) -> Array:
	var out := errors.duplicate()
	for c in cmds:
		if c.t == "choice" and not labels.has(c.target):
			out.append("%s 選項目標不存在：%s" % [c.where, c.target])
		elif c.t == "cmd":
			match c.op:
				"goto":
					if c.args.size() != 1 or not labels.has(c.args[0]):
						out.append("%s @goto 目標不存在" % c.where)
				"if":
					if c.args.size() != 2 or not labels.has(c.args[1]):
						out.append("%s @if 目標不存在" % c.where)
				"event":
					if c.args.size() != 1 or not c.args[0] in known_events:
						out.append("%s 未知事件 %s" % [c.where, c.args])
				"bg":
					if c.args.size() != 1 or not c.args[0] in KNOWN_BG:
						out.append("%s 未知背景 %s" % [c.where, c.args])
				"show":
					if c.args.size() != 1 or (c.args[0] != "none" and not ResourceLoader.exists("res://art/item_%s.png" % c.args[0])):
						out.append("%s 找不到物件圖 %s" % [c.where, c.args])
				"face":
					if c.args.is_empty() or c.args.size() > 2:
						out.append("%s @face 參數錯誤" % c.where)
				"set", "unset", "add", "sus", "courage", "wait", "mem", "roll", "conduct":
					if c.args.is_empty():
						out.append("%s @%s 缺少參數" % [c.where, c.op])
	return out
