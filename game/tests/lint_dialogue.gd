extends SceneTree
## 對話腳本檢查：godot --headless -s tests/lint_dialogue.gd

const EVENTS := ["candy", "board", "mirror_stare", "to_plaza", "mayor_appears", "fen_taken",
	"lulu_appears", "mayor_shadow", "sew", "bread",
	# 第二章
	"report_card", "apology", "roll_list", "c2_take_models", "c2_dove_appears", "c2_fence_lineup"]


func _init() -> void:
	var p := DialogueParser.new()
	p.parse_file("res://dialogue/chapter1.txt")
	p.parse_file("res://dialogue/chapter2.txt")
	var errs := p.validate(EVENTS)
	for e in errs:
		printerr(e)
	print("dialogue lint: %d labels, %d commands, %d errors" % [p.labels.size(), p.cmds.size(), errs.size()])
	quit(1 if errs.size() > 0 else 0)
