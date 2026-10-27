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
	"mirror_letter": "鏡之屋的回信",
	"candy_button": "糖果裡的鈕扣",
	"read_notes": "Fen 的筆記",
}

## 日記裡「記下的事」：謎題線索會自動記錄，玩家不用靠記憶力
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

const CLUES := {
	"lulu_slip": "露露叫我「小遙」，然後自己忘記了。",
	"met_mochi": "麻糬的名牌是空白的。",
	"tag_off": "名牌背面繡著一個被剪掉一半的字：「辶」。",
	"blank_letter": "波波給了我一封沒有寫收件人的信。",
	"found_lulu_bow": "森林裡有一隻垂耳，綁著黃色的蝴蝶結。露露現在的是綠色。",
	"found_sheep": "森林裡，舊的小綿羊腳上掛著牌子。號碼被剪掉了。",
	"heard_47": "Fen 說：這已經不是第一次了。他也數不清了。",
	"bell_heard": "第三天下午三點，鐘會響。鎮長會來。",
	"mochi_remembers": "麻糬好像想起了自己名字的第一個音。",
	"got_key": "我拿到了鐘塔的鑰匙。三點以前。",
	"mirror_letter": "鏡之屋的投信口回了一張紙，字是反的：「謝謝。我一直在等。」",
	"read_note_1": "Fen 的筆記：一整頁的「正」字。最後一筆是新的。",
	"read_note_2": "Fen 的筆記：「鐘塔　三點　鑰匙＝熊頭」",
	"read_note_3": "Fen 的筆記：「不要吃糖。吃了就會忘記。——給下一次的我」",
	"candy_button": "小玉的糖果裡，包著一顆小小的鈕扣。",
	"ate_candy": "我吃了小玉的糖。好像忘了什麼。",
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

## 第一天拜訪大家時收到的東西（日記「口袋裡的東西」）
const GIFTS := {
	"gift_bread": "露露的棉花糖麵包。跟昨天的一模一樣。",
	"gift_stamp": "波波給的郵票。上面沒有面額，也沒有圖案。",
	"gift_candy": "從鎮長家門縫底下滑出來的糖果。",
	"gift_thread": "修理室門口撿到的一截紅線。",
	"gift_glass": "鏡之屋門口的一小片玻璃。照不出你。",
	"gift_rust": "鐘塔大鎖上掉下來的一點點鐵鏽。鎖明明是新的。",
	"gift_leaf": "Fen 丟給你的一片葉子。背面用指甲刻了一個「笑」，又被劃掉了。",
	"got_button": "一顆灰色的舊鈕扣。",
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
	"truth": {"title": "老師", "desc": "你想起了一個人。鎮長也是。那天晚上，一班不在時刻表上的火車開走了。"},
}
const ENDING_ORDER := ["good_kid", "early", "brave", "betrayed", "hesitate", "mochi", "truth"]
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
	"mirror_letter": "knows_mirror_letter",
	"read_note_2": "knows_key_spot",
	"read_note_3": "knows_candy",
	"found_class_rules": "knows_teacher",
	"dog_confessed": "knows_dog",
	"lulu_mirror_seen": "saw_lulu_mirror",
	"saw_pink": "saw_pink",
	"saw_lulu_letter": "saw_lulu_letter",
	"saw_tama_test": "saw_tama_test",
	"tama_done": "helped_tama",
}
## 標題畫面「解開的謎團」：問題一直看得到（就是提示），解開以後才看得到答案（key＝跨輪記憶）
const MYSTERIES := [
	{"q": "「小布」是誰？", "a": "我叫遙。從有海的小鎮轉學過來。", "key": "story_1"},
	{"q": "這是第幾次了？", "a": "數不清了。Fen 在樹上刻滿了線。", "key": "knows_47"},
	{"q": "露露的蝴蝶結，為什麼換了顏色？", "a": "森林裡的垂耳綁著黃色的蝴蝶結。露露也被修理過。", "key": "knows_bow"},
	{"q": "晚上八點以後，大家在做什麼？", "a": "大家站在廣場上，一動也不動，看著鐘塔。", "key": "knows_night"},
	{"q": "鏡子裡的是誰？", "a": "一個人類小孩。他在敲鏡子。", "key": "knows_mirror"},
	{"q": "名牌的背面寫著什麼？", "a": "一個被剪掉一半的字：「辶」。", "key": "knows_tag"},
	{"q": "森林裡的小綿羊是誰？", "a": "以前的小布。腳上的號碼被剪掉了。", "key": "knows_sheep"},
	{"q": "下午三點會發生什麼事？", "a": "鐘會響。鎮長會來森林。", "key": "knows_bell"},
	{"q": "麻糬本來叫什麼？", "a": "一個很短的名字，只有兩個字。第一個音是「ㄒ」。", "key": "knows_mochi"},
	{"q": "修理室的鑰匙在哪裡？", "a": "Fen 的樹屋，從門口數過來第三塊木板底下。", "key": "knows_key"},
	{"q": "糖果裡包著什麼？", "a": "吃了就會忘記。", "key": "knows_candy"},
	{"q": "鏡之屋裡住著誰？", "a": "穿著醫院衣服的你。他一直在寫信，寫給下一個你。", "key": "knows_mirror_self"},
	{"q": "守則是誰寫的？", "a": "三年二班的班規。鎮長以前，是老師。", "key": "knows_teacher"},
	{"q": "小狗居民在掃什麼？", "a": "那天，他坐在窗邊，全部都看到了。他什麼都沒有說。", "key": "knows_dog"},
	{"q": "車掌，站在哪一邊？", "a": "「你應該忘記的。……終於，發生了嗎。……加油。」", "key": "conductor_4"},
	{"q": "第一個戳章，是誰蓋的？", "a": "慈愛組織。一隻戴著白手套的手。", "key": "story_4"},
	{"q": "為什麼要一直重來？", "a": "慈愛計劃：讓受傷的孩子忘記。忘記了，就不會痛。", "key": "end_truth"},
]
## 標題畫面「結局」：沒看過的結局只給一句提示
const ENDING_HINTS := {
	"good_kid": "如果，你一直、一直當個好孩子……",
	"early": "如果，你知道得太多、太快……",
	"brave": "如果，鎮長來的時候，你衝了出去……",
	"betrayed": "如果，你把躲的地方告訴了好朋友……",
	"hesitate": "如果，好朋友開始懷疑了……",
	"mochi": "如果，有人想起了自己的名字……",
	"truth": "鑰匙、六團棉花，還有一個你該叫出口的稱呼。",
}
## 標題畫面「蒐藏過的東西」：口袋裡的東西＋找到的東西（跨輪記在 meta.collected）
const COLLECTIBLES := {
	"got_button": "灰色鈕扣",
	"gift_bread": "棉花糖麵包",
	"gift_stamp": "沒有面額的郵票",
	"gift_candy": "門縫底下的糖果",
	"gift_thread": "一截紅線",
	"gift_glass": "照不出你的玻璃",
	"gift_rust": "新鎖上的鐵鏽",
	"gift_leaf": "刻著「笑」的葉子",
	"found_lulu_bow": "黃色蝴蝶結",
	"found_fox_tail": "狐狸尾巴",
	"read_notes": "Fen 的筆記",
	"candy_button": "糖果裡的鈕扣",
	"got_key": "修理室的鑰匙",
	"true_name": "「小布」的名牌",
	"conductor_glove": "車掌的白手套",
}
## 會被「修理」的結局：上一輪最後記下的事會被剪掉
const REPAIR_ENDINGS := ["early", "brave", "betrayed", "mochi"]
const FIRST_LOOP := 47
## 記憶深度：每多走完一輪，就多想起一層（0＝第一輪，最多 4）。
## 對話裡用 depth>=2 判斷；每一層在火車上會想起一段「遙」的過去（story_1～4）。
const MAX_DEPTH := 4
const DEPTH_NAMES := ["", "好像來過", "記得順序", "記得大家", "記得自己"]
## 開頭的固定任務：每走完三輪，小鎮就「改一次劇本」，越改越短（最多 10 種）。
## places＝第一天要去的地方（從裡面去 need 個）；day2＝第二天要做的事（bread 做麵包、letter 送信）
const OPENINGS := [
	{"places": ["lulu", "popo", "fen", "mayor_door", "repair_room", "mirror_house", "clocktower"], "need": 4, "day2": ["bread", "letter"]},
	{"places": ["lulu", "popo", "fen", "mayor_door", "mirror_house"], "need": 3, "day2": ["bread", "letter"]},
	{"places": ["lulu", "popo", "fen"], "need": 3, "day2": ["bread"]},
	{"places": ["lulu", "popo", "fen", "mayor_door", "repair_room", "mirror_house", "clocktower"], "need": 2, "day2": ["letter"]},
	{"places": ["fen", "mirror_house"], "need": 2, "day2": ["bread"]},
	{"places": ["mayor_door", "repair_room"], "need": 2, "day2": ["letter"]},
	{"places": ["lulu"], "need": 1, "day2": ["bread"]},
	{"places": ["fen"], "need": 1, "day2": ["letter"]},
	{"places": ["clocktower"], "need": 1, "day2": ["bread"]},
	{"places": ["lulu", "popo", "fen", "mayor_door", "repair_room", "mirror_house", "clocktower"], "need": 1, "day2": ["letter"]},
]
## 每一層想起來的過去（日記「想起來的事」）
const STORY_TEXT := {
	"story_1": "我叫遙。我從有海的小鎮轉學過來。媽媽幫我把新制服的領子翻好。",
	"story_2": "三年二班。教室後面貼著班規。老師說：「在這個班上，不會有人受傷。」",
	"story_3": "廁所的門外，有人在把風。走廊的盡頭，老師看到了。他在發抖。他沒有進來。",
	"story_4": "醫院。穿白外套的人說：「我們會讓你忘記。」有人在我的車票上，蓋了第一個戳章。",
}

const MAX_COURAGE := 2

var day := 1
var courage := MAX_COURAGE
var suspicion := 0
var flags := {}
var objective := ""
## 第二章：操行成績單（第一章隱藏的懷疑值，這章攤開給你看）
const CONDUCT_START := 100
var chapter := 1
var conduct := CONDUCT_START
var fast_apology_take := false
var fast_scrub_keep := false
var fast_sneak_caught := false
## 自動測試用：跳過等待與小遊戲
var fast := false
var auto_choices: Array = []
## 截圖測試用：fast 模式下每句對話出現時呼叫（可以 await），平常是空的
var on_line: Callable = Callable()
var resume_on_start := false

## 存檔：每天早上自動存一次（檢查點）。meta 是跨周目的記錄，標題畫面會依它改變。
const SAVE_PATH := "user://save.json"
const META_PATH := "user://meta.json"
var save_dir := "user://"
var checkpoint := ""
const PAD_DEADZONE := 0.25
## 最後使用的輸入裝置："keyboard"、"pad"、"touch"（"" ＝還沒操作過）
var last_device := ""
var meta := {"runs": 0, "chapters_done": 0, "loop": FIRST_LOOP, "loops_done": 0,
	"endings": [], "last_ending": "", "memory": {}, "past_clues": [], "cut_clues": [], "tufts": []}
## 結局之後重新載入場景時，直接開始下一輪（不經過標題畫面）
var pending_loop_start := false
## 開場 Logo 影片這次開啟遊戲是否已經播過
var intro_played := false
var font: Font


## Android 的返回鍵／返回手勢：不要直接關掉遊戲（project.godot quit_on_go_back=false），當成「打開選單」
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		for pressed in [true, false]:
			var ev := InputEventAction.new()
			ev.action = "menu"
			ev.pressed = pressed
			Input.parse_input_event(ev)


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


## 進入第二章：帶著第一章的旗標，天數與膽量重來
func start_chapter2() -> void:
	chapter = 2
	day = 1
	courage = MAX_COURAGE
	conduct = CONDUCT_START
	flags["tag_on"] = true
	objective = ""
	changed.emit()


## 第三章：接第二章結束時的旗標（meta.ch2_flags）與居民去向（meta.ch2_fates）
func start_chapter3() -> void:
	chapter = 3
	day = 1
	courage = MAX_COURAGE
	var carry: Dictionary = meta.get("ch2_flags", {})
	for k in carry:
		flags[k] = carry[k]
	var fates: Dictionary = meta.get("ch2_fates", {})
	for id in ["xiaoji", "zhongzhong", "gaga", "youyou"]:
		if fates.get(id, "") == "aboard":
			flags["with_%s" % id] = true
	if fates.get("youyou", "") == "unknown":
		flags["youyou_lost"] = true
	if fates.get("xiaoji", "") == "graduated":
		flags["xiaoji_grad"] = true
	objective = ""
	checkpoint = ""
	changed.emit()


## 第四章：前面三章的旗標都帶著走（第三章結束時存在 meta.ch3_flags，裡面已經有第二章的）
func start_chapter4() -> void:
	chapter = 4
	day = 1
	courage = MAX_COURAGE
	var carry: Dictionary = meta.get("ch3_flags", meta.get("ch2_flags", {}))
	for k in carry:
		flags[k] = carry[k]
	var fates: Dictionary = meta.get("ch2_fates", {})
	if fates.get("zhongzhong", "") == "dead":
		flags["zz_dead"] = true
	objective = ""
	checkpoint = ""
	changed.emit()


## 第五章（終章）：帶著第四章結束時的旗標（含前面所有章）
func start_chapter5() -> void:
	chapter = 5
	day = 1
	courage = MAX_COURAGE
	var carry: Dictionary = meta.get("ch4_flags", meta.get("ch3_flags", meta.get("ch2_flags", {})))
	for k in carry:
		flags[k] = carry[k]
	var fates: Dictionary = meta.get("ch2_fates", {})
	if fates.get("zhongzhong", "") == "dead":
		flags["zz_dead"] = true
	objective = ""
	checkpoint = ""
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


# ───────── 輪迴 ─────────

## 中文數字（1～99），用在「第四十七個小布」這類台詞
static func cn(n: int) -> String:
	const D := ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	if n < 10:
		return D[maxi(n, 0)]
	if n >= 100:
		return cn(n / 100) + "百" + ("" if n % 100 == 0 else ("零" if n % 100 < 10 else "") + cn(n % 100)) if n < 1000 else "好多"
	var tens := n / 10
	var ones := n % 10
	return ("" if tens == 1 else D[tens]) + "十" + ("" if ones == 0 else D[ones])


## 台詞裡的 {name}、{loop}（這一輪是第幾個）、{prev}（上一個）、{stamps}（車票上的戳章數）
func fill(text: String) -> String:
	var n := loop_number()
	text = text.replace("{name}", player_name()).replace("{loop}", cn(n)).replace("{prev}", cn(n - 1)) \
		.replace("{stamps}", cn(n - FIRST_LOOP + 1)).replace("{tufts}", str(tuft_count()))
	# 支線計數：{candies}、{letters}、{notes}、{mq_count}
	for k in ["candies", "letters", "notes", "mq_count"]:
		text = text.replace("{%s}" % k, str(int(flags.get(k, 0))))
	return text


## 記憶碎片（棉花）的內容，日記裡可以重看
const TUFT_TEXT := {
	"tuft_0": "新的制服。「轉學生？從哪裡來的啊？」",
	"tuft_1": "撕成一條一條的課本。後面有人在笑。",
	"tuft_2": "「外來的，不准坐那裡。」椅子被抽走了。",
	"tuft_3": "廁所的門被卡住了。「快開門……」沒有人來。",
	"tuft_4": "冷水。後腦勺被按住。笑聲好遠。",
	"tuft_5": "有人在耳邊說：「別出聲。」",
	"tuft_6": "走廊盡頭，一個高高的大人在發抖。",
	"tuft_7": "被丟進垃圾桶的小綿羊玩偶。它叫「小布」。",
	"tuft_8": "「慈愛……計劃……他會忘記的。」",
	"tuft_9": "「如果可以忘記就好了。」",
}
## 每一輪只會出現幾團（撿過的不會再出現），照這個順序
const TUFTS_PER_LOOP := 3

## 記憶碎片（棉花）：跨輪保留
func has_tuft(id: String) -> bool:
	return id in meta.get("tufts", [])


func collect_tuft(id: String) -> void:
	var t: Array = meta.get("tufts", [])
	if not id in t:
		t.append(id)
		var got: Array = flags.get("got_tufts", [])
		got.append(id)
		flags["got_tufts"] = got
	meta.tufts = t
	save_meta()
	changed.emit()


## 這一輪會出現的棉花：還沒撿過的，照順序取前三團（一輪開始時決定，存在旗標裡）
func loop_tufts() -> Array:
	if flags.has("loop_tufts"):
		return flags.loop_tufts
	var left: Array = []
	for i in TUFT_TEXT.size():
		var id := "tuft_%d" % i
		if not has_tuft(id):
			left.append(id)
	flags["loop_tufts"] = left.slice(0, TUFTS_PER_LOOP)
	return flags.loop_tufts


func tuft_count() -> int:
	return meta.get("tufts", []).size()


func loop_number() -> int:
	return int(meta.get("loop", FIRST_LOOP))


## 是不是第一輪以後（玩家帶著上一輪的記憶）
func is_repeat() -> bool:
	return loop_number() > FIRST_LOOP


func remembers(key: String) -> bool:
	return bool(meta.get("memory", {}).get(key, false))


## 跨輪記住一件事（對話裡的 @mem）
func remember(key: String) -> void:
	var memory: Dictionary = meta.get("memory", {})
	memory[key] = true
	meta.memory = memory
	save_meta()


## 記憶深度：走完幾輪，就想起幾層
func memory_depth() -> int:
	return clampi(int(meta.get("loops_done", 0)), 0, MAX_DEPTH)


## 這一輪開頭的固定任務是第幾版（0～9）：每走完三輪換一版
func opening_index() -> int:
	return clampi(int(meta.get("loops_done", 0)) / 3, 0, OPENINGS.size() - 1)


func opening() -> Dictionary:
	return OPENINGS[opening_index()]


## 曾經記得（包含「從第一章重新開始」之前的紀錄）：標題畫面的謎團、蒐藏用
func ever(key: String) -> bool:
	return remembers(key) or bool(meta.get("archive_memory", {}).get(key, false))


func ever_tufts() -> Array:
	var t: Array = meta.get("tufts", []).duplicate()
	for k in meta.get("archive_tufts", []):
		if not k in t:
			t.append(k)
	return t


## 第一章全破過（真結局）
func chapter1_cleared() -> bool:
	return "truth" in meta.get("endings", [])


## 選擇篇章 → 第一章：從「還沒開始輪迴」的第一天、空白的紀錄重新開始。
## 輪迴、記憶、棉花、車票戳章都歸零；看過的結局、蒐藏、謎團的紀錄留在標題畫面（archive）。
func restart_chapter1() -> void:
	var arch: Dictionary = meta.get("archive_memory", {})
	for k in meta.get("memory", {}):
		if meta.memory[k]:
			arch[k] = true
	meta.archive_memory = arch
	meta.archive_tufts = ever_tufts()
	record_collected()
	for k in ["memory", "past_clues", "cut_clues", "tufts", "fresh", "last_ending", "creepy_seen", "idle_norm"]:
		meta.erase(k)
	meta.loop = FIRST_LOOP
	meta.loops_done = 0
	save_meta()
	delete_save()
	reset()


## 把這一輪拿到的東西記進「蒐藏」（跨輪）
func record_collected() -> void:
	var got: Array = meta.get("collected", [])
	for k in COLLECTIBLES:
		if has(k) and not k in got:
			got.append(k)
	meta.collected = got


func has_collected(k: String) -> bool:
	return k in meta.get("collected", []) or has(k)


## 標題畫面的「沉重」程度：記憶越深、越接近真相越重（0～5）
func heaviness() -> int:
	return clampi(memory_depth() + int(meta.get("chapters_done", 0)), 0, 5)


## 上一輪「才剛」記住的事（記憶的 key、棉花 id）：火車上會先想起這些
func is_fresh(key: String) -> bool:
	if key == "any":
		return not meta.get("fresh", []).is_empty()
	return key in meta.get("fresh", [])


## 一輪結束：記下結局、把這一輪看到的事帶到下一輪
func finish_loop(ending: String) -> void:
	var endings: Array = meta.get("endings", [])
	if not ending in endings:
		endings.append(ending)
	meta.endings = endings
	meta.last_ending = ending
	meta.loops_done = int(meta.get("loops_done", 0)) + 1
	var memory: Dictionary = meta.get("memory", {})
	var fresh: Array = []
	for f in MEMORY_FROM_FLAGS:
		if has(f):
			if not memory.get(MEMORY_FROM_FLAGS[f], false):
				fresh.append(MEMORY_FROM_FLAGS[f])
			memory[MEMORY_FROM_FLAGS[f]] = true
	memory["end_" + ending] = true
	meta.memory = memory
	fresh.append_array(flags.get("got_tufts", []))
	meta.fresh = fresh
	record_collected()
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
	if ending in ["zero", "truth"]:
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
	return secret_defs().keys().filter(func(k): return has(k))


func threads_earned() -> int:
	return maxi(1, secrets_found().size() / 3)


## 條件語法：flag、!flag、sus>=40、sus<20、courage>=1、day==2
## 閒聊用的對話標籤：idle_<角色>_1～N 依序輪流（跨輪記住看到第幾句，不會一直重複同一句）；
## 第 3 次閒聊換成 idle_<角色>_x（驚悚，整個存檔只出現一次）
func idle_label(who: String, pool := 4) -> String:
	var n := int(flags.get("idle_" + who, 0)) + 1
	flags["idle_" + who] = n
	var seen: Array = meta.get("creepy_seen", [])
	if n == 3 and not who in seen:
		seen.append(who)
		meta["creepy_seen"] = seen
		save_meta()
		return "idle_%s_x" % who
	var counts: Dictionary = meta.get("idle_norm", {})
	var k := int(counts.get(who, 0))
	counts[who] = k + 1
	meta["idle_norm"] = counts
	return "idle_%s_%d" % [who, k % maxi(pool, 1) + 1]


func check(cond: String) -> bool:
	cond = cond.strip_edges()
	if cond == "":
		return true
	# 「或」：a|b（「且」比「或」優先：a&b|c ＝ (a&b) 或 c）
	if "|" in cond:
		for part in cond.split("|"):
			if check(part):
				return true
		return false
	if "&" in cond:
		for part in cond.split("&"):
			if not check(part):
				return false
		return true
	if cond.begins_with("!"):
		return not check(cond.substr(1))
	if cond.begins_with("mem."):
		return remembers(cond.substr(4))
	if cond.begins_with("fresh."):
		return is_fresh(cond.substr(6))
	if cond.begins_with("last."):
		return str(meta.get("last_ending", "")) == cond.substr(5)
	if cond.begins_with("end."):
		return cond.substr(4) in meta.get("endings", [])
	if cond == "gentle":
		return gentle()
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
	record_collected()
	save_meta()
	var data := {"version": 2, "checkpoint": cp, "chapter": chapter, "day": day, "courage": courage,
		"suspicion": suspicion, "conduct": conduct, "flags": flags}
	_write_json(_path(SAVE_PATH), data)


func has_save() -> bool:
	return FileAccess.file_exists(_path(SAVE_PATH)) or FileAccess.file_exists(_path(SAVE_PATH) + ".bak")


func load_game() -> bool:
	var data = _read_json(_path(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return false
	chapter = int(data.get("chapter", 1))
	conduct = int(data.get("conduct", CONDUCT_START))
	checkpoint = data.get("checkpoint", "")
	day = int(data.get("day", 1))
	courage = int(data.get("courage", MAX_COURAGE))
	suspicion = int(data.get("suspicion", 0))
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
		"loop": return int(meta.get("loop", FIRST_LOOP))
		"tufts": return tuft_count()
		"depth": return memory_depth()
		"opening": return opening_index()
		"gentle": return 1 if gentle() else 0
	return int(flags.get(key, 0))


## 設定「減少驚嚇與敏感內容」（跨周目、兩章共用）：不閃屏、不突臉、敏感段落只留畫面。
## 劇本可以用 [gentle]／[!gentle] 條件分開寫。
func gentle() -> bool:
	return bool(meta.get("gentle", false))


func set_gentle(on: bool) -> void:
	meta["gentle"] = on
	save_meta()


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


## 手機上點一下會同時送出「觸控」和系統模擬的「滑鼠點擊」兩個事件。
## 同時處理兩種的地方，要用這個把模擬的那一個丟掉，不然點一下會算兩下（2026-10-21 密碼鎖一次輸入兩個數字）。
static func is_touch_echo(e: InputEvent) -> bool:
	return e is InputEventMouseButton and e.device == InputEvent.DEVICE_ID_EMULATION


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
	# 第一章
	["WASD／方向鍵走路　·　靠近按 E 互動　·　Tab 打開日記", "左搖桿走路　·　靠近按 A 互動　·　START 打開日記", "用左下角的方向鍵走路，靠近有「！」的地方按「互動」。"],
	["滑鼠點一下，或用方向鍵選、按 E 調查　·　Tab 離開", "十字鍵選、按 A 調查　·　START 離開", "點一下東西來調查"],
	["← → 換道躲開　·　按住 ↑ 衝刺", "左搖桿左右換道躲開　·　往上推衝刺", "左右推：換道躲開　·　往上推：衝刺"],
	["連點滑鼠／連按 E", "連按 A", "連點畫面"],
	["按 E 下一句", "按 A 下一句", "點一下下一句"],
	["（Tab 打開日記）", "（START 打開日記）", "（點「日記」打開）"],
	# 最後才換單獨的「按 E」
	["按 E", "按 A", "按「互動」"],
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
