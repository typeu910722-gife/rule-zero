extends CanvasLayer
## 第零條。留下，或劃掉。

signal done


func _ready() -> void:
	layer = 30


func play() -> void:
	if GameState.fast:
		if GameState.has("fast_keep_rule"):
			GameState.set_flag("kept_zero")
		else:
			GameState.set_flag("rewrote_zero")
		queue_free()
		return
	var bg := ColorRect.new()
	bg.color = Color(0.97, 0.93, 0.94, 0.98)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var t := Label.new()
	t.text = "第零條\n不要想起來。"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(340, 120)
	t.custom_minimum_size = Vector2(600, 120)
	t.add_theme_font_size_override("font_size", 40)
	add_child(t)
	var keep := Button.new()
	keep.text = "把這一條留下"
	keep.position = Vector2(360, 400)
	keep.custom_minimum_size = Vector2(240, 64)
	keep.pressed.connect(func():
		GameState.set_flag("kept_zero")
		done.emit())
	add_child(keep)
	var cut := Button.new()
	cut.text = "劃掉"
	cut.position = Vector2(680, 400)
	cut.custom_minimum_size = Vector2(240, 64)
	cut.pressed.connect(func():
		GameState.set_flag("rewrote_zero")
		done.emit())
	add_child(cut)
	await done
	queue_free()
