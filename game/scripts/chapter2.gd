extends Node2D
## 第二章「漂白鎮」的流程導演（目前：序章＋第一天）。
## 劇情邏輯寫在 dialogue/chapter2.txt（標籤以 c2_ 開頭），這裡只處理「世界」的變化。
## 互動時依序尋找對話標籤：c2_<id>_<phase> → c2_<id>_d<day> → c2_<id>

const BleachTown := preload("res://scripts/world/bleach_town.gd")
const Player := preload("res://scripts/world/player.gd")
const Board := preload("res://scripts/ui/board.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const EndCard := preload("res://scripts/ui/end_card.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const Apology := preload("res://scripts/minigames/apology.gd")
const RollList := preload("res://scripts/ui/roll_list.gd")

const EXPLORE_PHASES := ["day1_explore", "day1_night"]

## 漂白鎮的六個居民（不跟棉花糖鎮的好孩子混在一起）＋和平鴿；露露他們在河對岸
const ACTORS := {
	"baimian": {"name": "白面", "species": "fox", "color": Color("#e2e2df"), "pos": Vector2(210, 418),
		"opts": {"pale": true, "no_tail": true}},
	"xiaoji": {"name": "小棘", "species": "hedgehog", "color": Color("#2f2f2f"), "pos": Vector2(410, 610),
		"opts": {"quills": 5}},
	"tiaoma": {"name": "條碼", "species": "zebra", "color": Color("#f4f4f2"), "pos": Vector2(1010, 510),
		"smile": false, "opts": {"stripes": 3}},
	"gaga": {"name": "嘎嘎", "species": "crow", "color": Color("#4a4a4a"), "pos": Vector2(320, 985),
		"smile": false, "opts": {"sewn": true}},
	"zhongzhong": {"name": "重重", "species": "hippo", "color": Color("#9c9c9c"), "pos": Vector2(350, 375),
		"smile": false, "size": 1.25, "stitched": true},
	"youyou": {"name": "鼬鼬", "species": "weasel", "color": Color("#b8b8b4"), "pos": Vector2(1130, 770),
		"opts": {"thread": true}},
	"dove": {"name": "和平鴿", "species": "dove", "color": Color.WHITE, "pos": Vector2(720, 560)},
	"lulu": {"name": "露露", "species": "rabbit", "color": Color("#f4b6c2"), "pos": Vector2(1370, 705)},
	"mochi": {"name": "麻糬", "species": "hamster", "color": Color("#fbf3e6"), "pos": Vector2(1435, 705), "smile": false},
	"popo": {"name": "波波", "species": "penguin", "color": Color("#2f3352"), "pos": Vector2(1500, 705)},
}
const RESIDENTS := ["baimian", "xiaoji", "tiaoma", "gaga", "zhongzhong", "youyou"]
const MODELS := ["lulu", "mochi", "popo"]

const OBJECTS := {
	"c2_board": {"name": "公告欄", "pos": Vector2(540, 580)},
	"treatment_door": {"name": "治療室的門", "pos": Vector2(735, 300)},
	"laundry": {"name": "洗衣房", "pos": Vector2(930, 480)},
	"tower": {"name": "廣播塔", "pos": Vector2(480, 315)},
	"station": {"name": "月台", "pos": Vector2(840, 1015)},
	"fence": {"name": "鐵絲網", "pos": Vector2(1160, 620)},
	"dining": {"name": "食堂", "pos": Vector2(200, 960)},
	"c2_bed": {"name": "鐵床", "pos": Vector2(290, 565)},
	"c2_pillow": {"name": "枕頭", "pos": Vector2(190, 560)},
}
const NIGHT_OBJECTS := ["c2_bed", "c2_pillow"]

const WORLD_BOUNDS := Rect2(20, 40, 1150, 1000)
const HOUSE_BOUNDS := Rect2(85, 490, 255, 180)
const HOME_SPOT := Vector2(230, 630)
const PLAZA_SPOT := Vector2(600, 680)

const TINTS := {
	"day": Color(1, 1, 1),
	"evening": Color(0.86, 0.86, 0.9),
	"night": Color(0.55, 0.55, 0.62),
}

var phase := "prologue"
var busy := true
var actors := {}

var town: Node2D
var player: Node2D
var hud: CanvasLayer
var board: CanvasLayer
var tint: CanvasModulate
var fade: ColorRect


func _ready() -> void:
	GameState.chapter = 2
	tint = CanvasModulate.new()
	add_child(tint)
	town = BleachTown.new()
	add_child(town)
	for id in ACTORS:
		var a := Interactable.new().setup(id, ACTORS[id])
		add_child(a)
		actors[id] = a
	for id in OBJECTS:
		var data: Dictionary = OBJECTS[id].duplicate()
		data["kind"] = "obj"
		var o := Interactable.new().setup(id, data)
		add_child(o)
		actors[id] = o
	player = Player.new()
	player.can_move = false
	add_child(player)
	for a in actors.values():
		a.target = player

	hud = Hud.new()
	add_child(hud)
	hud.title_requested.connect(_to_title)
	hud.board_requested.connect(func():
		hud.toggle_menu(false)
		await board.open())
	board = Board.new()
	add_child(board)
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 40
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade)
	var touch := TouchControls.new()
	touch.mode_provider = _touch_mode
	add_child(touch)
	Dialogue.event_requested.connect(_on_event)
	hud.set_status_visible(false)
	if GameState.checkpoint == "c2_day1_explore":
		_continue.call_deferred()
	else:
		run_chapter.call_deferred()


func _exit_tree() -> void:
	if Dialogue.event_requested.is_connected(_on_event):
		Dialogue.event_requested.disconnect(_on_event)


func _to_title() -> void:
	Dialogue.set_bg("none")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ───────────────────────── 章節流程 ─────────────────────────

func run_chapter() -> void:
	_set_phase("prologue")
	_layout("arrival")
	player.position = Vector2(700, 1030)
	await Dialogue.run("c2_prologue")
	await Dialogue.run("c2_arrival")
	await _fade_to(1.0)
	_layout("day")
	player.position = PLAZA_SPOT
	await _fade_to(0.0)
	await Dialogue.run("c2_report")
	await Dialogue.run("c2_apology")
	await _fade_to(1.0)
	player.position = Vector2(560, 700)
	hud.set_status_visible(true)
	_set_phase("day1_explore")
	GameState.save_game("c2_day1_explore")
	await _fade_to(0.0)
	busy = false
	player.can_move = true


## 從存檔繼續：第一天的自由時間
func _continue() -> void:
	Dialogue.set_bg("none")
	_set_tint("day")
	player.bounds = WORLD_BOUNDS
	player.position = Vector2(560, 700)
	_layout("day")
	hud.set_status_visible(true)
	_set_phase("day1_explore")
	busy = false
	player.can_move = true


func _after_interaction() -> void:
	match phase:
		"day1_explore":
			if _met_count() >= 2:
				await _day1_evening()
		"day1_night":
			if GameState.has("c2_sleep_1"):
				await _day1_end()


func _day1_evening() -> void:
	await _fade_to(1.0)
	_set_tint("evening")
	player.position = Vector2(1080, 640)
	await _fade_to(0.0)
	await Dialogue.run("c2_evening")
	await _fade_to(1.0)
	_set_tint("night")
	_layout("rollcall")
	player.position = Vector2(780, 720)
	await _fade_to(0.0)
	await Dialogue.run("c2_rollcall")
	await _fade_to(1.0)
	_layout("night")
	player.position = HOME_SPOT
	player.bounds = HOUSE_BOUNDS
	await _fade_to(0.0)
	await Dialogue.run("c2_night_intro")
	_set_phase("day1_night")


func _day1_end() -> void:
	_set_phase("ended")
	await _fade_to(1.0)
	await Dialogue.run("c2_dream_1")
	var card := EndCard.new()
	card.mode = "c2_day1"
	add_child(card)


# ───────────────────────── 互動 ─────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		hud.show_debug = not hud.show_debug
		hud.refresh()
	if busy or Dialogue.running or board.visible:
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		hud.toggle_menu(false)
		player.can_move = not hud.menu_open
		return
	if hud.menu_open:
		return
	if event.is_action_pressed("interact"):
		var it: Interactable = player.nearest()
		if it:
			get_viewport().set_input_as_handled()
			interact(it.id)


func interact(id: String) -> void:
	if busy:
		return
	busy = true
	player.can_move = false
	hud.set_prompt("")
	if id == "c2_board":
		await board.open()
	else:
		await Dialogue.run(_talk_label(id))
	actors[id].queue_redraw()
	await _after_interaction()
	if phase != "ended":
		busy = false
		player.can_move = true
		_refresh_objective()


func _talk_label(id: String) -> String:
	var base := id if id.begins_with("c2_") else "c2_" + id
	for c in ["%s_%s" % [base, phase], "%s_d%d" % [base, GameState.day], base]:
		if Dialogue.has_label(c):
			return c
	return "nothing"


func _process(_delta: float) -> void:
	if busy or Dialogue.running or hud.menu_open or board.visible:
		hud.set_prompt("")
		return
	var it: Interactable = player.nearest()
	var key := "互動" if DisplayServer.is_touchscreen_available() else "E"
	hud.set_prompt("%s：%s" % [key, it.display_name] if it else "")


func _touch_mode() -> String:
	if hud.menu_open:
		return "menu"
	if busy or Dialogue.running or board.visible or not phase in EXPLORE_PHASES:
		return ""
	return "explore"


## 對話腳本中的 @event
func _on_event(event_name: String) -> void:
	await get_tree().process_frame
	match event_name:
		"board":
			await board.open()
		"report_card":
			await board.open_report()
		"apology":
			var game := Apology.new()
			add_child(game)
			await game.play()
		"roll_list":
			var r := RollList.new()
			add_child(r)
			await r.show_and_wait()
		"c2_take_models":
			for id in MODELS:
				actors[id].visible = false
		"c2_dove_appears":
			var dove: Interactable = actors.dove
			dove.visible = true
			dove.position = Vector2(770, 960)
		"c2_fence_lineup":
			# 隔著鐵絲網排隊；對岸的模範生站在陽台上揮手
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = Vector2(1120 - (k % 2) * 40, 470 + k * 50)
				actors[RESIDENTS[k]].visible = true
			for id in MODELS:
				actors[id].position = ACTORS[id].pos
				actors[id].visible = true
			actors.dove.visible = false
	Dialogue.event_done.emit()


# ───────────────────────── 場景配置 ─────────────────────────

func _layout(mode: String) -> void:
	for id in ACTORS:
		var a: Interactable = actors[id]
		a.position = ACTORS[id].pos
		a.visible = not id in MODELS
	for id in OBJECTS:
		actors[id].visible = not id in NIGHT_OBJECTS
	match mode:
		"arrival":
			# 月台：模範生在左邊，漂白鎮的六個居民在右邊排成一排
			for k in MODELS.size():
				actors[MODELS[k]].position = Vector2(560 + k * 45, 1010)
				actors[MODELS[k]].visible = true
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = Vector2(810 + k * 52, 1020 - (k % 2) * 12)
			actors.dove.visible = false
		"rollcall":
			# 點名：所有人在廣場排成一排，第 8 個位置空著
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = Vector2(500 + k * 46, 720)
			actors.dove.position = Vector2(700, 560)
		"night":
			for id in ACTORS:
				actors[id].visible = false
			for id in OBJECTS:
				actors[id].visible = id in NIGHT_OBJECTS


func _set_phase(p: String) -> void:
	phase = p
	_refresh_objective()


func _refresh_objective() -> void:
	match phase:
		"day1_explore":
			GameState.set_objective("自由時間。認識漂白鎮的孩子們（%d / 2）" % mini(_met_count(), 2))
		"day1_night":
			GameState.set_objective("熄燈了。可以看看床邊，或上床睡覺。")
		_:
			GameState.set_objective("")


func _met_count() -> int:
	return RESIDENTS.filter(func(r): return GameState.has("met_" + r)).size()


func _set_tint(name: String) -> void:
	tint.color = TINTS[name]


func _fade_to(alpha: float) -> void:
	if GameState.fast:
		fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, 0.6)
	await tw.finished
