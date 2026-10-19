extends Node
## 全域遊戲狀態：天數、膽量、懷疑值、旗標。
## 旗標同時用來記錄「秘密」與帶入下一章的選擇（見 docs/script/chapter1.md 附錄 A）。

signal changed

## 本章 8 個秘密（決定章末獲得的線頭數）
const SECRETS := {
	"got_button": "灰色鈕扣",
	"mirror_1": "鏡中的人影",
	"tag_off": "名牌背面的字",
	"asked_past": "問「以前」",
	"night_out": "夜晚的小鎮",
	"found_lulu_bow": "黃色蝴蝶結",
	"found_fox_tail": "狐狸尾巴",
	"lulu_song": "露露哼的另一首歌",
}

## 第二章「漂白鎮」的 8 個秘密（docs/script/chapter2.md 附錄 B）
const SECRETS_2 := {
	"ch2_referral": "轉介單的空白事由",
	"xiaoji_mask_crack": "小棘的笑容",
	"answered_haruka": "替「遙」回答",
	"nirvana_clipboard": "涅槃計畫的夾板",
	"dove_first_page": "愛的日記的第一頁",
	"overheard_conductor": "月台上的兩個人",
	"tiaoma_color_left": "條碼的最後一句話",
	"mochi_name": "麻糬的本名",
}

## 日記裡「記下的事」：謎題線索會自動記錄，玩家不用靠記憶力
const CLUES := {
	"lulu_slip": "露露叫我「小遙」，然後自己忘記了。",
	"met_mochi": "麻糬的名牌是空白的。",
	"tag_off": "名牌背面繡著一個被剪掉一半的字：「辶」。",
	"blank_letter": "波波給了我一封沒有寫收件人的信。",
	"found_lulu_bow": "森林裡有一隻垂耳，綁著黃色的蝴蝶結。露露現在的是綠色。",
	"found_sheep": "森林裡，舊的小綿羊腳上掛著牌子：No.46。",
	"heard_47": "Fen 說：「你是第四十七個小布。」",
	# 第二章
	"ch2_referral": "我的轉介單寫著「壞孩子」。筆跡跟其他字不一樣，角落蓋著「校外參訪」。",
	"met_baimian": "屋頂上的白臉狐狸叫我「遙」。他說：「你還活著啊。」",
	"met_tiaoma": "條碼身上有 3 條斑紋。",
	"met_gaga": "嘎嘎在桌上寫：「你以前也被拍過。很多次。」",
	"met_youyou": "鼬鼬說：點名之後，鐵絲網會關電十五分鐘。",
	"saw_eighth_name": "點名的名單上有第 8 個名字，被墨水塗掉了。",
	"tiaoma_1": "條碼身上只剩 1 條斑紋。",
	"photo_1": "嘎嘎的照片：白臉狐狸把「遙」的書包倒進垃圾桶。",
	"photo_2": "嘎嘎的照片：黑色刺蝟拿著波波寫給露露的信。",
	"photo_nirvana": "嘎嘎燒壞的照片：很多張床，人類的小孩，牌子寫著「涅槃」。其中一個頭髮是捲的。",
	"baimian_dove_past": "白面說：和平鴿以前也坐過那張小椅子。面具上的裂痕，是上一個教官的。",
	"answered_haruka": "點名念到「遙」的時候，我回答了「到」。",
	"dove_first_page": "愛的日記最前面一頁：「今天，教官沒有醒來。我替他戴上了面具。很合。」",
	"nirvana_clipboard": "夾板：涅槃計畫區第七期。「意識：已處分　身體：維持中」。",
	"overheard_conductor": "月台上，和平鴿和車掌在說話。車掌的哥哥選了和平鴿。",
}

## 第二章：操行成績單（第一章隱藏的懷疑值，這章攤開給你看）
const CONDUCT_START := 100

const MAX_COURAGE := 2

var day := 1
var courage := MAX_COURAGE
var suspicion := 0
var chapter := 1
var conduct := CONDUCT_START
var flags := {}
var objective := ""
## 自動測試用：跳過等待與小遊戲
var fast := false
var auto_choices: Array = []
var fast_rhythm_streak := 0
var fast_apology_take := false
var fast_scrub_keep := false
var fast_sneak_caught := false
var resume_on_start := false

## 存檔：每天早上自動存一次（檢查點）。meta 是跨周目的記錄，標題畫面會依它改變。
const SAVE_PATH := "user://save.json"
const META_PATH := "user://meta.json"
var save_dir := "user://"
var checkpoint := ""
const PAD_DEADZONE := 0.25
## 最後使用的輸入裝置："keyboard"、"pad"、"touch"（"" ＝還沒操作過）
var last_device := ""
var meta := {"runs": 0, "chapters_done": 0}
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
	chapter = 1
	conduct = CONDUCT_START
	flags = {"tag_on": true}
	objective = ""
	changed.emit()


## 進入第二章：帶著第一章的旗標（露露的狀態、狐狸尾巴……），天數與膽量重來
func start_chapter2() -> void:
	chapter = 2
	day = 1
	courage = MAX_COURAGE
	conduct = CONDUCT_START
	flags["tag_on"] = true
	objective = ""
	changed.emit()


func add_conduct(amount: int) -> void:
	conduct = clampi(conduct + amount, 0, 100)
	changed.emit()


func secret_defs() -> Dictionary:
	return SECRETS if chapter == 1 else SECRETS_2


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


func secrets_found() -> Array:
	return secret_defs().keys().filter(func(k): return has(k))


func threads_earned() -> int:
	return maxi(1, secrets_found().size() / 3)


## 條件語法：flag、!flag、sus>=40、sus<20、courage>=1、day==2、conduct>=60；用 & 串接多個條件
func check(cond: String) -> bool:
	cond = cond.strip_edges()
	if cond == "":
		return true
	if "&" in cond:
		for part in cond.split("&"):
			if not check(part):
				return false
		return true
	if cond.begins_with("!"):
		return not check(cond.substr(1))
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
	var data := {"version": 2, "checkpoint": cp, "chapter": chapter, "day": day, "courage": courage,
		"suspicion": suspicion, "conduct": conduct, "flags": flags}
	_write_json(_path(SAVE_PATH), data)


func has_save() -> bool:
	return FileAccess.file_exists(_path(SAVE_PATH)) or FileAccess.file_exists(_path(SAVE_PATH) + ".bak")


func load_game() -> bool:
	var data = _read_json(_path(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	checkpoint = data.get("checkpoint", "")
	day = int(data.get("day", 1))
	courage = int(data.get("courage", MAX_COURAGE))
	suspicion = int(data.get("suspicion", 0))
	chapter = int(data.get("chapter", 1))
	conduct = int(data.get("conduct", CONDUCT_START))
	flags = data.get("flags", {"tag_on": true})
	changed.emit()
	return checkpoint != ""


func delete_save() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_path(SAVE_PATH) + suffix):
			DirAccess.remove_absolute(_path(SAVE_PATH) + suffix)


func load_meta() -> void:
	var data = _read_json(_path(META_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			meta[k] = data[k]


func save_meta() -> void:
	_write_json(_path(META_PATH), meta)


## 安全寫檔：先寫 .tmp、讀回確認，再把舊檔留成 .bak 後換上新檔。
## 手機在寫到一半被系統關掉時，最多只會失去這一次存檔，不會把舊存檔弄壞。
func _write_json(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("存檔失敗：無法寫入 %s" % tmp)
		return false
	f.store_string(text)
	f.close()
	if typeof(_parse_file(tmp)) != TYPE_DICTIONARY:
		push_warning("存檔失敗：%s 讀回來不完整" % tmp)
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


## 讀檔：主檔壞掉或不見時，改讀上一次的 .bak。
func _read_json(path: String) -> Variant:
	var data = _parse_file(path)
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return _parse_file(path + ".bak")


func _parse_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return null
	return json.data


func _value(key: String) -> int:
	match key:
		"sus": return suspicion
		"courage": return courage
		"day": return day
		"conduct": return conduct
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
	# 手把（Xbox 配置；PlayStation 為 ✕／OPTIONS，Switch 為 B／＋，Godot 會自動對應）
	var pad_buttons := {
		"move_left": [JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_BUTTON_DPAD_RIGHT],
		"move_up": [JOY_BUTTON_DPAD_UP],
		"move_down": [JOY_BUTTON_DPAD_DOWN],
		"interact": [JOY_BUTTON_A],
		"menu": [JOY_BUTTON_START, JOY_BUTTON_BACK],
	}
	var pad_axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0],
		"move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0],
		"move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in binds:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, PAD_DEADZONE if action in pad_axes else 0.5)
		for key in binds[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button in pad_buttons.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = button
			InputMap.action_add_event(action, jb)
		if action in pad_axes:
			var jm := InputEventJoypadMotion.new()
			jm.axis = pad_axes[action][0]
			jm.axis_value = pad_axes[action][1]
			InputMap.action_add_event(action, jm)


## 記住玩家最後用的是鍵盤、手把還是觸控，畫面上的按鍵提示跟著換
func _input(event: InputEvent) -> void:
	var dev := last_device
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > PAD_DEADZONE):
		dev = "pad"
	elif event is InputEventKey:
		dev = "keyboard"
	elif event is InputEventScreenTouch:
		dev = "touch"
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		dev = "keyboard"
	last_device = dev


## 畫面上的操作說明依裝置改寫：原文是鍵盤版，手把、觸控換成對應的說法。
## 長的句子放前面，避免先被短的規則換掉一半。
const HINT_RULES := [
	# [鍵盤原文, 手把, 觸控]
	["按住 E／空白鍵（手機：按住畫面）", "按住 A", "按住畫面"],
	["按 E／空白鍵（手機：點畫面）", "按 A", "點畫面"],
	["按 E／空白鍵，或點一下畫面 關閉", "按 A 關閉", "點一下畫面關閉"],
	["（按 E／點畫面）", "（按 A）", "（點畫面）"],
	["點畫面／按 E", "按 A", "點畫面"],
	["按 E／點畫面", "按 A", "點畫面"],
	["拖曳刷子／按住 E", "按住 A", "拖曳刷子"],
	["點刺／按 E", "按 A", "點刺"],
	["Tab / Esc 關閉", "START 關閉", "點「日記」關閉"],
	["（Tab）", "（START）", ""],
]


func hint(text: String) -> String:
	var col: int = {"pad": 1, "touch": 2}.get(_hint_device(), 0)
	if col == 0:
		return text
	for rule in HINT_RULES:
		text = text.replace(rule[0], rule[col])
	return text


## 手機版面：觸控操作時字級加大、按鈕加大（force_touch_ui：截圖與測試用）
var force_touch_ui := false


func touch_ui() -> bool:
	return force_touch_ui or _hint_device() == "touch"


func _hint_device() -> String:
	if force_touch_ui:
		return "touch"
	if last_device == "" and DisplayServer.is_touchscreen_available():
		return "touch"
	return last_device


## 互動鍵的提示文字（「E：公告欄」「A：公告欄」「互動：公告欄」）
func interact_key_label() -> String:
	match _hint_device():
		"pad": return "A"
		"touch": return "互動"
	return "E"


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
