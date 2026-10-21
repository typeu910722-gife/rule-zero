class_name Chase3D
extends CanvasLayer
## 3D 追逐（第一人稱）：在格子迷宮裡逃，追的人沿著走廊找最短路追上來。走到綠色的出口就結束。
## 用 Godot 內建形狀做（之後可以換成 Blender 做的 .glb：把 enemy_scene／wall_scene 指到模型）。
## 操作：上＝往前、下＝往後、左右＝轉身（觸控搖桿一樣）；按住互動鍵可以跑（體力會掉）。
## play() 回傳被抓到的次數；被抓到會回到上一個檢查點，最多被抓 MAX_CAUGHT 次就直接結束（劇情照走）。
## 自動測試（GameState.fast）直接回傳 0。

signal done(caught: int)

const CELL := 2.0
const EYE := 0.75                 # 玩偶的視線很低
const WALK := 2.6
const RUN := 4.0
const TURN := 2.4
const MAX_CAUGHT := 3

## 迷宮：# 牆　. 路　S 起點　E 出口　C 檢查點　D 追的人出發點（沒有 D：數完數之後從起點追來）
var maze := [
	"#################",
	"#S..#.....#.....#",
	"#.#.#.###.#.###.#",
	"#.#...#...#...#.#",
	"#.#####.#####.#.#",
	"#.....#C....#.#.#",
	"###.#.#####.#.#.#",
	"#...#.....#.....#",
	"#.#######.#.###.#",
	"#.......#...#..E#",
	"#################",
]
var title := "捉迷藏"
var hint := "上：往前　左右：轉身　按住互動鍵：跑"
var enemy_char := "dove"           # 之後換模型用
var enemy_delay := 4.0             # 「我不數了」：幾秒後開始追
var enemy_speed := 2.3            # 比走路（2.6）慢：只有走錯路、停下來才會被追上

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _enemy: Node3D
var _exit := Vector2i.ZERO
var _start := Vector2i.ZERO
var _check := Vector2i.ZERO
var _enemy_start := Vector2i.ZERO
var _pos := Vector2.ZERO           # 玩家在地面上的座標（x, z）
var _yaw := 0.0
var _epos := Vector2.ZERO
var _epath: Array = []
var _repath := 0.0
var _caught := 0
var _t := 0.0
var _stamina := 1.0
var _flash := 0.0
var _finished := false
var _hint: Label
var _status: Label
var _step_t := 0.0
var _has_d := false


func _ready() -> void:
	layer = 30
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cont := SubViewportContainer.new()
	cont.set_anchors_preset(Control.PRESET_FULL_RECT)
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cont)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.own_world_3d = true
	cont.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_build()
	var t := _label(Vector2(0, 20), 30)
	t.text = title
	_hint = _label(Vector2(0, 664), 20)
	_hint.text = hint
	_status = _label(Vector2(0, 60), 22)


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(1280, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#e8eef0"))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


func _center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)


func walkable(c: Vector2i) -> bool:
	if c.y < 0 or c.y >= maze.size() or c.x < 0 or c.x >= maze[c.y].length():
		return false
	return maze[c.y][c.x] != "#"


func _mat(col: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


func _build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("#0b0d0e")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#3a4448")
	e.ambient_light_energy = 0.35
	e.fog_enabled = true
	e.fog_light_color = Color("#0e1214")
	e.fog_density = 0.09
	env.environment = e
	_world.add_child(env)
	var wall_mat := _mat(Color("#cfd8db"))
	var floor_mat := _mat(Color("#8f9a9d"))
	var h := maze.size()
	var w: int = maze[0].length()
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(w * CELL, h * CELL)
	fl.mesh = pm
	fl.material_override = floor_mat
	fl.position = Vector3(w * CELL / 2.0, 0, h * CELL / 2.0)
	_world.add_child(fl)
	var ceil := fl.duplicate()
	ceil.position.y = 2.6
	ceil.rotation.x = PI
	ceil.material_override = _mat(Color("#5c6669"))
	_world.add_child(ceil)
	var box := BoxMesh.new()
	box.size = Vector3(CELL, 2.6, CELL)
	for y in h:
		for x in w:
			var ch: String = maze[y][x]
			var c := Vector2i(x, y)
			match ch:
				"#":
					var m := MeshInstance3D.new()
					m.mesh = box
					m.material_override = wall_mat
					m.position = Vector3((x + 0.5) * CELL, 1.3, (y + 0.5) * CELL)
					_world.add_child(m)
				"S":
					_start = c
				"E":
					_exit = c
				"C":
					_check = c
				"D":
					_enemy_start = c
					_has_d = true
	# 天花板的燈（一閃一閃）
	var k := 0
	for y in h:
		for x in w:
			if maze[y][x] != "#" and (x + y * 3) % 7 == 0:
				var l := OmniLight3D.new()
				l.position = Vector3((x + 0.5) * CELL, 2.3, (y + 0.5) * CELL)
				l.omni_range = 4.5
				l.light_energy = 0.7
				l.light_color = Color("#dfe9ea")
				l.set_meta("flicker", k)
				_world.add_child(l)
				k += 1
	# 出口：綠色的光
	var ex := OmniLight3D.new()
	ex.position = Vector3(_center(_exit).x, 1.2, _center(_exit).y)
	ex.light_color = Color("#7cf0a0")
	ex.light_energy = 2.0
	ex.omni_range = 6.0
	_world.add_child(ex)
	var sign := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(0.8, 0.3, 0.05)
	sign.mesh = sb
	sign.material_override = _mat(Color("#5be38a"), 2.0)
	sign.position = Vector3(_center(_exit).x, 2.1, _center(_exit).y)
	_world.add_child(sign)
	# 玩家的手電筒
	_cam = Camera3D.new()
	_cam.fov = 75
	_cam.current = true
	_world.add_child(_cam)
	var lamp := SpotLight3D.new()
	lamp.spot_range = 9.0
	lamp.spot_angle = 32
	lamp.light_energy = 2.2
	lamp.light_color = Color("#fff4e0")
	_cam.add_child(lamp)
	# 追的人（之後換成 Blender 的和平鴿模型）
	_enemy = _make_enemy()
	_world.add_child(_enemy)
	if not _has_d:
		_enemy_start = _start
	_respawn(_start)
	_epos = _center(_enemy_start)
	_place_enemy()


func _make_enemy() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.32
	cap.height = 1.8
	body.mesh = cap
	body.material_override = _mat(Color("#f4f4f2"))
	body.position.y = 0.9
	n.add_child(body)
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.24
	sp.height = 0.48
	head.mesh = sp
	head.material_override = _mat(Color.WHITE)
	head.position.y = 1.95
	n.add_child(head)
	var beak := MeshInstance3D.new()
	var bm := PrismMesh.new()
	bm.size = Vector3(0.14, 0.22, 0.14)
	beak.mesh = bm
	beak.material_override = _mat(Color("#e6c36a"))
	beak.position = Vector3(0, 1.93, -0.26)
	beak.rotation.x = -PI / 2.0
	n.add_child(beak)
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.035
		em.height = 0.07
		eye.mesh = em
		eye.material_override = _mat(Color("#ff3030"), 3.0)
		eye.position = Vector3(side * 0.1, 2.0, -0.21)
		n.add_child(eye)
	return n


func _respawn(c: Vector2i) -> void:
	_pos = _center(c)
	# 面向第一個可以走的方向
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		if walkable(c + d):
			_yaw = atan2(-float(d.x), -float(d.y))
			break
	_place_cam()


func _place_cam() -> void:
	_cam.position = Vector3(_pos.x, EYE, _pos.y)
	_cam.rotation = Vector3(0, _yaw, 0)


func _place_enemy() -> void:
	_enemy.position = Vector3(_epos.x, 0, _epos.y)
	var to := _pos - _epos
	if to.length() > 0.01:
		_enemy.rotation.y = atan2(-to.x, -to.y)


func play() -> int:
	if GameState.fast:
		await get_tree().process_frame
		queue_free()
		return 0
	Motif.play(self, "whistle", -6.0)
	var r: int = await done
	await get_tree().create_timer(0.6).timeout
	queue_free()
	return r


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta * 2.0)
	for l in _world.get_children():
		if l is OmniLight3D and l.has_meta("flicker"):
			var k: int = l.get_meta("flicker")
			l.light_energy = 0.0 if fmod(_t * 1.3 + k * 0.77, 4.0) < 0.12 else 0.7
	# 移動
	var turn := Input.get_axis("move_right", "move_left")
	var fwd := Input.get_axis("move_down", "move_up")
	_yaw += turn * TURN * delta
	var running := Input.is_action_pressed("interact") and _stamina > 0.05 and fwd > 0.0
	_stamina = clampf(_stamina + (-0.35 if running else 0.18) * delta, 0.0, 1.0)
	var speed := RUN if running else WALK
	var dir := Vector2(-sin(_yaw), -cos(_yaw)) * fwd * speed * delta
	_try_move(Vector2(dir.x, 0))
	_try_move(Vector2(0, dir.y))
	_place_cam()
	if fwd != 0.0:
		_step_t += delta * (1.6 if running else 1.0)
		_cam.position.y = EYE + sin(_step_t * 9.0) * 0.03
	if _cell(_pos) == _check:
		_start = _check
	# 追的人
	if _t > enemy_delay:
		_repath -= delta
		if _repath <= 0.0:
			_repath = 0.4
			_epath = _bfs(_cell(_epos), _cell(_pos))
		if not _epath.is_empty():
			var target := _center(_epath[0])
			var to := target - _epos
			var step := enemy_speed * delta
			if to.length() <= step:
				_epos = target
				_epath.pop_front()
			else:
				_epos += to.normalized() * step
		_place_enemy()
		var d := _epos.distance_to(_pos)
		if d < 0.85:
			_get_caught()
			return
		_status.text = ("……腳步聲很近。" if d < 4.0 else "") + ("　體力 " + "■".repeat(int(_stamina * 5)) + "□".repeat(5 - int(_stamina * 5)))
	else:
		_status.text = "（他在數數……）"
	if _cell(_pos) == _exit:
		_finish()


func _try_move(v: Vector2) -> void:
	var np := _pos + v
	var r := 0.28
	for off in [Vector2(r, r), Vector2(-r, r), Vector2(r, -r), Vector2(-r, -r)]:
		if not walkable(_cell(np + off)):
			return
	_pos = np


func _bfs(from: Vector2i, to: Vector2i) -> Array:
	if from == to:
		return [to]
	var prev := {from: from}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == to:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if walkable(n) and not prev.has(n):
				prev[n] = c
				q.append(n)
	if not prev.has(to):
		return []
	var path: Array = []
	var c2: Vector2i = to
	while c2 != from:
		path.push_front(c2)
		c2 = prev[c2]
	return path


func _get_caught() -> void:
	_caught += 1
	Sfx.play(self, "wrong", -2.0)
	if _caught >= MAX_CAUGHT:
		_finish()
		return
	_status.text = "……被抓到了。"
	_respawn(_start)
	# 追的人回到他出發的地方；如果玩家也回到那附近（還沒到檢查點），重新數完數才追
	_epos = _center(_enemy_start)
	_epath.clear()
	_t = 0.0 if _cell(_pos).distance_to(_enemy_start) < 4.0 else enemy_delay - 1.0


func _finish() -> void:
	if _finished:
		return
	_finished = true
	done.emit(_caught)
