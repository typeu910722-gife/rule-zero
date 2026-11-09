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
## 第二段（廣播點名）：比較長的迷宮
const MAZE_ROLLCALL := [
	"###################",
	"#S....#.......#...#",
	"#.###.#.#.###.#.#.#",
	"#.#...#.#...#...#.#",
	"#.#.###.#.#.#####.#",
	"#.#.....#.#.....#.#",
	"#.#######.#####.#.#",
	"#...C...#.....#.#.#",
	"###.###.#####.#.#.#",
	"#...#...#...#...#.#",
	"#.###.###.#.#####.#",
	"#.....#...#......E#",
	"###################",
]
## 第四章：芬一個人跑過放學後的走廊（沒有追的人，有時間限制）
const MAZE_SCHOOL := [
	"#####################",
	"#S.....#.....#......#",
	"###.##.#.###.#.####.#",
	"#...#..#...#...#....#",
	"#.###.####.#####.##.#",
	"#.....#..........#..#",
	"#####.#.#.######.#.##",
	"#.......#......#...E#",
	"#####################",
]
## 第五章終章 A：走出真的醫院（W＝地上的白線；沒有追的人，要注意呼吸）
const MAZE_REAL_HALL := [
	"#################",
	"#S..W.....#.....#",
	"####.####.#.###.#",
	"#....#....#...#.#",
	"#.####.######.#.#",
	"#......W......#E#",
	"#################",
]
## 終章 A 的 BOSS：理事追來（D＝理事出發的地方；C＝檢查點）。比較長，有繞得開的環
const MAZE_REAL_ESCAPE := [
	"#####################",
	"#S....#.....W.....#.#",
	"#.###.#.###.#####.#.#",
	"#.#...#...#.....#...#",
	"#.#.#####.#####.###.#",
	"#.#.....#.....#.#...#",
	"#.#####.#####.#.#.###",
	"#.....#..C..#...#...#",
	"#####.#.###.#####.#.#",
	"#.....#...#.....#.#.#",
	"#.#######.#####.#.#.#",
	"#D..W.....#.......#E#",
	"#####################",
]
## 單一路線的追逐（2026-11-09 使用者：沒有壓迫感、感受不到追的人多近；要只有一條路、跑錯就重開）
## tools/levels/make_chase_mazes.py 產生、驗證：路線是一棵樹，X＝死路（跑進去就被抓），D 在 S 正後方
## MAZE_LINEAR_HOSP：正確路線 55 格、6 個岔路
const MAZE_LINEAR_HOSP := [
	"#####################",
	"#DS......############",
	"#####X##.############",
	"#####X##.#.......####",
	"########.#.#####.####",
	"###......#.XXX##.XX##",
	"###.######C#####.####",
	"###.XXX###.##....####",
	"###.######.##.#######",
	"###........##.##X####",
	"#######X#####.##X####",
	"#######X#####......E#",
	"#####################",
]
## MAZE_LINEAR_ROLLCALL：正確路線 79 格、9 個岔路
const MAZE_LINEAR_ROLLCALL := [
	"#######################",
	"#DS....###########....#",
	"####X#.###########.##.#",
	"####X#.##......###.##.#",
	"######.##.##X#.###.##.#",
	"##.....##.##X#.#XX.##.#",
	"##.######.##X#.X##.##.#",
	"##.XX####...##.###.#X.#",
	"##.########.##.###.##.#",
	"##.....####C##.....##.#",
	"######.#XXX.#########.#",
	"###XXX.####.#######XX.#",
	"######.####.#########.#",
	"######......#########E#",
	"#######################",
]
## MAZE_LINEAR_REAL：正確路線 42 格、5 個岔路
const MAZE_LINEAR_REAL := [
	"###################",
	"#DS.....###########",
	"#####X#.###########",
	"#####X#.###......##",
	"#######.###.##X#.##",
	"###.....###.##X#.##",
	"###.#######CXX##.##",
	"###.XXX##X#.####.##",
	"###.#####X#.####.##",
	"###.........####E##",
	"###################",
]

## 配色：預設是第三章的醫院（暗、有霧、手電筒）
const LOOK_SCHOOL := {"wall": "#e2d6c2", "floor": "#a8957a", "ceil": "#efe6d6", "bg": "#e9c9a0", "fog": "#e8c49a",
	"fog_density": 0.035, "ambient": "#f0d2b0", "ambient_energy": 0.75, "lamp": false, "light": "#ffd9a8", "kit": "school"}
const LOOK_REAL := {"wall": "#eef0ee", "floor": "#c9cec9", "ceil": "#f7f8f7", "bg": "#f4f6f4", "fog": "#f4f6f4",
	"fog_density": 0.03, "ambient": "#ffffff", "ambient_energy": 0.7, "lamp": false, "light": "#ffffff", "kit": "real"}
## 美術（tools/art/make_chase_textures.py、tools/art/blender/chase_assets.py）：沒有檔案就退回純色、內建形狀
const TEX_DIR := "res://art/3d/tex/"
const MODEL_DIR := "res://art/3d/"
const DRAG_SFX := "res://audio/sfx_ivdrag.ogg"
const VIGNETTE := """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.25, 0.95, length(p));
	COLOR = vec4(0.02, 0.01, 0.02, v * strength);
}
"""

var title := "捉迷藏"
var hint := "上：往前　左右：轉身　按住互動鍵：跑"
var enemy_char := "dove"           # 之後換模型用；art/walk4/<id>.png 有的話用走路圖做成 3D 看板（終章 A：director＝理事）
var enemy_height := 2.3            # 走路圖看板的身高（公尺）
var enemy_sfx := ""                # 靠近時偶爾響的聲音（終章 A：hawk＝老鷹）
var _enemy_sprite: Sprite3D
var _enemy_cell := 0.0
var _esfx_t := 0.0
var enemy_delay := 4.0             # 「我不數了」：幾秒後開始追
## 單一路線模式：自動往前跑（不用體力）、往下＝回頭看、追的人一直跟在後面（保持 chase_gap 公尺，停下來、撞牆、跑錯就追上）
## 被抓到從起點（或檢查點）重來，沒有次數上限；路口地上有綠色的燈指著正確的方向
var linear := false
var chase_gap := 3.6
var enemy_base := 3.5
var chase_ease := 1.0           # 太近的時候追的人慢多少（越大越好逃）
var _main: Array = []
var _gap_bonus := 0.0
var _back := 0.0
var _meter: Control
var _red: ColorRect
var _estep_t := 0.0
var _trap := false
var _shake := 0.0
var enemy_speed := 2.3            # 比走路（2.6）慢：只有走錯路、停下來才會被追上
var has_enemy := true             # false：沒有追的人（只是走到出口）
var time_limit := 0.0             # > 0：要在幾秒內走到；超過也照樣能走完，只是回傳 1（「來不及了」）
var breath := false               # 終章 A：人類的身體。走路也會喘，喘不過氣就要停下來
var look := {}                    # 配色（LOOK_SCHOOL／LOOK_REAL；空＝醫院）
var start_motif := "whistle"
var late := false
var breath_stops := 0             # 喘不過氣、停下來的次數
var _stop_t := 0.0
## 左下角的側面全身小人（art/human/chase/<runner>_<動作>.png，需求 v2 第 2-4 節）；空＝不顯示
var runner := ""
var runner_pose := ""             # 目前的動作（測試用）
var _runner: TextureRect
var _runner_tex := {}
var _run_t := 0.0
var _stumble_t := 0.0
var _look_t := 0.0
var _look_cd := 6.0
var _stumble_cd := 0.0
const RUNNER_DIR := "res://art/human/chase/"
const RUNNER_POSES := ["run_00", "run_01", "run_02", "run_03", "run_04", "run_05", "run_06", "run_07",
	"idle", "look_back", "stumble", "breath"]

var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _enemy: Node3D
var _exit := Vector2i.ZERO
var _start := Vector2i.ZERO
var _check := Vector2i.ZERO
var _enemy_start := Vector2i.ZERO
## 玩偶醫院的病房門：走近時有些會「砰」地突然打開（chapter3.md 第 9 節的障礙），嚇一跳、腳步慢下來
var _doors: Array = []             # [{"mesh": MeshInstance3D, "at": Vector2（x, z）, "fired": bool}]
var _door_open_mat: StandardMaterial3D = null
var _door_slow := 0.0
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
var _vig: ColorRect
var _drag: AudioStreamPlayer3D
var _beat := 0.0
var _panels: Array = []           # 天花板的燈管（跟燈一起閃）
## 追的人離玩家多近（0～1）
var threat := 0.0


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
	# 壓迫感：追的人越近，四周越暗
	_vig = ColorRect.new()
	_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = Shader.new()
	vm.shader.code = VIGNETTE
	_vig.material = vm
	add_child(_vig)
	var t := _label(Vector2(0, 20), 30)
	t.text = title
	_hint = _label(Vector2(0, 664), 20)
	_hint.text = hint
	_status = _label(Vector2(0, 60), 22)
	_make_runner()
	if linear:
		_red = ColorRect.new()
		_red.set_anchors_preset(Control.PRESET_FULL_RECT)
		_red.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_red.color = Color(0.6, 0.0, 0.05, 0.0)
		add_child(_red)
		move_child(_red, _vig.get_index() + 1)
		_meter = Control.new()
		_meter.set_anchors_preset(Control.PRESET_FULL_RECT)
		_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_meter.draw.connect(_draw_meter)
		add_child(_meter)


## 距離計：畫面下方，右邊是你，紅點是追的人。越近越紅
func _draw_meter() -> void:
	if not has_enemy:
		return
	var d := _epos.distance_to(_pos)
	var k := clampf(d / 12.0, 0.0, 1.0)
	var x0 := 390.0
	var x1 := 890.0
	var y := 628.0
	var close := 1.0 - k
	var col := Color(1.0, 0.85 - close * 0.7, 0.85 - close * 0.75)
	_meter.draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.35), 4.0)
	_meter.draw_circle(Vector2(x1, y), 9.0, Color("#e8eef0"))
	var ex := x1 - k * (x1 - x0)
	var pulse := 1.0 + (sin(_t * (6.0 + close * 14.0)) * 0.25 if close > 0.5 else 0.0)
	_meter.draw_circle(Vector2(ex, y), 11.0 * pulse, Color(0.85, 0.1, 0.15) if close > 0.5 else col)
	var f: Font = GameState.font
	var txt := "距離 %.1f 公尺" % d
	_meter.draw_string_outline(f, Vector2(x0, y - 16), txt, HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, 18, 5, Color(0, 0, 0, 0.8))
	_meter.draw_string(f, Vector2(x0, y - 16), txt, HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, 18, col)


func _make_runner() -> void:
	if runner == "":
		return
	for p in RUNNER_POSES:
		var path: String = RUNNER_DIR + "%s_%s.png" % [runner, p]
		if ResourceLoader.exists(path):
			_runner_tex[p] = load(path)
	if _runner_tex.size() != RUNNER_POSES.size():
		_runner_tex.clear()
		return
	_runner = TextureRect.new()
	_runner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_runner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_runner.size = Vector2(230, 230)
	_runner.position = Vector2(16, 720 - 230 - 8)
	_runner.modulate = Color(1, 1, 1, 0.92)
	add_child(_runner)
	_set_runner("idle")


func _set_runner(pose: String) -> void:
	runner_pose = pose
	if _runner:
		_runner.texture = _runner_tex[pose]


## 小人跟著玩家：往前＝跑（終章 A 是慢慢走）、撞牆＝踉蹌、喘不過氣＝撐膝蓋、追的人靠近或偶爾＝回頭
func _update_runner(delta: float, fwd: float, running: bool, blocked: bool) -> void:
	if _runner == null:
		return
	_stumble_t = maxf(0.0, _stumble_t - delta)
	_look_t = maxf(0.0, _look_t - delta)
	_look_cd -= delta
	_stumble_cd -= delta
	var bob := 0.0
	if fwd > 0.0 and blocked and _stumble_cd <= 0.0 and _look_t <= 0.0:
		_stumble_t = 0.6
		_stumble_cd = 2.0
	if fwd > 0.0 and _look_cd <= 0.0 and _stumble_t <= 0.0:
		_look_t = 0.5
		_look_cd = randf_range(5.0, 9.0) if threat < 0.3 else randf_range(1.5, 3.0)
	if _stop_t > 0.0:
		_set_runner("breath")
		bob = sin(_t * 5.0) * 3.0
	elif _stumble_t > 0.0:
		_set_runner("stumble")
	elif _look_t > 0.0:
		_set_runner("look_back")
	elif fwd != 0.0:
		_run_t += delta * (12.0 if running else (7.0 if breath else 10.0))
		_set_runner("run_%02d" % (int(_run_t) % 8))
	elif _stamina < 0.3:
		_set_runner("breath")
		bob = sin(_t * 5.0) * 3.0
	else:
		_set_runner("idle")
	_runner.position.y = 720 - 230 - 8 + bob


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


## 自己會發光的貼圖（燈具、逃生燈牌）；沒有圖回傳 null
func _glow_mat(name: String, col: Color, emit: float) -> StandardMaterial3D:
	var path := TEX_DIR + name + ".png"
	if not ResourceLoader.exists(path):
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission = col
	m.emission_energy_multiplier = emit
	return m


func _kit() -> String:
	return look.get("kit", "hosp")


## 3D 走廊的門：跟地圖上的門同一套圖（玩偶醫院／學校／真實醫院）
const DOOR_KITS := {"hosp": "hospital", "school": "school", "real": "real"}


static func door_texture(kit: String) -> Texture2D:
	var p := "res://art/doors/door_%s_front_locked.png" % DOOR_KITS.get(kit, "hospital")
	return load(p) if ResourceLoader.exists(p) else null


## 有貼圖用貼圖（uv＝一張貼圖重複幾次），沒有就用純色
func _tex_mat(part: String, fallback: Color, uv := Vector3.ONE) -> StandardMaterial3D:
	var path := TEX_DIR + "%s_%s.png" % [_kit(), part]
	if not ResourceLoader.exists(path):
		return _mat(fallback)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.uv1_scale = uv
	m.roughness = 0.85
	return m


func _model(name: String) -> Node3D:
	var path := MODEL_DIR + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var ps = load(path)
	return ps.instantiate() if ps is PackedScene else null


## 牆：只蓋面向走道的那幾面（一格一面，貼圖剛好一張）；醫院的牆偶爾有一扇關著的病房門
func _build_walls(w: int, h: int) -> void:
	var wall_mat := _tex_mat("wall", Color(look.get("wall", "#cfd8db")))
	var quad := QuadMesh.new()
	quad.size = Vector2(CELL, 2.6)
	var door_mat := _mat(Color("#b9c9c9") if _kit() == "hosp" else (Color("#8a6a4a") if _kit() == "school" else Color("#e4e8e4")))
	var win_mat := _mat(Color("#1d2629"))
	var door := QuadMesh.new()
	door.size = Vector2(1.0, 2.15)
	# 有門的圖（地圖上用的那套，2026-11-04 ChatGPT）就貼上去：鎖著的正面
	var door_tex := door_texture(_kit())
	if door_tex != null:
		door_mat = StandardMaterial3D.new()
		door_mat.albedo_texture = door_tex
		door_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		door_mat.alpha_scissor_threshold = 0.5
		door_mat.roughness = 0.8
		door.size = Vector2(2.15 * door_tex.get_width() / door_tex.get_height(), 2.15)
	var win := QuadMesh.new()
	win.size = Vector2(0.28, 0.4)
	var n := 0
	for y in h:
		for x in w:
			if maze[y][x] != "#":
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not walkable(Vector2i(x, y) + d):
					continue
				var m := MeshInstance3D.new()
				m.mesh = quad
				m.material_override = wall_mat
				var c := Vector3((x + 0.5) * CELL, 1.3, (y + 0.5) * CELL) + Vector3(d.x, 0, d.y) * (CELL / 2.0)
				m.position = c
				m.rotation.y = atan2(float(d.x), float(d.y))
				_world.add_child(m)
				n += 1
				if n % 5 == 2:
					var dm := MeshInstance3D.new()
					dm.mesh = door
					dm.material_override = door_mat
					dm.position = c + Vector3(d.x, 0, d.y) * 0.01 + Vector3(0, -0.225, 0)
					dm.rotation.y = m.rotation.y
					_world.add_child(dm)
					if _kit() == "hosp" and door_tex != null and n % 10 == 2:
						_doors.append({"mesh": dm, "at": Vector2(c.x, c.z), "fired": false})
					if door_tex != null:
						continue  # 門的圖上已經有窗
					var wm := MeshInstance3D.new()
					wm.mesh = win
					wm.material_override = win_mat
					wm.position = c + Vector3(d.x, 0, d.y) * 0.02 + Vector3(0, 0.25, 0)
					wm.rotation.y = m.rotation.y
					_world.add_child(wm)


## 醫院的障礙物：死巷裡的推床、輪椅，走廊邊的點滴架（只是擺著，不擋路）
## 每一種走廊的擺設：[死巷裡的（輪流）, 走廊邊靠牆的]；學校和真實醫院的是 tools/art/make_props_3d.py 做的（2026-11-05）
const PROPS := {"hosp": [["gurney", "wheelchair"], "ivpole"], "school": [["school_desk"], "locker"], "real": [["cart"], "bench"]}


func _build_props(w: int, h: int) -> void:
	if not PROPS.has(_kit()):
		return
	var dead_end: Array = PROPS[_kit()][0]
	var side_name: String = PROPS[_kit()][1]
	var k := 0
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if maze[y][x] != ".":
				continue
			var open: Array = []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if walkable(c + d):
					open.append(d)
			var p := _center(c)
			if open.size() == 1:
				var mdl := _model(dead_end[k % dead_end.size()])
				if mdl:
					var o: Vector2i = open[0]
					mdl.position = Vector3(p.x - o.x * 0.45, 0, p.y - o.y * 0.45)
					mdl.rotation.y = atan2(float(o.x), float(o.y)) + PI / 2.0
					_world.add_child(mdl)
				k += 1
			elif open.size() == 2 and (x * 7 + y * 3) % 9 == 0:
				var side: Vector2i = Vector2i(open[0].y, open[0].x)
				if side_name == "ivpole":
					var iv := _model(side_name)
					if iv:
						iv.position = Vector3(p.x + side.x * 0.7, 0, p.y + side.y * 0.7)
						iv.rotation.y = x * 1.3
						_world.add_child(iv)
				elif not walkable(c + side):
					# 靠牆放（置物櫃、長椅），正面朝走廊
					var sm := _model(side_name)
					if sm:
						sm.position = Vector3(p.x + side.x * 0.74, 0, p.y + side.y * 0.74)
						sm.rotation.y = atan2(float(-side.x), float(-side.y))
						_world.add_child(sm)


func _build() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(look.get("bg", "#0b0d0e"))
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(look.get("ambient", "#3a4448"))
	e.ambient_light_energy = look.get("ambient_energy", 0.35)
	e.fog_enabled = true
	e.fog_light_color = Color(look.get("fog", "#0e1214"))
	e.fog_density = look.get("fog_density", 0.09)
	env.environment = e
	_world.add_child(env)
	var line_mat := _mat(Color.WHITE, 0.4)
	var h := maze.size()
	var w: int = maze[0].length()
	var floor_mat := _tex_mat("floor", Color(look.get("floor", "#8f9a9d")), Vector3(w, h, 1))
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
	ceil.material_override = _tex_mat("ceil", Color(look.get("ceil", "#5c6669")), Vector3(w, h, 1))
	_world.add_child(ceil)
	_build_walls(w, h)
	_build_props(w, h)
	for y in h:
		for x in w:
			var ch: String = maze[y][x]
			var c := Vector2i(x, y)
			match ch:
				"W":
					# 地上的白線（橫過走廊）
					var st := MeshInstance3D.new()
					var sm := BoxMesh.new()
					sm.size = Vector3(CELL, 0.01, 0.12)
					st.mesh = sm
					st.material_override = line_mat
					st.position = Vector3((x + 0.5) * CELL, 0.006, (y + 0.5) * CELL)
					var horiz := walkable(Vector2i(x - 1, y)) or walkable(Vector2i(x + 1, y))
					st.rotation.y = PI / 2.0 if horiz else 0.0
					_world.add_child(st)
				"S":
					_start = c
				"E":
					_exit = c
				"C":
					_check = c
				"D":
					_enemy_start = c
					_has_d = true
	if linear:
		_build_guides()
	# 天花板的燈（一閃一閃）；有燈具的圖就貼圖並自己發光
	var lamp_mat := _glow_mat("ceiling_lamp", Color(look.get("light", "#dfe9ea")), 1.3)
	var k := 0
	for y in h:
		for x in w:
			if maze[y][x] != "#" and (x + y * 3) % 7 == 0:
				var l := OmniLight3D.new()
				l.position = Vector3((x + 0.5) * CELL, 2.3, (y + 0.5) * CELL)
				l.omni_range = 4.5
				l.light_energy = 0.7
				l.light_color = Color(look.get("light", "#dfe9ea"))
				l.set_meta("flicker", k)
				_world.add_child(l)
				# 燈管（會跟著燈一起閃）
				var pnl := MeshInstance3D.new()
				var pq := QuadMesh.new()
				pq.size = Vector2(1.1, 0.32)
				pnl.mesh = pq
				pnl.material_override = lamp_mat if lamp_mat != null else _mat(Color(look.get("light", "#dfe9ea")), 1.6)
				if lamp_mat != null:
					pq.size = Vector2(1.1, 1.1 * 222.0 / 512.0)
				pnl.position = Vector3((x + 0.5) * CELL, 2.59, (y + 0.5) * CELL)
				pnl.rotation.x = PI / 2.0
				_world.add_child(pnl)
				l.set_meta("panel", pnl)
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
	# 逃生燈牌的圖：玩偶的醫院是毛氈的，學校和真實的醫院是發光的（2026-11-05 ChatGPT）
	var sign_mat := _glow_mat("exit_sign_felt" if _kit() == "hosp" else "exit_sign", Color("#5be38a"), 1.2)
	if sign_mat != null:
		var sq := QuadMesh.new()
		sq.size = Vector2(0.9, 0.9 * sign_mat.albedo_texture.get_height() / sign_mat.albedo_texture.get_width())
		sign.mesh = sq
		sign.material_override = sign_mat
		sign_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# 正面朝向走過來的那一格（不然從背面看箭頭是反的）
		for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
			if walkable(_exit + d):
				sign.rotation.y = atan2(float(d.x), float(d.y))
				break
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
	lamp.visible = look.get("lamp", true)
	_cam.add_child(lamp)
	# 追的人（之後換成 Blender 的和平鴿模型）
	_enemy = _make_enemy()
	_enemy.visible = has_enemy
	_world.add_child(_enemy)
	if not _has_d:
		_enemy_start = _start
	_respawn(_start)
	_epos = _center(_enemy_start)
	_place_enemy()


## 單一路線：算出正確路線；每個岔路口的地上放一條綠色的燈，指著正確的方向（死路那邊沒有）
func _build_guides() -> void:
	_main = [_start] + _bfs(_start, _exit)
	var mat := _mat(Color("#5be38a"), 2.2)
	for i in range(1, _main.size() - 1):
		var c: Vector2i = _main[i]
		var n := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if walkable(c + d):
				n += 1
		if n <= 2:
			continue
		var nxt: Vector2i = _main[i + 1]
		var dir := Vector2(nxt - c)
		for k in 3:
			var strip := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.5, 0.012, 0.12) if dir.x != 0.0 else Vector3(0.12, 0.012, 0.5)
			strip.mesh = bm
			strip.material_override = mat
			var at := _center(c) + dir * (0.1 + k * 0.55)
			strip.position = Vector3(at.x, 0.01, at.y)
			_world.add_child(strip)
		var gl := OmniLight3D.new()
		var at2 := _center(c) + dir * 0.6
		gl.position = Vector3(at2.x, 0.08, at2.y)
		gl.light_color = Color("#7cf0a0")
		gl.light_energy = 0.45
		gl.omni_range = 1.3
		_world.add_child(gl)


func _make_enemy() -> Node3D:
	# 走路圖看板（人類時期的大人：理事）：一直面向鏡頭，走路的四格會動
	if enemy_char != "dove" and ResourceLoader.exists(ExploreArt.WALK_DIR % enemy_char):
		var tex: Texture2D = load(ExploreArt.WALK_DIR % enemy_char)
		var root := Node3D.new()
		_enemy_sprite = Sprite3D.new()
		_enemy_sprite.texture = tex
		_enemy_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_enemy_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_enemy_sprite.shaded = false
		_enemy_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_enemy_cell = tex.get_width() / 4.0
		_enemy_sprite.region_enabled = true
		_enemy_sprite.region_rect = Rect2(0, 0, _enemy_cell, _enemy_cell)
		# 走路圖裡人大約佔一格的 0.9：照身高換算
		_enemy_sprite.pixel_size = enemy_height / (_enemy_cell * 0.9)
		_enemy_sprite.position.y = _enemy_cell * _enemy_sprite.pixel_size * 0.5 - 0.05
		root.add_child(_enemy_sprite)
		return root
	# 第三章：神志不清的畢業生（Blender 模型）＋拖著點滴架的聲音
	if _kit() == "hosp":
		var g := _model("graduate")
		if g:
			var root := Node3D.new()
			root.add_child(g)
			if ResourceLoader.exists(DRAG_SFX):
				_drag = AudioStreamPlayer3D.new()
				var st = load(DRAG_SFX)
				if st is AudioStreamOggVorbis:
					st.loop = true
				_drag.stream = st
				_drag.unit_size = 2.5
				_drag.max_distance = 22.0
				_drag.volume_db = -4.0
				_drag.position.y = 0.4
				root.add_child(_drag)
			return root
	return _make_placeholder_enemy()


func _make_placeholder_enemy() -> Node3D:
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
	_cam.rotation = Vector3(0, _yaw + _back * PI, 0)


func _place_enemy() -> void:
	_enemy.position = Vector3(_epos.x, absf(sin(_t * 2.6)) * 0.03, _epos.y)
	if _enemy_sprite:
		_enemy_sprite.region_rect = Rect2((int(_t * 6.0) % 4) * _enemy_cell, 0, _enemy_cell, _enemy_cell)
		if enemy_sfx != "" and has_enemy and _enemy.visible:
			_esfx_t -= get_process_delta_time()
			if _esfx_t <= 0.0 and _pos.distance_to(_epos) < CELL * 5.0:
				_esfx_t = 5.0
				Sfx.play(self, enemy_sfx, -6.0)
	var to := _pos - _epos
	if to.length() > 0.01:
		_enemy.rotation.y = atan2(-to.x, -to.y)
	_enemy.rotation.z = sin(_t * 1.3) * 0.05    # 走路歪歪斜斜


## 壓迫感：追的人越近，越暗、心跳越快、畫面越晃（溫和模式不晃、不放心跳）
func _dread(delta: float) -> void:
	var close := 0.0
	if has_enemy and _t > enemy_delay:
		close = clampf(1.0 - _epos.distance_to(_pos) / 9.0, 0.0, 1.0)
	threat = close
	if linear and has_enemy:
		var calm0 := GameState.gentle()
		# 紅色一閃一閃（越近越快、越紅）、追的人的腳步聲、畫面晃
		if _red:
			var pulse := 0.5 + 0.5 * sin(_t * (3.0 + close * 9.0))
			_red.color.a = maxf(_red.color.a - delta * 1.5, close * close * (0.18 + pulse * 0.17))
		if _meter:
			_meter.queue_redraw()
		_estep_t -= delta
		if _t > enemy_delay and _estep_t <= 0.0:
			_estep_t = lerpf(0.75, 0.28, close)
			Sfx.play(self, "dove_step", lerpf(-22.0, -4.0, close))
		_shake = maxf(_shake - delta, 0.0)
		if not calm0 and (close > 0.55 or _shake > 0.0):
			var amt := maxf(close - 0.55, 0.0) * 0.05 + _shake * 0.08
			_cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * amt
	if _vig:
		(_vig.material as ShaderMaterial).set_shader_parameter("strength", 0.35 + close * 0.6 if look.is_empty() else close * 0.5)
	if _drag:
		if has_enemy and _t > enemy_delay and not _drag.playing:
			_drag.play()
		_drag.position = Vector3(0, 0.4, 0)
	var calm := GameState.gentle()
	if close > 0.2 and not calm:
		_beat -= delta
		if _beat <= 0.0:
			Sound.sfx("heartbeat")
			_beat = lerpf(1.2, 0.4, close)
	if close > 0.6 and not calm:
		_cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * (close - 0.6) * 0.03


func play() -> int:
	if GameState.fast:
		await get_tree().process_frame
		queue_free()
		return 0
	if start_motif != "":
		Motif.play(self, start_motif, -6.0)
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
			if look.is_empty():   # 只有第三章的醫院會一閃一閃
				var off := fmod(_t * 1.3 + k * 0.77, 4.0) < 0.12
				l.light_energy = 0.0 if off else 0.7
				var pnl = l.get_meta("panel", null)
				if pnl:
					pnl.visible = not off
	# 移動
	var turn := Input.get_axis("move_right", "move_left")
	var fwd := Input.get_axis("move_down", "move_up")
	if linear:
		# 往下＝回頭看（看得到他離你多近）；不能往後退。轉身快一點
		_back = move_toward(_back, 1.0 if Input.is_action_pressed("move_down") else 0.0, delta * 5.0)
		fwd = maxf(fwd, 0.0)
		turn *= 1.35
	_yaw += turn * TURN * delta
	var running := (Input.is_action_pressed("interact") and _stamina > 0.05 and fwd > 0.0 and not breath) or (linear and fwd > 0.0 and not breath)
	var speed := RUN if running else WALK
	if breath:
		# 呼吸：往前走會慢慢喘，停下來才會恢復；喘到底就要停一下
		if _stop_t > 0.0:
			_stop_t -= delta
			fwd = 0.0
			_stamina = clampf(_stamina + 0.3 * delta, 0.0, 1.0)
		else:
			_stamina = clampf(_stamina + (-0.12 if fwd != 0.0 else 0.3) * delta, 0.0, 1.0)
			if _stamina <= 0.0:
				_stop_t = 1.5
				breath_stops += 1
		speed = WALK * 0.75
	elif not linear:
		_stamina = clampf(_stamina + (-0.35 if running else 0.18) * delta, 0.0, 1.0)
	if _door_slow > 0.0:
		_door_slow -= delta
		speed *= 0.4
	var dir := Vector2(-sin(_yaw), -cos(_yaw)) * fwd * speed * delta
	var moved_x := _try_move(Vector2(dir.x, 0))
	var moved_z := _try_move(Vector2(0, dir.y))
	_update_runner(delta, fwd, running, fwd > 0.0 and not moved_x and not moved_z)
	_check_doors()
	_place_cam()
	_dread(delta)
	if fwd != 0.0:
		_step_t += delta * (1.6 if running else 1.0)
		_cam.position.y = EYE + sin(_step_t * 9.0) * 0.03
	if _cell(_pos) == _check:
		_start = _check
	if not has_enemy:
		var s := ""
		if time_limit > 0.0:
			if _t > time_limit and not late:
				late = true
				_caught += 1
			s = "……來不及了。" if late else "　還有 %d 秒" % ceili(time_limit - _t)
		if breath:
			s = ("……喘不過氣。停下來，慢慢吸氣。" if _stop_t > 0.0 else "呼吸 " + "■".repeat(int(_stamina * 5)) + "□".repeat(5 - int(_stamina * 5)))
		_status.text = s
	# 追的人
	elif _t > enemy_delay:
		_repath -= delta
		if _repath <= 0.0:
			_repath = 0.4
			_epath = _bfs(_cell(_epos), _cell(_pos))
		if not _epath.is_empty():
			var target := _center(_epath[0])
			var to := target - _epos
			var spd := enemy_speed
			if linear:
				var dd := _epos.distance_to(_pos)
				spd = enemy_base + clampf((dd - chase_gap - _gap_bonus) * 0.9, -chase_ease, 2.6)
				if _trap:
					spd = 7.0   # 跑進死路：他衝過來
			var step := spd * delta
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
		if linear:
			var pc := _cell(_pos)
			var in_x: bool = maze[pc.y][pc.x] == "X"
			if in_x and not _trap:
				Sfx.play(self, "door_thud", -2.0)
			_trap = in_x
			_status.text = "死路——！" if _trap else ("……他就在你後面。" if d < 2.2 else ("……腳步聲。" if d < 4.5 else ""))
			if breath:
				_status.text += ("　喘不過氣，停下來……" if _stop_t > 0.0 else "　呼吸 " + "■".repeat(int(_stamina * 5)) + "□".repeat(5 - int(_stamina * 5)))
		else:
			_status.text = ("……腳步聲很近。" if d < 4.0 else "") + ("　體力 " + "■".repeat(int(_stamina * 5)) + "□".repeat(5 - int(_stamina * 5)))
	else:
		_status.text = "……跑！" if linear else "（他在數數……）"
	if _cell(_pos) == _exit:
		_finish()


## 走得動回傳 true；被牆擋住、或這個方向沒有要動，回傳 false
func _try_move(v: Vector2) -> bool:
	if v == Vector2.ZERO:
		return false
	var np := _pos + v
	var r := 0.28
	for off in [Vector2(r, r), Vector2(-r, r), Vector2(r, -r), Vector2(-r, -r)]:
		if not walkable(_cell(np + off)):
			return false
	_pos = np
	return true


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
	_cotton_burst()
	if linear:
		# 跑錯、被追上：從起點（過了檢查點就從檢查點）重來。追的人回到你正後方兩格
		_status.text = "……被抓到了。重來。"
		_shake = 0.5
		if _red:
			_red.color.a = 0.85
		_respawn(_start)
		var i := _main.find(_start)
		_epos = _center(_main[i - 2] if i >= 2 else _enemy_start)
		_epath.clear()
		_trap = false
		_t = enemy_delay - 1.2
		_gap_bonus = minf(_gap_bonus + 0.3, 1.5)   # 放水：每被抓一次，多讓一點距離
		return
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


## 玩偶醫院裡被抓到：棉花從畫面中間噴出來、散開、淡掉（chapter3.md 第 9 節「撞到時棉花飛出來」）。
## 第四、五章是人類的身體，不噴棉花。回傳噴出來的片數（測試用）。
func _cotton_burst() -> int:
	if _kit() != "hosp" or GameState.fast:
		return 0
	var tex: Texture2D = Ch3Mini.art("sew_cotton")
	if tex == null:
		return 0
	var center := Vector2(640, 400)
	for i in 9:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var size := randf_range(60.0, 120.0)
		r.size = Vector2(size, size)
		r.pivot_offset = r.size / 2
		r.position = center - r.size / 2
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		var ang := TAU * i / 9.0 + randf_range(-0.3, 0.3)
		var to := center + Vector2.from_angle(ang) * randf_range(220.0, 420.0) - r.size / 2
		var tw := r.create_tween().set_parallel()
		tw.tween_property(r, "position", to + Vector2(0, 60), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(r, "rotation", randf_range(-1.5, 1.5), 1.1)
		tw.tween_property(r, "modulate:a", 0.0, 1.1).set_delay(0.35)
		tw.chain().tween_callback(r.queue_free)
	return 9


## 走到病房門旁邊（1.6 公尺內）時，那扇門突然打開：換成開著的門、砰一聲、畫面閃一下、腳步慢 0.8 秒。
## 每扇門只會開一次；起點附近的門不會開（剛開始不要被嚇）。回傳這一次打開了幾扇（測試用）。
func _check_doors() -> int:
	var opened := 0
	for dr in _doors:
		if dr.fired or _pos.distance_to(dr.at) > 1.6 or _pos.distance_to(_center(_start)) < 3.0:
			continue
		dr.fired = true
		opened += 1
		if _door_open_mat == null:
			var p := "res://art/doors/door_hospital_front_open.png"
			_door_open_mat = (dr.mesh as MeshInstance3D).material_override.duplicate()
			if ResourceLoader.exists(p):
				_door_open_mat.albedo_texture = load(p)
		(dr.mesh as MeshInstance3D).material_override = _door_open_mat
		_door_slow = 0.8
		Sfx.play(self, "door_thud", 0.0)
		var fl := ColorRect.new()
		fl.color = Color(1, 1, 1, 0.45)
		fl.set_anchors_preset(Control.PRESET_FULL_RECT)
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fl)
		var tw := fl.create_tween()
		tw.tween_property(fl, "color:a", 0.0, 0.35)
		tw.tween_callback(fl.queue_free)
	return opened
