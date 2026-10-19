extends SceneTree
## 恐怖畫面效果截圖：xvfb-run godot --path . -s tests/screenshots_fx.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String, frames := 3) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var gs := root.get_node("GameState")
	var dlg := root.get_node("Dialogue")
	gs.save_dir = "user://test_saves"
	DirAccess.make_dir_recursive_absolute(gs.save_dir)
	var town: Node2D = load("res://scripts/world/town.gd").new()
	root.add_child(town)
	var cam := Camera2D.new()
	cam.position = Vector2(700, 520)
	town.add_child(cam)
	cam.make_current()
	await _shot("fx_01_town_plain")
	# 下午三點的鐘聲：色差＋錯位（截在最強的那一格）
	dlg.fx.glitch(5.0)
	await _shot("fx_02_glitch", 6)
	dlg.fx.clear()
	# 夢境 1（醫院走廊）：@bg dream 自動褪色
	dlg.run("dream_1")
	await create_timer(1.5).timeout
	await _shot("fx_03_dream")
	dlg._advance.emit()
	await create_timer(0.3).timeout
	dlg._advance.emit()
	await create_timer(0.3).timeout
	dlg._advance.emit()
	await create_timer(0.3).timeout
	_check_off(dlg)
	dlg.set_bg("none")
	# 鏡子凝視第 8 秒
	var m: Node = load("res://scripts/minigames/mirror_stare.gd").new()
	root.add_child(m)
	m.play()
	m._t = 7.6
	await _shot("fx_04_mirror", 6)
	# 第 10 秒人影消失時的輕微錯位
	m._t = 9.99
	await _shot("fx_05_mirror_end", 4)
	quit()


func _check_off(dlg: Node) -> void:
	print("離開夢境後效果關掉：", dlg.fx.preset == "off")
