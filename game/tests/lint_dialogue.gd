extends SceneTree
## 對話腳本檢查：godot --headless -s tests/lint_dialogue.gd

const EVENTS := ["candy", "board", "mirror_stare", "to_plaza", "mayor_appears", "fen_taken",
	"lulu_appears", "mayor_shadow", "sew", "bread",
	# 第二章
	"report_card", "apology", "roll_list", "c2_take_models", "c2_dove_appears", "c2_fence_lineup",
	"scrub", "find_1", "find_2", "find_3", "treatment_hold", "sneak", "photo_1", "photo_2", "photo_nirvana",
	"silhouette", "overlay_close", "roll_list_2", "c2_platform_scene", "c2_dove_mask_on",
	"c2_popo_fence", "c2_dove_hug", "confession_1", "confession_2", "trim_1", "trim_2", "trim_3",
	"c2_mochi_cross", "c2_mochi_back", "chairs_1", "chairs_2", "chairs_3", "long_hold", "special_hold",
	"c2_graduation_layout", "restuff_1", "restuff_2", "c2_tiaoma_gone", "c2_mask_crack", "c2_fates",
	"c2_special_love_cost", "c2_train_arrives", "c2_ending_cg",
	# 第三～七章
	"visit_hold", "mirror_hold", "deliver_lulu", "deliver_mochi", "deliver_fen", "deliver_self",
	"safe_code", "sew_round", "rewrite_rule", "baimian_gone"]


func _init() -> void:
	var p := DialogueParser.new()
	p.parse_file("res://dialogue/chapter1.txt")
	p.parse_file("res://dialogue/chapter2.txt")
	p.parse_file("res://dialogue/chapter3.txt")
	p.parse_file("res://dialogue/chapter4.txt")
	p.parse_file("res://dialogue/chapter5.txt")
	p.parse_file("res://dialogue/chapter6.txt")
	p.parse_file("res://dialogue/chapter7.txt")
	var errs := p.validate(EVENTS)
	for e in errs:
		printerr(e)
	print("dialogue lint: %d labels, %d commands, %d errors" % [p.labels.size(), p.cmds.size(), errs.size()])
	quit(1 if errs.size() > 0 else 0)
