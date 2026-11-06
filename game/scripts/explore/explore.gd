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
signal chase_changed(active: bool, by: String)

const REACH := 72.0
const Keypad := preload("res://scripts/explore/keypad.gd")

var level: Dictionary = {}
var level_path := ""
var _art: Dictionary = {}        # 這個房間的美術（_room_art）
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
var _chasing_patrols := {}
var _followers: Array = []
var _entry := Vector2.ZERO       # 被抓到時回到這裡（最後一次進門的位置）
var _waiting := ""               # until() 等的條件
var hidden_in := ""
## 不暗的房間的整體色調（第四章「放學後」用暖暗的夕陽色）
var tint := Color.WHITE
## 壓迫感：平常的暗角強度（0～1；章節導演可以調）。threat＝最近的巡邏有多近（0～1，給音效、測試看）
var dread := 0.22
## 進房間時依主題自動換環境音（章節導演要安靜的段落可以關掉）
var auto_ambience := true
const AMB_BY_THEME := {"hospital": "hum", "lab": "hum", "real": "hum", "hospital_old": "drone", "basement": "drone",
	"platform": "drone", "school": "room", "school_dark": "room", "home": "room", "town": ""}
var threat := 0.0
var _vig := 0.0
var _beat := 0.0


func load_level(path: String) -> void:
	level_path = path
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
	_guide_lbl = _label(ui, Vector2(16, 78), 18)
	_guide_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_guide_lbl.size = Vector2.ZERO
	_guide_lbl.add_theme_color_override("font_color", Color("#5a3d4f"))
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1, 0.98, 0.97, 0.82)
	gsb.set_corner_radius_all(10)
	gsb.content_margin_left = 12
	gsb.content_margin_right = 14
	gsb.content_margin_top = 4
	gsb.content_margin_bottom = 6
	_guide_lbl.add_theme_stylebox_override("normal", gsb)
	# 目標不在畫面裡：畫面邊緣一個箭頭指過去
	_edge_arrow = Control.new()
	_edge_arrow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_edge_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_arrow.draw.connect(_draw_edge_arrow)
	ui.add_child(_edge_arrow)
	_items = _label(ui, Vector2(16, 132), 18)
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
	# 追逐中換房間：追兵留在原本的房間，追逐結束（不然追逐的音樂會一直播）
	if not _chasing_patrols.is_empty():
		_chasing_patrols.clear()
		chase_changed.emit(false, "")
	_occluders.clear()
	_followers.clear()
	hidden_in = ""
	var size := _v(room.get("size", [1280, 720]))
	var th := ExploreArt.theme(room.get("theme", "hospital"))
	_art = _room_art(id)
	if auto_ambience:
		Sound.ambience(AMB_BY_THEME.get(room.get("theme", "hospital"), ""))
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
		var key := "prop:%s@%d,%d,%d,%d" % [kind, int(r.position.x), int(r.position.y), int(r.size.x), int(r.size.y)]
		if _art_tex(key):
			n.draw.connect(func(): _draw_art(n, key))
			# 遮擋圖蓋住的範圍：角色走到它後面時變半透明（_process）
			var tex := _art_tex(key)
			n.set_meta("occ", Rect2(n.position + _v(_art.props[key].off), tex.get_size()))
			_occluders.append(n)
		elif kind in ["window", "rug", "blackboard"] and _art.has("bg"):
			pass   # 已經畫在房間的背景圖裡
		else:
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
		fo.position = sp + FORMATION[i % FORMATION.size()]
		fo.set_meta("row", 3)
		fo.set_meta("frame", 0)
		fo.draw.connect(func(): ExploreArt.draw_char(fo, fid, Vector2.ZERO, false, fo.get_meta("row"), fo.get_meta("frame")))
		_ysort.add_child(fo)
		_followers.append(fo)
	# 鏡頭：人類時期（主角是 h_ 開頭的人）拉近，看得到臉；房間比畫面小時置中
	var z := cam_zoom()
	_cam.zoom = Vector2(z, z)
	ExploreArt.human_mul = HUMAN_SIZE if z > 1.0 else 1.0
	var view := Vector2(1280.0, 720.0) / z
	var top_pad := 60.0 / z
	_cam.limit_left = int(minf(0.0, (size.x - view.x) / 2.0))
	_cam.limit_right = int(maxf(size.x, _cam.limit_left + view.x))
	_cam.limit_top = int(minf(-top_pad, (size.y - view.y) / 2.0 - top_pad))
	_cam.limit_bottom = int(maxf(size.y + 40.0 / z, _cam.limit_top + view.y))
	_cam.reset_smoothing()
	# 暗的房間：只有身邊一圈亮
	_apply_dark()
	_refresh_items()
	refresh_guide()
	room_entered.emit(id)
	var on_enter: String = room.get("on_enter", "")
	if on_enter != "" and not GameState.has("seen_" + on_enter) and Dialogue.has_label(on_enter):
		GameState.flags["seen_" + on_enter] = true
		var was := busy
		busy = true
		await Dialogue.run(on_enter)
		Dialogue.set_bg("none")
		busy = was


## 人類時期：鏡頭拉近、人放大（房間是照玩偶的大小做的，人照原比例會比桌子還矮、看不到臉）
## 剛進房間時同伴站的位置（小布身後一小團，不排成一長列）
const FORMATION := [Vector2(-34, -16), Vector2(34, -16), Vector2(-62, -38), Vector2(0, -42), Vector2(62, -38), Vector2(-30, -64), Vector2(30, -64)]
const HUMAN_ZOOM := 1.5
const HUMAN_SIZE := 1.5


func cam_zoom() -> float:
	return HUMAN_ZOOM if player and player.look.begins_with("h_") else 1.0


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
			var pr := _r(p.rect)
			out.append(pr)
			# 靠牆的家具（櫃子、書架）：家具和牆中間的縫也擋住，不會走進家具裡、站到牆上
			var gap := pr.position.y - wall
			if gap > 0.0 and gap <= 75.0:
				out.append(Rect2(pr.position.x, wall, pr.size.x, gap))
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


## 房間美術（tools/art/blender/room.py 做的）：res://art/rooms/<關卡檔名>/<房間 id>/room.json；沒有就回傳空的，照舊用程式畫
func _room_art(id: String) -> Dictionary:
	var dir := "res://art/rooms/%s/%s/" % [level_path.get_file().get_basename(), id]
	if level_path == "" or not FileAccess.file_exists(dir + "room.json"):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(dir + "room.json"))
	if not (data is Dictionary):
		return {}
	data["dir"] = dir
	return data


func _art_tex(key: String) -> Texture2D:
	if not _art.get("props", {}).has(key):
		return null
	return ExploreArt.tex(_art.dir + str(_art.props[key].tex))


func _draw_art(n: Node2D, key: String) -> void:
	var t := _art_tex(key)
	if t:
		n.draw_texture(t, _v(_art.props[key].off))


func _draw_back(c: Node2D, size: Vector2, th: Dictionary) -> void:
	var bg_tex := ExploreArt.tex(_art.dir + str(_art.bg)) if _art.has("bg") else null
	if bg_tex:
		c.draw_rect(Rect2(-400, -400, size.x + 800, size.y + 800), Color(th.wall).darkened(0.8))
		c.draw_texture_rect(bg_tex, Rect2(Vector2.ZERO, size), false)
		# ChatGPT 重畫的房間（tools/art/room_repaint.py）：招牌、指示都畫在圖裡了，不再把字寫在地上
		for d in ([] if _art.get("painted", false) else room.get("decals", [])):
			if d.get("kind", "") == "text":
				c.draw_string(GameState.font, _v(d.pos), d.text, HORIZONTAL_ALIGNMENT_CENTER, float(d.get("w", 300)), int(d.get("size", 22)), Color(d.get("color", "#7c98a2")))
		return
	var art := _room_art_path()   # 沒有 Blender 美術時：關卡指定的圖，或第三章舊的整張地圖
	var tex := ExploreArt.tex(art) if art != "" else null
	if tex:
		# 房間比 1280×720 短時，鏡頭會看到邊界外；先鋪同色延伸，避免露出粉紅／黑色清除色。
		c.draw_rect(Rect2(-400, -400, size.x + 800, size.y + 800), Color(th.wall).darkened(0.18))
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


func _room_art_path() -> String:
	var explicit: String = room.get("art", "")
	if explicit != "" and ResourceLoader.exists(explicit):
		return explicit
	var ch3 := "res://art/ch3/maps/ch3_map_%s.jpg" % room_id
	return ch3 if ResourceLoader.exists(ch3) else ""


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
				# 白邊：重畫過的暗色地板上也看得清楚
				n.draw_string_outline(GameState.font, Vector2(-60, 20), s.name, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, 5, Color(1, 1, 1, 0.8))
				n.draw_string(GameState.font, Vector2(-60, 20), s.name, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color("#55606a"))
		"doors":
			var sz := _v(s.get("size", [90, 26]))
			var open := _door_open(s)
			var th := ExploreArt.theme(room.get("theme", "hospital"))
			var rc := Rect2(-sz / 2.0, sz)
			var painted: bool = _art.get("painted", false)
			# 重畫過的房間：門口就畫在地圖上，不再貼門的圖（會破圖），只在對應位置畫一個標記
			var art_kind := _draw_door_marker(n, sz, open, t) if painted else _draw_door_art(n, s, sz, open)
			if painted or art_kind != "":
				pass
			elif open:
				# 開著的門：一個暗暗的門洞，越裡面越黑
				n.draw_rect(rc.grow(4), Color(th.line).darkened(0.25))
				var steps := 6
				for k in steps:
					var f := float(k) / steps
					n.draw_rect(rc.grow(-minf(sz.x, sz.y) * 0.5 * f), Color(0.04, 0.045, 0.05, 0.55 + 0.45 * f))
			else:
				# 鎖著的門：關著的門板＋橫槓
				n.draw_rect(rc.grow(4), Color(th.line).darkened(0.35))
				n.draw_rect(rc, Color(th.wall).darkened(0.25))
				n.draw_rect(Rect2(rc.position + Vector2(0, sz.y * 0.45), Vector2(sz.x, 6)), Color(0.25, 0.27, 0.28))
			var near := player != null and player.position.distance_to(n.position) < 220.0
			var label: String = s.get("name", "門") + ("" if open else "（鎖著）")
			# 上面牆的門畫了正面的圖：名字寫在門的下面，不壓在門上
			var ly := sz.y / 2.0 + 20.0 if art_kind == "front" else -sz.y / 2.0 - 8.0
			n.draw_string_outline(GameState.font, Vector2(-80, ly), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, 5, Color(1, 1, 1, 0.75 if near else 0.35))
			n.draw_string(GameState.font, Vector2(-80, ly), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 15, Color(0.25, 0.28, 0.3, 1.0 if near else 0.45))
		"hides":
			var sz2 := _v(s.get("size", [60, 30]))
			if _art_tex("hide:" + str(s.get("id", ""))):
				_draw_art(n, "hide:" + str(s.get("id", "")))
			else:
				ExploreArt.draw_prop(n, s.get("kind", "locker"), Rect2(Vector2(-sz2.x / 2.0, -sz2.y), sz2), ExploreArt.theme(room.get("theme", "hospital")))
			if hidden_in == str(s.get("id", "")):
				n.draw_string(GameState.font, Vector2(-60, -100), "（躲著）", HORIZONTAL_ALIGNMENT_CENTER, 120, 15, Color("#d65a5a"))
		_:
			# 調查點：小小的閃光（有 kind 的話畫成家具）
			if s.has("kind") and _art_tex("spot:" + str(s.get("id", ""))):
				_draw_art(n, "spot:" + str(s.get("id", "")))
			elif s.has("kind"):
				var sz3 := _v(s.get("size", [60, 30]))
				ExploreArt.draw_prop(n, s.kind, Rect2(Vector2(-sz3.x / 2.0, -sz3.y), sz3), ExploreArt.theme(room.get("theme", "hospital")))
			if GameState.has("done_" + str(s.get("id", ""))) and not _pending(s):
				# 調查過了：灰色、不閃，一眼看得出來
				n.draw_arc(Vector2(0, -12), 8, 0, TAU, 16, Color(0.6, 0.6, 0.62, 0.45), 1.5)
			else:
				var a := 0.55 + 0.35 * sin(t * 3.0 + n.position.x)
				n.draw_circle(Vector2(0, -12), 5, Color(1, 1, 1, a))
				n.draw_arc(Vector2(0, -12), 10, 0, TAU, 16, Color(0.95, 0.55, 0.68, a), 2.0)
	if show_guide and not _guide.is_empty() and _guide.room == room_id and str(s.get("id", "")) == _guide.id and s._kind == _guide.kind:
		_draw_guide_arrow(n, s, t)


## 重畫過的房間的門口標記：地上一圈淡淡的光＋往外的箭頭（鎖著的門是灰色、畫一把鎖的橫槓）。
## 回傳 "front"（上面牆的門，名字寫在標記下面）或 "side"
func _draw_door_marker(n: Node2D, sz: Vector2, open: bool, t: float) -> String:
	var room_sz := _v(room.get("size", [1280, 720]))
	var p := n.position
	var dir := Vector2.UP
	if sz.y > sz.x:
		dir = Vector2.LEFT if p.x < room_sz.x / 2.0 else Vector2.RIGHT
	elif p.y > room_sz.y / 2.0:
		dir = Vector2.DOWN
	var col := Color(1.0, 0.86, 0.55) if open else Color(0.62, 0.64, 0.68)
	var a := (0.45 + 0.25 * sin(t * 2.5 + p.x * 0.01)) if open else 0.4
	# 地上的光：門的範圍畫成一塊淡淡的橢圓
	var r := maxf(sz.x, sz.y) * 0.5
	n.draw_set_transform(Vector2.ZERO, dir.angle() + PI / 2.0, Vector2(1.0, 0.35))
	for k in 4:
		var f := 1.0 - k * 0.22
		n.draw_circle(Vector2.ZERO, r * f, Color(col.r, col.g, col.b, a * 0.18))
	n.draw_set_transform(Vector2.ZERO)
	# 往外的箭頭（開著的門會往外輕輕動）
	var bob := (sin(t * 3.0) * 4.0) if open else 0.0
	var tip := dir * (16.0 + bob)
	var side := Vector2(-dir.y, dir.x) * 11.0
	var pts := PackedVector2Array([tip, tip - dir * 14.0 + side, tip - dir * 8.0, tip - dir * 14.0 - side])
	n.draw_colored_polygon(pts, Color(col.r, col.g, col.b, minf(1.0, a + 0.35)))
	n.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.2, 0.22, 0.5), 1.5)
	if not open:
		n.draw_rect(Rect2(Vector2(-9, -8), Vector2(18, 14)), Color(0.35, 0.37, 0.4, 0.85))
		n.draw_arc(Vector2(0, -8), 6, PI, TAU, 10, Color(0.35, 0.37, 0.4, 0.85), 2.5)
	return "front" if dir == Vector2.UP else "side"


## 門的圖：上面牆（橫的門、在房間上半）畫正面、腳在門框的下緣；左右牆、下面牆畫俯視的細長門。
## 右邊牆的門左右翻過來（門板朝房間裡開）。回傳畫了哪一種（"front"／"side"）；沒有圖回傳 ""，退回程式畫的方塊
func _draw_door_art(n: Node2D, _s: Dictionary, sz: Vector2, open: bool) -> String:
	var th: String = room.get("theme", "hospital")
	var room_sz := _v(room.get("size", [1280, 720]))
	var room_h := room_sz.y
	var room_w := room_sz.x
	var top := sz.x > sz.y and n.position.y < room_h / 2.0
	var art := ExploreArt.door_art(th, "front" if top else "side", open)
	if art.is_empty():
		return ""
	var t: Texture2D = art[0]
	var ratio := float(t.get_width()) / t.get_height()
	if top:
		# 正面：門的高度不超出房間上緣，寬度最多比門的範圍寬一點
		var h := minf(n.position.y + sz.y / 2.0 + 6.0, (sz.x + 12.0) / ratio)
		var w := h * ratio
		n.draw_texture_rect(t, Rect2(Vector2(-w / 2.0, sz.y / 2.0 - h), Vector2(w, h)), false, art[1])
	elif sz.y >= sz.x:
		var h2 := sz.y + 16.0
		var w2 := h2 * ratio
		var flip := n.position.x > room_w / 2.0
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if flip else 1, 1))
		n.draw_texture_rect(t, Rect2(Vector2(-w2 / 2.0, -h2 / 2.0), Vector2(w2, h2)), false, art[1])
		n.draw_set_transform(Vector2.ZERO)
	else:
		# 下面牆：俯視的門轉 90 度躺平
		var ln := sz.x + 16.0
		var thick := ln * ratio
		n.draw_set_transform(Vector2.ZERO, -PI / 2.0)
		n.draw_texture_rect(t, Rect2(Vector2(-thick / 2.0, -ln / 2.0), Vector2(thick, ln)), false, art[1])
		n.draw_set_transform(Vector2.ZERO)
	return "front" if top else "side"


func _door_open(s: Dictionary) -> bool:
	var cond: String = s.get("open", "")
	return cond == "" or GameState.check(cond)


# ───────── 每一幀 ─────────

func _process(delta: float) -> void:
	var can := not busy and not paused and hidden_in == ""
	player.can_move = can
	# 同伴沿著小布走過的路跟著
	for fo in _followers:
		if not player.walked:
			break
		var k: int = fo.get_meta("k")
		var idx := mini(player.trail.size() - 1, 7 + k * 7)
		if idx >= 0:
			var before: Vector2 = fo.position
			fo.position = fo.position.lerp(player.trail[idx], minf(1.0, delta * 10.0))
			# 走路圖：往哪邊走就換哪一列，有在動才換格
			var mv: Vector2 = fo.position - before
			if mv.length() > 0.3:
				fo.set_meta("row", ExploreArt.walk_row(mv))
				fo.set_meta("frame", int(Time.get_ticks_msec() / 140.0) % 4)
			else:
				fo.set_meta("frame", 0)
			fo.queue_redraw()
	if _ysort:   # 還沒進任何房間（加進場景後、enter() 之前）時是 null
		for n in _ysort.get_children():
			if n.has_meta("thing"):
				n.queue_redraw()
	if _edge_arrow:
		_edge_arrow.queue_redraw()
	_fade_occluders(delta)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.text = ""
	_dread_step(delta)
	if not can:
		_prompt.text = ""
		return
	var it := nearest()
	_prompt.text = ("%s：%s" % [GameState.interact_key_label(), _thing_name(it)]) if not it.is_empty() else ""


## 壓迫感：畫面四周的暗角（暗的房間更重）；巡邏的人越近，暗角越收、心跳越快、畫面微微晃
func _dread_step(delta: float) -> void:
	if player == null or room.is_empty():
		return
	var close := 0.0
	for pt in _patrols:
		if is_instance_valid(pt) and pt.active():
			var d: float = pt.position.distance_to(player.position)
			close = maxf(close, clampf(1.0 - (d - 90.0) / 380.0, 0.0, 1.0))
	threat = close
	var want := dread + (0.3 if is_dark() else 0.0) + close * 0.45
	_vig = lerpf(_vig, clampf(want, 0.0, 1.0), minf(1.0, delta * 3.0))
	if Dialogue.get("fx") and Dialogue.fx:
		Dialogue.fx.vignette = _vig
	var calm := GameState.gentle() or busy
	if close > 0.15 and not calm:
		_beat -= delta
		if _beat <= 0.0:
			Sound.sfx("heartbeat")
			_beat = lerpf(1.25, 0.45, close)
	else:
		_beat = 0.3
	if _cam:
		var k := maxf(0.0, close - 0.55) * 4.0 if not calm else 0.0
		_cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * k


func _exit_tree() -> void:
	ExploreArt.human_mul = 1.0
	# 地圖探索結束時還在被追：通知章節把追逐的音樂換回來
	if not _chasing_patrols.is_empty():
		_chasing_patrols.clear()
		chase_changed.emit(false, "")
	if Dialogue.get("fx") and Dialogue.fx:
		Dialogue.fx.vignette = 0.0


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
			# 按了、可是什麼都沒改變（例如還沒有鑰匙卡的電梯）：引導先跳過它，等旗標變了再說
			if _pending(s):
				_tried[room_id + "/" + id] = _flags_hash()
	busy = false
	if is_inside_tree():
		_rebuild_things()
		refresh_guide()


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


## 這個房間現在是不是暗的：dark＝true，而且 lit_when（例如配電箱修好）還沒成立
func is_dark() -> bool:
	if room.is_empty() or not room.get("dark", false):
		return false
	var lit: String = room.get("lit_when", "")
	return lit == "" or not GameState.check(lit)


## 暗的房間：只有身邊一圈亮；燈亮了（lit_when 成立）就恢復一般的顏色
func _apply_dark() -> void:
	if _dark == null or player == null:
		return
	var dark := is_dark()
	_dark.color = Color(0.13, 0.14, 0.17) if dark else tint
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


func _on_changed() -> void:
	_apply_dark()
	_refresh_items()
	refresh_guide()


func _refresh_items() -> void:
	if _items == null:
		return
	var names: Array = []
	var items: Dictionary = level.get("items", {})
	# 用過、之後用不到的東西就不再顯示（items_used：持有旗標 → 用掉的條件）
	var used: Dictionary = level.get("items_used", {})
	for k in items:
		if GameState.has(k) and not (used.has(k) and GameState.check(used[k])):
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
	goal_cond = cond
	refresh_guide()
	busy = false
	while is_inside_tree() and not GameState.check(cond):
		await get_tree().process_frame
		if GameState.fast and not busy:
			if auto_by_guide:
				await _guide_step()
			else:
				await _auto_step(cond)
	busy = true


## 被巡邏的看到（ExplorePatrol 呼叫）
func on_spotted(by: Dictionary) -> void:
	if busy or hidden_in != "":
		return
	busy = true
	var lab: String = by.get("catch", "")
	if not GameState.fast:
		var scare: String = by.get("scare", "")
		if scare != "":
			var j := JumpScare.new()
			j.who = scare
			add_child(j)
			Sound.duck(true)
			await j.play()
			Sound.duck(false)
			j.queue_free()
		else:
			Sfx.play(self, "wrong", -4.0)
			toast("！", 0.8)
			await get_tree().create_timer(0.6).timeout
	if lab != "" and Dialogue.has_label(lab):
		await Dialogue.run(lab)
	caught.emit(str(by.get("id", by.get("char", ""))))
	await _fade_to(1.0)
	player.place(_entry)
	for fo in _followers:
		fo.position = _entry + FORMATION[int(fo.get_meta("k")) % FORMATION.size()]
	for p in _patrols:
		p.reset()
	await _fade_to(0.0)
	busy = false


## 巡邏者開始／停止追逐。多個追兵同時存在時，最後一個停下才關掉追逐音樂。
func patrol_chase_changed(active: bool, by: String) -> void:
	if active:
		_chasing_patrols[by] = true
	else:
		_chasing_patrols.erase(by)
	chase_changed.emit(not _chasing_patrols.is_empty(), by)


## 劇本的 @event：密碼鎖等由這裡處理；回傳 true 表示處理掉了
func handle_event(name: String) -> bool:
	var pads: Dictionary = level.get("keypads", {})
	if pads.has(name):
		var pd: Dictionary = pads[name]
		var kp := Keypad.new()
		kp.title = pd.get("title", "密碼鎖")
		kp.code = str(pd.code)
		kp.hint_text = pd.get("hint", "")
		# 找到線索之後，密碼鎖下面幫你記著（hint_when 成立就換成 hint_found）
		if pd.get("hint_when", "") != "" and GameState.check(pd.hint_when):
			kp.hint_text = pd.get("hint_found", kp.hint_text)
		add_child(kp)
		var ok: bool = await kp.play()
		if ok:
			GameState.set_flag(pd.flag)
		elif pd.get("fail_flag", "") != "":
			GameState.set_flag(pd.fail_flag)
		return true
	return false


# ───────── 主線引導（第三～五章；同第一、二章的目標）─────────

## 每一段地圖探索的主線（chapter 腳本呼叫 until(條件) 時，依條件找這裡的文字）
const GOALS := {
	"c3_took_elevator": "到醫院裡面，找到上二樓的方法。",
	"c3_haruka_slip": "在二樓找一找：遙的床在哪裡。",
	"c3_to_wild": "找到往舊病棟的連通道。",
	"c3_crow": "穿過舊病棟，走到最裡面。",
	"c3_monitor_seen": "在地下二樓找到監控室。",
	"c4_h_spoke": "走進三年二班的教室，向全班自我介紹。",
	"c4_m_done": "找回書包和鞋子，然後去校門口。",
	"c4_t_done": "在自己的房間裡看一看。",
	"c4_l_done": "找齊三片鏡子的碎片，回到自己的房間。",
	"c4_x_done": "等大家走光，然後去校門口的郵筒。",
	"c4_p_done": "穿過人群，去校門口的信箱。",
	"c4_te_done": "待到晚上，最後看看教室後面的班規。",
	"c4_f_done": "看看自己的桌子和垃圾桶，然後走到走廊盡頭。",
	"c4_d1_done": "到樓梯口去。",
	"c4_d2_done": "拿水桶，把教室的窗戶擦乾淨。",
	"c4_d5_done": "去找老師，然後趕到樓梯口。",
	"c4_d8_done": "看看樓梯底下，然後打電話。",
	"c4_o_done": "像影子一樣走過那些地方，最後到月台。",
	"c4_n_done": "看看白線的兩邊，還有遙。",
	"c5_x_done": "在實驗室裡看看大家，然後去找車掌。",
	"c5_l_done": "去檔案室和監視室，再回到病床。",
	"c5_baimian_returned": "叫醒大家，走到白線的另一邊。",
	"c5_a_done": "走出醫院的大門。",
	"c5_b1_done": "走到月台，等夜車。",
	"c5_b2_done": "守住走廊，走到走廊盡頭的床。",
	"c5_b3_done": "出院，走到校門口。",
}

var goal_cond := ""          # 現在這段探索要等的條件（until）
var goal := ""               # 章節自己指定的主線文字（空＝用 GOALS）
var show_guide := true
var _guide := {}             # {"room", "id", "kind", "text"}：下一步要去的東西
var _guide_lbl: Label
var _tried := {}             # 玩家按過、沒有改變什麼的東西（房間/id → 當時的旗標）
var _edge_arrow: Control
var _occluders: Array = []     # 有遮擋圖的家具（角色在後面時變半透明）


func _things_in(r: Dictionary) -> Array:
	var keep := room
	room = r
	var out := _things()
	room = keep
	return out


## 調查點、人物還沒做完（做完：done_when 成立，或按過一次）
func _pending(s: Dictionary) -> bool:
	if not s.get("_kind", "") in ["spots", "npcs"] or s.get("auto_skip", false):
		return false
	if s.has("done_when"):
		return not GameState.check(s.done_when)
	return not GameState.has("done_" + str(s.get("id", "")))


## 會結束這一段的東西（set 這個條件，或 done_when 寫著它）
func _finishes(s: Dictionary) -> bool:
	return goal_cond != "" and (str(s.get("set", "")) == goal_cond or goal_cond in str(s.get("done_when", "")))


## 找下一步：先找能結束這一段的東西；沒有的話，最近的還沒調查的東西。在別的房間就指向路上的門。
func find_guide() -> Dictionary:
	if room_id == "" or not level.has("rooms"):
		return {}
	var h := _flags_hash()
	var best := {}
	var best_score := INF
	var fallback := {}
	var fallback_score := INF
	# 房間之間的最短路（只走打得開的門）
	var first_door := {room_id: {}}
	var dist := {room_id: 0}
	var queue := [room_id]
	while not queue.is_empty():
		var rid: String = queue.pop_front()
		for s in _things_in(level.rooms[rid]):
			if s._kind == "doors" and _door_open(s) and level.rooms.has(str(s.to)) and not dist.has(str(s.to)):
				dist[str(s.to)] = dist[rid] + 1
				first_door[str(s.to)] = s if rid == room_id else first_door[rid]
				queue.append(str(s.to))
	for rid in dist:
		for s in _things_in(level.rooms[rid]):
			if not _pending(s):
				continue
			var score := float(dist[rid]) * 10000.0
			if rid == room_id and player:
				score += player.position.distance_to(_v(s.pos))
			if _finishes(s):
				score -= 1000000.0
			# 調查過、可是還沒完成的（例如還沒鑰匙卡的電梯、要先跟大家說完話的車掌）：排在還沒調查過的後面
			if GameState.has("done_" + str(s.get("id", ""))):
				score += 3000000.0
			# 按過之後重要的旗標都沒變：先不指它；真的沒別的事可做了才指回去
			if _tried.get(rid + "/" + str(s.get("id", "")), -1) == h:
				if score < fallback_score:
					fallback_score = score
					fallback = {"room": rid, "s": s}
				continue
			if score < best_score:
				best_score = score
				best = {"room": rid, "s": s}
		# 還沒進去過的房間（有進門的劇情還沒看過）也是下一步，例如監控室
		var oe: String = level.rooms[rid].get("on_enter", "")
		if rid != room_id and oe != "" and not GameState.has("seen_" + oe) and Dialogue.has_label(oe):
			var sc := float(dist[rid]) * 10000.0 + 5000.0
			if sc < best_score:
				best_score = sc
				best = {"room": rid, "s": {}}
	if best.is_empty():
		best = fallback
	if best.is_empty():
		return {}
	var s: Dictionary = best.s
	if best.room == room_id:
		return {"room": room_id, "id": str(s.get("id", "")), "kind": s._kind, "text": ("找%s說話" if s._kind == "npcs" else "調查「%s」") % s.get("name", "")}
	var d: Dictionary = first_door[best.room]
	var where: String = level.rooms[best.room].get("name", "")
	return {"room": room_id, "id": str(d.get("id", "")), "kind": "doors", "text": "往「%s」（要去：%s）" % [d.get("name", "門"), where]}


func refresh_guide() -> void:
	if _guide_lbl == null:
		return
	_guide = find_guide() if show_guide else {}
	var g := goal if goal != "" else str(GOALS.get(goal_cond, ""))
	var lines := []
	if g != "":
		lines.append("目標：" + g)
	if not _guide.is_empty():
		lines.append("→ 下一步：" + _guide.text)
	_guide_lbl.text = "
".join(lines) if show_guide else ""
	_guide_lbl.visible = _guide_lbl.text != ""
	_guide_lbl.reset_size()


## 角色（小布或同伴）走到家具後面、被遮擋圖蓋住時，家具變半透明，不會看不到人
func _fade_occluders(delta: float) -> void:
	var feet: Array = [player.position]
	for fo in _followers:
		feet.append(fo.position)
	# 站在桌子後面的人物（教室裡坐著的同學）、巡邏的人：被家具擋住時家具也要變半透明
	if _ysort:
		for n in _ysort.get_children():
			if n.has_meta("thing") and str((n.get_meta("thing") as Dictionary).get("_kind", "")) == "npcs" and n.visible:
				feet.append(n.position)
	for pt in _patrols:
		if is_instance_valid(pt) and pt.visible:
			feet.append(pt.position)
	for n in _occluders:
		if not is_instance_valid(n):
			continue
		var r: Rect2 = n.get_meta("occ")
		var behind := false
		for f in feet:
			# 腳在家具的「腳」上面（比較後面），而且身體（往上約 80px）和遮擋圖重疊
			if f.y < n.position.y and r.intersects(Rect2(f - Vector2(18, 80 * cam_zoom()), Vector2(36, 80 * cam_zoom()))):
				behind = true
				break
		var want := 0.42 if behind else 1.0
		n.modulate.a = move_toward(n.modulate.a, want, delta * 4.0)


## 下一步的東西在畫面外：畫面邊緣畫一個指向它的箭頭（回傳箭頭的位置，給測試用；在畫面裡回傳 null）
func guide_edge_point() -> Variant:
	if _guide.is_empty() or _ysort == null or busy or not show_guide:
		return null
	for n in _ysort.get_children():
		if n.has_meta("thing"):
			var s: Dictionary = n.get_meta("thing")
			if str(s.get("id", "")) == _guide.id and s._kind == _guide.kind:
				var p: Vector2 = get_viewport().get_canvas_transform() * (n.global_position + Vector2(0, -30))
				var view := Rect2(Vector2(40, 150), Vector2(1200, 500))
				if view.has_point(p):
					return null
				return p.clamp(view.position, view.end)
	return null


func _draw_edge_arrow() -> void:
	var p = guide_edge_point()
	if p == null:
		return
	var center := Vector2(640, 400)
	var dir: Vector2 = ((p as Vector2) - center).normalized()
	var bob := sin(Time.get_ticks_msec() / 250.0) * 5.0
	var tip: Vector2 = p + dir * bob
	var side := dir.orthogonal()
	var col := Color(0.93, 0.36, 0.55, 0.95)
	_edge_arrow.draw_colored_polygon(PackedVector2Array([tip + dir * 4, tip - dir * 30 + side * 20, tip - dir * 30 - side * 20]), Color(1, 1, 1, 0.9))
	_edge_arrow.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 26 + side * 15, tip - dir * 26 - side * 15]), col)


## 下一步的東西頭上：一個上下跳的粉紅色箭頭
func _draw_guide_arrow(n: Node2D, s: Dictionary, t: float) -> void:
	var top := -60.0
	match s._kind:
		"npcs":
			top = -130.0
		"doors":
			top = -_v(s.get("size", [90, 26])).y / 2.0 - 34.0
	var y := top + sin(t * 4.0) * 6.0
	var col := Color(0.93, 0.36, 0.55, 0.95)
	n.draw_colored_polygon(PackedVector2Array([Vector2(-13, y - 16), Vector2(13, y - 16), Vector2(0, y)]), Color(1, 1, 1, 0.9))
	n.draw_colored_polygon(PackedVector2Array([Vector2(-9, y - 13), Vector2(9, y - 13), Vector2(0, y - 3)]), col)


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


## 自動測試：只照引導箭頭玩（tests/guide_test.gd）。引導找不到下一步就記一次「卡住」
static var auto_by_guide := false
static var guide_stuck := 0
static var guide_steps := 0


func _guide_step() -> void:
	await get_tree().process_frame
	if busy:
		return
	refresh_guide()
	if _guide.is_empty():
		guide_stuck += 1
		print("  [引導卡住] 房間 %s　等 %s" % [room_id, goal_cond])
		# 卡住時退回一般的自動玩家，測試才不會無限等
		await _auto_step(goal_cond)
		return
	for s in _things():
		if str(s.get("id", "")) == _guide.id and s._kind == _guide.kind:
			guide_steps += 1
			player.place(_v(s.pos) + Vector2(0, 30))
			await interact(s)
			return
	guide_stuck += 1
	await _auto_step(goal_cond)


## 引導用：連「按過哪些東西」也算進去（跟其他人說完話，車掌那邊才會有新的反應）
func _guide_hash() -> int:
	var keys := GameState.flags.keys().filter(func(k): return not str(k).begins_with("explore_"))
	keys.sort()
	return str(keys).hash()


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
