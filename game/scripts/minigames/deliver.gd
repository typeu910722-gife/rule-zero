extends CanvasLayer
## 送信：信封上是人類本名。你決定交到誰手上。

signal done

var letter_id := ""
var correct := ""
var ok_flag := ""
var prompt := "交給誰？"
var body := ""
var options: Array = []


func _ready() -> void:
	layer = 30


func play() -> void:
	if GameState.fast:
		_apply(correct)
		queue_free()
		return
	var bg := ColorRect.new()
	bg.color = Color(0.96, 0.93, 0.86, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.position = Vector2(340, 80)
	box.custom_minimum_size = Vector2(600, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title := Label.new()
	title.text = prompt
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)
	var letter := Label.new()
	letter.text = body
	letter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	letter.custom_minimum_size = Vector2(600, 80)
	letter.add_theme_font_size_override("font_size", 22)
	box.add_child(letter)
	for opt in options:
		var id: String = opt[0]
		var b := Button.new()
		b.text = opt[1]
		b.pressed.connect(_on_pick.bind(id))
		box.add_child(b)
	await done
	queue_free()


func _on_pick(id: String) -> void:
	_apply(id)
	done.emit()


func _apply(id: String) -> void:
	if id == "":
		return
	GameState.set_flag("gave_%s_%s" % [letter_id, id])
	if id == correct and ok_flag != "":
		GameState.set_flag(ok_flag)
