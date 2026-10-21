extends Node2D
## 第五章（終章）的章節導演（基礎可玩版；美術之後陸續補）。
## 劇本：docs/script/chapter5.md　對話：game/dialogue/chapter5.txt
## 流程：槍聲之後 → 理事 → 最後的選擇 → 判定 → 終章 A（醒來）／B-1（新鎮長）／B-2（同伴醒來、小布死亡）／B-3（小布醒來、同伴死亡）
## 判定：「想起來」remember、「沒有放手」hold 兩個分數，各自 >= THRESHOLD 才算足夠（見 scores()）。

const BreathWalk := preload("res://scripts/ch5/breath_walk.gd")
const Guard := preload("res://scripts/ch5/guard.gd")
const Chase3DScript := preload("res://scripts/ch3/chase3d.gd")

const SEGMENTS := ["opening", "director", "choice", "ending"]
const PLACES := {"opening": "實驗室", "director": "實驗室", "choice": "實驗室　最後一堂課", "ending": ""}
const THRESHOLD := 4
const ROUTES := {"a": "終章 A「醒來」", "b1": "終章 B-1「新鎮長」", "b2": "終章 B-2「最後一張床」", "b3": "終章 B-3「一個人的出院」"}

const BGM_DIR := "res://audio/ch2/bgm/ch2_bgm%s.ogg"
const BGM := {"memory": "11_memory", "dream": "16_dream", "nirvana": "10_nirvana", "next_stop": "14_next_stop", "night": "08_night"}

const LEVEL := "res://levels/chapter5.json"
const STAGES := ["lab", "lesson", "a", "b1", "b2", "b3"]
const PARTY := ["lulu", "mochi", "popo", "fen", "baimian"]
const HARUKA := "human:#33415c"     # 醒來之後的遙（和第四章同一個樣子）
const REAL_SLOW := 0.7              # 人類的身體很重、走很慢
const NIGHT := Color(0.62, 0.66, 0.8)

var segment := "opening"
var route := ""
var hud: Ch3Hud
var explore: Explore
var _bgm_name := ""


func _ready() -> void:
	GameState.chapter = 5
	Sound.override_bgm("")
	Sound.bgm("")
	Sound.ambience("")
	Sound.set_wear(0)
	Dialogue.portrait_state = Callable()
	Dialogue.event_requested.connect(_on_event)
	Dialogue.bgm_requested.connect(_bgm)
	hud = Ch3Hud.new()
	hud.header = "[b]第五章　終章[/b]"
	add_child(hud)
	hud.title_requested.connect(_to_title)
	var cp := GameState.checkpoint
	if cp.begins_with("c5_") and cp.trim_prefix("c5_") in SEGMENTS:
		segment = cp.trim_prefix("c5_")
	route = str(GameState.flags.get("c5_route", ""))
	_run.call_deferred()


func _exit_tree() -> void:
	Audio.stop_music()
	Dialogue.auto_voice = true
	if Dialogue.event_requested.is_connected(_on_event):
		Dialogue.event_requested.disconnect(_on_event)
	if Dialogue.bgm_requested.is_connected(_bgm):
		Dialogue.bgm_requested.disconnect(_bgm)


func _bgm(name: String) -> void:
	if name == _bgm_name:
		return
	_bgm_name = name
	var path: String = BGM_DIR % BGM[name] if BGM.has(name) else ""
	Audio.play_music(path, true, -3.0)


## 兩個分數：全部是前面幾章已經有的旗標（docs/script/chapter5.md 第 3 節）
static func scores(f: Dictionary) -> Dictionary:
	var has := func(k: String) -> bool: return bool(f.get(k, false))
	var remember := 0
	if has.call("true_name"): remember += 2
	if has.call("lulu_doubt"): remember += 1
	if has.call("found_fox_tail"): remember += 1
	if has.call("overheard_conductor"): remember += 1
	if has.call("nirvana_clipboard"): remember += 1
	if has.call("special_love_cut"): remember -= 2
	if has.call("c3_chart_pip"): remember += 1
	if has.call("c4_dove_seen"): remember += 2
	if has.call("c5_read_file"): remember += 1  # 檔案室：遙的檔案
	if has.call("c5_threw_candy"): remember += 2
	if has.call("c5_ate_candy"): remember -= 3
	var hold := 0
	for id in ["xiaoji", "zhongzhong", "gaga", "youyou"]:
		if has.call("with_%s" % id): hold += 1
	if has.call("letter_to_lulu") or has.call("kept_letter"): hold += 1
	if has.call("c3_ecg_saved"): hold += 1
	# 第三章：大家的棉花平均還有一半以上＝一路上沒有丟下誰
	var cotton := 0
	var n := 0
	for k in f:
		if str(k).begins_with("c3_cotton_"):
			cotton += int(f[k])
			n += 1
	if n > 0 and float(cotton) / n >= 5.0: hold += 1
	if has.call("c4_letter_not_taken"): hold += 1
	if has.call("c4_lien_told"): hold += 1
	if has.call("c5_talked_all"): hold += 1     # 實驗室裡，一個一個去看過大家
	if has.call("c5_held_fen"): hold += 2
	if has.call("c5_let_go"): hold -= 2
	return {"remember": remember, "hold": hold}


static func pick_route(f: Dictionary) -> String:
	var s := scores(f)
	var r: bool = s.remember >= THRESHOLD
	var h: bool = s.hold >= THRESHOLD
	if r and h:
		return "a"
	if r:
		return "b3"
	if h:
		return "b2"
	return "b1"


# ───────── 段落 ─────────

func _run() -> void:
	var i := SEGMENTS.find(segment)
	while i < SEGMENTS.size():
		segment = SEGMENTS[i]
		hud.place = PLACES[segment] if segment != "ending" else ROUTES.get(route, "")
		hud.refresh()
		if segment != "opening":
			GameState.save_game("c5_" + segment)
		await call("_seg_" + segment)
		if not is_inside_tree():
			return
		i += 1
	_chapter_end()


func _seg_opening() -> void:
	await _content_warning()
	_bgm("")
	if not GameState.has("explore_room"):
		Dialogue.auto_voice = false
		await Dialogue.run("c5_opening")
		Dialogue.auto_voice = true
	await _explore("lab", "lab5", "start", "c5_x_done")
	var all := true
	for id in ["lulu", "mochi", "popo", "fen", "baimian"]:
		if not GameState.has("done_c5_x_" + id):
			all = false
	if all:
		GameState.set_flag("c5_talked_all")


func _seg_director() -> void:
	_bgm("nirvana")
	if not GameState.has("explore_room"):
		await Dialogue.run("c5_director")
	await _explore("lesson", "lab5", "start", "c5_l_done", Color.WHITE, PARTY)
	# 第三章重重說過「我沒有推他」：第一次有人相信他
	if GameState.has("with_zhongzhong") and GameState.has("c3_zhongzhong_innocent"):
		await Dialogue.run("c5_zz_believed")


func _seg_choice() -> void:
	_bgm("memory")
	await Dialogue.run("c5_choice_candy")
	await Dialogue.run("c5_choice_hand")
	await Dialogue.run("c5_judge")
	route = pick_route(GameState.flags)
	GameState.set_flag("c5_route", route)


func _seg_ending() -> void:
	if route == "":
		route = pick_route(GameState.flags)
	hud.place = ROUTES[route]
	hud.refresh()
	match route:
		"a":
			_bgm("dream")
			if not GameState.has("explore_room"):
				await Dialogue.run("c5_a_intro")
				var w := BreathWalk.new()
				add_child(w)
				GameState.set_flag("c5_breath_falls", await w.play())
			if not GameState.has("c5_baimian_returned"):
				await _explore("a", "a_ward5", "start", "c5_baimian_returned")
			if not GameState.has("c5_a_walked"):
				await _walk_out()
			await _explore("a", "a_lobby5", "from_hall", "c5_a_done")
		"b1":
			_bgm("dream")
			if not GameState.has("explore_room"):
				await Dialogue.run("c5_b1_intro")
			await _explore("b1", "b1_square5", "start", "c5_b1_done")
		"b2":
			_bgm("night")
			if not GameState.has("explore_room"):
				await Dialogue.run("c5_b2_intro")
			await _explore("b2", "b2_hall5", "start", "c5_b2_done", NIGHT)
			_bgm("next_stop")
			await Dialogue.run("c5_b2_end")
		"b3":
			_bgm("night")
			if not GameState.has("explore_room"):
				await Dialogue.run("c5_b3_intro")
			await _explore("b3", "b3_ward5", "start", "c5_b3_done")


## 3D：走出真的醫院（終章 A）。人類的身體走很慢，喘不過氣就要停下來
func _walk_out() -> void:
	await Dialogue.run("c5_a_walk")
	var r := Chase3DScript.new()
	r.maze = Chase3DScript.MAZE_REAL_HALL.duplicate()
	r.look = Chase3DScript.LOOK_REAL
	r.has_enemy = false
	r.breath = true
	r.start_motif = ""
	r.title = "走出去"
	r.hint = "上：往前　左右：轉身　喘不過氣的時候，停下來"
	add_child(r)
	await r.play()
	GameState.set_flag("c5_a_walked")
	GameState.set_flag("c5_a_breath_stops", r.breath_stops)
	GameState.save_game("c5_ending")


## 地圖探索：設定階段旗標 c5_st_<stage>，走到條件成立為止（讀檔時從記住的房間繼續）
func _explore(stage: String, room_id: String, spawn: Variant, cond: String, tint := Color.WHITE, party: Array = []) -> void:
	Dialogue.set_bg("none")
	for k in STAGES:
		GameState.flags.erase("c5_st_" + k)
	GameState.flags["c5_st_" + stage] = true
	explore = Explore.new()
	explore.load_level(LEVEL)
	explore.party = party
	explore.tint = tint
	add_child(explore)
	if stage in ["a", "b3"]:
		explore.player.look = HARUKA
		explore.player.speed_mul = REAL_SLOW
	explore.room_entered.connect(func(_id):
		hud.place = "%s　%s" % [ROUTES[route] if segment == "ending" else PLACES[segment], explore.room.get("name", "")]
		hud.refresh()
		explore.save_state()
		GameState.save_game("c5_" + segment))
	await explore.restore_or(room_id, spawn)
	await explore.until(cond)
	GameState.flags.erase("explore_room")
	GameState.flags.erase("explore_pos")
	GameState.flags.erase("c5_st_" + stage)
	explore.queue_free()
	explore = null


func _process(_d: float) -> void:
	if explore:
		explore.paused = hud.menu_open


func _on_event(event_name: String) -> void:
	await get_tree().process_frame
	if explore and await explore.handle_event(event_name):
		Dialogue.event_done.emit()
		return
	match event_name:
		"c5_guard":
			var g := Guard.new()
			add_child(g)
			await g.play()
		_:
			await get_tree().process_frame
	Dialogue.event_done.emit()


func _content_warning() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#1a1a1c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.position = Vector2(200, 130)
	t.size = Vector2(880, 480)
	t.add_theme_font_size_override("normal_font_size", 24)
	t.add_theme_color_override("default_color", Color("#e6e2dc"))
	t.text = "[center][b]內容提醒[/b][/center]\n\n" + \
		"這一章的開頭有人結束了自己的生命（只用影子和聲音，不呈現細節），也有角色的死亡。\n\n" + \
		"可以在「選單」打開「減少驚嚇與敏感內容」，開頭只會留下黑畫面和一句旁白。\n\n" + \
		"如果你正在難過，或有傷害自己的念頭，請告訴你信任的人。\n台灣：1925 安心專線（24 小時）、1995 生命線。\n其他地區，請查詢當地的心理支持專線。\n\n" + \
		"[center][color=#8d8a86]（按一下繼續）[/color][/center]"
	layer.add_child(t)
	if not GameState.fast:
		while true:
			await get_tree().process_frame
			if Input.is_action_just_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				break
		await get_tree().create_timer(0.15).timeout
	layer.queue_free()


func _to_title() -> void:
	GameState.save_game("c5_" + segment)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ───────── 結束 ─────────

func _chapter_end() -> void:
	GameState.meta.chapters_done = maxi(int(GameState.meta.get("chapters_done", 0)), 5)
	var seen: Array = GameState.meta.get("finale_routes", [])
	if not route in seen:
		seen.append(route)
	GameState.meta.finale_routes = seen
	GameState.save_meta()
	GameState.delete_save()
	var card := CanvasLayer.new()
	card.layer = 60
	add_child(card)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	Audio.stop_music()
	if not GameState.fast:
		await get_tree().create_timer(2.0).timeout
		Motif.play(self, "resolved" if route == "a" else "sting")
	var s := scores(GameState.flags)
	var box := VBoxContainer.new()
	box.position = Vector2(290, 120)
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var lines := ["第五章　終章　—　" + ROUTES.get(route, ""), "",
		"想起來　%d　　沒有放手　%d　（門檻 %d）" % [s.remember, s.hold, THRESHOLD],
		"看過的終章　%d / 4" % seen.size(), "", "……故事還沒有結束。"]
	for k in lines.size():
		var l := Label.new()
		l.text = lines[k]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 700
		l.add_theme_font_size_override("font_size", 32 if k == 0 else 22)
		l.add_theme_color_override("font_color", Color("#eef2f3") if k == 0 else Color("#c9d3d6"))
		box.add_child(l)
	var b := Button.new()
	b.text = "回到標題"
	b.custom_minimum_size = Vector2(320, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	box.add_child(b)
	b.grab_focus.call_deferred()
	_finished = true


var _finished := false
