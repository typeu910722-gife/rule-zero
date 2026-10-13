class_name Interactable
extends Node2D
## 可以互動的角色或物件。id 對應對話腳本中的標籤（見 main.gd 的 _talk）。

var id := ""
var display_name := ""
var kind := "npc"          # npc / obj
var species := ""
var body_color := Color.WHITE
var size := 1.0
var smile := true
var stitched := false
## 夜晚異常：鈕扣眼睛跟著玩家轉
var follow_eyes := false
var covered := true        # 鏡子是否蓋著布
## 頭上的「！」：今天可以去的地方（main.gd 的 _refresh_objective 設定）
var marked := false
var target: Node2D
## 面向（行走圖的方向）；follow_eyes 時改為看著玩家
var facing := Vector2.DOWN
var _last_pos := Vector2.INF
var _step := -1
var _step_t := 0.0

const MIRROR_TEX := preload("res://art/mirror_states.png")


func setup(p_id: String, data: Dictionary) -> Interactable:
	id = p_id
	display_name = data.get("name", p_id)
	kind = data.get("kind", "npc")
	species = data.get("species", "")
	body_color = data.get("color", Color.WHITE)
	size = data.get("size", 1.0)
	smile = data.get("smile", true)
	stitched = data.get("stitched", false)
	position = data.get("pos", Vector2.ZERO)
	add_to_group("interactable")
	return self


func _glint(p: Vector2) -> void:
	var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
	draw_circle(p, 3, Color(1, 1, 1, a))


func reach() -> float:
	# 角色的圖比較寬：站在旁邊（不用正對）就能說話
	return 110.0 * maxf(size, 1.0) if kind == "npc" else 95.0


func face_toward(p: Vector2) -> void:
	facing = (p - global_position).normalized()
	queue_redraw()


func _process(delta: float) -> void:
	# 被程式移動時（例如 Fen 跟在後面）播放走路動畫，朝移動方向
	if _last_pos != Vector2.INF and kind == "npc":
		var moved := position - _last_pos
		if moved.length() > 0.6:
			facing = moved.normalized()
			_step_t += delta
			if _step < 0 or _step_t > 0.14:
				_step_t = 0.0
				_step = (_step + 1) % 4
			queue_redraw()
		elif _step != -1:
			_step = -1
			queue_redraw()
	_last_pos = position
	if marked or follow_eyes or id.begins_with("tuft_") or id.begins_with("candy_") or id.begins_with("note_") or kind == "obj":
		queue_redraw()


func _draw() -> void:
	if kind == "npc":
		var look := facing
		if follow_eyes and target:
			look = (target.global_position - global_position).normalized()
		Critter.draw(self, species, body_color, size * Critter.WORLD_SCALE, look, smile, stitched, false, _step)
		var f: Font = GameState.font
		draw_string_outline(f, Vector2(-60, 24), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, 5, Color(1, 1, 1, 0.85))
		draw_string(f, Vector2(-60, 24), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("#6d597a"))
	else:
		_draw_object()
	if marked:
		_draw_mark()


## 頭上的「！」小泡泡
func _draw_mark() -> void:
	var top := -Critter.BASE_HEIGHT * Critter.WORLD_SCALE * size - 22.0 if kind == "npc" else -70.0
	if id == "bed":
		top = -140.0
	var bob := sin(Time.get_ticks_msec() / 220.0) * 4.0
	var c := Vector2(0, top + bob)
	draw_circle(c, 15, Color("#ffffff"))
	draw_arc(c, 15, 0, TAU, 24, Color("#e05780"), 3)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 12), c + Vector2(5, 12), c + Vector2(0, 21)]), Color("#ffffff"))
	draw_string(GameState.font, c + Vector2(-15, 8), "！", HORIZONTAL_ALIGNMENT_CENTER, 30, 20, Color("#e05780"))


func _draw_object() -> void:
	# 支線物件（素材還沒畫，先用簡單的形狀，外加一點閃光讓玩家找得到）
	if id.begins_with("candy_"):
		var c: Color = [Color("#ffb3c7"), Color("#b5e8d5"), Color("#ffe08a")][int(id.right(1)) % 3]
		draw_circle(Vector2(0, -10), 9, c)
		draw_colored_polygon(PackedVector2Array([Vector2(-9, -10), Vector2(-18, -16), Vector2(-18, -4)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(9, -10), Vector2(18, -16), Vector2(18, -4)]), c)
		_glint(Vector2(10, -22))
		return
	if id.begins_with("note_"):
		draw_set_transform(Vector2(0, -8), 0.25, Vector2.ONE)
		draw_rect(Rect2(-12, -15, 24, 30), Color("#fffaf0"))
		for k in 4:
			draw_line(Vector2(-8, -9 + k * 6), Vector2(7, -9 + k * 6), Color("#9b8b7a"), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_glint(Vector2(12, -24))
		return
	if id.begins_with("tuft_"):
		var t := Time.get_ticks_msec() / 1000.0
		var bob := sin(t * 2.0 + position.x) * 2.0
		for o in [Vector2(-6, 0), Vector2(6, 0), Vector2(0, -6), Vector2(0, 4)]:
			draw_circle(o + Vector2(0, -12 + bob), 8, Color(1, 1, 1, 0.92))
		draw_circle(Vector2(0, -12 + bob), 18, Color(1, 0.85, 0.92, 0.18))
		return
	if id == "lulu_mailbox":
		draw_rect(Rect2(-3, -30, 6, 30), Color("#8d6e63"))
		draw_rect(Rect2(-16, -50, 32, 22), Color("#f4b6c2"))
		draw_rect(Rect2(-16, -50, 32, 22), Color("#c27a8c"), false, 2)
		draw_rect(Rect2(12, -56, 3, 12), Color("#e05780"))
		return
	match id:
		"board":
			# 地圖上已經畫了公告欄，這裡不再疊一張（以前會擋住小布）
			_glint_ring(Vector2(0, -6))
		"mirror":
			# 立鏡（鏡中的孩子素材第 1 格：空鏡）
			draw_texture_rect_region(MIRROR_TEX, Rect2(-60, -150, 120, 150), Rect2(30, 0, 196, 256))
			if covered:
				draw_colored_polygon(PackedVector2Array([Vector2(-42, -150), Vector2(42, -150), Vector2(52, -30), Vector2(-52, -30)]), Color("#f7c5d3"))
				for k in 9:
					draw_circle(Vector2(-28 + (k % 3) * 28, -128 + (k / 3) * 34), 4, Color("#ffffff"))
		"bed":
			draw_rect(Rect2(-80, -110, 160, 26), Color("#a47551"))
			draw_rect(Rect2(-80, -90, 160, 100), Color("#fdf6ec"))
			draw_rect(Rect2(-70, -84, 70, 30), Color("#ffffff"))
			draw_rect(Rect2(-80, -48, 160, 58), Color("#a2d2ff"))
			for k in 4:
				draw_circle(Vector2(-55 + k * 36, -20), 5, Color("#ffffff"))
			draw_rect(Rect2(-80, -110, 160, 120), Color("#7a5236"), false, 4)
		"bakery_photo":
			draw_rect(Rect2(-14, -40, 28, 22), Color("#ffffff"))
			draw_rect(Rect2(-14, -40, 28, 22), Color("#8d6e63"), false, 2)
			draw_rect(Rect2(-12, -38, 12, 18), Color("#e0d6cc"))
		"mail_sack":
			# 鼓鼓的帆布郵袋：袋口用繩子綁起來，露出一角信封
			Critter.ellipse(self, Vector2(0, -2), Vector2(22, 6), Color(0, 0, 0, 0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(-20, -2), Vector2(-24, -20), Vector2(-14, -36),
				Vector2(-6, -38), Vector2(6, -38), Vector2(14, -36), Vector2(24, -20), Vector2(20, -2)]), Color("#d8b98f"))
			draw_polyline(PackedVector2Array([Vector2(-20, -2), Vector2(-24, -20), Vector2(-14, -36),
				Vector2(-6, -38), Vector2(6, -38), Vector2(14, -36), Vector2(24, -20), Vector2(20, -2), Vector2(-20, -2)]), Color("#8d6e4a"), 2)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -38), Vector2(7, -38), Vector2(10, -50), Vector2(-10, -50)]), Color("#d8b98f"))
			draw_line(Vector2(-9, -40), Vector2(9, -40), Color("#7a4e2d"), 3)
			draw_rect(Rect2(-4, -56, 16, 10), Color("#fffaf0"))
			draw_rect(Rect2(-4, -56, 16, 10), Color("#c27a8c"), false, 1)
			draw_string(GameState.font, Vector2(-14, -12), "郵", HORIZONTAL_ALIGNMENT_CENTER, 28, 14, Color("#8d6e4a"))
			_glint_ring(Vector2(0, -20))
		"mayor_door":
			# 門是地圖原圖上的；這裡只在門框外加一圈淡淡的光
			_glint_ring(Vector2(0, -34))
		"forest_bow":
			Critter.ellipse(self, Vector2(0, -14), Vector2(7, 22), Color("#c9a3aa"), 1.2)
			draw_circle(Vector2(-14, -22), 6, Color("#f2d16b"))
			draw_circle(Vector2(-4, -22), 6, Color("#f2d16b"))
			draw_circle(Vector2(-9, -22), 3, Color("#c9a227"))
		"forest_tags":
			for k in 9:
				var p := Vector2(-30 + (k % 3) * 20, -30 + (k / 3) * 12) + Vector2((k * 7) % 5, 0)
				draw_rect(Rect2(p, Vector2(16, 9)), Color("#ece4da"))
				draw_rect(Rect2(p, Vector2(16, 9)), Color("#b08d9a"), false, 1)
		"forest_tail":
			Critter.ellipse(self, Vector2(0, -12), Vector2(26, 9), Color("#a8552a"), -0.3)
			draw_circle(Vector2(24, -20), 7, Color("#efe6da"))
			for k in 4:
				draw_line(Vector2(-14 + k * 8, -18), Vector2(-10 + k * 8, -6), Color("#4a2e1f"), 1.5)
		"forest_sheep":
			for k in 5:
				var off := Vector2(-96 + k * 48, -6 - (k % 2) * 18)
				draw_set_transform(off, 0.4 * (k - 2) * 0.3, Vector2(0.85, 0.85))
				Critter.draw(self, "sheep", Color.WHITE, 0.8, Vector2.ZERO, k != 2, k == 2, false, -1,
					Color(0.82, 0.8, 0.78, 0.95) if k != 2 else Color(0.95, 0.93, 0.9))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_rect(Rect2(-8, 0, 30, 14), Color("#f6efe6"))
			draw_string(GameState.font, Vector2(-8, 11), "No.46", HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color("#5c3d2e"))
		_:
			# 鐘塔門、森林、車站等：一圈會呼吸的光圈
			_glint_ring(Vector2(0, -10))


## 可以調查的地方：一圈慢慢呼吸的白色光圈
func _glint_ring(c: Vector2) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var a := 0.55 + 0.35 * sin(t * 2.4 + position.x * 0.01)
	var r := 10.0 + 3.0 * sin(t * 2.4 + position.x * 0.01)
	draw_circle(c, 5, Color(1, 1, 1, a))
	draw_arc(c, r, 0, TAU, 20, Color(1, 0.82, 0.9, a), 2.5)
