extends Node2D
## 第一章原型的流程導演：章節進行、場景配置、互動分派。
##
## 互動時依序尋找對話標籤：<id>_<phase> → <phase 預設> → <id>_d<day> → <id>
## 劇情邏輯盡量寫在 dialogue/chapter1.txt，這裡只處理「世界」的變化。

const Town := preload("res://scripts/world/town.gd")
const Player := preload("res://scripts/world/player.gd")
const Board := preload("res://scripts/ui/board.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const CandyCatch := preload("res://scripts/minigames/candy_catch.gd")
const MirrorStare := preload("res://scripts/minigames/mirror_stare.gd")
const Summary := preload("res://scripts/ui/summary.gd")
const EndCard := preload("res://scripts/ui/end_card.gd")
const EndingCard := preload("res://scripts/ui/ending_card.gd")
const Intro := preload("res://scripts/ui/intro.gd")
const Title := preload("res://scripts/ui/title.gd")
const BreadKnead := preload("res://scripts/minigames/bread_knead.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")

const EXPLORE_PHASES := ["day1_explore", "day1_night", "day2_explore", "day2_evening", "night_out", "day3_explore", "day3_home", "forest"]
const Forest := preload("res://scripts/world/forest.gd")
const RepairScene := preload("res://scripts/ui/repair_scene.gd")

## 位置都是世界座標＝地圖原圖座標 × 1.5（見 town.gd 的 at()）
const ACTORS := {
	"lulu": {"name": "露露", "species": "rabbit", "color": Color("#f4b6c2"), "pos": Vector2(435, 575)},
	"popo": {"name": "波波", "species": "penguin", "color": Color("#2f3352"), "pos": Vector2(1290, 935)},
	"fen": {"name": "Fen", "species": "fox", "color": Color("#c8642b"), "pos": Vector2(1815, 1000), "smile": false, "stitched": true},
	"mayor": {"name": "熊熊鎮長", "species": "bear", "color": Color("#c4894f"), "pos": Vector2(1050, 905), "size": 1.6},
	"mochi": {"name": "麻糬", "species": "hamster", "color": Color("#fbf3e6"), "pos": Vector2(230, 1290)},
	"tama": {"name": "小玉", "species": "calico", "color": Color("#fbf1df"), "pos": Vector2(645, 1330)},
	"extra1": {"name": "居民", "species": "puppy", "color": Color("#e6ccb2"), "pos": Vector2(-500, -500)},
	"extra2": {"name": "居民", "species": "cat", "color": Color("#d8e2dc"), "pos": Vector2(-500, -500)},
	"extra3": {"name": "居民", "species": "puppy", "color": Color("#e2ece9"), "pos": Vector2(-500, -500)},
}

const OBJECTS := {
	"board": {"name": "公告欄", "pos": Vector2(915, 860)},
	"bakery_photo": {"name": "櫥窗裡的照片", "pos": Vector2(510, 525)},
	"mail_sack": {"name": "郵袋", "pos": Vector2(1500, 900)},
	"mayor_door": {"name": "鎮長公館的門", "pos": Vector2(1107, 590)},
	"repair_room": {"name": "修理室", "pos": Vector2(1218, 300)},
	"mirror_house": {"name": "鏡之屋", "pos": Vector2(1647, 495)},
	"clocktower": {"name": "鐘塔大門", "pos": Vector2(867, 395)},
	"forest": {"name": "森林小徑", "pos": Vector2(1470, 140)},
	"station": {"name": "火車站", "pos": Vector2(1017, 1575)},
	"home_door": {"name": "小布的家", "pos": Vector2(285, 850)},
	# ── 支線物件：只在條件成立、而且還沒撿走時出現（"when"＝旗標條件）
	"lulu_mailbox": {"name": "露露家的信箱", "pos": Vector2(390, 545), "when": "q_letters"},
	"candy_1": {"name": "糖果", "pos": Vector2(1150, 1600), "when": "q_tama"},
	"candy_2": {"name": "糖果", "pos": Vector2(1560, 985), "when": "q_tama"},
	"candy_3": {"name": "糖果", "pos": Vector2(180, 570), "when": "q_tama"},
	"note_1": {"name": "一張紙", "pos": Vector2(750, 380), "when": "q_notes"},
	"note_2": {"name": "一張紙", "pos": Vector2(1320, 1590), "when": "q_notes"},
	"note_3": {"name": "一張紙", "pos": Vector2(1350, 260), "when": "q_notes"},
	# 散落在鎮上的棉花：每一團是一段記憶碎片，撿過的會跨輪保留（下一輪不再出現）
	"tuft_0": {"name": "一小團棉花", "pos": Vector2(90, 960)},
	"tuft_1": {"name": "一小團棉花", "pos": Vector2(705, 140)},
	"tuft_2": {"name": "一小團棉花", "pos": Vector2(1680, 630)},
	"tuft_3": {"name": "一小團棉花", "pos": Vector2(1470, 1290)},
	"tuft_4": {"name": "一小團棉花", "pos": Vector2(60, 1575)},
	"tuft_5": {"name": "一小團棉花", "pos": Vector2(1140, 1050)},
	"tuft_6": {"name": "一小團棉花", "pos": Vector2(495, 930)},
	"tuft_7": {"name": "一小團棉花", "pos": Vector2(1050, 705)},
	"tuft_8": {"name": "一小團棉花", "pos": Vector2(1828, 990)},
	"tuft_9": {"name": "一小團棉花", "pos": Vector2(705, 1590)},
	# 小布的房間（地圖右邊，見 town.gd 的 ROOM）
	"mirror": {"name": "鏡子", "pos": Vector2(2440, 360)},
	"bed": {"name": "床", "pos": Vector2(2600, 380)},
	"home_exit": {"name": "出門", "pos": Vector2(3040, 345)},
	# 森林（第三天）
	"forest_sheep": {"name": "小綿羊", "pos": Vector2(800, 320)},
	"forest_bow": {"name": "長耳朵", "pos": Vector2(640, 380)},
	"forest_tags": {"name": "一堆名牌", "pos": Vector2(960, 380)},
	"forest_tail": {"name": "狐狸尾巴", "pos": Vector2(880, 470)},
}

const FOREST_ITEMS := ["found_sheep", "found_lulu_bow", "seen_tags", "found_fox_tail"]
const FOREST_BOUNDS := Rect2(560, 180, 480, 900)

## 第一天要拜訪的地點（至少 2 個才會進入傍晚）
const DAY1_PLACES := ["lulu", "popo", "fen", "mayor_door", "repair_room", "mirror_house", "clocktower"]
const DAY1_NEEDED := 4
const PHASE_DEFAULT := {"day1_night": "late", "night_out": "night_resident"}
const HOUSE_BOUNDS := Town.ROOM_BOUNDS
const HOME_SPOT := Vector2(2720, 470)
const WORLD_BOUNDS := Town.WORLD_BOUNDS
## 走出家門時站的位置（門口）
const OUTSIDE_HOME := Vector2(285, 880)
const STATION_SPOT := Vector2(1017, 1625)

const TINTS := {
	"day": Color(1, 1, 1),
	"sunset": Color(1.0, 0.86, 0.85),
	"evening": Color(0.82, 0.78, 0.92),
	"night": Color(0.5, 0.47, 0.62),
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
var forest: Node2D
var repair_scene: CanvasLayer


func _ready() -> void:
	# 越下面的角色畫在越前面
	y_sort_enabled = true
	tint = CanvasModulate.new()
	add_child(tint)
	town = Town.new()
	add_child(town)
	forest = Forest.new()
	forest.visible = false
	add_child(forest)
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
	hud.tag_toggle_requested.connect(_on_tag_toggle)
	hud.title_requested.connect(func():
		Dialogue.set_bg("none")
		get_tree().reload_current_scene())
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
	if GameState.fast:
		# 自動測試：跳過標題畫面
		if GameState.resume_on_start:
			_continue.call_deferred()
		else:
			GameState.reset()
			run_chapter.call_deferred()
	elif GameState.pending_loop_start:
		# 結局之後：直接搭上下一班火車
		GameState.pending_loop_start = false
		run_chapter.call_deferred()
	else:
		_show_title.call_deferred()


func _show_title() -> void:
	# 開場 Logo 影片：每次開啟遊戲只播一次（回到標題時不再播）
	if not GameState.intro_played:
		GameState.intro_played = true
		var intro := Intro.new()
		add_child(intro)
		await intro.done
	var title := Title.new()
	add_child(title)
	title.new_game.connect(func():
		title.queue_free()
		GameState.reset()
		GameState.meta.runs = int(GameState.meta.get("runs", 0)) + 1
		GameState.save_meta()
		run_chapter())
	title.continue_game.connect(func():
		title.queue_free()
		_continue())


## 從存檔繼續：每個檢查點都是某一天的早上
func _continue() -> void:
	if not GameState.load_game():
		GameState.reset()
		run_chapter()
		return
	var cp := GameState.checkpoint
	Dialogue.set_bg("none")
	town.clock_stopped = GameState.day >= 2
	town.queue_redraw()
	_set_tint("day")
	if cp == "day1_explore":
		player.bounds = WORLD_BOUNDS
		player.position = Vector2(915, 960)
	else:
		_place_home()
	_layout("day")
	hud.set_status_visible(true)
	_set_phase(cp)
	busy = false
	player.can_move = true


# ───────────────────────── 章節流程 ─────────────────────────

func run_chapter() -> void:
	_set_phase("prologue")
	hud.set_status_visible(false)
	_layout("arrival")
	player.position = STATION_SPOT
	player.face(Vector2.UP)
	Sound.bgm("day")
	await Dialogue.run("prologue")
	await Dialogue.run("arrival")
	_layout("day")
	hud.set_status_visible(true)
	_set_phase("day1_explore")
	GameState.save_game("day1_explore")
	busy = false
	player.can_move = true


func _after_interaction() -> void:
	match phase:
		"day1_explore":
			if _visited_count() >= DAY1_NEEDED:
				await _day1_evening()
		"day1_night":
			if GameState.has("sleep_1"):
				await _day2_morning()
		"day2_explore":
			if GameState.has("bread_done") and GameState.has("letter_done") and not GameState.has("fen_invited"):
				var fen: Interactable = actors.fen
				var home := fen.position
				fen.position = player.position + Vector2(90, -40)
				await Dialogue.run("fen_invite")
				fen.position = home
				_set_phase("day2_evening")
		"day2_evening":
			if GameState.has("end_early"):
				await _ending_scene("early_repair", "early")
			elif GameState.has("night_out"):
				await _night_out()
			elif GameState.has("fen_disappointed"):
				await _day3_morning()
		"night_out":
			if GameState.has("saw_resident") and not GameState.has("met_night_fen"):
				var fen: Interactable = actors.fen
				fen.position = player.position + Vector2(-70, 20)
				fen.visible = true
				await Dialogue.run("night_fen")
				await _day3_morning()
		"day3_explore":
			if GameState.has("end_zero"):
				await _end_loop("zero")
			elif GameState.has("end_mochi"):
				await _end_loop("mochi")
			elif GameState.has("go_forest"):
				await _forest()
			elif GameState.has("refuse_forest"):
				_set_phase("day3_home")
		"day3_home":
			if GameState.has("sleep_3"):
				await _ending_scene("good_kid_end", "good_kid")
		"forest":
			if GameState.has("found_sheep") and _forest_count() >= 3 and not GameState.has("heard_47"):
				await _forest_climax()


func _day1_evening() -> void:
	await _fade_to(1.0)
	_set_tint("sunset")
	player.position = Vector2(450, 640)
	actors.lulu.position = Vector2(525, 630)
	player.face(Vector2.RIGHT)
	actors.lulu.face_toward(player.position)
	await _fade_to(0.0)
	await Dialogue.run("day1_evening")
	await _fade_to(1.0)
	_layout("day")
	_set_tint("evening")
	player.position = HOME_SPOT
	player.bounds = HOUSE_BOUNDS
	await _fade_to(0.0)
	_set_phase("day1_night")


func _day2_morning() -> void:
	await _fade_to(1.0)
	await Dialogue.run("dream_1")
	GameState.new_day()
	town.clock_stopped = true
	town.queue_redraw()
	_set_tint("day")
	_place_home()
	_layout("day")
	Dialogue.set_bg("none")
	await _fade_to(0.0)
	Sound.sfx("strange")
	await Dialogue.run("day2_morning")
	_set_phase("day2_explore")
	GameState.save_game("day2_explore")


func _night_out() -> void:
	await _fade_to(1.0)
	_layout("night")
	_set_tint("night")
	player.bounds = WORLD_BOUNDS
	player.position = OUTSIDE_HOME
	await _fade_to(0.0)
	Sound.sfx("strange")
	await Dialogue.run("night_intro")
	_set_phase("night_out")


func _day3_morning() -> void:
	await _fade_to(1.0)
	await Dialogue.run("dream_2")
	GameState.new_day()
	_set_tint("day")
	_place_home()
	_layout("day")
	Dialogue.set_bg("none")
	await _fade_to(0.0)
	await Dialogue.run("day3_morning")
	_set_phase("day3_explore")
	GameState.save_game("day3_explore")


func _forest() -> void:
	await _fade_to(1.0)
	town.visible = false
	forest.visible = true
	for id in actors:
		actors[id].visible = id.begins_with("forest_")
	actors.fen.visible = true
	actors.fen.position = Vector2(860, 1000)
	player.position = Vector2(800, 1030)
	player.bounds = FOREST_BOUNDS
	_set_phase("forest")
	Sound.bgm("night")
	await _fade_to(0.0)
	await Dialogue.run("forest_enter")


## 本章高潮：47、下午三點的鐘聲、Fen 被帶走、修理
func _forest_climax() -> void:
	var fen: Interactable = actors.fen
	fen.position = player.position + Vector2(50, 10)
	Sound.sfx("strange")
	Sound.bgm("memory")
	await Dialogue.run("forest_truth")
	GameState.set_flag("bell_heard")
	await Dialogue.run("bell_three")
	if GameState.has("lulu_hesitated"):
		# 露露沒有說出你在哪裡：被帶走的是她
		await _fade_to(1.0)
		await _end_loop("hesitate")
		return
	await _fade_to(1.0)
	forest.visible = false
	for a in actors.values():
		a.visible = false
	repair_scene = RepairScene.new()
	add_child(repair_scene)
	hud.set_status_visible(false)
	tint.color = TINTS.day
	await _fade_to(0.0)
	await Dialogue.run("repair")
	await _end_loop("brave" if GameState.has("brave_end") else "betrayed")


## 只放一段結局對話（沒有修理室畫面）的結局
func _ending_scene(label: String, ending: String) -> void:
	busy = true
	player.can_move = false
	await Dialogue.run(label)
	await _end_loop(ending)


## 一輪結束。「第零條」結束本章；其他結局回到火車上，開始下一輪。
func _end_loop(ending: String) -> void:
	busy = true
	player.can_move = false
	_set_phase("ended")
	hud.set_status_visible(false)
	GameState.finish_loop(ending)
	await _fade_to(1.0)
	Dialogue.set_bg("none")
	if repair_scene:
		repair_scene.queue_free()
		repair_scene = null
	if ending == "zero":
		Sound.bgm("memory")
		var s := Summary.new()
		add_child(s)
		fade.color.a = 0.0
		await s.show_and_wait()
		s.queue_free()
		GameState.set_flag("chapter_done")
		add_child(EndCard.new())
		return
	Sound.bgm("memory")
	var card := EndingCard.new()
	card.ending = ending
	add_child(card)
	fade.color.a = 0.0
	GameState.set_flag("loop_done")
	if GameState.fast:
		return
	var go_on: bool = await card.chosen
	GameState.start_next_loop()
	if not go_on:
		GameState.pending_loop_start = false
	Dialogue.set_bg("none")
	get_tree().reload_current_scene()


# ───────────────────────── 互動 ─────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		hud.show_debug = not hud.show_debug
		hud.refresh()
	if busy or Dialogue.running or board.visible:
		return
	if event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		hud.toggle_menu(GameState.day >= 2 and phase in ["day2_explore", "day2_evening", "day3_explore"])
		player.can_move = not hud.menu_open
		return
	if hud.menu_open:
		return
	if event.is_action_pressed("interact"):
		var it: Interactable = player.nearest()
		if it:
			get_viewport().set_input_as_handled()
			interact(it.id)


func _place_home() -> void:
	player.bounds = HOUSE_BOUNDS
	player.position = HOME_SPOT
	player.face(Vector2.DOWN)


func _place_outside() -> void:
	player.bounds = WORLD_BOUNDS
	player.position = OUTSIDE_HOME
	player.face(Vector2.DOWN)


## 小布家的門：進出房間（第一天晚上不能出門）
func _use_door(id: String) -> void:
	Sound.sfx("door")
	await _fade_to(1.0)
	if id == "home_door":
		_place_home()
	else:
		_place_outside()
	await _fade_to(0.0)


func interact(id: String) -> void:
	if busy:
		return
	busy = true
	player.can_move = false
	hud.set_prompt("")
	var it: Interactable = actors[id]
	if it.kind == "npc":
		it.face_toward(player.position)
		player.face(it.position - player.position)
	if id in ["home_door", "home_exit"] and phase != "day1_night":
		await _use_door(id)
	elif id == "board":
		Sound.sfx("menu")
		await board.open()
	elif id.begins_with("tuft_"):
		Sound.sfx("strange")
		GameState.collect_tuft(id)
		await Dialogue.run(id)
	else:
		Sound.sfx("interact")
		await Dialogue.run(_talk_label(id))
	await _after_interaction()
	_refresh_objects()
	if phase != "ended":
		busy = false
		player.can_move = true
		_refresh_objective()


func _talk_label(id: String) -> String:
	var candidates := ["%s_%s" % [id, phase]]
	if PHASE_DEFAULT.has(phase) and actors[id].kind == "npc":
		candidates.append(PHASE_DEFAULT[phase])
	elif phase == "day1_night":
		candidates.append("late")
	candidates.append_array(["%s_d%d" % [id, GameState.day], id])
	for c in candidates:
		if Dialogue.has_label(c):
			return c
	return "nothing"


func _process(_delta: float) -> void:
	if phase == "forest":
		# 越往森林深處，顏色就越淡
		var t := clampf((1030.0 - player.position.y) / 650.0, 0.0, 1.0)
		tint.color = Color(0.85, 0.85, 0.9).lerp(Color(0.6, 0.6, 0.64), t)
		if not busy:
			var fen: Interactable = actors.fen
			fen.position = fen.position.lerp(player.position + Vector2(55, 25), 0.04)
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


func _on_tag_toggle() -> void:
	hud.toggle_menu(false)
	busy = true
	player.can_move = false
	if GameState.has("tag_on"):
		if GameState.spend_courage(1):
			GameState.set_flag("tag_on", false)
			GameState.set_flag("tag_off")
			GameState.add_suspicion(10)
			await Dialogue.run("tag_off")
	else:
		GameState.set_flag("tag_on", true)
		await Dialogue.run("tag_on")
	busy = false
	player.can_move = true


## 對話腳本中的 @event
func _on_event(event_name: String) -> void:
	await get_tree().process_frame
	match event_name:
		"candy":
			var game := CandyCatch.new()
			add_child(game)
			var score: int = await game.play()
			GameState.set_flag("candy_good", score >= 15)
		"board":
			await board.open()
		"bread":
			var bread := BreadKnead.new()
			add_child(bread)
			Sound.duck(true)
			await bread.play()
			Sound.duck(false)
		"mirror_stare":
			var m := MirrorStare.new()
			add_child(m)
			await m.play()
		"to_plaza":
			player.position = Vector2(885, 935)
			actors.mayor.position = Vector2(985, 905)
			player.face(Vector2.RIGHT)
			actors.mayor.face_toward(player.position)
		"mayor_appears":
			actors.mayor.visible = true
			actors.mayor.position = Vector2(800, 1060)
			tint.color = TINTS.day
		"fen_taken":
			actors.fen.visible = false
		"lulu_appears":
			actors.mayor.visible = false
			actors.lulu.visible = true
			actors.lulu.position = player.position + Vector2(60, 30)
		"mayor_shadow":
			actors.mayor.visible = true
			actors.mayor.position = player.position + Vector2(-20, 70)
		"sew":
			await repair_scene.sew()
		"good_kid_station":
			# 第四天：你站在歡迎的人群裡，看著新的小布下車
			_layout("arrival")
			_set_tint("day")
			player.bounds = WORLD_BOUNDS
			player.position = STATION_SPOT + Vector2(-20, -70)
			player.face(Vector2.DOWN)
			var newbie: Interactable = actors.extra1
			newbie.species = "sheep"
			newbie.display_name = "新來的小布"
			newbie.position = STATION_SPOT + Vector2(0, 10)
			newbie.facing = Vector2.UP
			newbie.visible = true
			newbie.queue_redraw()
		"ch2_arrival":
			# 第二章：Fen 回來了。縫線整整齊齊的，在笑。
			_layout("arrival")
			player.position = STATION_SPOT
			var fen: Interactable = actors.fen
			fen.visible = true
			fen.smile = true
			fen.stitched = false
			fen.position = STATION_SPOT + Vector2(95, -15)
			fen.face_toward(player.position)
			actors.mayor.position = STATION_SPOT + Vector2(-170, -20)
	Dialogue.event_done.emit()


# ───────────────────────── 場景配置 ─────────────────────────

func _layout(mode: String) -> void:
	for id in ACTORS:
		var a: Interactable = actors[id]
		a.position = ACTORS[id].pos
		a.visible = not id.begins_with("extra")
		a.follow_eyes = false
		a.facing = Vector2.DOWN
	for id in OBJECTS:
		actors[id].visible = not id.begins_with("forest_")
	match mode:
		"arrival":
			# 火車站前：大家圍著剛下車的小布
			var spots := [Vector2(-190, 5), Vector2(-105, -25), Vector2(105, -25), Vector2(190, 5), Vector2(-300, -15)]
			var who := ["lulu", "popo", "mochi", "tama", "mayor"]
			for k in who.size():
				actors[who[k]].position = STATION_SPOT + spots[k]
				actors[who[k]].visible = true
				actors[who[k]].face_toward(STATION_SPOT)
			actors.fen.visible = false
		"day":
			actors.mayor.visible = GameState.day >= 2
			# 想起名字的麻糬，第三天已經被帶去修理了
			actors.mochi.visible = not (GameState.day >= 3 and GameState.has("mochi_remembers"))
		"night":
			# 夜晚：居民們站在廣場，面朝鐘塔。一動也不動。鈕扣眼睛跟著小布轉。
			var who := ["lulu", "popo", "mochi", "tama"]
			for k in who.size():
				var a: Interactable = actors[who[k]]
				a.position = Vector2(800 + k * 75, 960 + (k % 2) * 40)
				a.visible = true
				a.facing = Vector2.UP
				a.follow_eyes = true
			actors.mayor.visible = false
			actors.fen.visible = false
	_refresh_objects()
	actors.mirror.covered = not GameState.has("mirror_open")
	actors.mirror.queue_redraw()


## 支線物件與棉花：條件成立、還沒撿走才出現
func _refresh_objects() -> void:
	if forest.visible:
		return
	for id in OBJECTS:
		var data: Dictionary = OBJECTS[id]
		if id.begins_with("tuft_"):
			actors[id].visible = not GameState.has_tuft(id)
		elif data.has("when"):
			actors[id].visible = GameState.check(data.when) and not GameState.has(id + "_got")


func _set_phase(p: String) -> void:
	phase = p
	_refresh_objective()


func _refresh_objective() -> void:
	match phase:
		"day1_explore":
			GameState.set_objective("逛逛小鎮，認識大家（%d / %d）" % [mini(_visited_count(), DAY1_NEEDED), DAY1_NEEDED])
		"day1_night":
			GameState.set_objective("回家了。可以看看房間，或上床睡覺。")
		"day2_explore":
			var left := []
			if not GameState.has("bread_done"):
				left.append("幫露露做麵包")
			if not GameState.has("letter_done"):
				if GameState.has("q_letters"):
					var n := int(GameState.flags.get("letters", 0))
					left.append("幫波波送信（%d / 3）" % n if n < 3 else "回郵局找波波")
				else:
					left.append("幫波波的忙")
			GameState.set_objective("、".join(left))
		"day2_evening":
			GameState.set_objective("八點鐘聲響起前，回家上床。")
		"night_out":
			GameState.set_objective("……廣場那邊，好像有人。")
		"day3_explore":
			if GameState.has("got_key"):
				GameState.set_objective("下午三點以前，用鑰匙打開鐘塔。")
			elif GameState.has("lulu_d3_done"):
				GameState.set_objective("去樹屋找 Fen。")
			else:
				GameState.set_objective("去露露家看看。")
		"day3_home":
			GameState.set_objective("八點以前回家，上床睡覺。")
		"forest":
			GameState.set_objective("調查森林深處的東西（%d / 3）" % mini(_forest_count(), 3))
		_:
			GameState.set_objective("")


func _forest_count() -> int:
	return FOREST_ITEMS.filter(func(f): return GameState.has(f)).size()


func _visited_count() -> int:
	return DAY1_PLACES.filter(func(p): return GameState.has("visited_" + p)).size()


func _set_tint(name: String) -> void:
	tint.color = TINTS[name]
	Sound.bgm("day" if name in ["day", "sunset"] else "night")


func _fade_to(alpha: float) -> void:
	if GameState.fast:
		fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, 0.6)
	await tw.finished
