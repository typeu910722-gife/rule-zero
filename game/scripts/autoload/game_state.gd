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

const SECRETS_3 := {
	"saw_own_body": "靠窗的床",
	"chart_haruka": "病歷上的名字",
	"fen_bed": "沒有名字的床尾",
	"conductor_kin": "決議者的弟弟",
	"nw_door": "比斯泰德的門",
	"mayor_paw": "熊掌印",
	"chart_46": "編號 46",
	"maintained": "還在跳的監視器",
}

const SECRETS_4 := {
	"letter_lulu": "給希露飛",
	"letter_mochi": "給小滿",
	"letter_fen": "給芬",
	"sent_self_letter": "給遙的信",
	"handwriting": "同一隻手",
	"popo_bag": "沒有寄出的郵袋",
	"guilt_door": "門口",
	"saw_glass": "圓門裡的小孩",
}

const SECRETS_5 := {
	"mirror_child": "鏡中的孩子",
	"mirror_said": "你忘記的，是我",
	"safe_47": "第 47 個",
	"fen_why": "為什麼要保護你",
	"two_foxes": "一橘一白",
	"lulu_in_mirror": "裂縫裡的蝴蝶結",
	"dream_mirror": "玻璃兩邊",
	"desk_illegible": "看不清楚的字",
}

const SECRETS_6 := {
	"no_seam": "沒有縫線的那一個",
	"stamps_47": "四十七個戳章",
	"mayor_hesitate": "空著的下一格",
	"first_resident": "第一頁的熊掌印",
	"candy_jar": "白的糖",
	"left_a_thread": "留下的線頭",
	"dream_mayor": "鎮長的夜",
	"send_back": "再來一次",
}

const SECRETS_7 := {
	"rule_zero_seen": "第零條",
	"rewrote_zero": "劃掉的那一行",
	"kept_zero": "留著的那一行",
	"baimian_end": "沒有名字的那一半",
	"full_color": "顏色回來了",
	"cotton_wind": "風裡的棉花",
	"own_choice": "自己選",
	"stitch_title": "標題上的線",
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
	"chart_46": "病歷寫著：收治次數 46。本次 47。",
	"chart_haruka": "靠窗的床名牌寫著「遙」。椅子上是男生的制服。碟子裡有一個粉紅色髮夾。",
	"conductor_kin": "決議書：反對的人是車掌，他是決議者的弟弟。姓名被塗掉了。",
	"handwriting": "給遙的信，筆跡和名牌背面的「辶」一樣。",
	"sent_self_letter": "信上寫著：我站在門口。我看見了。我沒有阻止。",
	"guilt_door": "夢裡站在門口。比較小的那個人背對著你。桌上的名字被蹭掉了。",
	"desk_illegible": "夢裡的桌面寫滿了字，一個也看不清楚。",
	"fen_why": "白面說：書包那一次你看著他。剪開之後，留下來的一半只記得要保護你。",
	"stamps_47": "鎮長的名冊：火車票貼了四十七張。",
	"rule_zero_seen": "鐘塔頂端寫著：第零條　不要想起來。",
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
	match chapter:
		1:
			return SECRETS
		2:
			return SECRETS_2
		3:
			return SECRETS_3
		4:
			return SECRETS_4
		5:
			return SECRETS_5
		6:
			return SECRETS_6
		_:
			return SECRETS_7


func dream_count() -> int:
	var n := 0
	for k in ["dream_hospital", "dream_door", "dream_mirror", "dream_mayor"]:
		if has(k):
			n += 1
	return n


## 進入後續章節。不清除已經帶過來的旗標。
func start_chapter(n: int) -> void:
	chapter = n
	day = 1
	courage = MAX_COURAGE
	if n == 3:
		suspicion = 0
		conduct = CONDUCT_START
	objective = ""
	if not flags.has("tag_on"):
		flags["tag_on"] = true
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
	chapter = int(data.get("chapter", 1))
	conduct = int(data.get("conduct", CONDUCT_START))
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
