extends Node2D
## 第四章「三年二班」的章節導演（基礎可玩版：視角串＋房間調查＋小遊戲；美術之後陸續補）。
## 劇本：docs/script/chapter4.md　對話：game/dialogue/chapter4.txt
## 純粹的校園故事（過去）。每個段落是一個人的視角；每段開始時存檔（檢查點 c4_<段落>）。
## 描寫原則：「那一天」畫面永遠在門外，只用門外聽得到的聲音；減少驚嚇模式只留畫面與一聲關門。

const Speech := preload("res://scripts/ch4/speech.gd")
const GroupChat := preload("res://scripts/ch4/group_chat.gd")
const HoldDoor := preload("res://scripts/ch4/hold_door.gd")

const SEGMENTS := ["opening", "haruka", "mochi", "tiaoma", "lulu", "xinhe", "popo", "teacher", "fen", "theday", "org", "night"]
const POV := {"opening": "", "haruka": "視角：遙", "mochi": "視角：小滿", "tiaoma": "視角：薙文", "lulu": "視角：希露飛",
	"xinhe": "視角：辛禾", "popo": "視角：銘越", "teacher": "視角：導師", "fen": "視角：芬（白面）",
	"theday": "那一天", "org": "那一天之後", "night": "慈愛組織的第一個晚上"}

const BGM_DIR := "res://audio/ch2/bgm/ch2_bgm%s.ogg"
const BGM := {"memory": "11_memory", "dream": "16_dream", "night": "08_night", "evening": "02_evening", "nirvana": "10_nirvana"}


var segment := "opening"
var hud: Ch3Hud
var _bgm_name := ""
var _fx_layer: CanvasLayer
var _blackout: ColorRect
## 地圖探索（levels/chapter4.json）：同一間學校，每個視角用旗標 c4_pov_<視角> 決定誰在、能調查什麼
var explore: Explore
const LEVEL := "res://levels/chapter4.json"
const LOOKS := {"haruka": "human:#33415c", "mochi": "human:#8b9a7b", "tiaoma": "human:#d9d9d4", "lulu": "human:#e7a3b4",
	"xinhe": "human:#3a3a3a", "popo": "human:#3b4a73", "teacher": "human:#6f6a5e", "fen": "human:#c8642b",
	"d1": "human:#e9b8c8", "d2": "human:#7a8a6e", "d5": "human:#c8642b", "d8": "human:#5b6b78"}
const NIGHT := Color(0.55, 0.6, 0.82)
const EVENING := Color(0.95, 0.78, 0.66)


func _ready() -> void:
	GameState.chapter = 4
	Sound.override_bgm("")
	Sound.bgm("")
	Sound.ambience("")
	Sound.set_wear(0)
	Dialogue.portrait_state = Callable()
	Dialogue.event_requested.connect(_on_event)
	Dialogue.bgm_requested.connect(_bgm)
	hud = Ch3Hud.new()
	hud.header = "[b]第四章　三年二班[/b]"
	add_child(hud)
	hud.title_requested.connect(_to_title)
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 45
	add_child(_fx_layer)
	_blackout = ColorRect.new()
	_blackout.color = Color.BLACK
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.visible = false
	_fx_layer.add_child(_blackout)
	var cp := GameState.checkpoint
	if cp.begins_with("c4_") and cp.trim_prefix("c4_") in SEGMENTS:
		segment = cp.trim_prefix("c4_")
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


# ───────── 段落 ─────────

func _run() -> void:
	var i := SEGMENTS.find(segment)
	while i < SEGMENTS.size():
		segment = SEGMENTS[i]
		hud.place = POV[segment]
		hud.refresh()
		if segment != "opening":
			GameState.save_game("c4_" + segment)
		await call("_seg_" + segment)
		if not is_inside_tree():
			return
		i += 1
	_chapter_end()


func _seg_opening() -> void:
	await _content_warning()
	_bgm("memory")
	await Dialogue.run("c4_opening")


## 遙的第一天：校門 → 玄關（自己的鞋櫃）→ 走廊 → 教室（認識全班、看班規）→ 自我介紹
func _seg_haruka() -> void:
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_h_gate_intro")
	await _explore_pov("haruka", "gate", "start", "c4_h_spoke")


## 小滿放學後：書包裡的粉筆灰、不見的鞋子、校門口等不會來的人 → 辛禾
func _seg_mochi() -> void:
	_bgm("evening")
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_m_intro")
	await _explore_pov("mochi", "classroom", "from_hall", "c4_m_done", EVENING)


## 一個視角的地圖探索：設定視角旗標、主角的樣子，探索到條件成立
func _explore_pov(pov: String, room_id: String, spawn: Variant, cond: String, tint := Color.WHITE, party: Array = []) -> void:
	Dialogue.set_bg("none")
	for k in LOOKS:
		GameState.flags.erase("c4_pov_" + k)
	GameState.flags["c4_pov_" + pov] = true
	explore = Explore.new()
	explore.load_level(LEVEL)
	explore.party = party
	explore.tint = tint
	add_child(explore)
	explore.player.look = LOOKS.get(pov, "human:#6d7f8a")
	explore.room_entered.connect(func(_id):
		hud.place = "%s　%s" % [POV[segment], explore.room.get("name", "")]
		hud.refresh()
		explore.save_state()
		GameState.save_game("c4_" + segment))
	await explore.restore_or(room_id, spawn)
	await explore.until(cond)
	GameState.flags.erase("explore_room")
	GameState.flags.erase("explore_pos")
	GameState.flags.erase("c4_pov_" + pov)
	explore.queue_free()
	explore = null


func _process(_d: float) -> void:
	if explore:
		explore.paused = hud.menu_open


## 薙文：晚上自己的房間 → 床上的手機（群組）
func _seg_tiaoma() -> void:
	_bgm("night")
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_t_intro")
	await _explore_pov("tiaoma", "tiaoma_room", "start", "c4_t_done", NIGHT)


## 希露飛：被畫上耳朵的名牌、走廊的笑聲 → 回家 → 鏡子的碎片 → 沒寄出的信
func _seg_lulu() -> void:
	_bgm("memory")
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_l_intro")
	await _explore_pov("lulu", "entrance", "from_gate", "c4_l_done")


## 辛禾：垃圾桶裡的草稿、走廊的「你知道嗎」→ 校門口的郵筒（拿不拿信）
func _seg_xinhe() -> void:
	_bgm("evening")
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_x_intro")
	await _explore_pov("xinhe", "classroom", "from_hall", "c4_x_done", EVENING)


## 銘越：被圍著笑、屋頂上的鞋子、畫花的照片 → 空的信箱
func _seg_popo() -> void:
	_bgm("memory")
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_p_intro")
	await _explore_pov("popo", "entrance", "from_gate", "c4_p_done")


## 導師：斷掉的粉筆、被學聲音的點名、台下想說話的轉學生 → 辦公室（胃藥、公文）→ 晚上重寫班規
func _seg_teacher() -> void:
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_te_intro")
	await _explore_pov("teacher", "classroom", "from_hall", "c4_te_done")


## 芬（白面帶路，白面是玩偶的樣子跟在後面）：遙的桌子、垃圾桶的書包、劃掉的名牌、課本裡的紙條 → 走廊盡頭
func _seg_fen() -> void:
	_bgm("dream")
	if not GameState.has("explore_room"):
		await Dialogue.run("c4_fen_intro")
	await _explore_pov("fen", "classroom", "from_hall", "c4_f_done", Color(0.9, 0.88, 0.95), ["baimian"])


## 那一天：九個視角輪流。這一段的聲音全部由劇本指定（關掉自動語音），沒有配樂
func _seg_theday() -> void:
	_bgm("")
	Audio.stop_music()
	Dialogue.auto_voice = false
	# 地圖：① 遙、② 值日生、⑤ 芬、⑧ 李恩；其他視角是過場（畫面永遠在門外）
	var steps := [["c4_day_warning", ""], ["d1", "c4_d1_intro", "gate", "start", "c4_d1_done"],
		["d2", "c4_d2_intro", "classroom", "from_hall", "c4_d2_done"], ["c4_day_3", ""], ["c4_day_4", ""],
		["d5", "c4_d5_intro", "classroom", "from_hall", "c4_d5_done"], ["c4_day_6", ""], ["c4_day_7", ""]]
	for st in steps:
		var done_flag: String = st[4] if st.size() > 4 else ""
		if done_flag != "" and GameState.has(done_flag):
			continue
		if st.size() > 2:
			hud.place = _day_pov("c4_day_" + st[0].substr(1))
			hud.refresh()
			if not GameState.has("explore_room"):
				await Dialogue.run(st[1])
			await _explore_pov(st[0], st[2], st[3], st[4], Color(0.88, 0.9, 0.95))
		else:
			hud.place = _day_pov(st[0])
			hud.refresh()
			await Dialogue.run(st[0])
		if not is_inside_tree():
			return
	# 三個視角都看過窗外 → 知道推下芬的不是郡主
	if GameState.has("c4_win_5") and GameState.has("c4_win_6") and GameState.has("c4_win_7"):
		GameState.set_flag("c4_dove_seen")
	if not GameState.has("c4_d8_done"):
		hud.place = _day_pov("c4_day_8")
		hud.refresh()
		if not GameState.has("explore_room"):
			await Dialogue.run("c4_d8_intro")
		await _explore_pov("d8", "downstairs", "start", "c4_d8_done", Color(0.82, 0.84, 0.9))
	for label in ["c4_day_9", "c4_day_after"]:
		hud.place = _day_pov(label)
		hud.refresh()
		await Dialogue.run(label)
		if not is_inside_tree():
			return
	Dialogue.auto_voice = true


func _day_pov(label: String) -> String:
	var who := {"c4_day_1": "遙", "c4_day_2": "值日生", "c4_day_3": "秋歌", "c4_day_4": "門外", "c4_day_5": "芬",
		"c4_day_6": "白面" if GameState.has("zz_dead") else "郡主", "c4_day_7": "導師", "c4_day_8": "李恩", "c4_day_9": "遙"}
	return "那一天　" + (("視角：" + who[label]) if who.has(label) else "")


func _seg_org() -> void:
	_bgm("nirvana")
	for label in ["c4_org_principal", "c4_org_hospital", "c4_org_board", "c4_org_teacher", "c4_org_father", "c4_org_platform"]:
		await Dialogue.run(label)
		if not is_inside_tree():
			return


func _seg_night() -> void:
	_bgm("")
	Audio.stop_music()
	Dialogue.auto_voice = false
	await Dialogue.run("c4_night")
	Dialogue.auto_voice = true




# ───────── @event ─────────

func _on_event(event_name: String) -> void:
	await get_tree().process_frame
	if explore and await explore.handle_event(event_name):
		Dialogue.event_done.emit()
		return
	match event_name:
		"c4_speech":
			var s := Speech.new()
			add_child(s)
			await s.play()
		"c4_chat":
			var g := GroupChat.new()
			add_child(g)
			if await g.play() == false:
				GameState.set_flag("c4_tiaoma_paused")
		"c4_viewfinder":
			await _viewfinder()
		"c4_shoes":
			await _shoes()
		"c4_hold_door":
			var h := HoldDoor.new()
			add_child(h)
			await h.play()
		"c4_whistle":
			Motif.play(self, "whistle", -4.0)
			if not GameState.fast:
				await get_tree().create_timer(2.5).timeout
		"c4_breaker":
			await _breaker()
	Dialogue.event_done.emit()


## 開頭的內容警告與求助資源
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
	t.position = Vector2(200, 110)
	t.size = Vector2(880, 520)
	t.add_theme_font_size_override("normal_font_size", 24)
	t.add_theme_color_override("default_color", Color("#e6e2dc"))
	t.text = "[center][b]內容提醒[/b][/center]\n\n" + \
		"這一章是孩子們還是人類時候的故事。\n裡面有校園霸凌、暗示的暴力、有人從樓梯摔下去、被綁在病床上的畫面。\n" + \
		"最難受的那一段，畫面會停在門外，不會呈現發生了什麼。\n\n" + \
		"可以在「選單」打開「減少驚嚇與敏感內容」，那一段只會留下畫面和一聲關門。\n\n" + \
		"如果你或身邊的人正在經歷霸凌或傷害，請告訴你信任的大人。\n台灣：113 保護專線、1925 安心專線（24 小時）。\n其他地區，請查詢當地的兒少保護或心理支持專線。\n\n" + \
		"[center][color=#8d8a86]（按一下繼續）[/color][/center]"
	layer.add_child(t)
	if not GameState.fast:
		await _wait_press()
	layer.queue_free()


## 秋歌的手機：取景框裡只有門板，手一直在抖
func _viewfinder() -> void:
	_play("rec_beep", -6.0)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	var t0 := Time.get_ticks_msec()
	c.draw.connect(func():
		var tt := (Time.get_ticks_msec() - t0) / 1000.0
		var shake := Vector2(sin(tt * 23.0), cos(tt * 17.0)) * 6.0
		c.draw_rect(Rect2(0, 0, 1280, 720), Color("#111"))
		var phone := Rect2(390, 40, 500, 640)
		c.draw_rect(phone, Color("#000"))
		var view := Rect2(410, 90, 460, 540)
		c.draw_rect(view, Color("#8a8276"))
		c.draw_rect(Rect2(view.position + Vector2(110, 60) + shake, Vector2(240, 420)), Color("#6e6558"))
		c.draw_rect(Rect2(view.position + Vector2(110, 472) + shake, Vector2(240, 8)), Color("#1c1915"))
		c.draw_circle(Vector2(440, 70), 8, Color("#e33") if fmod(tt, 1.0) < 0.6 else Color("#511"))
		c.draw_string(GameState.font, Vector2(456, 78), "REC  00:%02d" % int(tt), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		c.draw_string(GameState.font, Vector2(0, 700), "（按一下繼續）", HORIZONTAL_ALIGNMENT_CENTER, 1280, 18, Color("#777")))
	var tick := func(): c.queue_redraw()
	if not GameState.fast:
		var timer := Timer.new()
		timer.wait_time = 0.05
		timer.autostart = true
		timer.timeout.connect(tick)
		layer.add_child(timer)
		await get_tree().create_timer(1.0).timeout
		await _wait_press()
	layer.queue_free()


## 把風：同一扇門、同一段走廊，門縫底下的鞋子一雙一雙換
func _shoes() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	var shoes := [Color("#2d2d33"), Color("#e9e6e0"), Color("#6b4a32"), Color("#2f4a6b"), Color("#8c2f2f"), Color("#3d5b3f")]
	var state := {"k": 0}
	c.draw.connect(func():
		c.draw_rect(Rect2(0, 0, 1280, 720), Color("#cfc6b6"))
		c.draw_colored_polygon(PackedVector2Array([Vector2(0, 720), Vector2(420, 430), Vector2(860, 430), Vector2(1280, 720)]), Color("#b9a68a"))
		c.draw_rect(Rect2(500, 120, 280, 310), Color("#7f7466"))
		c.draw_rect(Rect2(500, 120, 280, 310), Color("#5d5448"), false, 5.0)
		c.draw_rect(Rect2(500, 424, 280, 8), Color("#1c1915"))
		# 門外的人：只看得到腳
		var col: Color = shoes[state.k % shoes.size()]
		for side in [-1, 1]:
			c.draw_rect(Rect2(Vector2(640 + side * 40 - 26, 560), Vector2(52, 22)), col)
			c.draw_rect(Rect2(Vector2(640 + side * 40 - 14, 470), Vector2(28, 92)), Color("#4d4a52"))
		c.draw_string(GameState.font, Vector2(0, 680), "換了一雙鞋。" if state.k > 0 else "", HORIZONTAL_ALIGNMENT_CENTER, 1280, 24, Color("#4a4238")))
	if not GameState.fast:
		for k in shoes.size():
			state.k = k
			c.queue_redraw()
			if k == 0 and not GameState.gentle():
				_play("door_thud", -18.0)
			await get_tree().create_timer(1.6).timeout
	layer.queue_free()


## 慈愛組織的第一個晚上：電閘
func _breaker() -> void:
	if GameState.fast:
		return
	if GameState.gentle():
		_play("breaker_soft", -2.0)
		_blackout.visible = true
		await get_tree().create_timer(2.0).timeout
		_blackout.visible = false
		return
	_play("breaker", -2.0)
	_blackout.visible = true
	_blackout.color = Color(1, 1, 1, 0.85)
	await get_tree().create_timer(0.12).timeout
	for k in 6:
		_blackout.color = Color(0, 0, 0, 1) if k % 2 == 0 else Color(1, 1, 1, 0.4)
		await get_tree().create_timer(0.09).timeout
	_blackout.color = Color.BLACK
	await get_tree().create_timer(1.6).timeout
	_blackout.visible = false


func _play(name: String, db: float) -> void:
	if GameState.fast:
		return
	Sfx.play(self, name, db)


func _wait_press() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
	await get_tree().create_timer(0.15).timeout


func _to_title() -> void:
	GameState.save_game("c4_" + segment)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ───────── 章節結束 ─────────

func _chapter_end() -> void:
	GameState.meta.chapters_done = maxi(int(GameState.meta.get("chapters_done", 0)), 4)
	GameState.meta.ch4_flags = GameState.flags.duplicate()
	GameState.save_meta()
	GameState.delete_save()
	var card := CanvasLayer.new()
	card.layer = 60
	add_child(card)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	if not GameState.fast:
		await get_tree().create_timer(2.0).timeout
		Motif.play(self, "sting")
	var box := VBoxContainer.new()
	box.position = Vector2(290, 110)
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var lines := ["第四章　三年二班　—　完", "",
		"窗外的白鴿　%s" % ("三個人都看到了" if GameState.has("c4_dove_seen") else "沒有看清楚"),
		"辛禾的信　%s" % ("想要不拿" if GameState.has("c4_letter_not_taken") else "拿走了"),
		"李恩的電話　%s" % ("說出了還有一個人" if GameState.has("c4_lien_told") else "沒有說"),
		"", "被電的那一邊，後來變成了漂白鎮。", "睡著的那一邊，後來變成了棉花糖鎮。"]
	for k in lines.size():
		var l := Label.new()
		l.text = lines[k]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 700
		l.add_theme_font_size_override("font_size", 34 if k == 0 else 22)
		l.add_theme_color_override("font_color", Color("#eef2f3") if k == 0 else Color("#c9d3d6"))
		box.add_child(l)
	var next := Button.new()
	next.text = "繼續第五章（終章）"
	next.custom_minimum_size = Vector2(320, 56)
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(func(): load("res://scripts/main.gd").enter_chapter5(get_tree()))
	box.add_child(next)
	var b := Button.new()
	b.text = "回到標題"
	b.custom_minimum_size = Vector2(320, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	box.add_child(b)
	next.grab_focus.call_deferred()
	_finished = true


## 自動測試用：章節跑完了
var _finished := false
