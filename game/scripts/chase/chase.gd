class_name ChaseScene
extends CanvasLayer
## 第一章結尾：鎮長崩潰後的追逐戰（裸眼 3D 版）。
##
## 畫面是一個「框」：街道在框裡，比小布更靠近鏡頭的東西（飛過來的縫衣針、擦身而過的路燈、
## 撲上來的鎮長）會衝出框外——跟街上的裸眼 3D 看板一樣。
## 背景是一張手繪圖＋深度圖（art/chase2d/bg_z.png，tools/prep_chase2d.py 產生）：
## 鏡頭跟著小布左右換道、上下晃動（手機也會跟著傾斜），近的東西動得多、遠的動得少。
##
## 玩法：小布朝鏡頭跑，鎮長從後面的學校追出來。
##   ← → 換道（三條）：躲開鎮長丟過來的縫衣針、躲開他撲過來的方向
##   按住 ↑ 衝刺：拉開距離
##   被針打中會踉蹌、鎮長會追近；被撲中 → 被抓住，從頭再跑（被抓越多次越簡單）
##   跑完 DIST 公尺 → 修理室的門（在鏡頭這一邊）

signal finished

const DIR := "res://art/chase2d/"
const W := 1280.0
const H := 720.0
## 框（街道畫在框裡面）
const FRAME := Rect2(40, 74, 1200, 584)
## 背景的一點透視（跟 tools/prep_chase2d.py 一致）
const VP := Vector2(877, 466)
const F := 425.0
const CAM_H := 1.3
const CAM_X := 1.41
const BU_Z := 2.5          # 小布離鏡頭多遠（公尺）
const BU_H := 1.15         # 小布多高
const MAYOR_H := 2.5
const LANE_W := 1.1
const DIST := 130.0        # 要跑多遠
const SPEED := 5.0
const SPRINT := 1.3        # 衝刺多快多少
const DEPTH_SHADER := """
shader_type canvas_item;
uniform sampler2D bg : filter_linear, repeat_disable;
uniform sampler2D depth : filter_linear, repeat_disable;
uniform vec2 vp;
uniform float focal;
uniform vec3 cam; // x：左右移、y：上下、z：往前
uniform float danger;
void fragment() {
	vec2 size = vec2(1280.0, 720.0);
	vec2 q = UV * size;
	vec2 p = q;
	for (int i = 0; i < 4; i++) {
		float inv = texture(depth, clamp(p / size, 0.0, 1.0)).r * 0.6;
		float scale = 1.0 / max(1.0 - cam.z * inv, 0.2);
		vec2 shift = vec2(-focal * cam.x * inv, focal * cam.y * inv);
		p = vp + (q - vp - shift) / scale;
	}
	vec3 c = texture(bg, clamp(p / size, 0.001, 0.999)).rgb;
	// 越危險越紅、越暗
	float g = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(g * 1.25, g * 0.55, g * 0.6), danger * 0.45);
	c *= 1.0 - danger * 0.25;
	COLOR = vec4(c, 1.0);
}
"""
const MAYOR_LINES := ["老師會保護你們……", "壞掉的東西……要修理……", "不要跑……老師不會生氣的……",
	"想起來的事情，才會痛喔……", "{name}……過來……", "好孩子……好孩子……好孩子……"]

var tex := {}
var _bg_mat: ShaderMaterial
var _bg_tex: Texture2D
var _world: Node2D      # 框裡面（會被框切掉）
var _frame: Node2D      # 框
var _pop: Node2D        # 框外面（衝出畫面的東西）
var _hud: Node2D
var _sub: Label
var _sub_a := 0.0

# 狀態
var _lane := 0                 # -1 / 0 / 1
var _bu_x := 0.0
var _cam := Vector3.ZERO
var _tilt := Vector2.ZERO
var _t := 0.0
var _run := 0.0                # 跑了幾公尺
var _gap := 12.0               # 鎮長在小布後面幾公尺
var _mayor_x := 0.0
var _mayor_pose := "rise"
var _stumble := 0.0
var _props: Array = []
var _needles: Array = []
var _puffs: Array = []
var _next_prop := 0.0
var _next_tags := 6.0
var _next_throw := 3.0
var _tele := {}                # 預告：{"kind": "needle"/"lunge", "lane": int, "t": float}
var _lunge := {}               # 撲過來
var _beat_t := 0.0
var _line_t := 4.0
var _attempts := 0
var _hits := 0
var _state := "start"          # start / run / caught / door
var _state_t := 0.0
var _done := false
var _flash := 0.0
var _door_a := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	layer = 2
	add_to_group("touch_joystick")
	_rng.seed = 47
	for n in ["bu_run_00", "bu_run_01", "bu_run_02", "bu_run_03", "mayor_run_00", "mayor_run_01", "mayor_run_02", "mayor_run_03",
			"bu_caught", "bu_idle", "bu_open_door", "mayor_grab", "mayor_twitch", "mayor_rise", "needle", "lamp", "cotton",
			"nametags", "bench", "noticeboard", "door"]:
		tex[n] = load(DIR + n + ".png")
	_build()
	_reset_run()
	_start_tilt()
	if GameState.fast:
		_finish.call_deferred()


# ───────── 建畫面 ─────────

func _build() -> void:
	var back := ColorRect.new()
	back.color = Color(0.05, 0.025, 0.05)
	back.size = Vector2(W, H)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var clip := Control.new()
	clip.position = FRAME.position
	clip.size = FRAME.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	var bg := ColorRect.new()
	bg.position = -FRAME.position
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = Shader.new()
	_bg_mat.shader.code = DEPTH_SHADER
	_bg_tex = load(DIR + "bg.jpg")
	_bg_mat.set_shader_parameter("bg", _bg_tex)
	_bg_mat.set_shader_parameter("depth", load(DIR + "bg_z.png"))
	_bg_mat.set_shader_parameter("vp", VP)
	_bg_mat.set_shader_parameter("focal", F)
	bg.material = _bg_mat
	clip.add_child(bg)
	_world = Node2D.new()
	_world.position = -FRAME.position
	_world.draw.connect(func(): _draw_world(false, _world))
	clip.add_child(_world)
	_frame = Node2D.new()
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	_pop = Node2D.new()
	_pop.draw.connect(func(): _draw_world(true, _pop))
	add_child(_pop)
	_hud = Node2D.new()
	_hud.draw.connect(_draw_hud)
	add_child(_hud)
	_sub = Label.new()
	_sub.position = Vector2(0, 674)
	_sub.size = Vector2(W, 40)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 26)
	_sub.add_theme_color_override("font_color", Color("#fff0f5"))
	_sub.add_theme_color_override("font_outline_color", Color("#3a1426"))
	_sub.add_theme_constant_override("outline_size", 10)
	add_child(_sub)


## 手機：裝置傾斜也會帶動視差（iOS 要在使用者點一下之後才能要求權限）
func _start_tilt() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
	(function(){
	  if (window.__rzTilt) return; window.__rzTilt = {x:0, y:0, on:false};
	  function listen(){ window.addEventListener('deviceorientation', function(e){
	    if (e.gamma == null) return; window.__rzTilt.on = true;
	    window.__rzTilt.x = Math.max(-1, Math.min(1, e.gamma / 25));
	    window.__rzTilt.y = Math.max(-1, Math.min(1, ((e.beta || 45) - 45) / 25)); }); }
	  if (typeof DeviceOrientationEvent !== 'undefined' && DeviceOrientationEvent.requestPermission) {
	    window.addEventListener('touchend', function once(){ window.removeEventListener('touchend', once);
	      DeviceOrientationEvent.requestPermission().then(function(r){ if (r === 'granted') listen(); }).catch(function(){}); });
	  } else { listen(); }
	})();
	""", true)


func _read_tilt() -> Vector2:
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		var s = JavaScriptBridge.eval("window.__rzTilt && window.__rzTilt.on ? (window.__rzTilt.x + ',' + window.__rzTilt.y) : ''", true)
		var parts := str(s).split(",")
		if parts.size() == 2:
			return Vector2(float(parts[0]), float(parts[1]))
		return Vector2.ZERO
	if DisplayServer.is_touchscreen_available() or GameState.fast:
		return Vector2.ZERO
	var m := get_viewport().get_mouse_position()
	return Vector2(clampf((m.x - W / 2) / (W / 2), -1, 1), clampf((m.y - H / 2) / (H / 2), -1, 1)) * 0.6


# ───────── 遊戲 ─────────

func _reset_run() -> void:
	_lane = 0
	_bu_x = 0.0
	_run = 0.0
	_gap = 12.0
	_mayor_x = 0.0
	_mayor_pose = "rise"
	_stumble = 0.0
	_needles.clear()
	_tele = {}
	_lunge = {}
	_state = "start"
	_state_t = 0.0
	_next_throw = 2.2
	_props.clear()
	_next_prop = 0.0
	_next_tags = 5.0
	# 一開始街上就有東西
	var z := 3.0
	while z < 40.0:
		_spawn_prop(z)
		z += _rng.randf_range(2.6, 4.0)
	_say("熊熊鎮長：……老師來了喔。")


## 鎮長越追越瘋（0～1）：跑得越遠，出招越頻繁、預告越短、針越快
func _rage() -> float:
	return clampf(_run / DIST, 0.0, 1.0) * (1.0 - 0.5 * _ease())


func _needle_speed() -> float:
	return lerpf(15.0, 22.0, _rage())


## 難度：被抓越多次越簡單（0～1）
func _ease() -> float:
	return clampf(_attempts * 0.35, 0.0, 1.0)


func _spawn_prop(z: float) -> void:
	var left := _rng.randf() < 0.5
	var kinds := ["lamp", "lamp", "bench", "cotton", "cotton", "needle", "noticeboard"]
	var k: String = kinds[_rng.randi() % kinds.size()]
	var x := _rng.randf_range(-3.6, -2.4) if left else _rng.randf_range(1.8, 2.8)
	var size: float = {"lamp": 3.4, "bench": 1.9, "cotton": 1.5, "needle": 2.6, "noticeboard": 2.3}[k]
	_props.append({"k": k, "x": x, "z": z, "s": size, "flip": not left, "rot": _rng.randf_range(-0.35, 0.35)})


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	_state_t += delta
	_sub_a = maxf(_sub_a - delta * 0.45, 0.0)
	_sub.modulate.a = clampf(_sub_a, 0.0, 1.0)
	_flash = maxf(_flash - delta * 2.0, 0.0)
	_tilt = _tilt.lerp(_read_tilt(), clampf(delta * 4.0, 0, 1))
	match _state:
		"start":
			_bu_x = lerpf(_bu_x, 0.0, clampf(delta * 5, 0, 1))
			if _state_t > 1.6:
				_state = "run"
				_mayor_pose = "run"
		"run":
			_update_run(delta)
		"caught":
			if _state_t > 1.9:
				_attempts += 1
				_reset_run()
		"door":
			_door_a = minf(_door_a + delta * 0.9, 1.0)
			if _state_t > 3.4:
				_finish()
	# 鏡頭：跟著小布換道、跑步時上下晃、手機傾斜／滑鼠
	var bob := sin(_t * 11.0) * 0.035 if _state == "run" else 0.0
	var want := Vector3(_bu_x * 0.42 + _tilt.x * 0.35, bob - _tilt.y * 0.15, 0.0)
	_cam = _cam.lerp(want, clampf(delta * 6.0, 0, 1))
	_bg_mat.set_shader_parameter("cam", _cam)
	_bg_mat.set_shader_parameter("danger", danger())
	Dialogue.fx.vignette = 0.15 + 0.6 * danger()
	_world.queue_redraw()
	_pop.queue_redraw()
	_hud.queue_redraw()


func danger() -> float:
	if _state == "caught":
		return 1.0
	if _state != "run":
		return 0.0
	return clampf(1.0 - (_gap - 1.0) / 8.0, 0.0, 1.0)


func _speed() -> float:
	var sprint := Input.is_action_pressed("move_up")
	return SPEED * (SPRINT if sprint else 1.0) * (0.45 if _stumble > 0.0 else 1.0)


func _update_run(delta: float) -> void:
	# 換道
	if Input.is_action_just_pressed("move_left") and _lane > -1:
		_lane -= 1
	if Input.is_action_just_pressed("move_right") and _lane < 1:
		_lane += 1
	_bu_x = move_toward(_bu_x, _lane * LANE_W, delta * 7.5)
	var v := _speed()
	_stumble = maxf(_stumble - delta, 0.0)
	_run += v * delta
	# 世界往後退（小布朝鏡頭跑，鏡頭也一起往後）
	for p in _props:
		p.z += v * delta
	_props = _props.filter(func(p): return p.z < 45.0)
	_next_prop -= v * delta
	if _next_prop <= 0.0:
		_next_prop = _rng.randf_range(2.6, 4.0)
		_spawn_prop(0.55)
	_next_tags -= v * delta
	if _next_tags <= 0.0:
		_next_tags = _rng.randf_range(18.0, 26.0)
		_props.append({"k": "nametags", "x": -0.3, "z": 0.55, "s": 7.5, "flip": false, "rot": 0.0})
	# 棉絮
	if _rng.randf() < delta * 6.0:
		_puffs.append({"x": _rng.randf_range(-3, 3), "y": _rng.randf_range(0.2, 3.2), "z": _rng.randf_range(1.0, 12.0), "life": 1.0})
	for p in _puffs:
		p.z += v * delta * 0.6
		p.y -= delta * 0.15
		p.life -= delta * 0.35
	_puffs = _puffs.filter(func(p): return p.life > 0.0)
	# 鎮長：慢慢追近；衝刺可以拉開
	var close := 0.55 - 0.3 * _ease()
	_gap += (v - SPEED - close) * delta
	_gap = clampf(_gap, 0.0, 11.0)
	if _lunge.is_empty():
		_mayor_x = lerpf(_mayor_x, _bu_x, clampf(delta * 1.6, 0, 1))
		_mayor_pose = "run"
	# 預告 → 丟針／撲過來
	if not _tele.is_empty():
		_tele.t -= delta
		_mayor_pose = "twitch"
		if _tele.t <= 0.0:
			if _tele.kind == "needle":
				for ln in _tele.get("lanes", [_tele.lane]):
					_needles.append({"x": _mayor_x, "tx": float(ln) * LANE_W, "z": BU_Z + _gap, "z0": BU_Z + _gap, "y": 1.6, "hit": false, "spd": _needle_speed()})
				Sound.sfx("interact")
			else:
				_lunge = {"lane": _tele.lane, "t": 0.0, "x0": _mayor_x, "gap0": _gap}
				_mayor_pose = "grab"
				Sound.sfx("creepy")
			_tele = {}
	elif _lunge.is_empty():
		_next_throw -= delta
		if _gap < 2.4:
			_tele = {"kind": "lunge", "lane": _lane, "lanes": [_lane], "t": lerpf(0.75, 0.5, _rage()) + 0.3 * _ease()}
			_say(GameState.fill("熊熊鎮長：{name}……"))
		elif _next_throw <= 0.0:
			# 越跑越快：一開始 2～2.8 秒丟一次，最後 0.6～0.9 秒就丟一次
			var r := _rage()
			_next_throw = _rng.randf_range(lerpf(2.0, 0.6, r), lerpf(2.8, 0.9, r)) + 1.2 * _ease()
			var lane := _lane if _rng.randf() < 0.7 else clampi(_lane + (1 if _rng.randf() < 0.5 else -1), -1, 1)
			var lanes := [lane]
			# 後半段：一次丟兩根（一定留一道可以躲）
			if r > 0.45 and _rng.randf() < lerpf(0.25, 0.7, (r - 0.45) / 0.55):
				var others := [-1, 0, 1].filter(func(l): return l != lane)
				lanes.append(others[_rng.randi() % others.size()])
			_tele = {"kind": "needle", "lane": lane, "lanes": lanes, "t": lerpf(0.6, 0.38, r) + 0.25 * _ease()}
	# 撲過來
	if not _lunge.is_empty():
		_lunge.t += delta
		var k: float = clampf(_lunge.t / 0.4, 0.0, 1.0)
		_gap = lerpf(_lunge.gap0, 0.5, k)
		_mayor_x = lerpf(_lunge.x0, float(_lunge.lane) * LANE_W, k)
		if k >= 1.0:
			if absf(_bu_x - float(_lunge.lane) * LANE_W) < LANE_W * 0.55:
				_caught()
				return
			# 撲空：跌倒，拉開距離
			_say("熊熊鎮長：……")
			_lunge = {}
			_gap = 6.5
			_mayor_pose = "rise"
	# 縫衣針：飛向小布那一道，飛過小布之後衝出畫面
	for n in _needles:
		n.z -= (float(n.get("spd", 15.0)) + v) * delta
		var span: float = maxf(n.z0 - BU_Z, 0.1)
		var k2 := clampf(1.0 - (n.z - BU_Z) / span, 0.0, 1.0)
		if k2 < 1.0:
			n.x = lerpf(n.x, n.tx, clampf(delta * 8.0, 0, 1))
		if not n.hit and n.z <= BU_Z + 0.15:
			n.hit = true
			if absf(n.x - _bu_x) < LANE_W * 0.55:
				_hits += 1
				_stumble = 0.8
				_gap = maxf(_gap - (2.6 - 1.0 * _ease()), 0.6)
				_flash = 0.7
				Dialogue.fx.scare()
				_say("……！")
	_needles = _needles.filter(func(n): return n.z > 0.25)
	# 心跳
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t = lerpf(1.1, 0.34, danger())
		Sound.sfx("heartbeat")
	if _gap <= 0.4 and _lunge.is_empty():
		_caught()
		return
	_line_t -= delta
	if _line_t <= 0.0:
		_line_t = _rng.randf_range(4.5, 7.0)
		_say("熊熊鎮長：" + GameState.fill(MAYOR_LINES[_rng.randi() % MAYOR_LINES.size()]))
	if _run >= DIST:
		_reach_door()


func _caught() -> void:
	_state = "caught"
	_state_t = 0.0
	_lunge = {}
	_tele = {}
	_mayor_pose = "grab"
	_gap = 0.0
	_flash = 1.0
	Dialogue.fx.scare()
	Sound.sfx("glitch")
	_say("……被抓住了。再跑一次！")


func _reach_door() -> void:
	_state = "door"
	_state_t = 0.0
	_tele = {}
	_lunge = {}
	_needles.clear()
	Sound.sfx("door")
	_say("修理室的門——！")


func _finish() -> void:
	if _done:
		return
	_done = true
	Dialogue.fx.vignette = 0.0
	finished.emit()


func _say(text: String) -> void:
	_sub.text = text
	_sub_a = 2.6


# ───────── 投影與繪圖 ─────────

func _proj(x: float, y: float, z: float) -> Vector2:
	var cx := CAM_X + _cam.x
	var ch := CAM_H + _cam.y
	return Vector2(VP.x + F * (x - cx) / z, VP.y + F * (ch - y) / z)


## 畫一張站在地上的圖：腳底中心在 (x, y, z)；h＝高（by_width 時＝寬），單位公尺
func _sprite(c: CanvasItem, t: Texture2D, x: float, z: float, h: float, anchor := 0.9375, flip := false,
		by_width := false, y := 0.0, rot := 0.0, mod := Color.WHITE) -> void:
	var foot := _proj(x, y, z)
	var px := F * h / z
	var size: Vector2
	if by_width:
		size = Vector2(px, px * t.get_height() / t.get_width())
	else:
		size = Vector2(px * t.get_width() / t.get_height() / anchor, px / anchor)
	c.draw_set_transform(foot, rot, Vector2(-1 if flip else 1, 1))
	c.draw_texture_rect(t, Rect2(Vector2(-size.x / 2, -size.y * anchor), size), false, mod)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _shadow(c: CanvasItem, x: float, z: float, w: float) -> void:
	var p := _proj(x, 0, z)
	var r := F * w / z
	c.draw_set_transform(p, 0, Vector2(1, 0.28))
	for i in 4:
		c.draw_circle(Vector2.ZERO, r * (1.0 - i * 0.18), Color(0, 0, 0, 0.12))
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_world(pop: bool, c: CanvasItem) -> void:
	if _state == "door" and _door_a >= 1.0:
		return
	var items: Array = []
	for p in _props:
		items.append({"z": p.z, "d": "prop", "o": p})
	for n in _needles:
		items.append({"z": n.z, "d": "needle", "o": n})
	for p in _puffs:
		items.append({"z": p.z, "d": "puff", "o": p})
	items.append({"z": BU_Z, "d": "bu"})
	var mz := BU_Z + maxf(_gap, 0.35)
	if _state == "caught":
		mz = BU_Z - 0.9
	items.append({"z": mz, "d": "mayor"})
	items.sort_custom(func(a, b): return a.z > b.z)
	# 預告：地上閃爍的紅色虛線，從鎮長指向他要攻擊的那一道（兩根針就兩條）
	if not pop and not _tele.is_empty():
		var a := 0.45 + 0.4 * sin(_t * 22.0)
		var zz := BU_Z + _gap
		for ln in _tele.get("lanes", [_tele.lane]):
			var lx: float = float(ln) * LANE_W
			var prev := _proj(_mayor_x, 0.02, zz)
			for i in range(1, 11):
				var k := float(i) / 10.0
				var q := _proj(lerpf(_mayor_x, lx, k), 0.02, lerpf(zz, BU_Z - 0.3, k))
				if i % 2 == 1:
					c.draw_line(prev, q, Color(1, 0.15, 0.25, a), 6.0)
				prev = q
	for it in items:
		var is_pop: bool = it.z < BU_Z - 0.01 or it.d == "bu" or (it.d == "mayor" and _state == "caught")
		if is_pop != pop:
			continue
		match it.d:
			"prop":
				_draw_prop(c, it.o)
			"puff":
				var pf: Dictionary = it.o
				c.draw_circle(_proj(pf.x, pf.y, pf.z), F * 0.05 / pf.z + 1.5, Color(1, 0.97, 0.94, pf.life * 0.8))
			"needle":
				_draw_needle(c, it.o)
			"bu":
				_draw_bu(c)
			"mayor":
				_draw_mayor(c, it.z)


func _draw_prop(c: CanvasItem, p: Dictionary) -> void:
	var t: Texture2D = tex[p.k]
	var m := Color(1, 1, 1, clampf((44.0 - p.z) / 6.0, 0.0, 1.0))
	match p.k:
		"lamp":
			_sprite(c, t, p.x, p.z, p.s, 0.99, p.flip, false, 0.0, 0.0, m)
		"needle":
			_sprite(c, t, p.x, p.z, p.s, 0.98, p.flip, false, -0.3, p.rot, m)
		"nametags":
			_sprite(c, t, p.x, p.z, p.s, 0.0, false, true, 4.6, 0.0, m)
		_:
			_shadow(c, p.x, p.z, p.s * 0.4)
			_sprite(c, t, p.x, p.z, p.s, 0.97, p.flip, true, 0.0, 0.0, m)


func _draw_needle(c: CanvasItem, n: Dictionary) -> void:
	var q: Vector2 = _proj(n.x, n.y, n.z)
	var tail: Vector2 = _proj(n.x, n.y, n.z + 2.2)
	c.draw_line(tail, q, Color(1, 0.75, 0.85, 0.35), maxf(F * 0.05 / n.z, 2.0))
	var ang := (q - VP).angle() - PI / 2
	var len: float = F * 1.5 / float(n.z)
	var t: Texture2D = tex.needle
	var sz := Vector2(len * t.get_width() / t.get_height(), len)
	c.draw_set_transform(q, ang, Vector2.ONE)
	c.draw_texture_rect(t, Rect2(Vector2(-sz.x / 2, -sz.y * 0.85), sz), false)
	c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _draw_bu(c: CanvasItem) -> void:
	if _state == "door":
		return
	var t: Texture2D
	var anchor := 0.9375
	if _state == "caught" or _stumble > 0.4:
		t = tex.bu_caught
		anchor = 0.97
	elif _state == "start":
		t = tex.bu_idle
		anchor = 0.97
	else:
		t = tex["bu_run_%02d" % (int(_t * 10.0) % 4)]
	var hop := absf(sin(_t * 10.0 * PI / 2)) * 0.05 if _state == "run" else 0.0
	_shadow(c, _bu_x, BU_Z, 0.42)
	_sprite(c, t, _bu_x, BU_Z, BU_H, anchor, _bu_x < -0.3, false, hop)


func _draw_mayor(c: CanvasItem, z: float) -> void:
	if _state == "door":
		return
	var t: Texture2D
	var anchor := 0.97
	match _mayor_pose:
		"rise":
			t = tex.mayor_rise
		"twitch":
			t = tex.mayor_twitch
		"grab":
			t = tex.mayor_grab
		_:
			t = tex["mayor_run_%02d" % (int(_t * 8.0) % 4)]
			anchor = 0.9375
	var x := _mayor_x
	var tw := float(_mayor_pose == "twitch")
	if tw > 0.0:
		x += sin(_t * 60.0) * 0.06
	_shadow(c, x, z, 0.8)
	_sprite(c, t, x, z, MAYOR_H, anchor, x < _bu_x - 0.2, false, 0.0, 0.0, Color(1, 0.86 - 0.2 * tw, 0.86 - 0.2 * tw))
	# 眼睛的紅光
	if _mayor_pose != "rise":
		var e := _proj(x + 0.12, MAYOR_H * 0.74, z)
		var r := F * 0.18 / z
		for i in 3:
			c.draw_circle(e, r * (1.0 - i * 0.3), Color(1, 0.15, 0.2, 0.18))


func _draw_frame() -> void:
	var c := _frame
	var r := FRAME
	# 框：深色布＋黃銅色的縫線
	c.draw_rect(Rect2(r.position - Vector2(12, 12), r.size + Vector2(24, 24)), Color("#2a1220"), false, 24.0)
	c.draw_rect(r.grow(1), Color("#120810"), false, 3.0)
	var stitch := Color("#c9a46a")
	var o := r.grow(10)
	var x := o.position.x
	while x < o.end.x:
		c.draw_line(Vector2(x, o.position.y), Vector2(x + 9, o.position.y), stitch, 2.0)
		c.draw_line(Vector2(x, o.end.y), Vector2(x + 9, o.end.y), stitch, 2.0)
		x += 16
	var y := o.position.y
	while y < o.end.y:
		c.draw_line(Vector2(o.position.x, y), Vector2(o.position.x, y + 9), stitch, 2.0)
		c.draw_line(Vector2(o.end.x, y), Vector2(o.end.x, y + 9), stitch, 2.0)
		y += 16
	# 框的內陰影（畫面像是凹進去的）
	for i in 8:
		c.draw_rect(r.grow(-i * 3), Color(0, 0, 0, 0.09 - i * 0.01), false, 3.0)


func _draw_hud() -> void:
	var c := _hud
	var f: Font = GameState.font
	if _state == "door":
		_draw_door(c)
	var left := maxf(DIST - _run, 0.0)
	var bar := Rect2(340, 32, 600, 12)
	c.draw_rect(bar, Color(0.1, 0.04, 0.08, 0.85))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(_run / DIST, 0, 1), bar.size.y)), Color("#e8a0bf"))
	c.draw_rect(bar, Color("#c9a46a"), false, 2.0)
	var label := "修理室　還有 %d 公尺" % int(ceil(left))
	c.draw_string_outline(f, Vector2(0, 24), label, HORIZONTAL_ALIGNMENT_CENTER, W, 20, 7, Color("#3a1426"))
	c.draw_string(f, Vector2(0, 24), label, HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color("#fff0f5"))
	if _run < 20.0 and _attempts < 2 and _state != "door":
		var hint := "左右推：換道躲開　·　往上推：衝刺" if DisplayServer.is_touchscreen_available() else "← → 換道躲開　·　按住 ↑ 衝刺"
		# 提示放在框的右下角外面（不擋畫面、不擋字幕）
		c.draw_string_outline(f, Vector2(W - 560, 708), hint, HORIZONTAL_ALIGNMENT_RIGHT, 520, 16, 6, Color("#3a1426"))
		c.draw_string(f, Vector2(W - 560, 708), hint, HORIZONTAL_ALIGNMENT_RIGHT, 520, 16, Color("#ffd9e6"))
	if _flash > 0.0:
		c.draw_rect(Rect2(0, 0, W, H), Color(0.7, 0.05, 0.15, _flash * 0.45))


## 終點：鏡頭轉過來——修理室的門就在眼前；小布伸手開門（手伸出框外）
func _draw_door(c: CanvasItem) -> void:
	var a := _door_a
	# 鏡頭轉過來：背後的街道變暗、糊掉，修理室的門在眼前
	c.draw_rect(FRAME, Color(0.06, 0.03, 0.04, a))
	c.draw_texture_rect_region(_bg_tex, FRAME, Rect2(FRAME.position * 1.5 + Vector2(160, 40), FRAME.size * 1.2), Color(0.42, 0.28, 0.3, a * 0.7))
	var t: Texture2D = tex.door
	var h := lerpf(420.0, 560.0, ease(a, 0.6))
	var size := Vector2(h * t.get_width() / t.get_height(), h)
	var pos := Vector2(W / 2 - size.x / 2, FRAME.end.y - size.y + 6)
	c.draw_texture_rect(t, Rect2(pos, size), false, Color(1, 1, 1, a))
	if a > 0.5:
		var bt: Texture2D = tex.bu_open_door
		var bh := 340.0
		var bs := Vector2(bh * bt.get_width() / bt.get_height(), bh)
		c.draw_set_transform(Vector2(W / 2 + 40, H + 30), 0, Vector2(-1, 1))
		c.draw_texture_rect(bt, Rect2(Vector2(-bs.x / 2, -bs.y), bs), false, Color(1, 1, 1, clampf((a - 0.5) * 3, 0, 1)))
		c.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var glow := clampf((_state_t - 1.8) / 1.4, 0.0, 1.0)
	if glow > 0.0:
		var ctr := Vector2(W / 2, FRAME.end.y - size.y * 0.35)
		for i in 6:
			c.draw_circle(ctr, 80.0 + i * 70.0 * glow, Color(1, 0.85, 0.55, 0.08 * glow))
		c.draw_rect(Rect2(0, 0, W, H), Color(1, 0.92, 0.8, glow * glow * 0.9))
