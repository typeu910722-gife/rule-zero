extends Node
## 全域遊戲狀態：天數、膽量、鎮長懷疑值、旗標。
## 旗標同時用來記錄「秘密」與帶入下一章的選擇（見 docs/script/chapter1.md 附錄 A）。

signal changed

## 本章的秘密（結算畫面直接列出名稱）
const SECRETS := {
	"got_button": "灰色鈕扣",
	"mirror_1": "鏡中的人影",
	"tag_off": "名牌背面的字",
	"asked_past": "問「以前」",
	"night_out": "夜晚的小鎮",
	"found_lulu_bow": "黃色蝴蝶結",
	"found_fox_tail": "狐狸尾巴",
	"lulu_song": "露露哼的另一首歌",
	"mochi_remembers": "麻糬本來的名字",
	"mirror_knock": "鏡子裡的回應",
	"got_key": "鐘塔的鑰匙",
}

## 日記裡「記下的事」：謎題線索會自動記錄，玩家不用靠記憶力
const CLUES := {
	"lulu_slip": "露露叫我「小遙」，然後自己忘記了。",
	"met_mochi": "麻糬的名牌是空白的。",
	"tag_off": "名牌背面繡著一個被剪掉一半的字：「辶」。",
	"blank_letter": "波波給了我一封沒有寫收件人的信。",
	"found_lulu_bow": "森林裡有一隻垂耳，綁著黃色的蝴蝶結。露露現在的是綠色。",
	"found_sheep": "森林裡，舊的小綿羊腳上掛著牌子：No.46。",
	"heard_47": "Fen 說：我是第四十幾個小布。",
	"bell_heard": "第三天下午三點，鐘會響。鎮長會來。",
	"mochi_remembers": "麻糬好像想起了自己名字的第一個音。",
	"got_key": "Fen 給了我鐘塔的鑰匙。他說：三點以前。",
}

## 第一章的結局。只有「第零條」會結束本章，其他結局都會回到火車上，開始下一輪。
const ENDINGS := {
	"good_kid": {"title": "好孩子", "desc": "你守住了每一條守則。第四天早上，你站在月台上，和大家一起對新來的小布說：「歡迎回來。」"},
	"early": {"title": "提早修理", "desc": "你知道得太多、太快了。鎮長在第二天晚上來敲門。"},
	"brave": {"title": "勇敢", "desc": "你衝出去了。鎮長說，你這次比上次還要勇敢一點。"},
	"betrayed": {"title": "被出賣", "desc": "露露是好孩子。好孩子不可以說謊。"},
	"hesitate": {"title": "露露猶豫了", "desc": "露露沒有說出你在哪裡。被帶走的，是她。"},
	"mochi": {"title": "麻糬的名字", "desc": "麻糬想起了自己的名字。修理室的門，為你們兩個打開了。"},
	"zero": {"title": "第零條", "desc": "鐘塔的牆上，寫著第零條。你只看到了一半。"},
}
const ENDING_ORDER := ["good_kid", "early", "brave", "betrayed", "hesitate", "mochi", "zero"]
## 這一輪看到的事 → 下一輪「記得」的事（對話裡用 mem.xxx 判斷）
const MEMORY_FROM_FLAGS := {
	"heard_47": "knows_47",
	"found_lulu_bow": "knows_bow",
	"lulu_slip": "knows_haruka",
	"saw_resident": "knows_night",
	"mirror_1": "knows_mirror",
	"tag_off": "knows_tag",
	"found_sheep": "knows_sheep",
	"bell_heard": "knows_bell",
	"mochi_remembers": "knows_mochi",
	"got_key": "knows_key",
}
## 會被「修理」的結局：上一輪最後記下的事會被剪掉
const REPAIR_ENDINGS := ["early", "brave", "betrayed", "mochi"]
const FIRST_LOOP := 47

const MAX_COURAGE := 2

var day := 1
var courage := MAX_COURAGE
var suspicion := 0
var flags := {}
var objective := ""
## 自動測試用：跳過等待與小遊戲
var fast := false
var auto_choices: Array = []
var fast_rhythm_streak := 0
var resume_on_start := false

## 存檔：每天早上自動存一次（檢查點）。meta 是跨周目的記錄，標題畫面會依它改變。
const SAVE_PATH := "user://save.json"
const META_PATH := "user://meta.json"
var save_dir := "user://"
var checkpoint := ""
var meta := {"runs": 0, "chapters_done": 0, "loop": FIRST_LOOP, "loops_done": 0,
	"endings": [], "last_ending": "", "memory": {}, "past_clues": [], "cut_clues": []}
## 結局之後重新載入場景時，直接開始下一輪（不經過標題畫面）
var pending_loop_start := false
## 開場 Logo 影片這次開啟遊戲是否已經播過
var intro_played := false
var font: Font


func _ready() -> void:
	_setup_input()
	_setup_font()
	reset()
	load_meta()


func reset() -> void:
	day = 1
	courage = MAX_COURAGE
	suspicion = 0
	flags = {"tag_on": true}
	objective = ""
	changed.emit()


func has(flag: String) -> bool:
	return bool(flags.get(flag, false))


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	changed.emit()


func add_suspicion(amount: int) -> void:
	suspicion = clampi(suspicion + amount, 0, 100)
	changed.emit()


func spend_courage(amount: int) -> bool:
	if courage < amount:
		return false
	courage -= amount
	changed.emit()
	return true


func new_day() -> void:
	day += 1
	courage = MAX_COURAGE
	changed.emit()


func set_objective(text: String) -> void:
	objective = text
	changed.emit()


func player_name() -> String:
	return "小布" if has("tag_on") else "新朋友"


# ───────── 輪迴 ─────────

## 中文數字（1～99），用在「第四十七個小布」這類台詞
static func cn(n: int) -> String:
	const D := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n < 10:
		return D[n]
	var tens := n / 10
	var ones := n % 10
	return ("" if tens == 1 else D[tens]) + "十" + ("" if ones == 0 else D[ones])


## 台詞裡的 {name}、{loop}（這一輪是第幾個）、{prev}（上一個）、{stamps}（車票上的戳章數）
func fill(text: String) -> String:
	var n := loop_number()
	return text.replace("{name}", player_name()).replace("{loop}", cn(n)).replace("{prev}", cn(n - 1)) \
		.replace("{stamps}", cn(n - FIRST_LOOP + 1))


func loop_number() -> int:
	return int(meta.get("loop", FIRST_LOOP))


## 是不是第一輪以後（玩家帶著上一輪的記憶）
func is_repeat() -> bool:
	return loop_number() > FIRST_LOOP


func remembers(key: String) -> bool:
	return bool(meta.get("memory", {}).get(key, false))


## 一輪結束：記下結局、把這一輪看到的事帶到下一輪
func finish_loop(ending: String) -> void:
	var endings: Array = meta.get("endings", [])
	if not ending in endings:
		endings.append(ending)
	meta.endings = endings
	meta.last_ending = ending
	meta.loops_done = int(meta.get("loops_done", 0)) + 1
	var memory: Dictionary = meta.get("memory", {})
	for f in MEMORY_FROM_FLAGS:
		if has(f):
			memory[MEMORY_FROM_FLAGS[f]] = true
	memory["end_" + ending] = true
	meta.memory = memory
	var past: Array = meta.get("past_clues", [])
	var new_clues: Array = []
	for k in CLUES:
		if has(k) and not k in past:
			past.append(k)
			new_clues.append(k)
	meta.past_clues = past
	# 被修理：最後記下的那一頁被剪掉
	if ending in REPAIR_ENDINGS and not new_clues.is_empty():
		var cut: Array = meta.get("cut_clues", [])
		cut.append(new_clues[-1])
		meta.cut_clues = cut
	if ending == "zero":
		meta.chapters_done = maxi(int(meta.get("chapters_done", 0)), 1)
	save_meta()
	delete_save()


## 開始下一輪：車票多一個戳章，一切從第一天重來
func start_next_loop() -> void:
	meta.loop = loop_number() + 1
	save_meta()
	reset()
	pending_loop_start = true


func secrets_found() -> Array:
	return SECRETS.keys().filter(func(k): return has(k))


func threads_earned() -> int:
	return maxi(1, secrets_found().size() / 3)


## 條件語法：flag、!flag、sus>=40、sus<20、courage>=1、day==2
func check(cond: String) -> bool:
	cond = cond.strip_edges()
	if cond == "":
		return true
	if cond.begins_with("!"):
		return not check(cond.substr(1))
	if cond.begins_with("mem."):
		return remembers(cond.substr(4))
	if cond.begins_with("last."):
		return str(meta.get("last_ending", "")) == cond.substr(5)
	if cond.begins_with("end."):
		return cond.substr(4) in meta.get("endings", [])
	for op in [">=", "<=", "==", ">", "<"]:
		var i := cond.find(op)
		if i > 0:
			var left := _value(cond.left(i))
			var right := int(cond.substr(i + op.length()))
			match op:
				">=": return left >= right
				"<=": return left <= right
				"==": return left == right
				">": return left > right
				"<": return left < right
	return has(cond)


# ───────── 存檔 ─────────

func _path(name: String) -> String:
	return save_dir.path_join(name.get_file())


func save_game(cp: String) -> void:
	checkpoint = cp
	var data := {"version": 1, "checkpoint": cp, "day": day, "courage": courage,
		"suspicion": suspicion, "flags": flags}
	var f := FileAccess.open(_path(SAVE_PATH), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func has_save() -> bool:
	return FileAccess.file_exists(_path(SAVE_PATH))


func load_game() -> bool:
	var f := FileAccess.open(_path(SAVE_PATH), FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	checkpoint = data.get("checkpoint", "")
	day = int(data.get("day", 1))
	courage = int(data.get("courage", MAX_COURAGE))
	suspicion = int(data.get("suspicion", 0))
	flags = data.get("flags", {"tag_on": true})
	changed.emit()
	return checkpoint != ""


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(_path(SAVE_PATH))


func load_meta() -> void:
	var f := FileAccess.open(_path(META_PATH), FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			meta[k] = data[k]


func save_meta() -> void:
	var f := FileAccess.open(_path(META_PATH), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta, "\t"))


func _value(key: String) -> int:
	match key:
		"sus": return suspicion
		"courage": return courage
		"day": return day
		"loop": return int(meta.get("loop", FIRST_LOOP))
	return int(flags.get(key, 0))


func _setup_input() -> void:
	var binds := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_E, KEY_SPACE, KEY_ENTER],
		"menu": [KEY_TAB, KEY_ESCAPE],
		"debug": [KEY_F3],
	}
	for action in binds:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _setup_font() -> void:
	# 內建 Noto Sans TC（只含遊戲用到的字，tools/subset_font.py 產生）；缺字時退回系統字型。
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray([
		"Noto Sans CJK TC", "Noto Sans TC", "Microsoft JhengHei", "PingFang TC", "sans-serif",
	])
	var bundled := load("res://fonts/NotoSansTC-Game.otf") as FontFile
	if bundled:
		bundled.fallbacks = [sys]
		font = bundled
	else:
		font = sys
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	var bold := FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 0.9
	theme.set_font("bold_font", "RichTextLabel", bold)
	get_tree().root.theme = theme
	# 網頁版沒有系統字型可借：所有 Control 的預設字型也改成內建字型
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 22
	var default_theme := ThemeDB.get_default_theme()
	if default_theme:
		default_theme.default_font = font
		default_theme.set_font("bold_font", "RichTextLabel", bold)
