class_name JumpScare
extends CanvasLayer
## 突臉：一張臉突然塞滿整個畫面（約 0.9 秒）。
## 有美術就用 art/scare_<who>.png（全螢幕的臉），沒有就把表情頭像放大、加上色偏抖動。

signal done

var who := "mayor"
var _rect: TextureRect
var _shade: ColorRect


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.08, 0, 0.02, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var art := "res://art/scare_%s.png" % who
	if ResourceLoader.exists(art):
		_rect.texture = load(art)
	else:
		var a := AtlasTexture.new()
		a.atlas = load("res://art/face_%s.png" % who)
		# 表情頭像 4×2 格，取第一格（面無表情）
		a.region = Rect2(28, 20, 200, 200)
		_rect.texture = a
		_rect.modulate = Color(1.1, 0.85, 0.85)
	_rect.size = Vector2(1280, 1280)
	_rect.pivot_offset = _rect.size / 2
	_rect.position = Vector2(0, -280)
	_rect.scale = Vector2(0.25, 0.25)
	_rect.modulate.a = 0.0
	add_child(_rect)


func play() -> void:
	if GameState.fast:
		done.emit()
		return
	Sound.sfx("glitch")
	Dialogue.fx.scare()
	var tw := create_tween().set_parallel()
	tw.tween_property(_rect, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rect, "modulate:a", 1.0, 0.05)
	tw.tween_property(_shade, "color:a", 0.85, 0.08)
	await tw.finished
	# 抖動
	var base := _rect.position
	for i in 10:
		_rect.position = base + Vector2(randf_range(-26, 26), randf_range(-20, 20))
		await get_tree().create_timer(0.04).timeout
	_rect.position = base
	await get_tree().create_timer(0.25).timeout
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(_rect, "modulate:a", 0.0, 0.35)
	tw2.tween_property(_shade, "color:a", 0.0, 0.5)
	await tw2.finished
	done.emit()
