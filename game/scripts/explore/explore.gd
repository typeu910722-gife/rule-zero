class_name Explore
extends Node2D
## 第三～五章共用的「2D 室內探索」。關卡是一個 JSON 檔（game/levels/chapterN.json），格式見 docs/explore_format.md。
## 章節導演負責劇情順序：
##   explore = Explore.new(); explore.load_level("res://levels/chapter3.json"); add_child(explore)
##   explore.enter("hall", "start")            # 進房間（出生點名字或 [x, y]）
##   await explore.until("c3_heart_done")       # 讓玩家自由探索，直到條件成立（GameState.check 語法）
## 調查點、NPC、門、躲藏點、巡邏、密碼鎖都在 JSON 裡；劇本事件（@event）先交給 handle_event()，處理不了再由導演處理。

signal interacted(id: String)
signal caught(by: String)
signal room_entered(id: String)

const REACH := 72.0
const Keypad := preload("res://scripts/explore/keypad.gd")

var level: Dictionary = {}
var room_id := ""
var room: Dictionary = {}
var player: ExplorePlayer
var party: Array = []            # 跟在後面的同伴 id
var busy := true                 # 對話、小遊戲進行中：不能走、不能互動
var paused := false              # 選單開著等
var _world: Node2D               # 這個房間的東西（換房間時整個換掉）
var _ysort: Node2D
var _cam: Camera2D
var _prompt: Label
var _items: Label
var _toast: Label
var _toast_t := 0.0
var _fade: ColorRect
var _dark: CanvasModulate
var _light: PointLight2D
var _patrols: Array = []
var _followers: Array = []
var _entry := Vector2.ZERO       # 被抓到時回到這裡（最後一次進門的位置）
var _waiting := ""               # until() 等的條件
var hidden_in := ""


func load_level(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("找不到關卡 %s" % path)
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		level = data
	else:
		push_error("關卡 JSON 格式錯誤：%s" % path)


func _ready() -> void:
	_world = Node2D.new()
	add_child(_world)
	player = ExplorePlayer.new()
	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 7.0
	player.add_child(_cam)
	var ui := CanvasLayer.new()
	ui.layer = 15
	add_child(ui)
	_prompt = _label(ui, Vector2(0, 640), 24)
	_items = _label(ui, Vector2(16, 78), 18)
	_items.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_items.size.x = 900
	_toast = _label(ui, Vector2(0, 300), 26)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)
	_dark = CanvasModulate.new()
	_dark.color = Color.WHITE
	add_child(_dark)
	GameState.changed.connect(_on_changed)
	var touch := preload("res://scripts/ch2/touch_controls.gd").new()
	touch.mode_provider = func(): return "explore" if not busy and not paused else ""
	add_child(touch)


func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(1280, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#2e3a3f"))
	l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.92))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# ───────── 房間 ─────────

func enter(id: String, spawn: Variant = "start") -> void:
	if not level.get("rooms", {}).has(id):
		push_error("沒有這個房間：%s" % id)
		return
	room_id = id
	room = level.rooms[id]
	for c in _world.get_children():
		c.queue_free()
	_patrols.clear()
	_followers.clear()
	hidden_in = ""
	var size := _v(room.get("size", [1280, 720]))
	var th := ExploreArt.theme(room.get("theme", "hospital"))
	var back := Node2D.new()
	back.z_index = -10
	back.draw.connect(func(): _draw_back(back, size, th))
	_world.add_child(back)
	_ysort = Node2D.new()
	_ysort.y_sort_enabled = true
	_world.add_child(_ysort)
	# 家具
	for p in room.get("props", []):
		var n := Node2D.new()
		var r := _r(p.rect)
		n.position = Vector2(r.position.x, r.end.y)
		var local := Rect2(Vector2(0, -r.size.y), r.size)
		var kind: String = p.get("kind", "box")
		var lab: String = p.get("label", "")
		n.draw.connect(func(): ExploreArt.draw_prop(n, kind, local, th, lab))
		_ysort.add_child(n)
	# 調查點、NPC、門、躲藏點
	for s in _things():
		var n := Node2D.new()
		n.position = _v(s.pos)
		n.set_meta("thing", s)
		n.draw.connect(func(): _draw_thing(n, s))
		_ysort.add_child(n)
	# 巡邏
	for pd in room.get("patrols", []):
		var pt := ExplorePatrol.new()
		pt.setup(pd, self)
		_ysort.add_child(pt)
		_patrols.append(pt)
	# 小布與同伴
	if player.get_parent():
		player.get_parent().remove_child(player)
	_ysort.add_child(player)
	player.bounds = Rect2(Vector2.ZERO, size)
	player.blockers = _blockers()
	var sp := _spawn(spawn)
	player.place(sp)
	_entry = sp
	for i in party.size():
		var fo := Node2D.new()
		var fid: String = party[i]
		fo.set_meta("id", fid)
		fo.set_meta("k", i)
		fo.position = player.trail[mini(player.trail.size() - 1, 7 + i * 7)]
		fo.draw.connect(func(): ExploreArt.draw_char(fo, fid, Vector2.ZERO))
		_ysort.add_child(fo)
		_followers.append(fo)
	# 鏡頭：房間比畫面小時置中
	_cam.limit_left = int(minf(0.0, (size.x - 1280.0) / 2.0))
	_cam.limit_right = int(maxf(size.x, _cam.limit_left + 1280.0))
	_cam.limit_top = int(minf(-60.0, (size.y - 720.0) / 2.0 - 60.0))
	_cam.limit_bottom = int(maxf(size.y + 40.0, _cam.limit_top + 720.0))
	_cam.reset_smoothing()
	# 暗的房間：只有身邊一圈亮
	var dark: bool = room.get("dark", false)
	_dark.color = Color(0.13, 0.14, 0.17) if dark else Color.WHITE
	if dark and _light == null:
		_light = PointLight2D.new()
		var g := GradientTexture2D.new()
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		g.width = 512
		g.height = 512
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		g.gradient = gr
		_light.texture = g
		_light.texture_scale = 1.3
		_light.energy = 1.6
		player.add_child(_light)
	if _light:
		_light.enabled = dark
	_refresh_items()
	room_entered.emit(id)
	var on_enter: String = room.get("on_enter", "")
	if on_enter != "" and not GameState.has("seen_" + on_enter) and Dialogue.has_label(on_enter):
		GameState.flags["seen_" + on_enter] = true
		var was := busy
		busy = true
		await Dialogue.run(on_enter)
		Dialogue.set_bg("none")
		busy = was


func _spawn(spawn: Variant) -> Vector2:
	if spawn is Array:
		return _v(spawn)
	if spawn is Vector2:
		return spawn
	var spawns: Dictionary = room.get("spawns", {})
	if spawns.has(spawn):
		return _v(spawns[spawn])
	if spawns.has("start"):
		return _v(spawns.start)
	var size := _v(room.get("size", [1280, 720]))
	return size / 2.0


func _blockers() -> Array:
	var out: Array = []
	var size := _v(room.get("size", [1280, 720]))
	var wall := float(room.get("wall_h", 90))
	out.append(Rect2(0, 0, size.x, wall))      # 上面的牆
	for w in room.get("walls", []):
		out.append(_r(w))
	for p in room.get("props", []):
		if p.get("solid", true):
			out.append(_r(p.rect))
	return out


## 這個房間現在看得到的東西（條件 when 成立的）
func _things() -> Array:
	var out: Array = []
	for key in ["spots", "npcs", "doors", "hides"]:
		for s in room.get(key, []):
			var d: Dictionary = s.duplicate()
			d["_kind"] = key
			if d.get("when", "") != "" and not GameState.check(d.when):
				continue
			if d.get("once", false) and GameState.has("done_" + str(d.get("id", ""))):
				continue
			out.append(d)
	return out


func _draw_back(c: Node2D, size: Vector2, th: Dictionary) -> void:
	var art: String = room.get("art", "")
	var tex := ExploreArt.tex(art) if art != "" else null
	if tex:
		c.draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		return
	var wall := float(room.get("wall_h", 90))
	c.draw_rect(Rect2(-400, -400, size.x + 800, size.y + 800), Color(th.wall).darkened(0.55))
	c.draw_rect(Rect2(0, 0, size.x, wall), Color(th.wall))
	c.draw_rect(Rect2(0, wall - 8, size.x, 8), Color(th.line))
	c.draw_rect(Rect2(0, wall, size.x, size.y - wall), Color(th.floor))
	# 地磚
	var tile := 80.0
	var lc := Color(th.line)
	lc.a = 0.25
	var x := 0.0
	while x <= size.x:
		c.draw_line(Vector2(x, wall), Vector2(x, size.y), lc, 1.0)
		x += tile
	var y := wall
	while y <= size.y:
		c.draw_line(Vector2(0, y), Vector2(size.x, y), lc, 1.0)
		y += tile
	for w in room.get("walls", []):
		var r := _r(w)
		c.draw_rect(r, Color(th.wall))
		c.draw_rect(Rect2(r.position, Vector2(r.size.x, minf(10.0, r.size.y))), Color(th.top))
		c.draw_rect(r, lc.darkened(0.2), false, 1.0)
	# 地上的字、線（例如醫院的指示線）
	for d in room.get("decals", []):
		match d.get("kind", ""):
			"line":
				var pts := PackedVector2Array()
				for p in d.points:
					pts.append(_v(p))
				c.draw_polyline(pts, Color(d.get("color", "#f5a3b8")), float(d.get("width", 6)))
			"text":
				c.draw_string(GameState.font, _v(d.pos), d.text, HORIZONTAL_ALIGNMENT_CENTER, float(d.get("w", 300)), int(d.get("size", 22)), Color(d.get("color", "#7c98a2")))
			"rect":
				c.draw_rect(_r(d.rect), Color(d.get("color", "#ffffff")))


func _draw_thing(n: Node2D, s: Dictionary) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	match s._kind:
		"npcs":
			var who: String = s.get("char", "")
			if who.begins_with("human:"):
				ExploreArt.draw_human(n, Vector2.ZERO, who.trim_prefix("human:"))
			else:
				ExploreArt.draw_char(n, who, Vector2.ZERO, s.get("flip", false))
			if s.get("name", "") != "":
				n.draw_string(GameState.font, Vector2(-60, 20), s.name, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color("#55606a"))
		"doors":
			var sz := _v(s.get("size", [90, 26]))
			var open := _door_open(s)
			n.draw_rect(Rect2(-sz / 2.0, sz), Color("#f6d0da") if open else Color("#c8b5ba"))
			n.draw_rect(Rect2(-sz / 2.0, sz), Color("#d4788f") if open else Color("#8c7a80"), false, 2.0)
			n.draw_string(GameState.font, Vector2(-80, -sz.y / 2.0 - 6), s.get("name", "門") + ("" if open else "（鎖著）"), HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color("#6a4c56"))
		"hides":
			var sz2 := _v(s.get("size", [60, 30]))
			ExploreArt.draw_prop(n, s.get("kind", "locker"), Rect2(Vector2(-sz2.x / 2.0, -sz2.y), sz2), ExploreArt.theme(room.get("theme", "hospital")))
			if hidden_in == str(s.get("id", "")):
				n.draw_string(GameState.font, Vector2(-60, -100), "（躲著）", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color("#d65a5a"))
		_:
			# 調查點：小小的閃光（有 kind 的話畫成家具）
			if s.has("kind"):
				var sz3 := _v(s.get("size", [60, 30]))
				ExploreArt.draw_prop(n, s.kind, Rect2(Vector2(-sz3.x / 2.0, -sz3.y), sz3), ExploreArt.theme(room.get("theme", "hospital")))
			var a := 0.55 + 0.35 * sin(t * 3.0 + n.position.x)
			n.draw_circle(Vector2(0, -12), 5, Color(1, 1, 1, a))
			n.draw_arc(Vector2(0, -12), 10, 0, TAU, 16, Color(0.95, 0.55, 0.68, a), 2.0)


func _door_open(s: Dictionary) -> bool:
	var cond: String = s.get("open", "")
	return cond == "" or GameState.check(cond)


# ───────── 每一幀 ─────────

func _process(delta: float) -> void:
	var can := not busy and not paused and hidden_in == ""
	player.can_move = can
	# 同伴沿著小布走過的路跟著
	for fo in _followers:
		var k: int = fo.get_meta("k")
		var idx := mini(player.trail.size() - 1, 7 + k * 7)
		if idx >= 0:
			fo.position = fo.position.lerp(player.trail[idx], minf(1.0, delta * 10.0))
	for n in _ysort.get_children():
		if n.has_meta("thing"):
			n.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	if not can:
		_prompt.text = ""
		return
	var it := nearest()
	_prompt.text = ("%s：%s" % [GameState.interact_key_label(), _thing_name(it)]) if not it.is_empty() else ""


func _thing_name(s: Dictionary) -> String:
	match s.get("_kind", ""):
		"hides":
			return "躲進" + s.get("name", "裡面")
		"doors":
			return s.get("name", "門")
	return s.get("name", "")


func nearest() -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for n in _ysort.get_children():
		if not n.has_meta("thing"):
			continue
		var s: Dictionary = n.get_meta("thing")
		var reach := float(s.get("reach", REACH))
		var d := player.position.distance_to(n.position)
		if d < reach and d < bd:
			bd = d
			best = s
	return best


func _unhandled_input(event: InputEvent) -> void:
	if busy or paused:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if hidden_in != "":
			_unhide()
			return
		var it := nearest()
		if not it.is_empty():
			interact(it)


func interact(s: Dictionary) -> void:
	busy = true
	var id: String = str(s.get("id", ""))
	match s._kind:
		"doors":
			if _door_open(s):
				if not GameState.fast:
					Sfx.play(self, "train_door", -14.0)
				await _fade_to(1.0)
				await enter(s.to, s.get("spawn", "start"))
				await _fade_to(0.0)
			else:
				var lab: String = s.get("locked_label", "")
				if lab != "" and Dialogue.has_label(lab):
					await Dialogue.run(lab)
					Dialogue.set_bg("none")
				else:
					toast(s.get("locked_text", "鎖住了。"))
		"hides":
			hidden_in = id
			player.tucked = true
			player.queue_redraw()
			for fo in _followers:
				fo.visible = false
			toast("（躲起來了。按 %s 出來）" % GameState.interact_key_label())
		_:
			var lab2: String = s.get("label", id)
			if Dialogue.has_label(lab2):
				await Dialogue.run(lab2)
				# 對話裡換過背景（黑屏、CG）：回到地圖
				Dialogue.set_bg("none")
			if s.get("set", "") != "":
				GameState.set_flag(s.set)
			GameState.flags["done_" + id] = true
			interacted.emit(id)
	busy = false
	if is_inside_tree():
		_rebuild_things()


func _unhide() -> void:
	hidden_in = ""
	player.tucked = false
	player.queue_redraw()
	for fo in _followers:
		fo.visible = true


## 條件改變後（拿到鑰匙、門打開了）重新放調查點
func _rebuild_things() -> void:
	if _ysort == null:
		return
	for n in _ysort.get_children():
		if n.has_meta("thing"):
			n.queue_free()
	for s in _things():
		var n := Node2D.new()
		n.position = _v(s.pos)
		n.set_meta("thing", s)
		n.draw.connect(func(): _draw_thing(n, s))
		_ysort.add_child(n)
	player.blockers = _blockers()
	_refresh_items()


func _on_changed() -> void:
	_refresh_items()


func _refresh_items() -> void:
	if _items == null:
		return
	var names: Array = []
	var items: Dictionary = level.get("items", {})
	for k in items:
		if GameState.has(k):
			names.append(items[k])
	_items.text = ("持有：" + "、".join(names)) if not names.is_empty() else ""


func toast(text: String, secs := 2.2) -> void:
	_toast.text = text
	_toast_t = secs


func _fade_to(a: float) -> void:
	if GameState.fast:
		_fade.color.a = 0.0
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, 0.25)
	await tw.finished


## 讓玩家自由探索，直到條件成立
func until(cond: String) -> void:
	busy = false
	while is_inside_tree() and not GameState.check(cond):
		await get_tree().process_frame
		if GameState.fast and not busy:
			await _auto_step(cond)
	busy = true


## 被巡邏的看到（ExplorePatrol 呼叫）
func on_spotted(by: Dictionary) -> void:
	if busy or hidden_in != "":
		return
	busy = true
	var lab: String = by.get("catch", "")
	if not GameState.fast:
		Sfx.play(self, "wrong", -4.0)
		toast("！", 0.8)
		await get_tree().create_timer(0.6).timeout
	if lab != "" and Dialogue.has_label(lab):
		await Dialogue.run(lab)
	caught.emit(str(by.get("id", by.get("char", ""))))
	await _fade_to(1.0)
	player.place(_entry)
	for fo in _followers:
		fo.position = _entry
	for p in _patrols:
		p.reset()
	await _fade_to(0.0)
	busy = false


## 劇本的 @event：密碼鎖等由這裡處理；回傳 true 表示處理掉了
func handle_event(name: String) -> bool:
	var pads: Dictionary = level.get("keypads", {})
	if pads.has(name):
		var pd: Dictionary = pads[name]
		var kp := Keypad.new()
		kp.title = pd.get("title", "密碼鎖")
		kp.code = str(pd.code)
		kp.hint_text = pd.get("hint", "")
		add_child(kp)
		var ok: bool = await kp.play()
		if ok:
			GameState.set_flag(pd.flag)
		elif pd.get("fail_flag", "") != "":
			GameState.set_flag(pd.fail_flag)
		return true
	return false


# ───────── 存檔 ─────────

func save_state() -> void:
	GameState.flags["explore_room"] = room_id
	GameState.flags["explore_pos"] = [player.position.x, player.position.y]


func restore_or(room_default: String, spawn_default: Variant = "start") -> void:
	var r: String = str(GameState.flags.get("explore_room", ""))
	var p = GameState.flags.get("explore_pos", null)
	if r != "" and level.rooms.has(r) and p is Array:
		await enter(r, p)
	else:
		await enter(room_default, spawn_default)


# ───────── 自動測試：快速模式下自己找下一個可以做的事 ─────────

## 依序：還沒調查過的調查點／NPC → 打得開、還沒走過的門。用 BFS 走過所有房間。
var _auto_seen := {}
## 按過、但當時什麼都沒改變的東西：旗標狀態沒變之前不要再按（例如還沒有鑰匙卡的電梯）
var _auto_tried := {}


func _auto_step(_cond: String) -> void:
	await get_tree().process_frame
	if busy:
		return
	for s in _things():
		var sid := str(s.get("id", ""))
		var pending: bool = not GameState.check(s.done_when) if s.has("done_when") else not GameState.has("done_" + sid)
		if pending and _auto_tried.get(sid, -1) == _flags_hash():
			pending = false
		if s._kind in ["spots", "npcs"] and pending and not s.get("auto_skip", false):
			player.place(_v(s.pos) + Vector2(0, 30))
			var before := _flags_hash()
			await interact(s)
			_auto_tried[sid] = _flags_hash() if _flags_hash() == before else -1
			return
	# 換房間：挑一扇打得開、最久沒走過的門
	var doors: Array = _things().filter(func(s): return s._kind == "doors" and _door_open(s))
	if doors.is_empty():
		return
	doors.sort_custom(func(a, b): return int(_auto_seen.get(room_id + ">" + str(a.to), 0)) < int(_auto_seen.get(room_id + ">" + str(b.to), 0)))
	var d: Dictionary = doors[0]
	var key := room_id + ">" + str(d.to)
	_auto_seen[key] = int(_auto_seen.get(key, 0)) + 1
	await interact(d)


func _flags_hash() -> int:
	var keys := GameState.flags.keys().filter(func(k): return not str(k).begins_with("explore_") and not str(k).begins_with("seen_") and not str(k).begins_with("done_"))
	keys.sort()
	return str(keys).hash()


static func _v(a) -> Vector2:
	if a is Vector2:
		return a
	return Vector2(float(a[0]), float(a[1]))


static func _r(a) -> Rect2:
	return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
