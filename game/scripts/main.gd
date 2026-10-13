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
const Title := preload("res://scripts/ui/title.gd")
const BreadKnead := preload("res://scripts/minigames/bread_knead.gd")
const Forest := preload("res://scripts/world/forest.gd")
const RepairScene := preload("res://scripts/ui/repair_scene.gd")

const ACTORS := {
	"lulu": {"name": "露露", "species": "rabbit", "color": Color("#f4b6c2"), "pos": Vector2(390, 420)},
	"popo": {"name": "波波", "species": "penguin", "color": Color("#2f3352"), "pos": Vector2(960, 700)},
	"fen": {"name": "Fen", "species": "fox", "color": Color("#c8642b"), "pos": Vector2(1400, 740), "smile": false, "stitched": true},
	"mayor": {"name": "熊熊鎮長", "species": "bear", "color": Color("#c4894f"), "pos": Vector2(740, 600), "size": 1.9},
	"mochi": {"name": "麻糬", "species": "hamster", "color": Color("#fbf3e6"), "pos": Vector2(230, 940)},
	"tama": {"name": "小玉", "species": "calico", "color": Color("#fbf1df"), "pos": Vector2(400, 960)},
	"extra1": {"name": "居民", "species": "puppy", "color": Color("#e6ccb2"), "pos": Vector2(-500, -500)},
	"extra2": {"name": "居民", "species": "cat", "color": Color("#d8e2dc"), "pos": Vector2(-500, -500)},
	"extra3": {"name": "居民", "species": "puppy", "color": Color("#e2ece9"), "pos": Vector2(-500, -500)},
}

const OBJECTS := {
	"board": {"name": "公告欄", "pos": Vector2(580, 580)},
	"bakery_photo": {"name": "櫥窗裡的照片", "pos": Vector2(470, 410)},
	"mail_sack": {"name": "郵袋", "pos": Vector2(1040, 700)},
	"mayor_door": {"name": "鎮長公館的門", "pos": Vector2(870, 430)},
	"repair_room": {"name": "修理室", "pos": Vector2(1070, 250)},
	"mirror_house": {"name": "鏡之屋", "pos": Vector2(1090, 485)},
	"clocktower": {"name": "鐘塔大門", "pos": Vector2(700, 360)},
	"forest": {"name": "森林小徑", "pos": Vector2(1260, 285)},
	"station": {"name": "火車站", "pos": Vector2(760, 1020)},
	"mirror": {"name": "鏡子", "pos": Vector2(120, 550)},
	"bed": {"name": "床", "pos": Vector2(290, 550)},
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
const PHASE_DEFAULT := {"day1_night": "late", "night_out": "night_resident"}
const HOUSE_BOUNDS := Rect2(85, 490, 255, 180)
const HOME_SPOT := Vector2(220, 630)
const WORLD_BOUNDS := Rect2(20, 40, 1560, 1000)

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

	Dialogue.event_requested.connect(_on_event)
	hud.set_status_visible(false)
	if GameState.fast:
		# 自動測試：跳過標題畫面
		if GameState.resume_on_start:
			_continue.call_deferred()
		else:
			GameState.reset()
			run_chapter.call_deferred()
	else:
		_show_title.call_deferred()


func _show_title() -> void:
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
	player.bounds = WORLD_BOUNDS
	player.position = Vector2(640, 700) if cp == "day1_explore" else HOME_SPOT
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
	player.position = Vector2(700, 1030)
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
			if _visited_count() >= 2:
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
			if GameState.has("night_out"):
				await _night_out()
			elif GameState.has("fen_disappointed"):
				await _day3_morning()
		"night_out":
			if GameState.has("saw_resident") and not GameState.has("fen_trust"):
				var fen: Interactable = actors.fen
				fen.position = player.position + Vector2(-70, 20)
				fen.visible = true
				await Dialogue.run("night_fen")
				await _day3_morning()
		"day3_explore":
			if GameState.has("go_forest"):
				await _forest()
		"forest":
			if GameState.has("found_sheep") and _forest_count() >= 3 and not GameState.has("heard_47"):
				await _forest_climax()


func _day1_evening() -> void:
	await _fade_to(1.0)
	_set_tint("sunset")
	player.position = Vector2(470, 580)
	actors.lulu.position = Vector2(530, 560)
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
	player.bounds = WORLD_BOUNDS
	player.position = HOME_SPOT
	_layout("day")
	Dialogue.set_bg("none")
	await _fade_to(0.0)
	await Dialogue.run("day2_morning")
	_set_phase("day2_explore")
	GameState.save_game("day2_explore")


func _night_out() -> void:
	await _fade_to(1.0)
	_layout("night")
	_set_tint("night")
	player.position = Vector2(400, 600)
	await _fade_to(0.0)
	await Dialogue.run("night_intro")
	_set_phase("night_out")


func _day3_morning() -> void:
	await _fade_to(1.0)
	await Dialogue.run("dream_2")
	GameState.new_day()
	_set_tint("day")
	player.bounds = WORLD_BOUNDS
	player.position = HOME_SPOT
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
	await _fade_to(0.0)
	await Dialogue.run("forest_enter")


## 本章高潮：47、下午三點的鐘聲、Fen 被帶走、修理
func _forest_climax() -> void:
	var fen: Interactable = actors.fen
	fen.position = player.position + Vector2(50, 10)
	await Dialogue.run("forest_truth")
	await Dialogue.run("bell_three")
	await _fade_to(1.0)
	forest.visible = false
	for a in actors.values():
		a.visible = false
	repair_scene = RepairScene.new()
	add_child(repair_scene)
	hud.set_status_visible(false)
	_set_tint("day")
	await _fade_to(0.0)
	await Dialogue.run("repair")
	await _chapter_end()


func _chapter_end() -> void:
	_set_phase("ended")
	GameState.set_flag("ticket_stamps", 2)
	# 跨周目記錄：標題畫面的車票會多一個戳章
	GameState.meta.chapters_done = maxi(int(GameState.meta.get("chapters_done", 0)), 1)
	GameState.save_meta()
	GameState.delete_save()
	var s := Summary.new()
	add_child(s)
	Dialogue.set_bg("none")
	await s.show_and_wait()
	# 第二章自動開場：不給玩家按鍵，直接接下去
	s.queue_free()
	repair_scene.queue_free()
	GameState.set_flag("chapter2")
	town.visible = true
	player.bounds = WORLD_BOUNDS
	await Dialogue.run("ch2_opening")
	add_child(EndCard.new())


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


func interact(id: String) -> void:
	if busy:
		return
	busy = true
	player.can_move = false
	hud.set_prompt("")
	if id == "board":
		await board.open()
	else:
		await Dialogue.run(_talk_label(id))
	await _after_interaction()
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
	hud.set_prompt("E：%s" % it.display_name if it else "")


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
			await bread.play()
		"mirror_stare":
			var m := MirrorStare.new()
			add_child(m)
			await m.play()
		"to_plaza":
			player.position = Vector2(560, 660)
			actors.mayor.position = Vector2(660, 620)
		"mayor_appears":
			actors.mayor.visible = true
			actors.mayor.position = Vector2(800, 1060)
			_set_tint("day")
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
		"ch2_arrival":
			# 第二章：Fen 回來了。縫線整整齊齊的，在笑。
			_layout("arrival")
			player.position = Vector2(700, 1030)
			var fen: Interactable = actors.fen
			fen.visible = true
			fen.smile = true
			fen.stitched = false
			fen.position = Vector2(700, 975)
			fen.queue_redraw()
			actors.mayor.position = Vector2(640, 945)
	Dialogue.event_done.emit()


# ───────────────────────── 場景配置 ─────────────────────────

func _layout(mode: String) -> void:
	for id in ACTORS:
		var a: Interactable = actors[id]
		a.position = ACTORS[id].pos
		a.visible = not id.begins_with("extra")
		a.follow_eyes = false
	for id in OBJECTS:
		actors[id].visible = not id.begins_with("forest_")
	match mode:
		"arrival":
			var spots := [Vector2(580, 1010), Vector2(630, 990), Vector2(800, 990), Vector2(850, 1010),
				Vector2(540, 1030), Vector2(890, 1030), Vector2(720, 975)]
			var who := ["lulu", "popo", "mochi", "tama", "extra1", "extra2", "mayor"]
			for k in who.size():
				actors[who[k]].position = spots[k]
				actors[who[k]].visible = true
			actors.fen.visible = false
		"day":
			actors.mayor.visible = GameState.day >= 2
		"night":
			# 夜晚：居民們站在廣場，面朝鐘塔。一動也不動。鈕扣眼睛跟著小布轉。
			var who := ["lulu", "popo", "mochi", "tama", "extra1", "extra2", "extra3"]
			for k in who.size():
				var a: Interactable = actors[who[k]]
				a.position = Vector2(545 + k * 40, 432 + (k % 2) * 38)
				a.visible = true
				a.follow_eyes = true
			actors.mayor.visible = false
			actors.fen.visible = false
	actors.mirror.covered = not GameState.has("mirror_open")
	actors.mirror.queue_redraw()


func _set_phase(p: String) -> void:
	phase = p
	_refresh_objective()


func _refresh_objective() -> void:
	match phase:
		"day1_explore":
			GameState.set_objective("逛逛小鎮，認識大家（%d / 2）" % mini(_visited_count(), 2))
		"day1_night":
			GameState.set_objective("回家了。可以看看房間，或上床睡覺。")
		"day2_explore":
			var left := []
			if not GameState.has("bread_done"):
				left.append("幫露露做麵包")
			if not GameState.has("letter_done"):
				left.append("幫波波的忙")
			GameState.set_objective("、".join(left))
		"day2_evening":
			GameState.set_objective("八點鐘聲響起前，回家上床。")
		"night_out":
			GameState.set_objective("……廣場那邊，好像有人。")
		"day3_explore":
			if GameState.has("lulu_d3_done"):
				GameState.set_objective("去樹屋找 Fen。")
			else:
				GameState.set_objective("去露露家看看。")
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


func _fade_to(alpha: float) -> void:
	if GameState.fast:
		fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, 0.6)
	await tw.finished
