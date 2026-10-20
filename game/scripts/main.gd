extends Node2D
## 第一章原型的流程導演：章節進行、場景配置、互動分派。
##
## 互動時依序尋找對話標籤：<id>_<phase> → <phase 預設> → <id>_d<day> → <id>
## 劇情邏輯盡量寫在 dialogue/chapter1.txt，這裡只處理「世界」的變化。

const Town := preload("res://scripts/world/town.gd")
const Player := preload("res://scripts/world/player.gd")
const Board := preload("res://scripts/ui/board.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const Summary := preload("res://scripts/ui/summary.gd")
const EndCard := preload("res://scripts/ui/end_card.gd")
const EndingCard := preload("res://scripts/ui/ending_card.gd")
const Intro := preload("res://scripts/ui/intro.gd")
const Flash := preload("res://scripts/ui/flash.gd")
const MirrorStare := preload("res://scripts/ui/mirror_stare.gd")
const Title := preload("res://scripts/ui/title.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")

const EXPLORE_PHASES := ["day1_explore", "day1_night", "day2_explore", "day2_evening", "night_out", "day3_explore", "day3_home", "forest"]
const Forest := preload("res://scripts/world/forest.gd")
const RepairScene := preload("res://scripts/ui/repair_scene.gd")

## 位置都是世界座標＝地圖原圖座標 × 1.5（見 town.gd 的 at()）
const ACTORS := {
	"lulu": {"name": "露露", "species": "rabbit", "color": Color("#f4b6c2"), "pos": Vector2(445, 625)},
	"popo": {"name": "波波", "species": "penguin", "color": Color("#2f3352"), "pos": Vector2(1290, 985)},
	"fen": {"name": "Fen", "species": "fox", "color": Color("#c8642b"), "pos": Vector2(1815, 1000), "smile": false, "stitched": true},
	"mayor": {"name": "熊熊鎮長", "species": "bear", "color": Color("#c4894f"), "pos": Vector2(1050, 930), "size": 1.6},
	"mochi": {"name": "麻糬", "species": "hamster", "color": Color("#fbf3e6"), "pos": Vector2(215, 1330)},
	"tama": {"name": "小玉", "species": "calico", "color": Color("#fbf1df"), "pos": Vector2(645, 1330)},
	"conductor": {"name": "車掌", "species": "conductor", "color": Color("#4a2a32"), "pos": Vector2(1260, 1620), "size": 1.5},
	"extra1": {"name": "小狗居民", "species": "puppy", "color": Color("#e6ccb2"), "pos": Vector2(645, 940)},
	"extra3": {"name": "居民", "species": "puppy", "color": Color("#e2ece9"), "pos": Vector2(-500, -500)},
}

const OBJECTS := {
	"board": {"name": "公告欄", "pos": Vector2(915, 860)},
	"bakery_photo": {"name": "櫥窗裡的照片", "pos": Vector2(510, 525)},
	"mail_sack": {"name": "郵袋", "pos": Vector2(1470, 963)},
	"mayor_door": {"name": "鎮長公館的門", "pos": Vector2(1107, 590)},
	"repair_room": {"name": "修理室", "pos": Vector2(1222, 277)},
	"mirror_house": {"name": "鏡之屋", "pos": Vector2(1647, 495)},
	"clocktower": {"name": "鐘塔大門", "pos": Vector2(867, 395)},
	"forest": {"name": "森林小徑", "pos": Vector2(1470, 140)},
	"station": {"name": "火車站", "pos": Vector2(1017, 1575)},
	"home_door": {"name": "小布的家", "pos": Vector2(292, 850)},
	# 每個人的小屋：進去以後用點擊調查（scripts/world/interiors.gd）
	"lulu_house": {"name": "露露的家", "pos": Vector2(515, 505)},
	"popo_house": {"name": "郵局", "pos": Vector2(1402, 925)},
	"fen_tree": {"name": "Fen 的樹屋", "pos": Vector2(1800, 965)},
	"mochi_house": {"name": "麻糬的小屋", "pos": Vector2(183, 1232)},
	"tama_house": {"name": "小玉的小屋", "pos": Vector2(618, 1272)},
	"station_office": {"name": "站務室", "pos": Vector2(1240, 1572)},
	# ── 支線物件：只在條件成立、而且還沒撿走時出現（"when"＝旗標條件）
	"lulu_mailbox": {"name": "露露家的信箱", "pos": Vector2(372, 606), "when": "q_letters"},
	"candy_1": {"name": "糖果", "pos": Vector2(1150, 1600), "when": "q_tama"},
	"candy_2": {"name": "糖果", "pos": Vector2(1560, 985), "when": "q_tama"},
	"candy_3": {"name": "糖果", "pos": Vector2(318, 578), "when": "q_tama"},
	"note_1": {"name": "一張紙", "pos": Vector2(750, 380), "when": "q_notes"},
	"note_2": {"name": "一張紙", "pos": Vector2(1320, 1590), "when": "q_notes"},
	"note_3": {"name": "一張紙", "pos": Vector2(1350, 262), "when": "q_notes"},
	# 散落在鎮上的棉花：每一團是一段記憶碎片，撿過的會跨輪保留（下一輪不再出現）
	"tuft_0": {"name": "一小團棉花", "pos": Vector2(162, 1251)},
	"tuft_1": {"name": "一小團棉花", "pos": Vector2(837, 312)},
	"tuft_2": {"name": "一小團棉花", "pos": Vector2(1650, 660)},
	"tuft_3": {"name": "一小團棉花", "pos": Vector2(1494, 1065)},
	"tuft_4": {"name": "一小團棉花", "pos": Vector2(290, 1386)},
	"tuft_5": {"name": "一小團棉花", "pos": Vector2(1140, 1050)},
	"tuft_6": {"name": "一小團棉花", "pos": Vector2(492, 957)},
	"tuft_7": {"name": "一小團棉花", "pos": Vector2(1050, 705)},
	"tuft_8": {"name": "一小團棉花", "pos": Vector2(1828, 990)},
	"tuft_9": {"name": "一小團棉花", "pos": Vector2(705, 1557)},
	# 小布的房間（地圖右邊，見 town.gd 的 ROOM）
	"mirror": {"name": "鏡子", "pos": Vector2(3080, 375)},
	"bed": {"name": "床", "pos": Vector2(2425, 470)},
	"home_exit": {"name": "出門", "pos": Vector2(3290, 470)},
	# 森林（第三天）
	"forest_sheep": {"name": "小綿羊", "pos": Vector2(1192, 250)},
	"forest_bow": {"name": "長耳朵", "pos": Vector2(365, 815)},
	"forest_tags": {"name": "一堆名牌", "pos": Vector2(1725, 650)},
	"forest_tail": {"name": "狐狸尾巴", "pos": Vector2(1915, 845)},
}

const FOREST_ITEMS := ["found_sheep", "found_lulu_bow", "seen_tags", "found_fox_tail"]
const FOREST_BOUNDS := Forest.BOUNDS

## 第一天要拜訪的地點（至少 2 個才會進入傍晚）
const DAY1_PLACES := ["lulu", "popo", "fen", "mayor_door", "repair_room", "mirror_house", "clocktower"]
const DAY1_NEEDED := 4
const PLACE_NAMES := {"lulu": "麵包店", "popo": "郵局", "fen": "石橋的 Fen", "mayor_door": "鎮長公館",
	"repair_room": "公館後的小屋", "mirror_house": "鏡之屋", "clocktower": "鐘塔"}
## 互動結束後，這段時間內再按 E 不會馬上又開啟對話（避免連按重播）
const TALK_COOLDOWN_MS := 350
const PHASE_DEFAULT := {"day1_night": "late", "night_out": "night_resident"}
const HOUSE_BOUNDS := Town.ROOM_BOUNDS
const HOME_SPOT := Vector2(2840, 540)
const WORLD_BOUNDS := Town.WORLD_BOUNDS
## 走出家門時站的位置（門口）
const OUTSIDE_HOME := Vector2(300, 872)
const STATION_SPOT := Vector2(1017, 1625)

const TINTS := {
	"day": Color(1, 1, 1),
	"sunset": Color(1.0, 0.86, 0.85),
	"evening": Color(0.82, 0.78, 0.92),
	"night": Color(0.5, 0.47, 0.62),
}

var phase := "prologue"
var busy := true
var _talk_end_ms := 0
## 說過、而且沒改變任何事的對話標籤 → 接下來改聊閒聊幾次
var _stale := {}
## 角色 → 閒聊台詞（dialogue 的 idle_<名字>_N）
const IDLE_KEY := {"lulu": "lulu", "popo": "popo", "fen": "fen", "mayor": "mayor", "mochi": "mochi",
	"tama": "tama", "extra1": "puppy", "conductor": "conductor"}
var actors := {}

var town: Node2D
var player: Node2D
var hud: CanvasLayer
var board: CanvasLayer
var tint: CanvasModulate
var fade: ColorRect
var forest: Node2D
var repair_scene: CanvasLayer
var guide: GuideArrow
var interior: InteriorScene
## 自動測試用：進到小屋後先不要出來
var hold_interior := false
## 森林和夜晚：每隔一陣子，遠處傳來鈴聲
var _bell_t := 25.0


func _ready() -> void:
	# 越下面的角色畫在越前面
	y_sort_enabled = true
	Dialogue.fx.vignette = 0.0
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

	guide = GuideArrow.new()
	add_child(guide)
	var touch := TouchControls.new()
	touch.mode_provider = _touch_mode
	add_child(touch)
	guide.touch = touch.enabled
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
	elif _dev_preview() != "":
		_run_dev_preview.call_deferred(_dev_preview())
	else:
		_show_title.call_deferred()


## 網頁版預覽用：網址加上 ?dev=chase（追逐戰）、?dev=ending（修理室之後）、?dev=room_mayor（某間小屋）
func _dev_preview() -> String:
	if not OS.has_feature("web"):
		return ""
	var q: String = str(JavaScriptBridge.eval("location.search", true))
	var i := q.find("dev=")
	return q.substr(i + 4).split("&")[0] if i >= 0 else ""


func _run_dev_preview(what: String) -> void:
	GameState.reset()
	_layout("day")
	_set_tint("day")
	player.bounds = WORLD_BOUNDS
	player.position = Vector2(915, 1060)
	hud.set_status_visible(true)
	_set_phase("day2_explore")
	GameState.day = 2
	match what:
		"chase":
			GameState.set_flag("breakdown")
			await _true_ending()
		"ending":
			GameState.set_flag("fen_trust")
			busy = true
			Sound.bgm("memory")
			await Dialogue.run("showdown")
			await _end_loop("truth")
		_:
			if what.begins_with("room_") and Interiors.ROOMS.has(what.substr(5)):
				busy = true
				await _enter_interior(what.substr(5))
			busy = false
			player.can_move = true


func _show_title() -> void:
	# 開場 Logo 影片：每次開啟遊戲只播一次（回到標題時不再播）
	# 網頁版：Logo 影片在網頁載入時就播過了（game/web/head_include.html）
	if OS.has_feature("web"):
		GameState.intro_played = true
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
	title.chapter2.connect(func():
		# 從「選擇篇章」進第二章：從第二章的序章重新開始
		GameState.reset()
		enter_chapter2(get_tree()))


## 從存檔繼續：每個檢查點都是某一天的早上
func _continue() -> void:
	Sound.set_wear(GameState.memory_depth())
	if not GameState.load_game():
		GameState.reset()
		run_chapter()
		return
	if GameState.chapter == 2:
		get_tree().change_scene_to_file.call_deferred("res://scenes/chapter2.tscn")
		return
	var cp := GameState.checkpoint
	Dialogue.set_bg("none")
	town.clock_stopped = GameState.day >= 2
	town.queue_redraw()
	_set_tint("day")
	if cp == "day1_explore":
		player.bounds = WORLD_BOUNDS
		player.position = Vector2(915, 1060)
	else:
		_place_home()
	_layout("day")
	hud.set_status_visible(true)
	_set_phase(cp)
	busy = false
	player.can_move = true


## 進入第二章「漂白鎮」（scenes/chapter2.tscn）。從第一章結尾接過來時，第一章的旗標會帶著走
static func enter_chapter2(tree: SceneTree) -> void:
	Sound.bgm("")
	Sound.ambience("")
	Dialogue.set_bg("none")
	GameState.set_flag("chapter2")
	GameState.start_chapter2()
	GameState.checkpoint = ""
	tree.change_scene_to_file.call_deferred("res://scenes/chapter2.tscn")


# ───────────────────────── 章節流程 ─────────────────────────

func run_chapter() -> void:
	Sound.set_wear(GameState.memory_depth())
	_set_phase("prologue")
	hud.set_status_visible(false)
	# 第一次搭上列車前的一瞬間：閃過一段影片。之後再也不會出現。
	if not GameState.meta.get("flash_seen", false) and not GameState.fast:
		GameState.meta["flash_seen"] = true
		GameState.save_meta()
		Sound.duck(true)
		var f := Flash.new()
		add_child(f)
		await f.done
		Sound.duck(false)
	_layout("arrival")
	player.position = STATION_SPOT
	player.face(Vector2.UP)
	Sound.bgm("day")
	await Dialogue.run("prologue")
	await Dialogue.run("arrival")
	if Dialogue.has_label("opening_%d" % GameState.opening_index()):
		await Dialogue.run("opening_%d" % GameState.opening_index())
	_layout("day")
	hud.set_status_visible(true)
	_set_phase("day1_explore")
	GameState.save_game("day1_explore")
	busy = false
	player.can_move = true
	var depth := GameState.memory_depth()
	if depth > 0:
		hud.toast(GameState.hint("記憶加深了：%s　%s（Tab 打開日記）") % ["●".repeat(depth) + "○".repeat(GameState.MAX_DEPTH - depth), GameState.DEPTH_NAMES[depth]], 6.0)
	else:
		hud.toast(GameState.hint("WASD／方向鍵走路　·　靠近按 E 互動　·　Tab 打開日記"), 7.0)
	hud.toast("頭上有「！」的地方，就是今天可以去的地方。不在畫面裡時，邊緣的粉紅箭頭會指給你看。", 6.0)


func _after_interaction() -> void:
	match phase:
		"day1_explore":
			if _visited_count() >= int(GameState.opening().need):
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
	# 開頭固定任務的版本：這一版不用做的事，直接算完成（台詞裡用 skip_bread／skip_letter）
	var chores: Array = GameState.opening().day2
	if not "bread" in chores:
		GameState.set_flag("skip_bread")
		GameState.set_flag("bread_done")
	if not "letter" in chores:
		GameState.set_flag("skip_letter")
		GameState.set_flag("letter_done")
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
	actors.fen.position = Forest.START + Vector2(60, -20)
	player.position = Forest.START
	player.bounds = FOREST_BOUNDS
	player.in_forest = true
	_set_phase("forest")
	Sound.bgm("night")
	Sound.ambience("forest")
	await _fade_to(0.0)
	await Dialogue.run("forest_enter")


## 本章高潮：「第幾次了」、下午三點的鐘聲、Fen 被帶走（條件成立 → 鎮長崩潰）
func _forest_climax() -> void:
	var fen: Interactable = actors.fen
	fen.position = player.position + Vector2(50, 10)
	Sound.sfx("strange")
	Sound.bgm("memory")
	await Dialogue.run("forest_truth")
	GameState.set_flag("bell_heard")
	await Dialogue.run("bell_three")
	if GameState.has("breakdown"):
		await _true_ending()
		return
	if GameState.has("lulu_hesitated"):
		# 露露沒有說出你在哪裡：被帶走的是她
		await _fade_to(1.0)
		await _end_loop("hesitate")
		return
	await _fade_to(1.0)
	forest.visible = false
	player.in_forest = false
	player.sway = 0.0
	Dialogue.fx.vignette = 0.0
	for a in actors.values():
		a.visible = false
	repair_scene = RepairScene.new()
	add_child(repair_scene)
	hud.set_status_visible(false)
	tint.color = TINTS.day
	await _fade_to(0.0)
	await Dialogue.run("repair")
	await _end_loop("brave" if GameState.has("brave_end") else "betrayed")


## 真結局：鎮長崩潰 → 3D 追逐戰 → 修理室的剪刀 → 鎮長想起來 → 車掌 → 前往第二章
func _true_ending() -> void:
	busy = true
	player.can_move = false
	_set_phase("chase")
	await _fade_to(1.0)
	forest.visible = false
	town.visible = false
	player.in_forest = false
	player.sway = 0.0
	player.visible = false
	for a in actors.values():
		a.visible = false
	hud.set_status_visible(false)
	Sound.ambience("")
	Sound.bgm("chase")
	var chase := ChaseScene.new()
	add_child(chase)
	await _fade_to(0.0)
	await chase.finished
	await _fade_to(1.0)
	chase.queue_free()
	Dialogue.fx.vignette = 0.0
	tint.color = TINTS.day
	Sound.bgm("memory")
	await _fade_to(0.0)
	await Dialogue.run("showdown")
	await _end_loop("truth")


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
	if ending in ["zero", "truth"]:
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
		if Time.get_ticks_msec() - _talk_end_ms < TALK_COOLDOWN_MS:
			get_viewport().set_input_as_handled()
			return
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
	# 任何互動（包括信箱、門、物件）改變了進度，大家「說過了」的標記都要清掉，
	# 不然回去找人時會一直是閒聊，接不到新的劇情（例：送完信回郵局，波波沒反應）
	var state_before := _state_snapshot()
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
		var n := GameState.tuft_count()
		var left := GameState.loop_tufts().filter(func(t): return not GameState.has_tuft(t)).size()
		var msg := "撿到記憶碎片（%d / 10）。撿過的，下一輪也會記得。" % n
		if n >= 6 and n - 1 < 6:
			msg = "記憶碎片已經有 %d 團了。……好像想起了什麼重要的事。" % n
		elif left > 0:
			msg += "這一輪，鎮上還有 %d 團。" % left
		hud.toast(msg, 5.0)
	else:
		Sound.sfx("interact")
		var label := _talk_label(id)
		var who: String = IDLE_KEY.get(id, "")
		if who != "" and (label == "nothing" or int(_stale.get(label, 0)) > 0):
			# 這段話已經說過、而且什麼都沒改變：換成閒聊（每個人都有一大堆台詞）
			if label != "nothing":
				_stale[label] = int(_stale[label]) - 1
			await Dialogue.run("chat_" + who)
		else:
			var before := _state_snapshot()
			await Dialogue.run(label)
			if who != "":
				if _state_snapshot() == before:
					_stale[label] = 2   # 接下來兩次先聊別的
				else:
					_stale.clear()      # 有事情改變了：大家的話也可能不一樣了
	# 小屋：對話裡 @set want_enter_<房間> → 進去
	for room in Interiors.ROOMS:
		if GameState.has("want_enter_" + room):
			GameState.set_flag("want_enter_" + room, false)
			await _enter_interior(room)
	if _state_snapshot() != state_before:
		_stale.clear()
	await _after_interaction()
	_refresh_objects()
	if phase != "ended":
		busy = false
		player.can_move = true
		_refresh_objective()
	_talk_end_ms = Time.get_ticks_msec()


## 進到小屋裡（點擊調查），按「離開」回到門口
func _enter_interior(room: String) -> void:
	Sound.sfx("door")
	await _fade_to(1.0)
	var scene := InteriorScene.new()
	scene.room_id = room
	add_child(scene)
	interior = scene
	hud.set_status_visible(false)
	guide.point_to(null)
	await _fade_to(0.0)
	if GameState.fast:
		# 自動測試：hold_interior 時由測試自己調查、離開（tests/interiors_test.gd），否則直接出來
		if not hold_interior:
			await _exit_interior()
		return
	await scene.closed
	await _exit_interior()


func _exit_interior() -> void:
	await _fade_to(1.0)
	if interior:
		interior.queue_free()
		interior = null
	hud.set_status_visible(true)
	_refresh_objective()
	await _fade_to(0.0)


func _state_snapshot() -> String:
	var f := {}
	for k in GameState.flags:
		if not str(k).begins_with("idle_"):
			f[k] = GameState.flags[k]
	return JSON.stringify([f, GameState.suspicion, GameState.courage, GameState.day])


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
	if Sound.ambience_name() != "" and phase in EXPLORE_PHASES:
		_bell_t -= _delta
		if _bell_t <= 0.0:
			_bell_t = randf_range(35.0, 70.0)
			Sound.sfx("bell_far")
	if phase == "forest":
		# 越往森林深處，顏色就越淡
		var t := clampf((Forest.START.y - player.position.y) / (Forest.START.y - 240.0), 0.0, 1.0)
		tint.color = Color(1, 1, 1).lerp(Color(0.6, 0.6, 0.66), t)
		Dialogue.fx.vignette = 0.25 + 0.75 * t
		player.sway = t
		if not busy:
			var fen: Interactable = actors.fen
			fen.position = fen.position.lerp(player.position + Vector2(55, 25), 0.04)
	if busy or Dialogue.running or hud.menu_open or board.visible:
		hud.set_prompt("")
		guide.point_to(null)
		return
	_update_guide()
	var it: Interactable = player.nearest()
	var key := GameState.interact_key_label()
	hud.set_prompt("%s：%s" % [key, it.display_name] if it else "")
	if it:
		_first_time_tip(it)


## 目標不在畫面裡時，畫面邊緣的箭頭指過去（最近的一個「！」）
func _update_guide() -> void:
	var in_room: bool = player.position.x > 2000.0
	var best: Interactable = null
	var best_d := INF
	for a: Interactable in actors.values():
		if not a.marked or not a.visible:
			continue
		var t := a
		# 目標在房間裡、人在外面（或反過來）：先指向門
		if (t.position.x > 2000.0) != in_room:
			t = actors.home_exit if in_room else actors.home_door
		var d: float = player.position.distance_to(t.position)
		if d < best_d:
			best = t
			best_d = d
	if best == null:
		guide.point_to(null)
		return
	guide.point_to(get_viewport().get_canvas_transform() * best.position, best.display_name)


## 第一次靠近某種東西時，上方跳出一句說明（整個存檔只說一次）
func _first_time_tip(it: Interactable) -> void:
	var kind := ""
	var text := ""
	if it.id.begins_with("tuft_"):
		kind = "tuft"
		text = "飄浮的棉花團是「記憶碎片」。撿起來的話，下一輪也會記得。"
	elif it.id.begins_with("candy_") or it.id.begins_with("note_"):
		kind = "quest_item"
		text = "閃閃發亮的小東西，可能是誰在找的東西。"
	elif it.kind == "obj" and it.id != "board":
		kind = "spot"
		text = "有白色光圈的地方，可以按 E 調查。"
	if kind == "":
		return
	var tips: Array = GameState.meta.get("tips", [])
	if kind in tips:
		return
	tips.append(kind)
	GameState.meta["tips"] = tips
	GameState.save_meta()
	hud.toast(GameState.hint(text), 5.0)


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
		"board":
			await board.open()
		"mirror_stare":
			# 盯著鏡子 10 秒：第 7 秒，鏡子裡浮現一個人類小孩
			var m := MirrorStare.new()
			add_child(m)
			Sound.duck(true)
			await m.play()
			Sound.duck(false)
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
		"scissors":
			Sound.bgm("chase")
			var sc := ScissorsScene.new()
			add_child(sc)
			await sc.play()
			sc.queue_free()
			Sound.bgm("memory")
		"mayor_falls":
			Sound.sfx("strange")
		"conductor_enters":
			Sound.sfx("door")
		"night_train":
			Sound.bgm("night")
		"jumpscare_fen", "jumpscare_mayor":
			var j := JumpScare.new()
			j.who = event_name.trim_prefix("jumpscare_")
			add_child(j)
			Sound.duck(true)
			await j.play()
			Sound.duck(false)
			j.queue_free()
		"good_kid_station":
			# 第四天：你站在歡迎的人群裡，看著新的小布下車
			_layout("arrival")
			_set_tint("day")
			player.bounds = WORLD_BOUNDS
			player.position = STATION_SPOT + Vector2(-20, -70)
			player.face(Vector2.DOWN)
			var newbie: Interactable = actors.extra3
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
		a.visible = not id.begins_with("extra") or id == "extra1"
		a.follow_eyes = false
		a.stare = false
		a.facing = Vector2.DOWN
	for id in OBJECTS:
		actors[id].visible = not id.begins_with("forest_")
	match mode:
		"arrival":
			# 火車站前：大家圍著剛下車的小布
			var spots := [Vector2(-190, 5), Vector2(-105, -25), Vector2(105, -25), Vector2(190, 5), Vector2(-300, -15), Vector2(290, -10)]
			var who := ["lulu", "popo", "mochi", "tama", "mayor", "extra1"]
			for k in who.size():
				actors[who[k]].position = STATION_SPOT + spots[k]
				actors[who[k]].visible = true
				actors[who[k]].face_toward(STATION_SPOT)
			actors.fen.visible = false
			actors.conductor.visible = false
		"day":
			actors.mayor.visible = GameState.day >= 2
			# 車掌：第二天起，一直站在月台的盡頭
			actors.conductor.visible = GameState.day >= 2
			# 想起名字的麻糬，第三天已經被帶去修理了
			actors.mochi.visible = not (GameState.day >= 3 and GameState.has("mochi_remembers"))
			# 第三天：有幾個居民站著不動，一直盯著小布看
			if GameState.day >= 3:
				for who in ["tama", "extra1", "conductor"]:
					actors[who].stare = true
		"night":
			# 夜晚：居民們站在廣場，面朝鐘塔。一動也不動。鈕扣眼睛跟著小布轉。
			var who := ["lulu", "popo", "mochi", "tama", "extra1"]
			for k in who.size():
				var a: Interactable = actors[who[k]]
				a.position = Vector2(800 + k * 75, 960 + (k % 2) * 40)
				a.visible = true
				a.facing = Vector2.UP
				a.follow_eyes = true
			actors.mayor.visible = false
			actors.conductor.visible = false
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
			# 每一輪只散落三團（撿過的不會再出現）
			actors[id].visible = not GameState.has_tuft(id) and id in GameState.loop_tufts()
		elif data.has("when"):
			actors[id].visible = GameState.check(data.when) and not GameState.has(id + "_got")


func _set_phase(p: String) -> void:
	phase = p
	_refresh_objective()


func _refresh_objective() -> void:
	var marks := []
	hud.checklist = []
	match phase:
		"day1_explore":
			var left := []
			var need := int(GameState.opening().need)
			for id in GameState.opening().places:
				var done := GameState.has("visited_" + id)
				hud.checklist.append([PLACE_NAMES[id], done])
				if not done:
					left.append(PLACE_NAMES[id])
					marks.append(id)
			var goal := "逛逛小鎮，認識大家" if GameState.opening_index() == 0 else "今天的功課"
			GameState.set_objective("%s（%d / %d）\n還沒去：%s" % [goal, mini(_visited_count(), need), need, "、".join(left)])
			# 記得鑰匙在哪裡（第三輪起）：樹屋上會出現標記
			if GameState.memory_depth() >= 2 and GameState.remembers("knows_key") and not GameState.has("got_key"):
				marks.append("fen_tree")
		"day1_night":
			GameState.set_objective("回家了。可以看看房間，或上床睡覺。")
			marks.append("bed")
		"day2_explore":
			var left := []
			if not GameState.has("bread_done"):
				left.append("幫露露做麵包")
				marks.append("lulu")
			if not GameState.has("letter_done"):
				if GameState.has("q_letters"):
					var n := int(GameState.flags.get("letters", 0))
					left.append("幫波波送信（%d / 3）" % n if n < 3 else "回郵局找波波")
					if n >= 3:
						marks.append("popo")
					else:
						for pair in [["lulu_mailbox", "lulu_mail_done"], ["mayor_door", "mayor_mail_done"], ["mirror_house", "mirror_mail_done"]]:
							if not GameState.has(pair[1]):
								marks.append(pair[0])
				else:
					left.append("幫波波的忙")
					marks.append("popo")
			hud.checklist = []
			if not GameState.has("skip_bread"):
				hud.checklist.append(["幫露露做麵包", GameState.has("bread_done")])
			if not GameState.has("skip_letter"):
				hud.checklist.append(["幫波波送信", GameState.has("letter_done")])
			GameState.set_objective("、".join(left))
		"day2_evening":
			GameState.set_objective("八點鐘聲響起前，回家上床。")
			marks.append("home_door")
		"night_out":
			GameState.set_objective("……廣場那邊，好像有人。")
		"day3_explore":
			if GameState.has("fen_plan") and not GameState.has("got_key"):
				GameState.set_objective("去 Fen 的樹屋，拿地板下面的鑰匙。")
				marks.append("fen_tree")
			elif GameState.has("fen_plan"):
				GameState.set_objective("回去找 Fen。")
				marks.append("fen")
			elif GameState.has("lulu_d3_done"):
				GameState.set_objective("去樹屋找 Fen。")
				marks.append("fen")
			else:
				GameState.set_objective("去露露家看看。")
				marks.append("lulu")
		"day3_home":
			GameState.set_objective("八點以前回家，上床睡覺。")
			marks.append("home_door")
		"forest":
			GameState.set_objective("調查森林深處的東西（%d / 3）" % mini(_forest_count(), 3))
			for k in FOREST_ITEMS.size():
				if not GameState.has(FOREST_ITEMS[k]):
					marks.append(["forest_sheep", "forest_bow", "forest_tags", "forest_tail"][k])
		_:
			GameState.set_objective("")
	# 記憶碎片：還沒撿的棉花頭上也有「！」
	if phase in EXPLORE_PHASES and phase != "forest":
		for id in actors:
			if id.begins_with("tuft_") and actors[id].visible:
				marks.append(id)
	for id in actors:
		var a: Interactable = actors[id]
		var m: bool = id in marks
		if a.marked != m:
			a.marked = m
			a.queue_redraw()
	hud.refresh()


func _forest_count() -> int:
	return FOREST_ITEMS.filter(func(f): return GameState.has(f)).size()


func _visited_count() -> int:
	return GameState.opening().places.filter(func(p): return GameState.has("visited_" + p)).size()


func _set_tint(name: String) -> void:
	tint.color = TINTS[name]
	Sound.bgm("day" if name in ["day", "sunset"] else "night")
	Sound.ambience("night" if name in ["evening", "night"] else "")


func _fade_to(alpha: float) -> void:
	if GameState.fast:
		fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, 0.6)
	await tw.finished
