extends Node2D
## 第三章到第六章的流程導演。
## 第三章醫院，第四章人類時期的學校，第五、六章收尾。
## 白面從第三章跟著走到第六章，不在中間退場。

const Places := preload("res://scripts/world/places.gd")
const Player := preload("res://scripts/world/player.gd")
const Board := preload("res://scripts/ui/board.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const EndCard := preload("res://scripts/ui/end_card.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const Visit := preload("res://scripts/minigames/visit.gd")
const Deliver := preload("res://scripts/minigames/deliver.gd")
const SafeCode := preload("res://scripts/minigames/safe_code.gd")
const SewRound := preload("res://scripts/minigames/sew_round.gd")
const RewriteRule := preload("res://scripts/minigames/rewrite_rule.gd")

const EXPLORE := ["c3_day1", "c3_day2", "c4_day1", "c4_day2", "c5_night", "c6_plaza"]
const BGM := {3: "ward", 4: "school", 5: "mayor", 6: "plaza"}
const PLACE := {3: "ward", 4: "school", 5: "workshop", 6: "plaza"}
const TINT := {
	"ward": Color(0.94, 0.98, 0.96),
	"school": Color(1, 0.98, 0.94),
	"workshop": Color(0.82, 0.78, 0.72),
	"plaza": Color(1, 0.97, 0.96),
}

var phase := ""
var busy := true
var actors := {}
var places: Node2D
var player: Node2D
var hud: CanvasLayer
var board: CanvasLayer
var tint: CanvasModulate
var fade: ColorRect
var music: AudioStreamPlayer
var _bgm_name := ""


func _ready() -> void:
	_build()
	match GameState.checkpoint:
		"c3_day1", "c3_day2":
			_resume("c3_day1" if GameState.checkpoint == "c3_day1" else "c3_day2")
		"c4_day1", "c4_day2":
			_resume(GameState.checkpoint)
		"c5_night", "c6_plaza":
			_resume(GameState.checkpoint)
		"c5_replay":
			_ch5_open.call_deferred()
		_:
			match GameState.chapter:
				4:
					_ch4_open.call_deferred()
				5:
					_ch5_open.call_deferred()
				6:
					_ch6_open.call_deferred()
				_:
					GameState.chapter = 3
					_ch3_open.call_deferred()


func _build() -> void:
	tint = CanvasModulate.new()
	add_child(tint)
	places = Places.new()
	add_child(places)
	var cast := {
		"baimian": {"name": "白面", "species": "fox", "color": Color("#e4e4e0"), "smile": false, "opts": {"pale": true, "no_tail": true}},
		"lulu": {"name": "露露", "species": "rabbit", "color": Color("#f4b6c2")},
		"mochi": {"name": "麻糬", "species": "hamster", "color": Color("#fbf3e6"), "smile": false},
		"popo": {"name": "波波", "species": "penguin", "color": Color("#2f3352")},
		"fen": {"name": "Fen", "species": "fox", "color": Color("#d4773a"), "smile": false},
		"xiaoji": {"name": "小棘", "species": "hedgehog", "color": Color("#2f2f2f"), "opts": {"quills": 5}},
		"gaga": {"name": "嘎嘎", "species": "crow", "color": Color("#4a4a4a"), "smile": false, "opts": {"sewn": true}},
		"zhongzhong": {"name": "重重", "species": "hippo", "color": Color("#9c9c9c"), "smile": false, "size": 1.2, "stitched": true},
		"youyou": {"name": "鼬鼬", "species": "weasel", "color": Color("#b8b8b4"), "opts": {"thread": true}},
		"pip": {"name": "小布", "species": "sheep", "color": Color("#fffdf8")},
		"child": {"name": "鏡中", "species": "child", "color": Color.WHITE, "size": 1.15},
		"xiaoman": {"name": "小滿", "species": "student", "color": Color.WHITE, "opts": {"hair": Color("#c4a484")}},
		"xilufei": {"name": "希露飛", "species": "student", "color": Color.WHITE, "opts": {"hair": Color("#6a5344"), "bow": Color("#f2d16b")}},
		"mingyue": {"name": "銘越", "species": "student", "color": Color.WHITE, "opts": {"hair": Color("#2f3352")}},
		"xinhe": {"name": "辛禾", "species": "student", "color": Color.WHITE, "opts": {"hair": Color("#2a2a2a")}},
		"naiwen": {"name": "薙文", "species": "student", "color": Color.WHITE, "opts": {"hair": Color("#4a4a4a")}},
		"qiuge": {"name": "秋歌", "species": "student", "color": Color.WHITE, "opts": {"hair": Color("#1c1c1c")}},
		"staff": {"name": "職員", "species": "staff", "color": Color.WHITE},
		"conductor": {"name": "車掌", "species": "conductor", "color": Color.BLACK},
		"dove": {"name": "和平鴿", "species": "dove", "color": Color.WHITE},
	}
	for id in cast:
		var a := Interactable.new().setup(id, cast[id])
		a.visible = false
		add_child(a)
		actors[id] = a
	var objs := {
		"board": "公告欄", "file": "病歷櫃", "nw": "比斯泰德", "cot": "小床",
		"bed_self": "靠窗的床", "bed_fen": "床尾", "bed_naiwen": "還在跳的床",
		"desk": "遙的桌子", "bag": "垃圾桶", "gate": "門口",
		"mirror": "洗手台", "safe": "鐵櫃", "candy": "糖果罐", "ledger": "名冊", "tower": "鐘塔",
	}
	for id in objs:
		var o := Interactable.new().setup(id, {"name": objs[id], "kind": "obj"})
		o.visible = false
		add_child(o)
		actors[id] = o
	player = Player.new()
	player.can_move = false
	player.bounds = Rect2(30, 40, 1540, 1060)
	player.z_index = 2
	add_child(player)
	for a in actors.values():
		a.target = player
	music = AudioStreamPlayer.new()
	music.volume_db = -12.0
	add_child(music)
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
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade)
	var touch := TouchControls.new()
	touch.mode_provider = func():
		if hud.menu_open:
			return "menu"
		if busy or Dialogue.running or board.visible or not phase in EXPLORE:
			return ""
		return "explore"
	add_child(touch)
	Dialogue.event_requested.connect(_on_event)
	Dialogue.bgm_requested.connect(_bgm)
	hud.set_status_visible(false)


func _resume(which: String) -> void:
	Dialogue.set_bg("none")
	GameState.set_flag("play_as_mayor", which == "c5_night")
	_setup_place(PLACE.get(GameState.chapter, "ward"))
	_layout()
	player.position = _spot()
	hud.set_status_visible(true)
	fade.color.a = 0.0
	_enter(which)


func _ch3_open() -> void:
	GameState.start_chapter(3)
	_setup_place("ward")
	_layout()
	player.position = _spot()
	await _fade_to(0.0)
	await Dialogue.run("c3_opening")
	await Dialogue.run("c3_arrive")
	hud.set_status_visible(true)
	_enter("c3_day1")


func _ch4_open() -> void:
	GameState.start_chapter(4)
	GameState.set_flag("play_as_mayor", false)
	_setup_place("school")
	_layout()
	player.position = _spot()
	await _fade_to(0.0)
	await Dialogue.run("c4_opening")
	hud.set_status_visible(true)
	_enter("c4_day1")


func _ch5_open() -> void:
	GameState.start_chapter(5)
	GameState.set_flag("play_as_mayor")
	_setup_place("workshop")
	_layout()
	player.position = _spot()
	player.queue_redraw()
	await _fade_to(0.0)
	await Dialogue.run("c5_opening")
	hud.set_status_visible(true)
	_enter("c5_night")


func _ch6_open() -> void:
	GameState.start_chapter(6)
	GameState.set_flag("play_as_mayor", false)
	player.queue_redraw()
	_setup_place("plaza")
	_layout()
	player.position = _spot()
	await _fade_to(0.0)
	await Dialogue.run("c6_opening")
	hud.set_status_visible(true)
	_enter("c6_plaza")


func _sleep() -> void:
	match GameState.chapter:
		3:
			if GameState.day <= 1:
				await Dialogue.run("c3_sleep1")
				GameState.new_day()
				await Dialogue.run("c3_morning2")
				_enter("c3_day2")
			else:
				await Dialogue.run("c3_sleep2")
				GameState.new_day()
				await Dialogue.run("c3_morning3")
				actors.dove.visible = true
				actors.dove.position = Vector2(900, 760)
				await Dialogue.run("c3_dove")
				actors.dove.visible = false
				await Dialogue.run("c3_end")
				_finish_chapter(3)
				await _ch4_open()
		4:
			if GameState.day <= 1:
				await Dialogue.run("c4_sleep1")
				GameState.new_day()
				await Dialogue.run("c4_morning2")
				_enter("c4_day2")
			else:
				await Dialogue.run("c4_end")
				_finish_chapter(4)
				await _ch5_open()
		_:
			_enter(phase)


func _tower() -> void:
	await Dialogue.run("c6_tower_climb")
	if GameState.suspicion >= 80:
		await _play_finale("c6_repair")
		return
	await Dialogue.run("c6_tower_choice")
	await _play_finale(_finale_label())


func _ledger() -> void:
	await Dialogue.run("c5_ledger")
	if GameState.has("mayor_ask"):
		await _play_finale("c6_stay")
	else:
		_finish_chapter(5)
		await _ch6_open()


func _finale_label() -> String:
	return GameState.finale_label()


func _play_finale(label: String) -> void:
	if label == "c6_remember":
		GameState.set_flag("full_color")
		GameState.set_flag("cotton_wind")
		places.full_color = true
		places.queue_redraw()
		tint.color = Color.WHITE
		_bgm("remember")
	elif label == "c6_repair":
		_bgm("repair")
	elif label == "c6_stay":
		_bgm("mayor")
	else:
		actors.baimian.modulate = Color(0.78, 0.78, 0.78)
		_bgm("repair")
		_note_who_is_missing()
		if GameState.dream_count() < 3:
			GameState.set_flag("dreams_short")
	await Dialogue.run(label)
	_close_book(label)


func _note_who_is_missing() -> void:
	var raw: Variant = GameState.meta.get("ch2_fates", {})
	if not (raw is Dictionary):
		return
	var fates: Dictionary = raw
	if str(fates.get("xiaoji", "")) == "dead":
		GameState.set_flag("left_xiaoji")
	if str(fates.get("zhongzhong", "")) == "dead":
		GameState.set_flag("left_zhongzhong")


func _close_book(label: String) -> void:
	var key := "good"
	match label:
		"c6_remember":
			key = "remember"
		"c6_good":
			key = "good"
		"c6_short":
			key = "short"
		"c6_repair":
			key = "repair"
		"c6_stay":
			key = "stay"
		"c6_hid":
			key = "hid"
		"c6_comforted":
			key = "comforted"
		"c6_left":
			key = "left_behind"
		"c6_never":
			key = "never_ran"
		"c6_no_letter":
			key = "no_letter"
		"c6_no_why":
			key = "no_why"
	var kind := "壞"
	if key == "remember":
		kind = "好"
	elif key == "stay":
		kind = "不好不壞"
	phase = "ended"
	if not GameState.has("replay_mayor"):
		GameState.meta.threads = int(GameState.meta.get("threads", 0)) + GameState.threads_earned()
	GameState.meta.chapters_done = maxi(int(GameState.meta.get("chapters_done", 0)), 6)
	GameState.meta.ending = key
	GameState.meta.ending_kind = kind
	if key == "remember":
		GameState.meta.true_seen = true
	if key == "repair" or GameState.has("stitch_title"):
		GameState.meta.stitched = true
	GameState.save_meta()
	GameState.delete_save()
	busy = true
	player.can_move = false
	var card := EndCard.new()
	card.mode = "finale"
	add_child(card)


func _finish_chapter(n: int) -> void:
	GameState.meta.threads = int(GameState.meta.get("threads", 0)) + GameState.threads_earned()
	GameState.meta.chapters_done = maxi(int(GameState.meta.get("chapters_done", 0)), n)
	GameState.save_meta()


# ───────────────────────── 世界 ─────────────────────────

func _setup_place(name: String) -> void:
	places.place = name
	places.full_color = GameState.has("full_color")
	places.queue_redraw()
	tint.color = TINT.get(name, Color.WHITE)


func _spot() -> Vector2:
	match GameState.chapter:
		3:
			return Vector2(740, 820)
		4:
			return Vector2(640, 640)
		5:
			return Vector2(640, 860)
		_:
			return Vector2(640, 800)


func _layout() -> void:
	for a in actors.values():
		a.visible = false
	actors.baimian.modulate = Color.WHITE
	actors.baimian.display_name = "" if GameState.chapter == 4 else "白面"
	actors.fen.display_name = "芬" if GameState.chapter == 4 else "Fen"
	var show: Array = []
	match GameState.chapter:
		3:
			show = ["baimian", "lulu", "mochi", "popo", "staff", "conductor", "board", "file", "nw", "cot", "bed_self", "bed_fen"]
			if not _walking("tiaoma"):
				show.append("bed_naiwen")
		4:
			show = ["baimian", "fen", "xiaoman", "xilufei", "mingyue", "xinhe", "naiwen", "qiuge", "board", "cot", "desk", "bag", "mirror", "safe"]
			if GameState.day >= 2:
				show.append("gate")
		5:
			show = ["pip", "baimian", "lulu", "mochi", "popo", "board", "candy", "ledger"]
		_:
			show = ["baimian", "fen", "lulu", "mochi", "popo", "board", "tower"]
	for id in ["xiaoji", "gaga", "zhongzhong", "youyou"]:
		if _walking(id) and GameState.chapter != 4:
			show.append(id)
	var at := {
		"baimian": Vector2(420, 500), "lulu": Vector2(860, 540), "mochi": Vector2(1020, 580),
		"popo": Vector2(1180, 540), "fen": Vector2(1180, 520), "staff": Vector2(1240, 780),
		"conductor": Vector2(180, 980), "board": Vector2(700, 180), "file": Vector2(1340, 280),
		"nw": Vector2(1340, 520), "cot": Vector2(240, 980), "bed_self": Vector2(220, 360),
		"bed_fen": Vector2(420, 340), "bed_naiwen": Vector2(640, 360), "dove": Vector2(900, 760),
		"desk": Vector2(480, 300), "bag": Vector2(1380, 420), "gate": Vector2(700, 900),
		"mirror": Vector2(140, 300), "safe": Vector2(1380, 760), "child": Vector2(780, 400),
		"xiaoman": Vector2(280, 460), "xilufei": Vector2(460, 500), "mingyue": Vector2(640, 460),
		"xinhe": Vector2(820, 500), "naiwen": Vector2(980, 460), "qiuge": Vector2(1140, 500),
		"pip": Vector2(560, 620), "candy": Vector2(280, 420), "ledger": Vector2(1040, 380),
		"tower": Vector2(705, 280),
	}
	if GameState.chapter == 4:
		at.baimian = Vector2(180, 820)
	elif GameState.chapter == 5:
		at.baimian = Vector2(420, 680)
		at.lulu = Vector2(860, 640)
		at.board = Vector2(200, 240)
		at.pip = Vector2(640, 600)
	else:
		at.baimian = Vector2(480, 680)
		at.fen = Vector2(760, 640)
		at.lulu = Vector2(960, 700)
		at.board = Vector2(600, 420)
		at.tower = Vector2(705, 260)
	var extra := 0
	for id in show:
		if not actors.has(id):
			continue
		actors[id].visible = true
		if id in ["xiaoji", "gaga", "zhongzhong", "youyou"]:
			actors[id].position = Vector2(360 + extra * 140, 1000)
			extra += 1
		else:
			actors[id].position = at.get(id, Vector2(640, 640))
		actors[id].queue_redraw()
	if actors.has("mirror"):
		actors.mirror.covered = false


func _walking(id: String) -> bool:
	if id in ["baimian", "lulu", "mochi", "popo"]:
		return true
	return _fate(id) == "aboard"


func _fate(id: String) -> String:
	var fates: Dictionary = GameState.meta.get("ch2_fates", {})
	if fates.is_empty():
		return {"baimian": "aboard", "tiaoma": "dead"}.get(id, "unknown")
	return str(fates.get(id, "unknown"))


func _enter(which: String) -> void:
	_layout()
	_set_phase(which)
	_bgm(BGM.get(GameState.chapter, "plaza"))
	GameState.save_game(which)
	busy = false
	player.can_move = true


func _set_phase(p: String) -> void:
	phase = p
	match p:
		"c3_day1":
			GameState.set_objective("探視時間。看看病床和病歷櫃。看完了，回小床。")
		"c3_day2":
			GameState.set_objective("公告欄多了一行。白面在芬的床尾。")
		"c4_day1":
			GameState.set_objective("看看教室。桌面上的字，一個也不用念出來。")
		"c4_day2":
			GameState.set_objective("保健室旁邊的門開了。那扇門跟垃圾桶不在同一邊。")
		"c5_night":
			GameState.set_objective("你是鎮長。名冊在燈底下。")
		"c6_plaza":
			GameState.set_objective("鐘塔的門開了。")
		_:
			GameState.set_objective("")


func _fade_to(alpha: float) -> void:
	if GameState.fast:
		fade.color.a = alpha
		return
	var tw := create_tween()
	tw.tween_property(fade, "color:a", alpha, 0.45)
	await tw.finished


func _bgm(name: String) -> void:
	if name == _bgm_name:
		return
	_bgm_name = name
	music.stop()
	var stream: AudioStreamWAV = Score.loop(name)
	if stream == null:
		return
	music.stream = stream
	music.play()


func _exit_tree() -> void:
	if Dialogue.event_requested.is_connected(_on_event):
		Dialogue.event_requested.disconnect(_on_event)
	if Dialogue.bgm_requested.is_connected(_bgm):
		Dialogue.bgm_requested.disconnect(_bgm)


func _to_title() -> void:
	Dialogue.set_bg("none")
	_bgm("")
	get_tree().change_scene_to_file("res://scenes/main.tscn")


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
	if event.is_action_pressed("interact") and phase in EXPLORE:
		var it: Interactable = player.nearest()
		if it:
			get_viewport().set_input_as_handled()
			interact(it.id)


func interact(id: String) -> void:
	if busy or not phase in EXPLORE:
		return
	busy = true
	player.can_move = false
	hud.set_prompt("")
	if id == "board":
		await board.open()
	elif id == "cot":
		await _sleep()
	elif id == "ledger":
		await _ledger()
	elif id == "tower":
		await _tower()
	else:
		await Dialogue.run(_talk_label(id))
		if actors.has(id):
			actors[id].queue_redraw()
	if phase != "ended":
		busy = false
		player.can_move = true
		_set_phase(phase)


func _talk_label(id: String) -> String:
	var base := "c%d_%s" % [GameState.chapter, id]
	for c in ["%s_d%d" % [base, GameState.day], base]:
		if Dialogue.has_label(c):
			return c
	return "c_nothing"


func _process(_delta: float) -> void:
	if busy or Dialogue.running or hud.menu_open or board.visible or not phase in EXPLORE:
		hud.set_prompt("")
		return
	var it: Interactable = player.nearest()
	var key := "互動" if DisplayServer.is_touchscreen_available() else "E"
	hud.set_prompt("%s：%s" % [key, it.display_name] if it else "")


func _on_event(event_name: String) -> void:
	await get_tree().process_frame
	match event_name:
		"board":
			await board.open()
		"visit_hold":
			var visit := Visit.new()
			add_child(visit)
			await visit.play()
		"mirror_hold":
			if not GameState.fast:
				await get_tree().create_timer(1.1).timeout
			GameState.set_flag("mirror_looked")
		"deliver_lulu", "deliver_mochi", "deliver_fen", "deliver_self":
			await _deliver(event_name)
		"safe_code":
			var safe := SafeCode.new()
			add_child(safe)
			await safe.play()
		"sew_round":
			var sew := SewRound.new()
			sew.people = _sew_people()
			add_child(sew)
			await sew.play()
		"rewrite_rule":
			var rw := RewriteRule.new()
			add_child(rw)
			await rw.play()
		"baimian_gone":
			GameState.set_flag("baimian_unraveled")
			if actors.has("baimian"):
				actors.baimian.visible = false
		_:
			push_error("後期章節未處理的事件：%s" % event_name)
	Dialogue.event_done.emit()


func _deliver(event_name: String) -> void:
	var spec: Array = _letter_spec(event_name)
	var d := Deliver.new()
	d.letter_id = spec[0]
	d.correct = spec[1]
	d.ok_flag = spec[2]
	d.body = spec[3]
	d.prompt = "交給誰？"
	d.options = spec[4]
	add_child(d)
	await d.play()


func _letter_spec(event_name: String) -> Array:
	match event_name:
		"deliver_lulu":
			return ["lulu", "lulu", "sent_letter_lulu", "信封：給希露飛。", [["lulu", "露露"], ["mochi", "麻糬"], ["popo", "波波"], ["self", "自己"]]]
		"deliver_mochi":
			return ["mochi", "mochi", "sent_letter_mochi", "信封：給小滿。", [["mochi", "麻糬"], ["lulu", "露露"], ["baimian", "白面"], ["self", "自己"]]]
		"deliver_fen":
			return ["fen", "baimian", "sent_letter_fen", "信封：給芬。", [["baimian", "白面（放到芬的床上）"], ["lulu", "露露"], ["self", "自己"]]]
		_:
			return ["self", "self", "sent_self_letter", "給遙。\n我站在門口。我看見了。我沒有阻止。", [["self", "自己"], ["lulu", "露露"], ["mochi", "麻糬"], ["baimian", "白面"]]]


func _sew_people() -> Array:
	var ids := ["pip", "lulu", "mochi", "popo"]
	for id in ["xiaoji", "gaga", "zhongzhong", "youyou"]:
		if _walking(id):
			ids.append(id)
	ids.append("baimian")
	return ids
