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
		Critter.draw(self, species, body_color, size, look, smile, stitched)
		var f: Font = GameState.font
		draw_string(f, Vector2(-60, 22 * size), display_name, HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color("#6d597a"))
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
		_:
			# 鐘塔門、森林、車站等：只畫一個小小的閃光提示
			draw_circle(Vector2(0, -10), 5, Color(1, 1, 1, 0.8))
			draw_arc(Vector2(0, -10), 9, 0, TAU, 16, Color(1, 0.8, 0.9, 0.7), 2)
