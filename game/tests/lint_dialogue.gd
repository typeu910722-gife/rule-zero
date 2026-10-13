extends SceneTree
## 對話腳本檢查：godot --headless -s tests/lint_dialogue.gd

const EVENTS := ["candy", "board", "mirror_stare", "to_plaza"]


func _init() -> void:
	var p := DialogueParser.new()
	p.parse_file("res://dialogue/chapter1.txt")
	var errs := p.validate(EVENTS)
	for e in errs:
		printerr(e)
	print("dialogue lint: %d labels, %d commands, %d errors" % [p.labels.size(), p.cmds.size(), errs.size()])
	quit(1 if errs.size() > 0 else 0)
