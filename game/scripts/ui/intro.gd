extends CanvasLayer
## 開場的歪計劃 Logo 影片（game/video/yz_intro.ogv）。
## 網頁版：瀏覽器規定要先點一下才能播聲音，所以先顯示「點一下開始」。
## 播放中點一下可以跳過。

signal done

const VIDEO := preload("res://video/yz_intro.ogv")

var _player: VideoStreamPlayer
var _hint: Label
var _started := false
var _started_at := 0


func _ready() -> void:
	layer = 80
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_player = VideoStreamPlayer.new()
	_player.stream = VIDEO
	_player.expand = true
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.finished.connect(_finish)
	add_child(_player)
	_hint = Label.new()
	_hint.text = "點一下開始"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.add_theme_font_size_override("font_size", 22)
	_hint.add_theme_color_override("font_color", Color("#8e7d8a"))
	add_child(_hint)
	if GameState.fast:
		_finish.call_deferred()
	elif not OS.has_feature("web"):
		_start()
	else:
		var tw := create_tween().set_loops()
		tw.tween_property(_hint, "modulate:a", 0.35, 0.9)
		tw.tween_property(_hint, "modulate:a", 1.0, 0.9)


func _start() -> void:
	_started = true
	_started_at = Time.get_ticks_msec()
	_hint.visible = false
	_player.play()


func _input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("interact") or event.is_action_pressed("menu") or \
		(event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if not _started:
		_start()
	elif Time.get_ticks_msec() - _started_at > 600:
		_finish()


func _finish() -> void:
	if not is_inside_tree():
		return
	_player.stop()
	set_process_input(false)
	done.emit()
	queue_free()
