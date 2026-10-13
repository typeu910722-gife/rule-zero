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

const MAX_COURAGE := 2

var day := 1
var courage := MAX_COURAGE
var suspicion := 0
var flags := {}
var objective := ""
## 自動測試用：跳過等待與小遊戲
var fast := false
var auto_choices: Array = []
var font: SystemFont


func _ready() -> void:
	_setup_input()
	_setup_font()
	reset()


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


func _value(key: String) -> int:
	match key:
		"sus": return suspicion
		"courage": return courage
		"day": return day
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
	# 原型階段使用系統中文字型；正式版請改為打包授權字型（例如 Noto Sans TC / 圓體）。
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"Noto Sans CJK TC", "Noto Sans TC", "Microsoft JhengHei", "PingFang TC",
		"Heiti TC", "Noto Sans CJK SC", "WenQuanYi Zen Hei", "sans-serif",
	])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 22
	get_tree().root.theme = theme
