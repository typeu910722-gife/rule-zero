extends Node2D
## 第三章「慈愛實驗醫院」的章節導演（基礎可玩版：房間調查＋小遊戲＋過場；美術之後陸續補）。
## 劇本：docs/script/chapter3.md　對話：game/dialogue/chapter3.txt
## 流程是一串「段落」：每段開始時存檔（檢查點 c3_<段落>），讀檔從那一段的開頭繼續。

const HeartCards := preload("res://scripts/ch3/heart_cards.gd")
const Thermo := preload("res://scripts/ch3/thermo.gd")
const Drip := preload("res://scripts/ch3/drip.gd")
const Sew := preload("res://scripts/ch3/sew.gd")
const Cpr := preload("res://scripts/ch3/cpr.gd")
const Runner := preload("res://scripts/ch3/runner.gd")
const Chase3DScript := preload("res://scripts/ch3/chase3d.gd")

const SEGMENTS := ["arrival", "floor1", "floor2", "wild", "chase1", "b2", "monitor", "chase2", "cpr", "ending"]
const PLACES := {"arrival": "地下月台", "floor1": "一樓", "floor2": "二樓",
	"wild": "舊病棟　失控區", "chase1": "醫院長廊", "b2": "地下二樓", "monitor": "地下二樓　監控室",
	"chase2": "醫院長廊", "cpr": "地下二樓", "ending": "實驗室"}

## 第二章的配樂沿用（第三章自製配樂之後補上）
const BGM_DIR := "res://audio/ch2/bgm/ch2_bgm%s.ogg"
const BGM := {"nirvana": "10_nirvana", "night": "08_night", "escape": "13_escape", "dove": "04_dove",
	"dream": "16_dream", "memory": "11_memory", "next_stop": "14_next_stop"}
const BGM_ONCE := ["escape"]

## 各房間的調查點（座標是 1280×720 的畫面）
const ROOMS := {
	"b2": [
		{"id": "c3_b2_locker", "name": "置物櫃", "rect": Rect2(50, 300, 160, 56)},
		{"id": "c3_b2_bed", "name": "病床底下", "rect": Rect2(470, 380, 180, 56)},
		{"id": "c3_b2_ecg", "name": "門外的心電圖", "rect": Rect2(800, 300, 200, 56)},
		{"id": "exit", "name": "監控室　→", "rect": Rect2(1040, 590, 200, 60), "when": "c3_scare_locker|c3_scare_bed|c3_scare_ecg", "exit": true},
	],
}

var segment := "arrival"
var party: Array = []
var hud: Ch3Hud
var room: Ch3Room
var _bgm_name := ""
var _blackout: ColorRect
var _lights_layer: CanvasLayer
## 地圖探索（levels/chapter3.json）：一樓已經改成自由走動；其他段落陸續改
var explore: Explore
const LEVEL := "res://levels/chapter3.json"


func _ready() -> void:
	GameState.chapter = 3
	# 標題畫面的「回憶」配樂（第一章的音樂系統，會變慢走音）不能帶進來，不然兩首疊在一起
	Sound.override_bgm("")
	Sound.bgm("")
	Sound.ambience("")
	Sound.set_wear(0)
	Dialogue.portrait_state = Callable()
	Dialogue.event_requested.connect(_on_event)
	Dialogue.bgm_requested.connect(_bgm)
	_build_party()
	hud = Ch3Hud.new()
	hud.party = party
	add_child(hud)
	hud.title_requested.connect(_to_title)
	_lights_layer = CanvasLayer.new()
	_lights_layer.layer = 45
	add_child(_lights_layer)
	_blackout = ColorRect.new()
	_blackout.color = Color.BLACK
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.visible = false
	_lights_layer.add_child(_blackout)
	var cp := GameState.checkpoint
	# 舊存檔：改成地圖探索之前的檢查點
	cp = {"c3_hall": "c3_floor1", "c3_nirvana": "c3_floor2", "c3_records": "c3_floor2"}.get(cp, cp)
	if cp.begins_with("c3_") and cp.trim_prefix("c3_") in SEGMENTS:
		segment = cp.trim_prefix("c3_")
	_run.call_deferred()


func _exit_tree() -> void:
	Audio.stop_music()
	if Dialogue.event_requested.is_connected(_on_event):
		Dialogue.event_requested.disconnect(_on_event)
	if Dialogue.bgm_requested.is_connected(_bgm):
		Dialogue.bgm_requested.disconnect(_bgm)


func _build_party() -> void:
	party = [["pip", "小布"], ["lulu", "露露"], ["mochi", "麻糬"], ["popo", "波波"], ["fen", "Fen"], ["baimian", "白面"]]
	for p in [["xiaoji", "小棘"], ["zhongzhong", "重重"], ["gaga", "嘎嘎"], ["youyou", "鼬鼬"]]:
		if GameState.has("with_%s" % p[0]):
			party.append(p)
	for p in party:
		var key := "c3_cotton_%s" % p[0]
		if not GameState.flags.has(key):
			GameState.flags[key] = 10


func _bgm(name: String) -> void:
	if name == _bgm_name:
		return
	_bgm_name = name
	var path: String = BGM_DIR % BGM[name] if BGM.has(name) else ""
	Audio.play_music(path, not name in BGM_ONCE, -3.0)


# ───────── 段落 ─────────

func _run() -> void:
	var i := SEGMENTS.find(segment)
	while i < SEGMENTS.size():
		segment = SEGMENTS[i]
		hud.place = PLACES[segment]
		hud.refresh()
		if segment != "arrival":
			GameState.save_game("c3_" + segment)
		await call("_seg_" + segment)
		if not is_inside_tree():
			return
		i += 1
	_chapter_end()


func _seg_arrival() -> void:
	await Dialogue.run("c3_arrival")


## 一樓：從地下月台開始自由探索，拿到鑰匙卡、搭上電梯就到二樓
func _seg_floor1() -> void:
	await _explore_until("platform", "start", "c3_took_elevator")


## 地圖探索：進到某個房間（讀檔時回到存檔的房間與位置），直到條件成立
func _explore_until(room_id: String, spawn: Variant, cond: String) -> void:
	await _explore_start(room_id, spawn)
	await explore.until(cond)
	_explore_end()


func _explore_start(room_id: String, spawn: Variant) -> void:
	Dialogue.set_bg("none")
	if explore == null:
		explore = Explore.new()
		explore.load_level(LEVEL)
		explore.party = party.map(func(p): return p[0]).filter(func(id): return id != "pip")
		add_child(explore)
		explore.room_entered.connect(_on_room_entered)
		explore.caught.connect(func(_by): _lose_cotton(1, 1))
	explore.visible = true
	await explore.restore_or(room_id, spawn)


func _explore_end() -> void:
	# 這一段結束：下一段從頭開始，不要回到這裡的位置
	GameState.flags.erase("explore_room")
	GameState.flags.erase("explore_pos")
	explore.queue_free()
	explore = null


func _on_room_entered(id: String) -> void:
	hud.place = explore.room.get("name", PLACES.get(segment, ""))
	hud.refresh()
	explore.save_state()
	GameState.save_game("c3_" + segment)


func _process(_d: float) -> void:
	if explore:
		explore.paused = hud.menu_open


## 二樓：前半看病床、找到「遙」被轉床的紙 → 巡房量體溫；後半有護理師巡邏，找鑰匙進病歷室、理事室 → 連通道
func _seg_floor2() -> void:
	GameState.courage = GameState.MAX_COURAGE
	GameState.changed.emit()
	await _explore_start("hall2", "from_elevator")
	if not GameState.has("c3_thermo_done"):
		await explore.until("c3_haruka_slip")
		explore.busy = true
		await Dialogue.run("c3_thermo_intro")
		GameState.set_flag("c3_thermo_done")
		explore.save_state()
		GameState.save_game("c3_floor2")
	await explore.until("c3_to_wild")
	_explore_end()


## 舊病棟：暗的走廊、點滴、找保險絲接上配電箱、畢業生巡邏（被抓會掉棉花）→ 盡頭的窗（烏鴉）
func _seg_wild() -> void:
	await _explore_until("wild_hall", "start", "c3_crow")


func _seg_chase1() -> void:
	Dialogue.set_bg("c3_wild")
	await Dialogue.run("c3_hideseek")


func _seg_b2() -> void:
	Dialogue.set_bg("c3_b2")
	await Dialogue.run("c3_b2_intro")
	Dialogue.set_bg("none")
	await _room("b2", "")


func _seg_monitor() -> void:
	await Dialogue.run("c3_monitor")


func _seg_chase2() -> void:
	Dialogue.set_bg("c3_monitor")
	await Dialogue.run("c3_rollcall")


func _seg_cpr() -> void:
	await Dialogue.run("c3_cpr")


func _seg_ending() -> void:
	await Dialogue.run("c3_ending")


## 一個房間：先跑開場對話，之後玩家調查，按「出口」才離開
func _room(id: String, intro: String) -> void:
	Dialogue.set_bg("none")
	room = Ch3Room.new()
	room.room_id = id
	room.spots = ROOMS[id]
	room.busy = true
	add_child(room)
	if intro != "":
		await Dialogue.run(intro)
	room.set_busy(false)
	while true:
		var picked: String = await room.picked
		room.set_busy(true)
		if picked == "exit":
			break
		await Dialogue.run(picked)
		Dialogue.set_bg("none")
		room.set_busy(false)
	room.queue_free()
	room = null


# ───────── @event ─────────

func _on_event(event_name: String) -> void:
	await get_tree().process_frame
	if explore and await explore.handle_event(event_name):
		Dialogue.event_done.emit()
		return
	match event_name:
		"c3_whistle":
			Motif.play(self, "whistle", -6.0)
		"c3_rules":
			await _show_rules()
		"c3_heart":
			var h := HeartCards.new()
			add_child(h)
			var misses: int = await h.play()
			if misses > 0:
				GameState.set_flag("c3_heart_miss", misses)
		"c3_thermo":
			var th := Thermo.new()
			th.queue = party.duplicate()
			add_child(th)
			for id in await th.play():
				GameState.set_flag("c3_fever_%s" % id)
		"c3_chase1":
			# 捉迷藏：3D 第一人稱追逐（之後換 Blender 的和平鴿模型）
			var c3d := Chase3DScript.new()
			add_child(c3d)
			_lose_cotton(await c3d.play(), 3)
			_lose_all(2)
		"c3_drip":
			var d := Drip.new()
			add_child(d)
			if await d.play() == false:
				GameState.set_flag("c3_drip_woke")
		"c3_drip_chase":
			if GameState.has("c3_drip_woke"):
				var r := Runner.new()
				r.duration = 15.0
				add_child(r)
				_lose_cotton(await r.play(), 3)
		"c3_sew":
			var low := party.duplicate()
			low.sort_custom(func(a, b): return _cotton(a[0]) < _cotton(b[0]))
			low = low.slice(0, 3)
			if _cotton("fen") <= 3:
				GameState.set_flag("c3_low_fen")
			var s := Sew.new()
			s.patients = low
			add_child(s)
			var crooked: Dictionary = await s.play()
			for p in low:
				_set_cotton(p[0], _cotton(p[0]) + 4)
			for id in crooked:
				GameState.set_flag("c3_crooked_%s" % id, crooked[id])
		"c3_chase2":
			var r2 := Runner.new()
			r2.rollcall = true
			add_child(r2)
			_lose_cotton(await r2.play(), 2)
			_lose_all(2)
		"c3_cpr":
			var c := Cpr.new()
			add_child(c)
			GameState.set_flag("c3_ecg_saved" if await c.play() else "c3_ecg_lost")
		"c3_lights":
			await _lights_on()
		"c3_gun":
			await _gunshot()
	Dialogue.event_done.emit()


func _cotton(id: String) -> int:
	return int(GameState.flags.get("c3_cotton_%s" % id, 10))


func _set_cotton(id: String, v: int) -> void:
	GameState.flags["c3_cotton_%s" % id] = clampi(v, 0, 10)
	GameState.changed.emit()


## 撞到幾次就掉幾次棉花（隨機一個人）；棉花不會歸零（本章不讓同伴退場）
func _lose_cotton(times: int, each: int) -> void:
	for k in times:
		var p: Array = party[randi() % party.size()]
		_set_cotton(p[0], maxi(1, _cotton(p[0]) - each))


func _lose_all(amount: int) -> void:
	for p in party:
		_set_cotton(p[0], maxi(1, _cotton(p[0]) - amount))


func _show_rules() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(340, 120)
	panel.custom_minimum_size = Vector2(600, 420)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fbfdfd")
	sb.border_color = Color("#9fb3ba")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.add_theme_font_size_override("normal_font_size", 26)
	t.add_theme_color_override("default_color", Color("#3d4a4f"))
	t.text = "[center][b]慈愛實驗醫院　醫院守則[/b][/center]\n\n1. 請保持安靜。\n2. 請不要離開病床。\n3. 請按時吃藥（白色的）。\n4. 探病時間以外，請不要看自己。\n5. 夜間巡房時，請閉上眼睛。\n\n[center][color=#9fb3ba]（按一下關閉）[/color][/center]"
	panel.add_child(t)
	if not GameState.fast:
		await _wait_press()
	layer.queue_free()


func _wait_press() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			break
	await get_tree().create_timer(0.15).timeout


## 結尾：燈一盞一盞亮起（一片黑 → 四段亮），口哨
func _lights_on() -> void:
	Dialogue.set_bg("c3_lab")
	_blackout.visible = true
	_blackout.color = Color(0, 0, 0, 1)
	if GameState.fast:
		_blackout.visible = false
		return
	Motif.play(self, "whistle", -4.0)
	for k in 4:
		await get_tree().create_timer(1.0).timeout
		_play("res://audio/ch3/light_on.ogg", -6.0)
		_blackout.color = Color(0, 0, 0, 1.0 - (k + 1) * 0.25)
	_blackout.visible = false


## 舉槍、上膛、黑屏、槍聲；什麼畫面都沒有，停一拍
func _gunshot() -> void:
	if not GameState.fast:
		_play("res://audio/ch3/gun_cock.ogg", -2.0)
		await get_tree().create_timer(1.2).timeout
	_blackout.color = Color.BLACK
	_blackout.visible = true
	Dialogue.set_bg("black")
	Audio.stop_music()
	if not GameState.fast:
		await get_tree().create_timer(0.8).timeout
		_play("res://audio/ch3/gunshot_soft.ogg" if GameState.gentle() else "res://audio/ch3/gunshot.ogg", 0.0)
		await get_tree().create_timer(3.0).timeout


func _play(path: String, db: float) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db + Audio.sfx_db()
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _to_title() -> void:
	GameState.save_game("c3_" + segment)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# ───────── 章節結束 ─────────

func _chapter_end() -> void:
	GameState.meta.chapters_done = maxi(int(GameState.meta.get("chapters_done", 0)), 3)
	GameState.meta.ch3_flags = GameState.flags.duplicate()
	GameState.save_meta()
	GameState.delete_save()
	var card := CanvasLayer.new()
	card.layer = 60
	add_child(card)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	# 結算的音樂先停一拍
	if not GameState.fast:
		await get_tree().create_timer(1.5).timeout
		Motif.play(self, "sting")
	var box := VBoxContainer.new()
	box.position = Vector2(290, 90)
	box.custom_minimum_size = Vector2(700, 0)
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	var t := Label.new()
	t.text = "第三章　慈愛實驗醫院　—　完"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color("#eef2f3"))
	box.add_child(t)
	var charts := ["pip", "fen"].filter(func(k): return GameState.has("c3_chart_%s" % k)).size()
	var bodies := ["lulu", "popo", "mochi", "fen", "zhongzhong"].filter(func(k): return GameState.has("c3_saw_body_%s" % k)).size()
	var lines := ["看見的身體　%d　　找到的病歷　%d" % [bodies, charts],
		"心電圖　%s" % ("救回來了" if GameState.has("c3_ecg_saved") else "沒有救回來"),
		"棉花　" + "　".join(party.map(func(p): return "%s %d" % [p[1], _cotton(p[0])]))]
	for s in lines:
		var l := Label.new()
		l.text = s
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 700
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color("#c9d3d6"))
		box.add_child(l)
	var next := Button.new()
	next.text = "繼續第四章「三年二班」"
	next.custom_minimum_size = Vector2(320, 56)
	next.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next.pressed.connect(func(): load("res://scripts/main.gd").enter_chapter4(get_tree()))
	box.add_child(next)
	var b := Button.new()
	b.text = "回到標題"
	b.custom_minimum_size = Vector2(260, 56)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	box.add_child(b)
	next.grab_focus.call_deferred()
	_finished = true


## 自動測試用：章節跑完了
var _finished := false
