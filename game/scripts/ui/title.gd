extends CanvasLayer
## 標題畫面。會依跨周目記錄（GameState.meta）悄悄改變：
## 車票上的戳章數＝已完成章數＋1；玩過一章以後，角落會多一行「歡迎回來。」

signal new_game
signal continue_game

var _area: Control
const BG := preload("res://art/bg_platform.jpg")
const TICKET := preload("res://art/item_ticket.png")
const TICKET_STAMPED := preload("res://art/item_ticket_stamped.png")


func _ready() -> void:
	layer = 70
	Sound.bgm("memory")
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)

	var box := VBoxContainer.new()
	box.position = Vector2(120, 380)
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var cont := _button("繼續", func(): continue_game.emit())
	cont.disabled = not GameState.has_save()
	box.add_child(cont)
	box.add_child(_button("新遊戲", func(): new_game.emit()))
	if not OS.has_feature("web"):
		box.add_child(_button("離開", func(): get_tree().quit()))
	(cont if not cont.disabled else box.get_child(1)).grab_focus.call_deferred()


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	UiSkin.button(b, 24)
	b.pressed.connect(func():
		Sound.sfx("choice")
		cb.call())
	return b


func _draw_area() -> void:
	var f: Font = GameState.font
	# 背景：月台上的小布，看著棉花糖鎮（art/bg_platform.jpg）
	_area.draw_texture_rect(BG, Rect2(0, 0, 1280, 720), false)
	# 左邊淡淡的一層，讓標題字看得清楚
	for k in 40:
		_area.draw_rect(Rect2(k * 14, 0, 14, 720), Color(1, 0.95, 0.96, 0.62 * (1.0 - k / 40.0)))
	_area.draw_string_outline(f, Vector2(110, 210), "第零條規則", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 10, Color(1, 0.97, 0.97, 0.9))
	_area.draw_string(f, Vector2(110, 210), "第零條規則", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Color("#6d4c5c"))
	_area.draw_string(f, Vector2(116, 270), "Rule Zero", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#b56576"))
	_area.draw_string(f, Vector2(116, 320), "一個溫柔的世界，藏著被遺忘的規則。", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#8e6f7e"))

	# 車票：結束過一輪以上，背面就蓋著戳章
	var stamps := clampi(GameState.loop_number() - GameState.FIRST_LOOP, 0, 15)
	var tk: Texture2D = TICKET_STAMPED if stamps > 0 else TICKET
	var ticket := Rect2(560, 560, 240, 240.0 * tk.get_height() / tk.get_width())
	_area.draw_set_transform(ticket.get_center(), -0.08, Vector2.ONE)
	_area.draw_texture_rect(tk, Rect2(-ticket.size / 2, ticket.size), false)
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 不寫次數：數不清，才有失憶感
	var seen: Array = GameState.meta.get("endings", [])
	if not seen.is_empty():
		_area.draw_string(f, Vector2(116, 640), "看過的結局　%d / %d" % [seen.size(), GameState.ENDING_ORDER.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#8e6f7e"))

	if GameState.is_repeat():
		_area.draw_string_outline(f, Vector2(0, 700), "歡迎回來。", HORIZONTAL_ALIGNMENT_RIGHT, 1250, 18, 5, Color(0, 0, 0, 0.35))
		_area.draw_string(f, Vector2(0, 700), "歡迎回來。", HORIZONTAL_ALIGNMENT_RIGHT, 1250, 18, Color("#fbe7ee"))


## E（互動鍵）也可以按下目前選中的按鈕
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_action_pressed("ui_accept"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and not (f as Button).disabled:
			get_viewport().set_input_as_handled()
			(f as Button).pressed.emit()
