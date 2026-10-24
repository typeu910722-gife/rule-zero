extends CanvasLayer
## 鎮長的縫補。縫緊，對方會忘記；留下線頭，記憶還在。
## 白面沒有縫線。介面仍然是星星和「做得好」。

signal done

var people: Array = []
var _i := 0
var _running := false
var _area: Control
var _tight: Button
var _loose: Button

const LOOK := {
	"pip": ["sheep", Color("#fffdf8"), {}],
	"lulu": ["rabbit", Color("#f4b6c2"), {}],
	"mochi": ["hamster", Color("#fbf3e6"), {}],
	"popo": ["penguin", Color("#2f3352"), {}],
	"baimian": ["fox", Color("#e4e4e0"), {"pale": true, "no_tail": true}],
	"xiaoji": ["hedgehog", Color("#2f2f2f"), {"quills": 5}],
	"gaga": ["crow", Color("#4a4a4a"), {"sewn": true}],
	"zhongzhong": ["hippo", Color("#9c9c9c"), {}],
	"youyou": ["weasel", Color("#b8b8b4"), {"thread": true}],
}
const NAMES := {
	"pip": "小布", "lulu": "露露", "mochi": "麻糬", "popo": "波波", "baimian": "白面",
	"xiaoji": "小棘", "gaga": "嘎嘎", "zhongzhong": "重重", "youyou": "鼬鼬",
}


func _ready() -> void:
	layer = 30


func play() -> void:
	if GameState.fast:
		for id in people:
			if id == "baimian":
				GameState.set_flag("no_seam")
			else:
				GameState.set_flag("loose_%s" % id)
		GameState.set_flag("left_a_thread")
		queue_free()
		return
	_running = true
	var bg := ColorRect.new()
	bg.color = Color("#2c3330")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw)
	add_child(_area)
	_tight = Button.new()
	_tight.text = "縫緊　★"
	_tight.position = Vector2(420, 560)
	_tight.pressed.connect(_choose.bind(false))
	add_child(_tight)
	_loose = Button.new()
	_loose.text = "留下線頭"
	_loose.position = Vector2(680, 560)
	_loose.pressed.connect(_choose.bind(true))
	add_child(_loose)
	_sync_buttons()
	await done
	queue_free()


func _sync_buttons() -> void:
	var id: String = people[_i] if _i < people.size() else ""
	var none := id == "baimian"
	_tight.visible = not none
	_loose.visible = true
	_loose.text = "沒有縫線。把手放下。" if none else "留下線頭"
	_area.queue_redraw()


func _choose(loose: bool) -> void:
	if _i >= people.size():
		return
	var id: String = people[_i]
	if id == "baimian":
		GameState.set_flag("no_seam")
	elif loose:
		GameState.set_flag("loose_%s" % id)
		GameState.set_flag("left_a_thread")
	else:
		GameState.set_flag("tight_%s" % id)
	_i += 1
	if _i >= people.size():
		_running = false
		done.emit()
		return
	_sync_buttons()


func _draw() -> void:
	if _i >= people.size():
		return
	var id: String = people[_i]
	var spec: Array = LOOK.get(id, ["sheep", Color.WHITE, {}])
	var f: Font = GameState.font
	_area.draw_string(f, Vector2(0, 90), "今晚的縫補　%d / %d" % [_i + 1, people.size()], HORIZONTAL_ALIGNMENT_CENTER, 1280, 28, Color("#f6f1e6"))
	_area.draw_set_transform(Vector2(640, 400), 0, Vector2(3.2, 3.2))
	Critter.draw(_area, spec[0], spec[1], 1.0, Vector2.ZERO, id != "baimian", false, id == "pip", spec[2])
	_area.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_area.draw_string(f, Vector2(0, 500), NAMES.get(id, id), HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Color("#f6f1e6"))
	if id == "baimian":
		_area.draw_string(f, Vector2(0, 530), "沒有縫線可以縫。", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#c9b8a4"))
