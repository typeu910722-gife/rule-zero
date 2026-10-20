extends SceneTree
## 第二章「只能走在路上」：每個角色、物件都要能從路上走到旁邊互動；所有路都連在一起。
## godot --headless --path . -s tests/walkmask_ch2_test.gd

var BT: GDScript
var failures := 0


func _init() -> void:
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func _run() -> void:
	BT = load("res://scripts/world/bleach_town.gd")
	var gs := root.get_node("GameState")
	gs.reset()
	gs.start_chapter2()
	var ch: Node = load("res://scenes/chapter2.tscn").instantiate()
	root.add_child(ch)
	for i in 5:
		await process_frame
	# 連通：從廣場出發，網格 BFS（每格 8px）
	var start: Vector2 = BT.nearest_walkable(ch.PLAZA_SPOT)
	var seen := {}
	var q := [start]
	seen[Vector2i(start / 8.0)] = true
	while not q.is_empty():
		var p: Vector2 = q.pop_back()
		for d in [Vector2(8, 0), Vector2(-8, 0), Vector2(0, 8), Vector2(0, -8)]:
			var n: Vector2 = p + d
			var k := Vector2i(n / 8.0)
			if seen.has(k) or BT.blocked(n):
				continue
			seen[k] = true
			q.append(n)
	var total := 0
	for y in range(0, 1150, 8):
		for x in range(0, 1600, 8):
			if not BT.blocked(Vector2(x, y)):
				total += 1
	_check(seen.size() >= total * 0.97, "路都連在一起（廣場走得到 %d / %d 格）" % [seen.size(), total])
	var far := ["lulu", "mochi", "fen", "popo"]   # 河對岸，本來就走不到
	for id in ch.actors:
		var it = ch.actors[id]
		if id in far:
			continue
		var home: Vector2 = it.home
		if home.y < 180 and home.x < 600 and id != "baimian":
			continue   # 宿舍裡面（夜晚用）
		if id in ["c2_bed", "c2_pillow"]:
			continue
		var reach: float = it.reach_home if it.reach_home > 0.0 else it.reach()
		var best := INF
		for r in range(0, int(reach), 4):
			var steps := maxi(8, r)
			for k in steps:
				var p := home + Vector2.from_angle(TAU * k / steps) * r
				if not BT.blocked(p) and seen.has(Vector2i(p / 8.0)):
					best = minf(best, float(r))
		_check(best < reach, "%s（%s）從路上互動得到（距離 %s，範圍 %.0f）" % [id, it.display_name, str(best), reach])
	quit(1 if failures else 0)
