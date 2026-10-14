class_name ChaseScene
extends CanvasLayer
## 第一章結尾：鎮長崩潰後的 3D 追逐戰。
## 小鎮被扭曲成縫線圍牆的迷宮。小布要在被抓到之前，跑到修理室的門口。
##
## 操作：↑ 前進、↓ 後退、← → 轉彎（手機：左下的方向鍵，往上推前進、左右推轉彎）
## 美術還沒有 3D 模型：牆是程式產生的布紋，角色用原本的 2D 行走圖（永遠面向鏡頭）。
## 被抓到 → 從頭再跑一次（被抓兩次以上，鎮長會變慢一點）。

signal finished

const MAZE := [
	"###############",
	"#S....#.......#",
	"####.##.#####.#",
	"#....#..#...#.#",
	"#.####.##.#.#.#",
	"#.#....#..#...#",
	"#.#.####.######",
	"#...#....#....#",
	"###.#.####.##.#",
	"#...#....#..#.#",
	"#.######.##.#.#",
	"#......#....#.#",
	"######.######.#",
	"#E.....#......#",
	"###############",
]
const CELL := 3.0
const WALL_H := 3.6
const BU_SPEED := 4.6
const TURN_SPEED := 2.8
const RADIUS := 0.42
const CATCH_DIST := 1.0
const START_DELAY := 2.6
const RULES := ["每天都要笑嘻嘻", "不要問以前的事", "壞掉的東西　交給老師修理", "老師會保護你們",
	"好孩子不可以哭", "不要想起來", "名牌要一直戴好", "放學鐘響了　要乖乖回家"]
const MAYOR_LINES := ["老師會保護你們……", "壞掉的東西……要修理……", "不要跑……老師不會生氣的……",
	"想起來的事情，才會痛喔……", "{name}……過來……", "好孩子……好孩子……好孩子……"]

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _bu: Sprite3D
var _mayor: Sprite3D
var _route: Array = []        # 起點 → 修理室的格子
var _start := Vector2i.ZERO
var _exit := Vector2i.ZERO
var _heading := 0.0
var _start_heading := 0.0
var _mayor_on := false
var _rise := 0.0
var _t := 0.0
var _mayor_path: Array = []
var _repath_t := 0.0
var _step_t := 0.0
var _step := 0
var _beat_t := 0.0
var _line_t := 5.0
var _attempts := 0
var _done := false
var _frozen := false
var _hud: Label
var _sub: Label
var _sub_a := 0.0
var _hud_a := 1.0


func _ready() -> void:
	layer = 2
	add_to_group("touch_joystick")
	_find_cells()
	_build()
	_reset_run()
	if GameState.fast:
		_finish.call_deferred()


func _find_cells() -> void:
	for y in MAZE.size():
		for x in MAZE[y].length():
			if MAZE[y][x] == "S":
				_start = Vector2i(x, y)
			elif MAZE[y][x] == "E":
				_exit = Vector2i(x, y)
	_route = _bfs(_start, _exit)


func _open(c: Vector2i) -> bool:
	return c.y >= 0 and c.y < MAZE.size() and c.x >= 0 and c.x < MAZE[c.y].length() and MAZE[c.y][c.x] != "#"


func _bfs(a: Vector2i, b: Vector2i) -> Array:
	var prev := {a: a}
	var q: Array = [a]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == b:
			break
		for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n: Vector2i = c + d
			if _open(n) and not prev.has(n):
				prev[n] = c
				q.append(n)
	if not prev.has(b):
		return []
	var path: Array = [b]
	while path[0] != a:
		path.push_front(prev[path[0]])
	return path


static func cell_center(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0, c.y * CELL)


func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))


func _blocked(p: Vector3) -> bool:
	for o in [Vector3(RADIUS, 0, 0), Vector3(-RADIUS, 0, 0), Vector3(0, 0, RADIUS), Vector3(0, 0, -RADIUS)]:
		if not _open(_cell_of(p + o)):
			return true
	return false


# ───────── 建場景 ─────────

func _build() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.size = Vector2i(1280, 720)
	box.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)

	var env := Environment.new()
	# 天空：紫紅色的霧、遠方的城堡（art/chase_sky.png）
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://art/chase_sky.png")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.42, 0.55)
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_light_color = Color(0.32, 0.14, 0.2)
	env.fog_density = 0.042
	env.fog_sky_affect = 0.25
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	# 月光（很淡的冷色，讓牆的邊緣看得出來）
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.55, 0.85)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-50, 30, 0)
	_world.add_child(moon)

	var w := MAZE[0].length()
	var h := MAZE.size()
	# 地板：石板路（貼圖 3 公尺一張，照世界座標鋪）
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(w * CELL, h * CELL)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = load("res://art/chase_floor.png")
	fm.uv1_triplanar = true
	fm.uv1_world_triplanar = true
	fm.uv1_scale = Vector3.ONE / CELL
	fm.roughness = 0.85
	floor_mesh.material = fm
	var floor := MeshInstance3D.new()
	floor.mesh = floor_mesh
	floor.position = Vector3((w - 1) * CELL / 2, 0, (h - 1) * CELL / 2)
	_world.add_child(floor)

	# 牆：拼布＋黃銅色的縫線，高高低低（像被縫起來的房子）
	var wm := StandardMaterial3D.new()
	wm.albedo_texture = load("res://art/chase_wall.png")
	wm.uv1_triplanar = true
	wm.uv1_world_triplanar = true
	wm.uv1_scale = Vector3.ONE / CELL
	wm.roughness = 0.95
	wm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if _open(c):
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				if _open(c + d):
					near = true
			if not near:
				continue
			var hh := WALL_H + (rng.randf() * 2.6 if rng.randf() < 0.45 else 0.0)
			var bm := BoxMesh.new()
			bm.size = Vector3(CELL, hh, CELL)
			bm.material = wm
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.position = cell_center(c) + Vector3(0, hh / 2, 0)
			_world.add_child(mi)
			# 有些牆上有發光的窗戶
			if rng.randf() < 0.22:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if _open(c + d):
						var win := Sprite3D.new()
						win.texture = load("res://art/chase_window.png")
						win.pixel_size = 0.0068
						var dv := Vector3(d.x, 0, d.y)
						win.position = cell_center(c) + dv * (CELL / 2 + 0.02) + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(2.2, hh - 0.7), 0).rotated(Vector3.UP, 0)
						win.basis = Basis.looking_at(-dv, Vector3.UP)
						_world.add_child(win)
						break
	_dress(rng)

	# 沿著正確的路，牆上貼著發光的守則（也是路標）
	for i in range(2, _route.size() - 1, 3):
		var c: Vector2i = _route[i]
		var along: Vector2i = _route[i + 1] - c
		for side in [Vector2i(along.y, -along.x), Vector2i(-along.y, along.x)]:
			if not _open(c + side):
				var d := Vector3(side.x, 0, side.y)
				var lab := Label3D.new()
				lab.text = RULES[(i / 3) % RULES.size()]
				lab.font = GameState.font
				lab.font_size = 72
				lab.pixel_size = 0.0055
				lab.outline_size = 10
				lab.modulate = Color(1, 0.86, 0.92)
				lab.outline_modulate = Color(0.35, 0.08, 0.2)
				lab.position = cell_center(c) + d * (CELL / 2 - 0.04) + Vector3(0, 2.0, 0)
				lab.basis = Basis.looking_at(d, Vector3.UP)
				_world.add_child(lab)
				break

	# 修理室的門
	var door_dir := Vector3.ZERO
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if not _open(_exit + d):
			door_dir = Vector3(d.x, 0, d.y)
			break
	var door := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.6, 2.6, 0.2)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.55, 0.32, 0.22)
	dmat.emission_enabled = true
	dmat.emission = Color(0.35, 0.2, 0.1)
	dm.material = dmat
	door.mesh = dm
	door.position = cell_center(_exit) + door_dir * (CELL / 2 - 0.12) + Vector3(0, 1.3, 0)
	door.basis = Basis.looking_at(door_dir, Vector3.UP)
	_world.add_child(door)
	var sign := Label3D.new()
	sign.text = "修理室"
	sign.font = GameState.font
	sign.font_size = 96
	sign.pixel_size = 0.006
	sign.outline_size = 12
	sign.modulate = Color(1, 0.95, 0.8)
	sign.position = door.position + Vector3(0, 1.75, 0) - door_dir * 0.2
	sign.basis = door.basis
	_world.add_child(sign)
	var dl := OmniLight3D.new()
	dl.light_color = Color(1, 0.8, 0.55)
	dl.omni_range = 7.0
	dl.light_energy = 1.4
	dl.position = cell_center(_exit) + Vector3(0, 2.4, 0)
	_world.add_child(dl)

	# 小布（背影）＋提燈
	_bu = _sprite("res://art/walk_bu.png", 1.35)
	_world.add_child(_bu)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1, 0.86, 0.7)
	lamp.omni_range = 9.0
	lamp.light_energy = 1.5
	lamp.position = Vector3(0, 1.6, 0)
	_bu.add_child(lamp)
	# 鎮長＋眼睛的紅光
	# 鎮長：崩潰版的立繪（縫線繃開、棉花跑出來），永遠正面朝著鏡頭
	_mayor = Sprite3D.new()
	_mayor.texture = load("res://art/item_stand_mayor_broken.png")
	_mayor.pixel_size = 3.0 / 560.0
	_mayor.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_mayor.offset = Vector2(0, 268)
	_mayor.modulate = Color(1, 0.88, 0.88)
	_world.add_child(_mayor)
	_mayor.add_child(_blob(1.7))
	_bu.add_child(_blob(0.9))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1, 0.25, 0.3)
	glow.omni_range = 5.5
	glow.light_energy = 1.8
	glow.position = Vector3(0, 2.4, 0)
	_mayor.add_child(glow)

	_cam = Camera3D.new()
	_cam.fov = 72
	_cam.current = true
	_world.add_child(_cam)

	# 字幕與提示
	_hud = _label(30, Vector2(0, 30))
	_hud.text = "逃到修理室！\n" + ("左下的方向鍵：往上推前進，左右推轉彎" if DisplayServer.is_touchscreen_available() else "↑ 前進　↓ 後退　← → 轉彎　·　跟著牆上發光的字走")
	_sub = _label(28, Vector2(0, 600))


## 場景佈置：路燈（暖光）、橫跨走廊的名牌串、牆腳的棉花、插在地上的大縫衣針
func _dress(rng: RandomNumberGenerator) -> void:
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.12, 0.14)
	iron.metallic = 0.6
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1, 0.8, 0.5)
	glass.emission_enabled = true
	glass.emission = Color(1, 0.7, 0.4)
	glass.emission_energy_multiplier = 2.0
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.78, 0.8, 0.86)
	steel.metallic = 0.9
	steel.roughness = 0.25
	for i in range(1, _route.size() - 1):
		var c: Vector2i = _route[i]
		var along: Vector2i = _route[i + 1] - c
		var side := Vector2i(along.y, -along.x)
		var sv := Vector3(side.x, 0, side.y)
		# 路燈：每 6 格一盞，靠牆
		if i % 6 == 4:
			var pole := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.08
			cm.height = 3.0
			cm.material = iron
			pole.mesh = cm
			pole.position = cell_center(c) + sv * 1.15 + Vector3(0, 1.5, 0)
			_world.add_child(pole)
			var lamp := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.3, 0.42, 0.3)
			lm.material = glass
			lamp.mesh = lm
			lamp.position = pole.position + Vector3(0, 1.6, 0)
			_world.add_child(lamp)
			var l := OmniLight3D.new()
			l.light_color = Color(1, 0.72, 0.45)
			l.omni_range = 6.5
			l.light_energy = 1.3
			l.position = lamp.position
			_world.add_child(l)
		# 名牌串：橫跨走廊
		if i % 5 == 2:
			var t := Sprite3D.new()
			t.texture = load("res://art/chase_tags.png")
			t.pixel_size = CELL / 768.0
			t.position = cell_center(c) + Vector3(0, 3.1, 0)
			t.basis = Basis.looking_at(Vector3(along.x, 0, along.y), Vector3.UP)
			t.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			_world.add_child(t)
	# 牆腳的棉花、插在地上的大縫衣針（隨機放在走廊邊）
	var open_cells: Array = []
	for y in MAZE.size():
		for x in MAZE[y].length():
			var c := Vector2i(x, y)
			if _open(c) and c != _start and c != _exit:
				open_cells.append(c)
	for k in 16:
		var c: Vector2i = open_cells[rng.randi() % open_cells.size()]
		var cot := Sprite3D.new()
		cot.texture = load("res://art/chase_cotton.png")
		cot.pixel_size = rng.randf_range(0.0035, 0.006)
		cot.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		cot.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		cot.offset = Vector2(0, 90)
		cot.shaded = true
		cot.position = cell_center(c) + Vector3(rng.randf_range(-1.1, 1.1), 0, rng.randf_range(-1.1, 1.1))
		_world.add_child(cot)
	for k in 4:
		var c: Vector2i = open_cells[rng.randi() % open_cells.size()]
		if c in _route:
			continue
		var needle := MeshInstance3D.new()
		var nm := CylinderMesh.new()
		nm.top_radius = 0.015
		nm.bottom_radius = 0.06
		nm.height = 3.4
		nm.material = steel
		needle.mesh = nm
		needle.position = cell_center(c) + Vector3(rng.randf_range(-0.6, 0.6), 1.3, rng.randf_range(-0.6, 0.6))
		needle.rotation = Vector3(rng.randf_range(-0.45, 0.45), rng.randf() * TAU, rng.randf_range(-0.45, 0.45))
		_world.add_child(needle)


## 腳底下一塊淡淡的影子（角色才不會像飄在空中）
func _blob(size: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size * 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	var gr := Gradient.new()
	gr.set_color(0, Color(0, 0, 0, 0.55))
	gr.set_color(1, Color(0, 0, 0, 0))
	g.gradient = gr
	mat.albedo_texture = g
	pm.material = mat
	m.mesh = pm
	m.position = Vector3(0, 0.02, 0)
	return m


func _label(size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(1280, 100)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#fff0f5"))
	l.add_theme_color_override("font_outline_color", Color("#3a1426"))
	l.add_theme_constant_override("outline_size", 10)
	add_child(l)
	return l


func _sprite(path: String, height: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(path)
	s.region_enabled = true
	s.region_rect = Rect2(192, 0, 192, 192)
	s.pixel_size = height / 192.0
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	s.offset = Vector2(0, 92)
	return s


func _checker() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 16:
			var a := (x / 8 + y / 8) % 2 == 0
			img.set_pixel(x, y, Color(0.2, 0.14, 0.22) if a else Color(0.13, 0.09, 0.15))
	return ImageTexture.create_from_image(img)


func _fabric() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for y in n:
		for x in n:
			var base := Color(0.58, 0.4, 0.52).darkened(rng.randf() * 0.08 + (0.12 if (x + y) % 6 < 2 else 0.0))
			base = base.darkened(clampf((y - 90) / 60.0, 0, 0.35))
			img.set_pixel(x, y, base)
	# 縫線：直的一條、橫的一條（虛線）
	for y in n:
		if y % 10 < 6:
			for k in 2:
				img.set_pixel(63 + k, y, Color(0.95, 0.88, 0.9))
	for x in n:
		if x % 10 < 6:
			for k in 2:
				img.set_pixel(x, 30 + k, Color(0.95, 0.88, 0.9))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ───────── 遊戲 ─────────

func _reset_run() -> void:
	_bu.position = cell_center(_start)
	var first: Vector2i = _route[1] - _route[0]
	_heading = atan2(-first.x, -first.y)
	_mayor.position = cell_center(_start) - _fwd() * 0.1
	_mayor.visible = false
	_mayor_on = false
	_rise = 0.0
	_t = 0.0
	_frozen = false
	_cam.position = _bu.position - _fwd() * 3.2 + Vector3(0, 1.9, 0)
	_cam_update(1.0)


func _fwd() -> Vector3:
	return Vector3(-sin(_heading), 0, -cos(_heading))


func _process(delta: float) -> void:
	if _done:
		return
	_hud_a = maxf(_hud_a - delta * 0.12, 0.0)
	_hud.modulate.a = clampf(_hud_a * 1.6, 0.0, 1.0)
	_sub_a = maxf(_sub_a - delta * 0.4, 0.0)
	_sub.modulate.a = clampf(_sub_a, 0.0, 1.0)
	if _frozen:
		return
	_t += delta
	# 小布
	var turn := Input.get_axis("move_right", "move_left")
	var go := Input.get_axis("move_down", "move_up")
	_heading += turn * TURN_SPEED * delta
	# 跑步時，方向自動對齊走廊（快要正對的時候吸過去），不用很準也能直直地跑
	if go > 0.1 and absf(turn) < 0.1:
		var snap := roundf(_heading / (PI / 2)) * (PI / 2)
		if absf(snap - _heading) < 0.35:
			_heading = lerpf(_heading, snap, clampf(delta * 6.0, 0.0, 1.0))
	var move := _fwd() * go * (BU_SPEED if go > 0 else BU_SPEED * 0.5) * delta
	for axis in [Vector3(move.x, 0, 0), Vector3(0, 0, move.z)]:
		if not _blocked(_bu.position + axis):
			_bu.position += axis
	var moving := absf(go) > 0.1
	if moving:
		_step_t += delta
		if _step_t > 0.12:
			_step_t = 0.0
			_step = (_step + 1) % 4
			if _step % 2 == 0:
				Sound.sfx("step")
	else:
		_step = 1
	var col: int = [1, 0, 1, 2][_step] if moving else 1
	_bu.region_rect = Rect2(col * 192, (3 if go >= 0 else 0) * 192, 192, 192)
	_cam_update(delta)
	# 到了修理室
	if _bu.position.distance_to(cell_center(_exit)) < 1.3:
		_finish()
		return
	# 鎮長
	if not _mayor_on:
		# 小布跑離起點幾步之後（或一直不動超過 8 秒），鎮長才從起點爬起來
		var away := _bu.position.distance_to(cell_center(_start)) > 4.5
		if (_t > START_DELAY and away) or _t > 8.0:
			_mayor_on = true
			_rise = 2.2
			_mayor.position = cell_center(_start)
			_mayor.visible = true
			Sound.sfx("creepy")
			_say("熊熊鎮長：……老師來了喔。")
		return
	if _rise > 0.0:
		# 慢慢站起來（這段時間不會動、不會抓人）
		_rise -= delta
		_mayor.scale = Vector3.ONE * lerpf(1.0, 0.55, clampf(_rise / 2.2, 0.0, 1.0))
		return
	_mayor.scale = Vector3.ONE
	_move_mayor(delta)
	var dist := _mayor.position.distance_to(_bu.position)
	var near := clampf(1.0 - dist / 14.0, 0.0, 1.0)
	# 鎮長從鏡頭後面追上來時，不要整張臉糊在鏡頭上
	var to_cam := _mayor.position.distance_to(Vector3(_cam.position.x, 0, _cam.position.z))
	_mayor.modulate.a = clampf((to_cam - 0.9) / 1.4, 0.0, 1.0)
	Dialogue.fx.vignette = 0.2 + 0.75 * near
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t = lerpf(1.2, 0.36, near)
		Sound.sfx("heartbeat")
	_line_t -= delta
	if _line_t <= 0.0:
		_line_t = randf_range(5.0, 8.0)
		_say("熊熊鎮長：" + GameState.fill(MAYOR_LINES[randi() % MAYOR_LINES.size()]))
	if dist < CATCH_DIST:
		_caught()


func _cam_update(delta: float) -> void:
	var back := -_fwd()
	var dist := 3.0
	var k := 0.6
	while k <= 3.0:
		if not _open(_cell_of(_bu.position + back * k)):
			dist = maxf(k - 0.45, 0.5)
			break
		k += 0.2
	# 後面是牆、鏡頭只能靠近時：鏡頭往上抬，從上往下看（小布不會塞滿畫面）
	var height := 2.0 + (3.0 - dist) * 0.9
	var want := _bu.position + back * dist + Vector3(0, height, 0)
	_cam.position = _cam.position.lerp(want, clampf(delta * 9.0, 0.0, 1.0))
	_cam.look_at(_bu.position + _fwd() * 2.8 + Vector3(0, 0.7, 0), Vector3.UP)


func _move_mayor(delta: float) -> void:
	_repath_t -= delta
	if _repath_t <= 0.0:
		_repath_t = 0.25
		_mayor_path = _bfs(_cell_of(_mayor.position), _cell_of(_bu.position))
	var target := _bu.position
	if _mayor_path.size() > 1:
		target = cell_center(_mayor_path[1])
	var speed := minf(2.9 + _t * 0.03, 3.6) - (0.6 if _attempts >= 2 else 0.0)
	if _mayor_path.size() > 8:
		speed = 4.4  # 離得太遠：追上來
	var to := target - _mayor.position
	to.y = 0
	if to.length() > 0.05:
		var stepv := to.normalized() * minf(speed * delta, to.length())
		_mayor.position += stepv
		# 一拐一拐地撲過來（上下晃）
		_mayor.offset.y = 268 + absf(sin(_t * 6.5)) * 12.0


func _say(text: String) -> void:
	_sub.text = text
	_sub_a = 2.5


func _caught() -> void:
	_frozen = true
	_attempts += 1
	Dialogue.fx.scare()
	_say("……被抓住了。")
	_hud.text = "再跑一次！"
	_hud_a = 1.0
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	_reset_run()


func _finish() -> void:
	if _done:
		return
	_done = true
	Dialogue.fx.vignette = 0.0
	finished.emit()
