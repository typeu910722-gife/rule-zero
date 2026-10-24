extends CanvasLayer
## 鏡之屋的保險箱。鎖上寫著「給第＿＿個小布」。答案是 47。

signal done

var _entry := ""
var _fails := 0
var _hint := ""
var _running := false
var _label: Label
var _hint_label: Label


func _ready() -> void:
	layer = 30


func play() -> void:
	if GameState.fast:
		GameState.set_flag("safe_47")
		queue_free()
		return
	_running = true
	var bg := ColorRect.new()
	bg.color = Color("#e6e8ef")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := Label.new()
	title.text = "給第　　個小布"
	title.position = Vector2(390, 70)
	title.add_theme_font_size_override("font_size", 36)
	add_child(title)
	_label = Label.new()
	_label.position = Vector2(520, 140)
	_label.add_theme_font_size_override("font_size", 48)
	add_child(_label)
	_hint_label = Label.new()
	_hint_label.position = Vector2(240, 560)
	_hint_label.custom_minimum_size = Vector2(800, 80)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 20)
	add_child(_hint_label)
	for d in 10:
		var b := Button.new()
		b.text = str(d)
		b.position = Vector2(390 + (d % 5) * 100, 250 + int(d / 5) * 80)
		b.custom_minimum_size = Vector2(80, 60)
		b.pressed.connect(_press.bind(d))
		add_child(b)
	var clear := Button.new()
	clear.text = "重來"
	clear.position = Vector2(460, 470)
	clear.pressed.connect(func():
		_entry = ""
		_show())
	add_child(clear)
	var leave := Button.new()
	leave.text = "離開"
	leave.position = Vector2(640, 470)
	leave.pressed.connect(func():
		if not _running:
			return
		_running = false
		done.emit())
	add_child(leave)
	_show()
	await done
	queue_free()


func _press(d: int) -> void:
	if not _running or _entry.length() >= 2:
		return
	_entry += str(d)
	_show()
	if _entry.length() == 2:
		_submit()


func _submit() -> void:
	if _entry == "47":
		GameState.set_flag("safe_47")
		_running = false
		done.emit()
		return
	_fails += 1
	_entry = ""
	if _fails >= 3:
		_hint = "森林裡那隻舊的小綿羊是 46。病歷寫著：上一張 46，這一次是下一個數字。"
	elif _fails == 1:
		_hint = "鎖上問的是「第幾個」。日記裡有。"
	_show()


func _show() -> void:
	_label.text = _entry if _entry != "" else "＿＿"
	_hint_label.text = _hint
