extends Node2D
## 第二章「漂白鎮」的流程導演：序章、三天、畢業典禮、結尾（含操行過低的壞結局）。
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
const Scrub := preload("res://scripts/minigames/scrub.gd")
const FindOdd := preload("res://scripts/minigames/find_odd.gd")
const HoldEndure := preload("res://scripts/minigames/hold_endure.gd")
const Sneak := preload("res://scripts/minigames/sneak.gd")
const SceneOverlay := preload("res://scripts/ui/scene_overlay.gd")
const Confession := preload("res://scripts/minigames/confession.gd")
const Trim := preload("res://scripts/minigames/trim.gd")
const Chairs := preload("res://scripts/minigames/chairs.gd")
const Restuff := preload("res://scripts/minigames/restuff.gd")

## 反省會的罪狀卡：前四張是小棘真的做過的事，後四張是孤兒院的大人說過的話
const CARDS_DONE := ["偷拿別人的信。", "在班上說波波偷東西。", "舉報同學換糖果。", "說謊。一直說謊。"]
const CARDS_ORPHAN := ["刺太多，會刺傷我們的孩子。", "他不親人。", "我們有自己的孩子了。", "沒有人要你。"]
## 畢業典禮後，每個居民的去向（見 docs/script/chapter2.md 7.2）
const FATES := ["aboard", "graduated", "dead", "unknown"]

const EXPLORE_PHASES := ["day1_explore", "day1_night", "day2_explore", "night_out_2", "day3_explore"]

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
	"conductor": {"name": "車掌", "species": "conductor", "color": Color.BLACK, "pos": Vector2(880, 1000)},
}
const RESIDENTS := ["baimian", "xiaoji", "tiaoma", "gaga", "zhongzhong", "youyou"]
const MODELS := ["lulu", "mochi", "popo"]
## 平常不在場的人
const HIDDEN := ["lulu", "mochi", "popo", "conductor"]

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
	# 第二天夜晚（跟鼬鼬偷溜）
	"treatment_window": {"name": "治療室的窗戶", "pos": Vector2(800, 300)},
	"office": {"name": "辦公室", "pos": Vector2(560, 330)},
	"platform": {"name": "月台", "pos": Vector2(760, 1000)},
}
const NIGHT_OBJECTS := ["c2_bed", "c2_pillow"]
const NIGHT_OUT_OBJECTS := ["treatment_window", "office", "platform"]

const WORLD_BOUNDS := Rect2(20, 40, 1150, 1000)
const HOUSE_BOUNDS := Rect2(85, 490, 255, 180)
const HOME_SPOT := Vector2(230, 630)
const PLAZA_SPOT := Vector2(600, 680)

const TINTS := {
	"day": Color(1, 1, 1),
	"evening": Color(0.86, 0.86, 0.9),
	"night": Color(0.55, 0.55, 0.62),
	# 漂白鎮的夜晚沒有黑色：所有東西都在發白光，像底片的負片
	"negative": Color(0.82, 0.86, 0.95),
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
var overlay: CanvasLayer


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
	match GameState.checkpoint:
		"c2_day1_explore":
			_continue.call_deferred()
		"c2_day2_morning":
			_day2_morning.call_deferred()
		"c2_day3_morning":
			_day3_morning.call_deferred()
		_:
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
		"day2_explore":
			if GameState.has("gaga_done") and (GameState.has("baimian_d2_done") or not GameState.has("photo_1")):
				await _day2_evening()
		"night_out_2":
			if GameState.has("overheard_conductor"):
				await _day2_end()
		"day3_explore":
			if GameState.has("c2_d3_evening_done"):
				await _graduation()


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
	_set_phase("day2_morning")
	await _fade_to(1.0)
	await Dialogue.run("c2_dream_1")
	GameState.new_day()
	GameState.save_game("c2_day2_morning")
	await _day2_morning()


## 第二天：早上的公告欄 → 早餐 → 洗白白 → 找出壞孩子 → 治療室 → 自由時間
func _day2_morning() -> void:
	busy = true
	player.can_move = false
	_set_phase("day2_morning")
	Dialogue.set_bg("none")
	_set_tint("day")
	player.bounds = WORLD_BOUNDS
	_layout("day")
	hud.set_status_visible(true)
	player.position = PLAZA_SPOT
	await _fade_to(0.0)
	await Dialogue.run("c2_d2_morning")
	await _fade_to(1.0)
	player.position = Vector2(260, 980)
	await _fade_to(0.0)
	await Dialogue.run("c2_breakfast")
	await _fade_to(1.0)
	player.position = Vector2(960, 520)
	await _fade_to(0.0)
	await Dialogue.run("c2_scrub")
	_layout("day")
	await _fade_to(1.0)
	player.position = Vector2(350, 420)
	await _fade_to(0.0)
	await Dialogue.run("c2_find")
	await Dialogue.run("c2_treatment_1")
	_layout("day")
	await _fade_to(1.0)
	player.position = Vector2(400, 560)
	_set_phase("day2_explore")
	await _fade_to(0.0)
	busy = false
	player.can_move = true


## 第二天傍晚：第二晚點名（名單上的「遙」）→ 宿舍 → 鼬鼬敲窗
func _day2_evening() -> void:
	await _fade_to(1.0)
	_set_tint("night")
	_layout("rollcall")
	player.position = Vector2(780, 720)
	await _fade_to(0.0)
	await Dialogue.run("c2_rollcall_2")
	await _fade_to(1.0)
	_layout("night")
	player.position = HOME_SPOT
	player.bounds = HOUSE_BOUNDS
	await _fade_to(0.0)
	await Dialogue.run("c2_night2")
	if not GameState.has("night_out_2"):
		await _day2_end()
		return
	await _fade_to(1.0)
	_layout("night_out")
	_set_tint("negative")
	player.bounds = WORLD_BOUNDS
	player.position = Vector2(1080, 640)
	await _fade_to(0.0)
	await Dialogue.run("c2_night2_intro")
	_set_phase("night_out_2")


func _day2_end() -> void:
	_set_phase("day3_morning")
	await _fade_to(1.0)
	_close_overlay()
	await Dialogue.run("c2_dream_2")
	GameState.new_day()
	GameState.save_game("c2_day3_morning")
	await _day3_morning()


## 第三天：公告欄 → 波波認出小棘 → 反省會 → 修剪 → 傍晚（麻糬）→ 搶椅子 → 畢業典禮 → 結尾
func _day3_morning() -> void:
	busy = true
	player.can_move = false
	_set_phase("day3_morning")
	Dialogue.set_bg("none")
	_set_tint("day")
	player.bounds = WORLD_BOUNDS
	_layout("day")
	hud.set_status_visible(true)
	player.position = PLAZA_SPOT
	await _fade_to(0.0)
	await Dialogue.run("c2_d3_morning")
	await _fade_to(1.0)
	_layout("day")
	player.position = Vector2(1060, 660)
	await _fade_to(0.0)
	await Dialogue.run("c2_popo_fence")
	await _fade_to(1.0)
	_layout("day")
	player.position = Vector2(350, 420)
	await _fade_to(0.0)
	await Dialogue.run("c2_confession")
	await Dialogue.run("c2_trim")
	GameState.set_flag("c2_trimmed")
	await _fade_to(1.0)
	_layout("day")
	_set_tint("evening")
	actors.xiaoji.position = Vector2(1130, 650)
	player.position = Vector2(900, 640)
	_set_phase("day3_explore")
	await _fade_to(0.0)
	busy = false
	player.can_move = true


func _graduation() -> void:
	_set_phase("graduation")
	await _fade_to(1.0)
	_layout("day")
	player.position = Vector2(560, 700)
	await _fade_to(0.0)
	await Dialogue.run("c2_chairs")
	await _fade_to(1.0)
	_layout("graduation")
	player.position = Vector2(560, 700)
	await _fade_to(0.0)
	await Dialogue.run("c2_graduation")
	await _chapter_end()


func _chapter_end() -> void:
	_set_phase("ended")
	var fates := {}
	for id in RESIDENTS:
		for fate in FATES:
			if GameState.has("fate_%s_%s" % [id, fate]):
				fates[id] = fate
	GameState.meta.chapters_done = maxi(int(GameState.meta.get("chapters_done", 0)), 2)
	GameState.meta.ch2_fates = fates
	GameState.save_meta()
	GameState.delete_save()
	var card := EndCard.new()
	card.mode = "c2_done"
	add_child(card)


## 依存活條件決定每個居民的去向（docs/script/chapter2.md 7.2）
func _compute_fates() -> void:
	var f := {"baimian": "aboard", "tiaoma": "dead"}
	if GameState.has("xiaoji_by_pip"):
		f.xiaoji = "graduated"
	else:
		var saved := int(GameState.has("xiaoji_last_quill")) + int(GameState.has("skipped_orphan_cards"))
		f.xiaoji = ["dead", "graduated", "aboard"][saved]
	f.zhongzhong = "aboard" if GameState.has("took_shock_for_zhongzhong") or GameState.has("lost_chair_for_zhongzhong") else "dead"
	f.gaga = "graduated" if GameState.has("reported_gaga") else "aboard"
	var yy := not GameState.has("reported_youyou") and GameState.has("night_out_2") and GameState.has("stabbed_mask")
	f.youyou = "aboard" if yy else "unknown"
	for id in f:
		for fate in FATES:
			GameState.set_flag("fate_%s_%s" % [id, fate], f[id] == fate)


## 壞結局「特別的愛」的代價：一位本來能上車的居民，被留在月台上
func _special_love_cost() -> void:
	for id in ["zhongzhong", "gaga", "xiaoji"]:
		if GameState.has("fate_%s_aboard" % id):
			GameState.set_flag("fate_%s_aboard" % id, false)
			GameState.set_flag("fate_%s_unknown" % id, true)
			GameState.set_flag("special_love_left", id)
			return


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
		"scrub":
			var sc := Scrub.new()
			add_child(sc)
			await sc.play()
		"find_1", "find_2", "find_3":
			var fo := FindOdd.new()
			add_child(fo)
			var n := int(event_name.right(1))
			GameState.set_flag("c2_found_%d" % n, await fo.play(n))
		"treatment_hold":
			var h := HoldEndure.new()
			h.questions = [["第一題。你為什麼沒有笑？", 3.0], ["第二題。你在看誰？", 4.0],
				["第三題。你還記得，遙是誰嗎？", 5.0]]
			add_child(h)
			await h.play()
		"sneak":
			var sn := Sneak.new()
			add_child(sn)
			if await sn.play():
				GameState.set_flag("c2_sneak_caught")
				GameState.add_conduct(-10)
		"photo_1", "photo_2", "photo_nirvana", "silhouette":
			if overlay == null:
				overlay = SceneOverlay.new()
				add_child(overlay)
			overlay.mode = event_name
			overlay.get_child(0).queue_redraw()
		"overlay_close":
			_close_overlay()
		"roll_list_2":
			var r2 := RollList.new()
			r2.haruka = true
			add_child(r2)
			await r2.show_and_wait()
		"c2_platform_scene":
			# 月台：和平鴿沒有戴面具，背對著小布；對面是車掌
			for id in RESIDENTS:
				actors[id].visible = false
			var dove: Interactable = actors.dove
			dove.visible = true
			dove.position = Vector2(700, 1010)
			dove.opts["unmasked"] = true
			dove.queue_redraw()
			actors.conductor.visible = true
			actors.conductor.position = Vector2(900, 1010)
			player.position = Vector2(560, 960)
		"c2_dove_mask_on":
			actors.dove.opts["unmasked"] = false
			actors.dove.queue_redraw()
		"c2_popo_fence":
			actors.popo.visible = true
			actors.popo.position = Vector2(1300, 640)
			for id in ["lulu", "mochi"]:
				actors[id].visible = true
			actors.xiaoji.position = Vector2(1140, 650)
		"c2_dove_hug":
			actors.dove.position = Vector2(1100, 690)
		"confession_1", "confession_2":
			var cf := Confession.new()
			cf.cards = CARDS_DONE if event_name == "confession_1" else CARDS_ORPHAN
			add_child(cf)
			await cf.play()
		"trim_1", "trim_2", "trim_3":
			var tr := Trim.new()
			tr.quills = {"trim_1": Trim.TOTAL, "trim_2": 6, "trim_3": 1}[event_name]
			tr.leave = {"trim_1": 6, "trim_2": 1, "trim_3": 0}[event_name]
			add_child(tr)
			await tr.play()
		"c2_mochi_cross":
			actors.mochi.visible = true
			actors.mochi.position = Vector2(1165, 660)
			actors.lulu.visible = true
		"c2_mochi_back":
			actors.mochi.position = ACTORS.mochi.pos
		"chairs_1", "chairs_2", "chairs_3":
			var ch := Chairs.new()
			var everyone := ["pip", "xiaoji", "tiaoma", "gaga", "zhongzhong", "youyou"]
			var second := "gaga" if GameState.has("reported_gaga") else "youyou"
			match event_name:
				"chairs_1":
					ch.players = everyone
					ch.out = "tiaoma"
				"chairs_2":
					ch.players = everyone.filter(func(p): return p != "tiaoma")
					ch.out = second
				"chairs_3":
					ch.players = ["pip", "zhongzhong"]
			add_child(ch)
			await ch.play()
		"long_hold", "special_hold":
			var lh := HoldEndure.new()
			lh.questions = [["（他沒有問問題。他一直按。）", 10.0 if event_name == "long_hold" else 15.0]]
			add_child(lh)
			await lh.play()
		"c2_graduation_layout":
			pass
		"restuff_1", "restuff_2":
			var rs := Restuff.new()
			rs.step = 0 if event_name == "restuff_1" else 2
			rs.steps = 2 if event_name == "restuff_1" else 4
			add_child(rs)
			await rs.play()
		"c2_tiaoma_gone":
			actors.tiaoma.visible = false
		"c2_mask_crack":
			actors.dove.opts["crack"] = 2.0
			actors.dove.queue_redraw()
		"c2_fates":
			_compute_fates()
		"c2_special_love_cost":
			_special_love_cost()
		"c2_train_arrives":
			town.train = true
			town.queue_redraw()
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
		a.visible = not id in HIDDEN
	for id in OBJECTS:
		actors[id].visible = not id in NIGHT_OBJECTS and not id in NIGHT_OUT_OBJECTS
	_refresh_looks()
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
		"graduation":
			# 點名廣場：布條、工作台；模範生站在高台上
			town.banner = true
			town.queue_redraw()
			for k in MODELS.size():
				actors[MODELS[k]].visible = true
				actors[MODELS[k]].position = Vector2(670 + k * 45, 500)
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = Vector2(470 + k * 52, 640 + (k % 2) * 14)
			actors.baimian.position = Vector2(820, 520)
			actors.dove.position = Vector2(880, 680)
		"night_out":
			# 偷溜：只有鼬鼬跟著你
			for id in ACTORS:
				actors[id].visible = false
			for id in OBJECTS:
				actors[id].visible = id in NIGHT_OUT_OBJECTS
			actors.youyou.visible = true
			actors.youyou.position = Vector2(1120, 600)


## 依劇情改變居民的樣子：條碼的斑紋、嘎嘎的嘴、鼬鼬的紅毛線、和平鴿的面具
func _refresh_looks() -> void:
	var stripes := 3
	if GameState.has("tiaoma_1"):
		stripes = 1
	elif GameState.has("tiaoma_2"):
		stripes = 2
	actors.tiaoma.opts["stripes"] = stripes
	actors.gaga.opts["sewn"] = not GameState.has("reported_gaga")
	actors.youyou.opts["thread"] = not (GameState.has("reported_youyou") or GameState.has("youyou_lost_thread"))
	actors.dove.opts["unmasked"] = false
	if GameState.has("c2_trimmed"):
		actors.xiaoji.opts["quills"] = 1 if GameState.has("xiaoji_last_quill") else 0
	for id in ["tiaoma", "gaga", "youyou", "dove", "xiaoji"]:
		actors[id].queue_redraw()


func _close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null


func _set_phase(p: String) -> void:
	phase = p
	_refresh_objective()


func _refresh_objective() -> void:
	match phase:
		"day1_explore":
			GameState.set_objective("自由時間。認識漂白鎮的孩子們（%d / 2）" % mini(_met_count(), 2))
		"day1_night":
			GameState.set_objective("熄燈了。可以看看床邊，或上床睡覺。")
		"day2_explore":
			if not GameState.has("gaga_done"):
				GameState.set_objective("自由時間。嘎嘎好像有話要說（食堂）。")
			elif GameState.has("photo_1") and not GameState.has("baimian_d2_done"):
				GameState.set_objective("拿照片去問屋頂上的白面。")
			else:
				GameState.set_objective("")
		"night_out_2":
			GameState.set_objective("十五分鐘。治療室、辦公室、月台。")
		"day3_explore":
			GameState.set_objective("傍晚。鐵絲網關電的十五分鐘——去河邊看看小棘。")
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
