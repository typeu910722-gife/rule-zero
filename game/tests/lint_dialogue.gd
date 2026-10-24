extends SceneTree
## 對話腳本檢查：godot --headless -s tests/lint_dialogue.gd

const EVENTS := ["candy", "board", "mirror_stare", "to_plaza", "mayor_appears", "fen_taken",
	"lulu_appears", "mayor_shadow", "sew", "bread", "good_kid_station",
	"jumpscare_fen", "jumpscare_mayor", "breakdown", "chase", "scissors", "mayor_falls", "conductor_enters", "night_train",
	# 第二章
	"report_card", "apology", "roll_list", "c2_take_models", "c2_dove_appears", "c2_fence_lineup",
	"scrub", "find_1", "find_2", "find_3", "treatment_hold", "sneak", "photo_1", "photo_2", "photo_nirvana",
	"silhouette", "overlay_close", "roll_list_2", "c2_platform_scene", "c2_dove_mask_on",
	"c2_popo_fence", "c2_dove_hug", "confession_1", "confession_2", "trim_1", "trim_2", "trim_3",
	"c2_mochi_cross", "c2_mochi_back", "chairs_1", "chairs_2", "chairs_3", "long_hold", "special_hold",
	"c2_graduation_layout", "restuff_1", "restuff_2", "c2_tiaoma_gone", "c2_mask_crack", "c2_fates",
	"c2_special_love_cost", "c2_train_arrives", "c2_ending_cg",
	# 第三章
	"c3_whistle", "c3_rules", "c3_heart", "c3_thermo", "c3_chase1", "c3_sew", "c3_chase2", "c3_cpr", "c3_lights", "c3_gun", "c3_drip", "c3_drip_chase",
	"jumpscare_dove_up",
	"c4_speech", "c4_chat", "c4_viewfinder", "c4_shoes", "c4_hold_door", "c4_whistle", "c4_breaker", "c5_guard", "c4_run"]


func _init() -> void:
	var p := DialogueParser.new()
	p.parse_file("res://dialogue/chapter1.txt")
	p.parse_file("res://dialogue/chapter2.txt")
	p.parse_file("res://dialogue/chapter3.txt")
	p.parse_file("res://dialogue/chapter4.txt")
	p.parse_file("res://dialogue/chapter5.txt")
	# 關卡（levels/*.json）：密碼鎖是合法的 @event；調查點、NPC、門的對話標籤都要存在
	var events := EVENTS.duplicate()
	var level_errs: Array = []
	for n in ["chapter3", "chapter4", "chapter5"]:
		var path := "res://levels/%s.json" % n
		if not FileAccess.file_exists(path):
			continue
		var lv = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not lv is Dictionary:
			level_errs.append("%s JSON 格式錯誤" % path)
			continue
		events.append_array(lv.get("keypads", {}).keys())
		for rid in lv.get("rooms", {}):
			var r: Dictionary = lv.rooms[rid]
			for key in ["spots", "npcs"]:
				for sp in r.get(key, []):
					var lab: String = sp.get("label", sp.get("id", ""))
					if not p.labels.has(lab):
						level_errs.append("%s 房間 %s 的 %s 沒有對話標籤 %s" % [n, rid, key, lab])
			for d in r.get("doors", []):
				if not lv.rooms.has(d.get("to", "")):
					level_errs.append("%s 房間 %s 的門通往不存在的房間 %s" % [n, rid, d.get("to", "")])
				if d.get("locked_label", "") != "" and not p.labels.has(d.locked_label):
					level_errs.append("%s 房間 %s 的門缺少對話 %s" % [n, rid, d.locked_label])
			if r.get("on_enter", "") != "" and not p.labels.has(r.on_enter):
				level_errs.append("%s 房間 %s 的 on_enter 沒有對話 %s" % [n, rid, r.on_enter])
	var errs := p.validate(events)
	errs.append_array(level_errs)
	for e in errs:
		printerr(e)
	print("dialogue lint: %d labels, %d commands, %d errors" % [p.labels.size(), p.cmds.size(), errs.size()])
	quit(1 if errs.size() > 0 else 0)
