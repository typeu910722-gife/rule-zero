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
## 第二章的外觀細節（斑紋數、縫起來的嘴……），見 Critter.draw 的 opts
var opts := {}
var target: Node2D


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
	opts = data.get("opts", {}).duplicate()
	add_to_group("interactable")
	return self


func reach() -> float:
	return 70.0 * size


func _process(_delta: float) -> void:
	if follow_eyes:
		queue_redraw()


func _draw() -> void:
	if kind == "npc":
		var look := Vector2.ZERO
		if follow_eyes and target:
			look = (target.global_position - global_position).normalized()
		var label_col := Color("#6d597a")
		if species == "dove":
			Critter.draw_dove(self, size, opts.get("unmasked", false), opts.get("crack", 1.0))
			label_col = Color("#555555")
		elif species == "conductor":
			Critter.draw_conductor(self, size)
			label_col = Color("#555555")
		else:
			Critter.draw(self, species, body_color, size, look, smile, stitched, false, opts)
			if GameState.chapter == 2:
				label_col = Color("#555555")
		var f: Font = GameState.font
		draw_string(f, Vector2(-60, 22 * size), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, label_col)
	else:
		_draw_object()


func _draw_object() -> void:
	match id:
		"board":
			draw_rect(Rect2(-36, -20, 6, 40), Color("#8d6e63"))
			draw_rect(Rect2(30, -20, 6, 40), Color("#8d6e63"))
			draw_rect(Rect2(-46, -70, 92, 56), Color("#fff3e0"))
			draw_rect(Rect2(-46, -70, 92, 56), Color("#a1887f"), false, 3)
			for k in 5:
				draw_line(Vector2(-36, -60 + k * 9), Vector2(30 - (k % 3) * 10, -60 + k * 9), Color("#bcaaa4"), 2)
		"mirror":
			Critter.ellipse(self, Vector2(0, -30), Vector2(18, 28), Color("#e9c46a"))
			Critter.ellipse(self, Vector2(0, -30), Vector2(14, 24), Color("#cfe8ef"))
			if covered:
				draw_colored_polygon(PackedVector2Array([Vector2(-20, -60), Vector2(20, -60), Vector2(24, -2), Vector2(-24, -2)]), Color("#f7c5d3"))
				for k in 6:
					draw_circle(Vector2(-14 + (k % 3) * 14, -48 + (k / 3) * 22), 3, Color("#ffffff"))
		"c2_bed":
			# 漂白鎮宿舍的鐵製上下舖
			draw_rect(Rect2(-42, -70, 84, 80), Color("#8d8d8d"), false, 3)
			draw_rect(Rect2(-40, -34, 80, 16), Color("#e6e6e6"))
			draw_rect(Rect2(-40, -66, 80, 14), Color("#e6e6e6"))
			draw_rect(Rect2(-36, -40, 26, 8), Color("#ffffff"))
		"c2_pillow":
			Critter.ellipse(self, Vector2(0, -8), Vector2(18, 9), Color("#f5f5f5"))
			Critter.ellipse(self, Vector2(0, -8), Vector2(18, 9), Color("#cfcfcf"))
			Critter.ellipse(self, Vector2(0, -9), Vector2(16, 7), Color("#fafafa"))
			if not GameState.has("c2_pillow_done"):
				draw_circle(Vector2(10, -3), 3, Color("#f28fb0"))
		"c2_board":
			draw_rect(Rect2(-36, -20, 6, 40), Color("#6e6e6e"))
			draw_rect(Rect2(30, -20, 6, 40), Color("#6e6e6e"))
			draw_rect(Rect2(-46, -70, 92, 56), Color("#f4f4f2"))
			draw_rect(Rect2(-46, -70, 92, 56), Color("#7a7a7a"), false, 3)
			for k in 7:
				draw_line(Vector2(-36, -63 + k * 7), Vector2(30 - (k % 3) * 10, -63 + k * 7), Color("#a8a8a8"), 2)
		"bed":
			draw_rect(Rect2(-40, -50, 80, 60), Color("#bde0fe"))
			draw_rect(Rect2(-36, -46, 72, 16), Color("#ffffff"))
			draw_rect(Rect2(-40, -24, 80, 34), Color("#a2d2ff"))
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
				var off := Vector2(-56 + k * 28, -8 - (k % 2) * 16)
				draw_set_transform(off, 0.4 * (k - 2) * 0.3, Vector2(0.85, 0.85))
				Critter.draw(self, "sheep", Color("#e9e4dc"), 1.0, Vector2.ZERO, k != 2, k == 2)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_rect(Rect2(-8, 0, 30, 14), Color("#f6efe6"))
			draw_string(GameState.font, Vector2(-8, 11), "No.46", HORIZONTAL_ALIGNMENT_CENTER, 30, 10, Color("#5c3d2e"))
		_:
			# 鐘塔門、森林、車站等：只畫一個小小的閃光提示
			draw_circle(Vector2(0, -10), 5, Color(1, 1, 1, 0.8))
			draw_arc(Vector2(0, -10), 9, 0, TAU, 16, Color(1, 0.8, 0.9, 0.7), 2)
