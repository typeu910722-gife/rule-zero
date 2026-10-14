extends SceneTree
## 追逐戰截圖：xvfb-run godot --path . -s tests/screenshots_chase.gd -- <輸出資料夾>

var out := "user://shots"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)


func _run() -> void:
	var c = load("res://scripts/chase/chase.gd").new()
	root.add_child(c)
	for i in 20:
		await process_frame
	await _shot("chase_1_start")
	# 往前跑一段
	Input.action_press("move_up")
	for i in 50:
		await process_frame
	Input.action_release("move_up")
	await _shot("chase_2_run")
	# 回頭看：鎮長在 5 公尺外追過來
	c._mayor_on = true
	c._rise = 0.0
	c._attempts = 0
	c._frozen = false
	c._mayor.visible = true
	c._heading += PI
	c._mayor.position = c._bu.position + c._fwd() * 5.0
	c._cam_update(1.0)
	for i in 4:
		await process_frame
	await _shot("chase_3_mayor")
	quit()
