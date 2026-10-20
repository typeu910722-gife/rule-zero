extends Node2D
## 第二章「漂白鎮」的流程導演：序章、三天、畢業典禮、結尾（含操行過低的壞結局）。
## 劇情邏輯寫在 dialogue/chapter2.txt（標籤以 c2_ 開頭），這裡只處理「世界」的變化。
## 互動時依序尋找對話標籤：c2_<id>_<phase> → c2_<id>_d<day> → c2_<id>

const BleachTown := preload("res://scripts/world/bleach_town.gd")
const Player := preload("res://scripts/ch2/player.gd")
const Board := preload("res://scripts/ch2/board.gd")
const Hud := preload("res://scripts/ch2/hud.gd")
const EndCard := preload("res://scripts/ch2/end_card.gd")
const TouchControls := preload("res://scripts/ch2/touch_controls.gd")
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
const SP := "res://art/ch2/characters/sprites/ch2_"
const ACTORS := {
	"baimian": {"name": "白面", "species": "fox", "color": Color("#e2e2df"), "pos": Vector2(585, 128), "reach_home": 180.0,
		"opts": {"pale": true, "no_tail": true}, "sprites": [
			# 平常坐在宿舍屋頂晃腳；其他時候站著
			{"tex": SP + "baimian_sprite_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "frames": [0, 1, 2, 3], "fps": 4, "requires": {"home": true}},
			{"tex": SP + "baimian_sprite_stand_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152)}]},
	"xiaoji": {"name": "小棘", "species": "hedgehog", "color": Color("#2f2f2f"), "pos": Vector2(430, 315),
		"opts": {"quills": 5, "white": false}, "sprites": [
			{"tex": SP + "xiaoji_sprite_white_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"white": true}},
			# 平常在宿舍前掃地
			{"tex": SP + "xiaoji_sprite_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "frames": [0, 1, 2, 3], "fps": 4, "requires": {"quills": 5, "home": true}},
			{"tex": SP + "xiaoji_sprite_stand_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"quills": 5}},
			{"tex": SP + "xiaoji_sprite_onequill_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"quills": 1}},
			{"tex": SP + "xiaoji_sprite_bald_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"quills": 0}}]},
	"tiaoma": {"name": "條碼", "species": "zebra", "color": Color("#f4f4f2"), "pos": Vector2(1255, 610),
		"smile": false, "opts": {"stripes": 3}, "sprites": [
			{"tex": SP + "tiaoma_sprite_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"stripes": 3}},
			{"tex": SP + "tiaoma_sprite_s2_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"stripes": 2}},
			{"tex": SP + "tiaoma_sprite_s1_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"stripes": 1}},
			{"tex": SP + "tiaoma_sprite_s0_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"stripes": 0}}]},
	"gaga": {"name": "嘎嘎", "species": "crow", "color": Color("#4a4a4a"), "pos": Vector2(700, 705),
		"smile": false, "opts": {"sewn": true}, "sprites": [
			{"tex": SP + "gaga_sprite_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"sewn": true}},
			{"tex": SP + "gaga_sprite_unsewn_sheet.png", "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"sewn": false}}]},
	"zhongzhong": {"name": "重重", "species": "hippo", "color": Color("#9c9c9c"), "pos": Vector2(420, 600),
		"smile": false, "size": 1.25, "stitched": true, "sprites": [
			# 平常坐著摺紙鶴
			{"tex": SP + "zhongzhong_sprite_sheet.png", "cols": 2, "frame": Vector2(208, 208), "origin": Vector2(104, 200), "frames": [0, 1, 2, 3], "fps": 3, "requires": {"home": true}},
			{"tex": SP + "zhongzhong_sprite_stand_sheet.png", "frame": Vector2(208, 208), "origin": Vector2(104, 200)}]},
	"youyou": {"name": "鼬鼬", "species": "weasel", "color": Color("#b8b8b4"), "pos": Vector2(990, 715),
		"opts": {"thread": true}, "sprites": [
			# 平常趴在鐵絲網下
			{"tex": SP + "youyou_sprite_crawl_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "frames": [0, 1], "fps": 2, "requires": {"thread": true, "home": true}},
			{"tex": SP + "youyou_sprite_sheet.png", "cols": 4, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"thread": true}},
			{"tex": SP + "youyou_sprite_nothread_sheet.png", "cols": 4, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "requires": {"thread": false}}]},
	"dove": {"name": "和平鴿", "species": "dove", "color": Color.WHITE, "pos": Vector2(900, 440),
		"opts": {"unmasked": false, "crack": 1.0, "clap": false}, "sprites": [
			# 沒戴面具：只有背影（第二天夜晚的月台）
			{"tex": SP + "dove_sprite_unmasked_sheet.png", "cols": 4, "frame": Vector2(384, 416), "origin": Vector2(192, 408), "requires": {"unmasked": true}},
			{"tex": SP + "dove_sprite_cracked_sheet.png", "cols": 4, "frame": Vector2(384, 416), "origin": Vector2(192, 408), "requires": {"crack": 2.0}},
			{"tex": SP + "dove_sprite_clap_sheet.png", "cols": 2, "frame": Vector2(384, 416), "origin": Vector2(192, 408), "frames": [0, 1], "fps": 2, "requires": {"clap": true}},
			{"tex": SP + "dove_sprite_sheet.png", "cols": 4, "frame": Vector2(384, 416), "origin": Vector2(192, 408)}]},
	# 河對岸陽台上揮手的模範生（彩色）
	"lulu": {"name": "露露", "species": "rabbit", "color": Color("#f4b6c2"), "pos": Vector2(1355, 905), "sprites": [
		{"tex": SP + "lulu_sprite_wave_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "frames": [0, 1], "fps": 2, "requires": {"home": true}},
		{"tex": SP + "lulu_sprite_wave_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152)}]},
	"mochi": {"name": "麻糬", "species": "hamster", "color": Color("#fbf3e6"), "pos": Vector2(1415, 920), "smile": false, "sprites": [
		{"tex": SP + "mochi_sprite_wave_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "frames": [0, 1], "fps": 2, "requires": {"home": true}},
		{"tex": SP + "mochi_sprite_wave_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152)}]},
	# Fen：和露露他們一起住河對岸（模範生）。地圖小人是白面的身體換回赭橘色（同一個身體）
	"fen": {"name": "Fen", "species": "fox", "color": Color("#c8642b"), "pos": Vector2(1535, 950), "smile": false, "sprites": [
		{"tex": SP + "fen_sprite_stand_sheet.png", "cols": 1, "frame": Vector2(160, 160), "origin": Vector2(80, 152)}]},
	"popo": {"name": "波波", "species": "penguin", "color": Color("#2f3352"), "pos": Vector2(1475, 935), "sprites": [
		{"tex": SP + "popo_sprite_wave_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152), "frames": [0, 1], "fps": 2, "requires": {"home": true}},
		{"tex": SP + "popo_sprite_wave_sheet.png", "cols": 2, "frame": Vector2(160, 160), "origin": Vector2(80, 152)}]},
	# 車掌：正面、背面（人類規格）；月台上背對小布時用背面
	"conductor": {"name": "車掌", "species": "conductor", "color": Color.BLACK, "pos": Vector2(560, 975), "sprites": [
		{"tex": SP + "conductor_sprite_stand_sheet.png", "cols": 1, "frame": Vector2(384, 416), "origin": Vector2(192, 408)}]},
}
const RESIDENTS := ["baimian", "xiaoji", "tiaoma", "gaga", "zhongzhong", "youyou"]
const MODELS := ["lulu", "mochi", "popo", "fen"]
## 平常不在場的人
const HIDDEN := ["lulu", "mochi", "popo", "fen", "conductor"]

const OBJECTS := {
	"c2_board": {"name": "公告欄", "pos": Vector2(790, 385), "reach_home": 110.0},
	"treatment_door": {"name": "治療室的門", "pos": Vector2(1150, 285)},
	"laundry": {"name": "洗衣房", "pos": Vector2(1170, 560)},
	"tower": {"name": "廣播塔", "pos": Vector2(790, 285)},
	"station": {"name": "月台", "pos": Vector2(230, 935)},
	"fence": {"name": "鐵絲網", "pos": Vector2(880, 795)},
	"dining": {"name": "食堂", "pos": Vector2(790, 695)},
	"c2_bed": {"name": "鐵床", "pos": Vector2(300, 210)},
	"c2_pillow": {"name": "枕頭", "pos": Vector2(240, 222)},
	# 第二天夜晚（跟鼬鼬偷溜）
	"treatment_window": {"name": "治療室的窗戶", "pos": Vector2(1320, 245)},
	"office": {"name": "辦公室", "pos": Vector2(1060, 275)},
	"platform": {"name": "月台", "pos": Vector2(480, 965)},
}
const NIGHT_OBJECTS := ["c2_bed", "c2_pillow"]
const NIGHT_OUT_OBJECTS := ["treatment_window", "office", "platform"]
## 傍晚隔著鐵絲網排隊的位置（沿著地圖上的鐵絲網）
const FENCE_LINE := [Vector2(720, 930), Vector2(775, 870), Vector2(830, 830), Vector2(885, 785),
	Vector2(940, 750), Vector2(995, 720)]
## 外包配樂（docs/chapter2_asset_requests.txt 第 8 節）；腳本裡用 @bgm <名字> 切換
const BGM_DIR := "res://audio/ch2/bgm/ch2_bgm%s.ogg"
const BGM := {
	"town": "01_bleach_town", "evening": "02_evening", "far_shore": "03_far_shore", "dove": "04_dove",
	"correction": "05_correction_time", "night": "08_night", "humming": "09_humming", "nirvana": "10_nirvana",
	"memory": "11_memory", "graduation": "12_graduation", "escape": "13_escape", "next_stop": "14_next_stop",
	"special_love": "15_special_love", "dream": "16_dream",
}
## 只播一次、不循環的曲子
const BGM_ONCE := ["humming", "escape", "special_love"]

## 地圖：game/art/ch2/backgrounds/ch2_bg_town_day.jpg（外包 P0）。鐵絲網另一邊走不過去（BleachTown.BLOCKED）
const WORLD_BOUNDS := Rect2(20, 40, 1560, 975)
## 宿舍的剖面（地圖左上）：夜晚只能在裡面走動
const HOUSE_BOUNDS := Rect2(225, 165, 235, 100)
const HOME_SPOT := Vector2(380, 250)
const PLAZA_SPOT := Vector2(790, 500)

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
var _bgm_name := ""


func _ready() -> void:
	GameState.chapter = 2
	# 標題畫面的「回憶」配樂（第一章的音樂系統，會變慢走音）不能帶進來，不然兩首疊在一起
	Sound.override_bgm("")
	Sound.bgm("")
	Sound.ambience("")
	Sound.set_wear(0)
	tint = CanvasModulate.new()
	add_child(tint)
	town = BleachTown.new()
	add_child(town)
	for id in ACTORS:
		var a := Ch2Interactable.new().setup(id, ACTORS[id])
		add_child(a)
		actors[id] = a
	for id in OBJECTS:
		var data: Dictionary = OBJECTS[id].duplicate()
		data["kind"] = "obj"
		var o := Ch2Interactable.new().setup(id, data)
		add_child(o)
		actors[id] = o
	player = Player.new()
	player.can_move = false
	if town.has_map():
		player.blocked = PackedVector2Array(BleachTown.BLOCKED)
	add_child(player)
	Dialogue.portrait_state = _portrait_state
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
	Dialogue.bgm_requested.connect(_bgm)
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


## 配樂：town（漂白鎮）、dove（和平鴿）、correction（矯正時間）；"" 停止
func _bgm(name: String) -> void:
	if name == _bgm_name:
		return
	_bgm_name = name
	var path: String = BGM_DIR % BGM.get(name, "") if name != "" else ""
	Audio.play_music(path, not name in BGM_ONCE, -3.0)


## 小遊戲時換配樂，結束後換回來
func _with_bgm(name: String, game: Node, method := "play") -> Variant:
	var prev := _bgm_name
	Motif.play(self, "start")          # 小遊戲開始：主旋律的開頭兩個音
	_bgm(name)
	var r = await game.call(method)
	_bgm(prev)
	# 偷溜（sneak）回傳「被抓到」；其他小遊戲做完就算過關
	Motif.play(self, "fail" if r is bool and r else "clear")
	return r


func _exit_tree() -> void:
	Audio.stop_music()
	Dialogue.portrait_state = Callable()
	if Dialogue.event_requested.is_connected(_on_event):
		Dialogue.event_requested.disconnect(_on_event)
	if Dialogue.bgm_requested.is_connected(_bgm):
		Dialogue.bgm_requested.disconnect(_bgm)


func _to_title() -> void:
	Dialogue.set_bg("none")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ───────────────────────── 章節流程 ─────────────────────────

func run_chapter() -> void:
	_set_phase("prologue")
	_layout("arrival")
	player.position = Vector2(250, 975)
	await Dialogue.run("c2_prologue")
	await Dialogue.run("c2_arrival")
	await _fade_to(1.0)
	_layout("day")
	player.position = PLAZA_SPOT
	await _fade_to(0.0)
	await Dialogue.run("c2_report")
	await Dialogue.run("c2_apology")
	await _fade_to(1.0)
	player.position = Vector2(620, 560)
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
	player.position = Vector2(620, 560)
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
	player.position = Vector2(850, 830)
	await _fade_to(0.0)
	await Dialogue.run("c2_evening")
	await _fade_to(1.0)
	_set_tint("night")
	_layout("rollcall")
	player.position = Vector2(950, 520)
	await _fade_to(0.0)
	_bgm("dove")
	await Dialogue.run("c2_rollcall")
	await _fade_to(1.0)
	_layout("night")
	player.position = HOME_SPOT
	player.bounds = HOUSE_BOUNDS
	await _fade_to(0.0)
	_bgm("")
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
	player.position = Vector2(790, 740)
	await _fade_to(0.0)
	await Dialogue.run("c2_breakfast")
	await _fade_to(1.0)
	player.position = Vector2(1250, 640)
	await _fade_to(0.0)
	await Dialogue.run("c2_scrub")
	_layout("day")
	await _fade_to(1.0)
	player.position = Vector2(300, 600)
	await _fade_to(0.0)
	await Dialogue.run("c2_find")
	await Dialogue.run("c2_treatment_1")
	_layout("day")
	await _fade_to(1.0)
	player.position = Vector2(500, 560)
	_set_phase("day2_explore")
	await _fade_to(0.0)
	busy = false
	player.can_move = true


## 第二天傍晚：第二晚點名（名單上的「遙」）→ 宿舍 → 鼬鼬敲窗
func _day2_evening() -> void:
	await _fade_to(1.0)
	_set_tint("night")
	_layout("rollcall")
	player.position = Vector2(950, 520)
	await _fade_to(0.0)
	_bgm("dove")
	await Dialogue.run("c2_rollcall_2")
	await _fade_to(1.0)
	_layout("night")
	player.position = HOME_SPOT
	player.bounds = HOUSE_BOUNDS
	await _fade_to(0.0)
	_bgm("")
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
	player.position = Vector2(850, 800)
	await _fade_to(0.0)
	await Dialogue.run("c2_popo_fence")
	await _fade_to(1.0)
	_layout("day")
	player.position = Vector2(300, 600)
	await _fade_to(0.0)
	await Dialogue.run("c2_confession")
	await Dialogue.run("c2_trim")
	GameState.set_flag("c2_trimmed")
	await _fade_to(1.0)
	_layout("day")
	_set_tint("evening")
	actors.xiaoji.position = Vector2(920, 755)
	player.position = Vector2(830, 800)
	_set_phase("day3_explore")
	await _fade_to(0.0)
	busy = false
	player.can_move = true


func _graduation() -> void:
	_set_phase("graduation")
	await _fade_to(1.0)
	_layout("day")
	player.position = Vector2(620, 560)
	await _fade_to(0.0)
	await Dialogue.run("c2_chairs")
	await _fade_to(1.0)
	_layout("graduation")
	player.position = Vector2(620, 560)
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
	GameState.meta.ch2_flags = GameState.flags.duplicate()
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
		var it: Ch2Interactable = player.nearest()
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
	var it: Ch2Interactable = player.nearest()
	var key := GameState.interact_key_label()
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
			await _with_bgm("", game)
		"roll_list":
			var r := RollList.new()
			add_child(r)
			await r.show_and_wait()
		"c2_take_models":
			for id in MODELS:
				actors[id].visible = false
		"c2_dove_appears":
			Motif.play(self, "whistle", -6.0)   # 和平鴿的口哨：主旋律，最後一個音往上滑
			_bgm("dove")
			var dove: Ch2Interactable = actors.dove
			dove.visible = true
			dove.position = Vector2(560, 935)
		"scrub":
			var sc := Scrub.new()
			add_child(sc)
			await _with_bgm("correction", sc)
		"find_1", "find_2", "find_3":
			var fo := FindOdd.new()
			add_child(fo)
			var n := int(event_name.right(1))
			_bgm("correction")
			Motif.play(self, "start")
			var found: bool = await fo.play(n)
			Motif.play(self, "clear" if found else "fail")
			GameState.set_flag("c2_found_%d" % n, found)
		"treatment_hold":
			var h := HoldEndure.new()
			h.questions = [["第一題。你為什麼沒有笑？", 3.0], ["第二題。你在看誰？", 4.0],
				["第三題。你還記得，遙是誰嗎？", 5.0]]
			add_child(h)
			await _with_bgm("dove", h)
		"sneak":
			var sn := Sneak.new()
			add_child(sn)
			if await _with_bgm("dove", sn):
				GameState.set_flag("c2_sneak_caught")
				GameState.add_conduct(-10)
		"photo_1", "photo_2", "photo_nirvana", "silhouette":
			# 照片在 layer 25，對話層的背景圖（layer 50）會蓋住它：投影期間不要有背景圖
			Dialogue.set_bg("none")
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
			var dove: Ch2Interactable = actors.dove
			dove.visible = true
			dove.position = Vector2(420, 965)
			dove.opts["unmasked"] = true
			dove.queue_redraw()
			actors.conductor.visible = true
			actors.conductor.position = Vector2(600, 965)
			player.position = Vector2(250, 960)
		"c2_dove_mask_on":
			Motif.play(self, "whistle", -8.0)
			actors.dove.opts["unmasked"] = false
			actors.dove.queue_redraw()
		"c2_popo_fence":
			actors.popo.visible = true
			actors.popo.position = Vector2(1240, 935)
			# Fen 跟在波波後面（把他從鐵絲網拉開的人）
			actors.fen.visible = true
			actors.fen.position = Vector2(1300, 950)
			for id in ["lulu", "mochi"]:
				actors[id].visible = true
			actors.xiaoji.position = Vector2(920, 755)
		"c2_dove_hug":
			actors.dove.position = Vector2(860, 735)
		"confession_1", "confession_2":
			var cf := Confession.new()
			cf.cards = CARDS_DONE if event_name == "confession_1" else CARDS_ORPHAN
			add_child(cf)
			await _with_bgm("correction", cf)
		"trim_1", "trim_2", "trim_3":
			var tr := Trim.new()
			tr.quills = {"trim_1": Trim.TOTAL, "trim_2": 6, "trim_3": 1}[event_name]
			tr.leave = {"trim_1": 6, "trim_2": 1, "trim_3": 0}[event_name]
			add_child(tr)
			await _with_bgm("correction", tr)
			# 剪完之後的樣子（留下最後一根時停在 1 根）
			actors.xiaoji.opts["quills"] = {"trim_1": 5, "trim_2": 1, "trim_3": 0}[event_name]
		"c2_mochi_cross":
			actors.mochi.visible = true
			actors.mochi.position = Vector2(965, 740)
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
			await _with_bgm("", ch)
		"long_hold", "special_hold":
			var lh := HoldEndure.new()
			lh.questions = [["（他沒有問問題。他一直按。）", 10.0 if event_name == "long_hold" else 15.0]]
			add_child(lh)
			await _with_bgm("dove", lh)
		"c2_graduation_layout":
			pass
		"restuff_1", "restuff_2":
			var rs := Restuff.new()
			rs.step = 0 if event_name == "restuff_1" else 2
			rs.steps = 2 if event_name == "restuff_1" else 4
			add_child(rs)
			await _with_bgm("correction", rs)
		"c2_tiaoma_gone":
			actors.tiaoma.visible = false
		"c2_mask_crack":
			actors.dove.opts["crack"] = 2.0
			actors.dove.queue_redraw()
		"c2_fates":
			_compute_fates()
			_refresh_looks()
		"c2_special_love_cost":
			_special_love_cost()
		"c2_train_arrives":
			town.train = true
			town.queue_redraw()
		"c2_ending_cg":
			# 結尾的車廂：上車的人每人一層（外包 CG-20 分層）
			var layers := ["res://art/ch2/backgrounds/ch2_bg_ending_color.jpg"]
			# Fen 的分層還沒有圖（缺圖時自動略過）：見 docs/chapter2_asset_requests.txt 追加需求
			var aboard := ["pip", "lulu", "mochi", "popo", "fen", "conductor"]
			for id in ["baimian", "zhongzhong", "gaga", "youyou"]:
				if GameState.has("fate_%s_aboard" % id):
					aboard.append(id)
			if GameState.has("fate_xiaoji_aboard"):
				aboard.append("xiaoji_onequill" if GameState.has("xiaoji_last_quill") else "xiaoji_bald")
			for id in aboard:
				layers.append("res://art/ch2/cg/ending_layers/ch2_cg20_%s.png" % id)
			Dialogue.set_bg_layers(layers)
		"c2_fence_lineup":
			# 隔著鐵絲網排隊；對岸的模範生站在陽台上揮手
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = FENCE_LINE[k]
				actors[RESIDENTS[k]].visible = true
			for id in MODELS:
				actors[id].position = ACTORS[id].pos
				actors[id].visible = true
			actors.dove.visible = false
	Dialogue.event_done.emit()


# ───────────────────────── 場景配置 ─────────────────────────

func _layout(mode: String) -> void:
	for id in ACTORS:
		var a: Ch2Interactable = actors[id]
		a.position = ACTORS[id].pos
		a.visible = not id in HIDDEN
	for id in OBJECTS:
		actors[id].visible = not id in NIGHT_OBJECTS and not id in NIGHT_OUT_OBJECTS
	_refresh_looks()
	match mode:
		"arrival":
			# 月台：模範生在左邊，漂白鎮的六個居民在右邊排成一排
			for k in MODELS.size():
				actors[MODELS[k]].position = Vector2(300 + k * 45, 980)
				actors[MODELS[k]].visible = true
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = Vector2(470 + k * 48, 975 - (k % 2) * 10)
			actors.dove.visible = false
		"rollcall":
			# 點名：所有人在廣場排成一排，第 8 個位置空著
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = Vector2(650 + k * 50, 520)
			actors.dove.position = Vector2(790, 440)
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
				actors[MODELS[k]].position = Vector2(750 + k * 40, 420)
			for k in RESIDENTS.size():
				actors[RESIDENTS[k]].position = Vector2(640 + k * 55, 500 + (k % 2) * 8)
			actors.baimian.position = Vector2(950, 450)
			actors.dove.position = Vector2(600, 450)
			actors.dove.opts["clap"] = true
		"night_out":
			# 偷溜：只有鼬鼬跟著你
			for id in ACTORS:
				actors[id].visible = false
			for id in OBJECTS:
				actors[id].visible = id in NIGHT_OUT_OBJECTS
			actors.youyou.visible = true
			actors.youyou.position = Vector2(880, 765)


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
	actors.dove.opts["clap"] = false
	town.incinerator_open = GameState.day >= 3
	town.queue_redraw()
	if GameState.has("c2_trimmed"):
		actors.xiaoji.opts["quills"] = 1 if GameState.has("xiaoji_last_quill") else 0
	# 畢業典禮：條碼被洗到一條斑紋都不剩；被縫完的小棘全身是白的
	if phase == "graduation":
		actors.tiaoma.opts["stripes"] = 0
	actors.xiaoji.opts["white"] = GameState.has("fate_xiaoji_graduated")
	for id in ["tiaoma", "gaga", "youyou", "dove", "xiaoji"]:
		actors[id].queue_redraw()


## 立繪的狀態（檔名中間那一段，見 Dialogue.portrait_path）：跟地圖上的小人同一套劇情狀態
func _portrait_state(id: String) -> String:
	if id == "pip":
		# 第二天夜晚的治療室之後，手腕上有兩圈紅痕
		return "marks" if GameState.day >= 3 else ""
	if id in ["staff", "conductor"]:
		return "stand"
	if not actors.has(id):
		return ""
	var o: Dictionary = actors[id].opts
	match id:
		"xiaoji":
			if o.get("white", false):
				return "white"
			if GameState.has("c2_tied"):
				return "tied"  # 反省會：被綁在講台的椅子上
			return {5: "a", 1: "onequill", 0: "bald"}.get(o.get("quills", 5), "a")
		"tiaoma":
			var n: int = o.get("stripes", 3)
			if n == 0:
				return "s0mark" if GameState.has("tiaoma_color_left") else "s0"
			return "s%d" % n
		"gaga":
			return "a" if o.get("sewn", true) else "unsewn"
		"youyou":
			# 逃上火車的時候，紅毛線被扯斷了一截
			if GameState.has("stabbed_mask") and GameState.has("fate_youyou_aboard"):
				return "broken"
			return "a" if o.get("thread", true) else "nothread"
		"dove":
			if o.get("unmasked", false):
				return "back"
			return "cracked" if o.get("crack", 1.0) > 1.0 else "a"
	return "a"


func _close_overlay() -> void:
	if overlay != null:
		overlay.queue_free()
		overlay = null


## 每個時段的配樂
const PHASE_BGM := {"prologue": "", "day1_explore": "town", "day1_night": "", "day2_morning": "town",
	"day2_explore": "town", "night_out_2": "", "day3_morning": "town", "day3_explore": "town",
	"graduation": "dove", "ended": ""}


## 每個時段的環境音（循環、很小聲）：白天是遠方的洗衣機和哨音，偷溜的夜晚是負片世界的高頻嗡鳴
const PHASE_AMBIENCE := {"day1_explore": "ambience", "day2_explore": "ambience", "day3_explore": "ambience",
	"night_out_2": "negative_hum"}
var _ambience: AudioStreamPlayer


func _set_ambience(name: String) -> void:
	if _ambience == null:
		_ambience = AudioStreamPlayer.new()
		_ambience.volume_db = -15.0 + Audio.music_db()
		add_child(_ambience)
	_ambience.stop()
	var st := Sfx.stream(name) if name != "" else null
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		st.loop = true
	if st:
		_ambience.stream = st
		_ambience.play()


func _set_phase(p: String) -> void:
	phase = p
	if PHASE_BGM.has(p):
		_bgm(PHASE_BGM[p])
	_set_ambience(PHASE_AMBIENCE.get(p, ""))
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


## 有外包時段地圖的時候，地圖本身已經上好色：只把角色稍微調暗，讓他們跟地圖的光線一致
const TINTS_WITH_MAP := {
	"day": Color(1, 1, 1),
	"evening": Color(0.93, 0.93, 0.97),
	"night": Color(0.8, 0.8, 0.88),
	"negative": Color(1, 1, 1),
}


func _set_tint(name: String) -> void:
	town.set_time(name)
	tint.color = TINTS_WITH_MAP[name] if town.has_map() and town.has_time_map(name) else TINTS[name]


func _fade_to(alpha: float) -> void:
	if GameState.fast:
		fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, 0.6)
	await tw.finished
