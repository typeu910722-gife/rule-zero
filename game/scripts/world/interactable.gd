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
	return 80.0 * maxf(size, 1.0) if kind == "npc" else 90.0


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
	if follow_eyes or id.begins_with("tuft_") or id.begins_with("candy_") or id.begins_with("note_"):
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
			draw_rect(Rect2(-36, -20, 6, 40), Color("#8d6e63"))
			draw_rect(Rect2(30, -20, 6, 40), Color("#8d6e63"))
			draw_rect(Rect2(-46, -70, 92, 56), Color("#fff3e0"))
			draw_rect(Rect2(-46, -70, 92, 56), Color("#a1887f"), false, 3)
			for k in 5:
				draw_line(Vector2(-36, -60 + k * 9), Vector2(30 - (k % 3) * 10, -60 + k * 9), Color("#bcaaa4"), 2)
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
			Critter.ellipse(self, Vector2(0, -14), Vector2(18, 16), Color("#c9a37a"))
			draw_line(Vector2(-8, -22), Vector2(8, -6), Color("#5c3d2e"), 2)
			draw_line(Vector2(8, -22), Vector2(-8, -6), Color("#5c3d2e"), 2)
		"mayor_door":
			draw_rect(Rect2(-20, -60, 40, 60), Color("#8d5524"))
			draw_circle(Vector2(12, -30), 3, Color("#ffd166"))
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
			# 鐘塔門、森林、車站等：只畫一個小小的閃光提示
			draw_circle(Vector2(0, -10), 5, Color(1, 1, 1, 0.8))
			draw_arc(Vector2(0, -10), 9, 0, TAU, 16, Color(1, 0.8, 0.9, 0.7), 2)
