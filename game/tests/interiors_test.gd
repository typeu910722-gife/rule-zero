extends SceneTree
## 小屋室內：從門口進去、每樣東西都點得到、對話標籤都存在、離開回到小鎮。
## godot --headless -s tests/interiors_test.gd

var main: Node
var gs: Node
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _wait_phase(p: String) -> void:
	for i in 600:
		if main.phase == p:
			return
		await process_frame
	_check(false, "等待 phase=%s 逾時" % p)


## 從門口進去，依序點每一樣東西，再離開
func _visit(door: String, room: String, choices: Array = []) -> void:
	var dlg := root.get_node("Dialogue")
	gs.auto_choices = choices.duplicate()
	await main.interact(door)
	var scene = main.interior
	_check(scene != null and scene.room_id == room, "%s → 進到「%s」" % [door, room])
	if scene == null:
		return
	for h in scene._hot.duplicate():
		_check(dlg.has_label(h.id), "%s：%s 有對話" % [room, h.name])
		await scene.inspect(h.id)
	await main._exit_interior()
	_check(main.interior == null, "%s：離開，回到小鎮" % room)
	gs.auto_choices = []


func _run() -> void:
	gs = root.get_node("GameState")
	gs.fast = true
	gs.save_dir = "user://test_saves"
	gs.meta = {"runs": 0, "chapters_done": 0}
	gs.reset()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.hold_interior = true
	await _wait_phase("day1_explore")

	print("[第一天]")
	await _visit("lulu_house", "lulu")
	await _visit("popo_house", "popo")
	# 樹屋：地板下的鑰匙（選「掀開來看看」）、樹洞（選「湊近看看」）
	await _visit("fen_tree", "fen", [0, 0])
	_check(gs.has("got_key"), "樹屋地板下 → 修理室的鑰匙")
	_check(gs.has("fen_hole_seen"), "樹洞：突臉（只會一次）")
	await _visit("mochi_house", "mochi")
	await _visit("tama_house", "tama")
	await main.interact("station_office")
	_check(main.interior == null, "第一天：站務室鎖著")
	await main.interact("mayor_door")
	_check(main.interior == null, "第一天：鎮長在家，公館進不去")

	print("[第二天]")
	gs.day = 2
	main._set_phase("day2_explore")
	# 公館：抽屜裡的班規（「老師」的線索）、老鼠洞（選「趴下來看看」）
	gs.auto_choices = [0]
	await main.interact("mayor_door")
	var scene = main.interior
	_check(scene != null and scene.room_id == "mayor", "第二天：鎮長不在家 → 進到公館")
	if scene:
		for h in scene._hot.duplicate():
			gs.auto_choices = [0, 0]
			await scene.inspect(h.id)
		await main._exit_interior()
	_check(gs.has("found_class_rules"), "公館的抽屜 → 三年二班的班規")
	_check(gs.has("mayor_hole_seen"), "老鼠洞：突臉")
	gs.auto_choices = []
	await _visit("station_office", "station")

	print("[跨輪記得]")
	gs.finish_loop("good_kid")
	_check(gs.remembers("knows_teacher"), "下一輪記得：鎮長＝老師")
	print("結果：%s（%d 個失敗）" % ["通過" if failures == 0 else "失敗", failures])
	quit(1 if failures > 0 else 0)
