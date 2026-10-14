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
## 第三天：站著一動也不動，一直盯著小布（不呼吸、不跳）
var stare := false
## 小布走近時轉頭看他
var _noticed := false
var _hop_t := 0.0
var _hop_next := randf_range(3.0, 9.0)
const HOP_TIME := 0.32

const MIRROR_TEX := preload("res://art/mirror_states.png")
const PHOTO_TEX := preload("res://art/item_photo.png")
const SACK_TEX := preload("res://art/item_sack.png")
const TREEHOUSE_TEX := preload("res://art/fen_treehouse.png")
const FOREST_TEX := {
	"forest_bow": preload("res://art/item_bow_ear.png"),
	"forest_tags": preload("res://art/item_tags_pile.png"),
	"forest_tail": preload("res://art/item_fox_tail.png"),
	"forest_sheep": preload("res://art/item_sheep_pile.png"),
}


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
	if kind == "npc":
		if target:
			var d := global_position.distance_to(target.global_position)
			var was := _noticed
			_noticed = d < (250.0 if _noticed else 200.0)
			if was != _noticed:
				queue_redraw()
		# 偶爾輕輕跳一下（看起來是活的）
		if not stare and not follow_eyes and _step == -1:
			_hop_next -= delta
			if _hop_next <= 0.0:
				_hop_t = HOP_TIME
				_hop_next = randf_range(5.0, 12.0)
		_hop_t = maxf(_hop_t - delta, 0.0)
		queue_redraw()
	if marked or follow_eyes or id.begins_with("tuft_") or id.begins_with("candy_") or id.begins_with("note_") or kind == "obj":
		queue_redraw()


func _draw() -> void:
	if kind == "npc":
		var look := facing
		var to_player := Vector2.ZERO
		if target:
			to_player = (target.global_position - global_position).normalized()
		if (follow_eyes or stare) and target:
			look = to_player
		elif _noticed and _step == -1 and target:
			# 小布走近：轉頭看他
			look = to_player
		var alive := not stare and not follow_eyes
		if alive:
			# 呼吸：身體輕輕上下伸縮；偶爾跳一下
			var t := Time.get_ticks_msec() / 1000.0
			var breath := sin(t * 2.2 + position.x * 0.013) * 0.016 if _step == -1 else 0.0
			var hop := sin(PI * (1.0 - _hop_t / HOP_TIME)) * 7.0 if _hop_t > 0.0 else 0.0
			draw_set_transform(Vector2(0, -hop), 0.0, Vector2(1.0 - breath * 0.5, 1.0 + breath))
		Critter.draw(self, species, body_color, size * Critter.WORLD_SCALE, look, smile, stitched, false, _step)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
			# 房間的美術圖上已經畫了蓋著布的立鏡；掀開布之後，在原處畫出鏡子
			if not covered:
				draw_rect(Rect2(-86, -288, 172, 276), Color("#2a2230"))
				draw_texture_rect_region(MIRROR_TEX, Rect2(-86, -288, 172, 276), Rect2(30, 0, 196, 256))
			_glint_ring(Vector2(0, -150))
		"bed":
			_glint_ring(Vector2(-110, -40))
		"home_exit":
			_glint_ring(Vector2(-20, -60))
		"bakery_photo":
			draw_texture_rect(PHOTO_TEX, Rect2(-17, -46, 34, 40), false)
			_glint_ring(Vector2(0, -26))
		"mail_sack":
			Critter.ellipse(self, Vector2(0, -2), Vector2(24, 6), Color(0, 0, 0, 0.15))
			draw_texture_rect(SACK_TEX, Rect2(-28, -56, 56, 55), false)
			_glint_ring(Vector2(0, -28))
		"fen_tree":
			# 石橋旁的樹屋（繩梯底部＝這個點）
			draw_texture_rect(TREEHOUSE_TEX, Rect2(-100, -232, 200, 240), false)
			_glint_ring(Vector2(0, -40))
		"mayor_door":
			# 門是地圖原圖上的；這裡只在門框外加一圈淡淡的光
			_glint_ring(Vector2(0, -34))
		"forest_bow", "forest_tags", "forest_tail", "forest_sheep":
			var tex: Texture2D = FOREST_TEX[id]
			var w := 170.0 if id == "forest_sheep" else 110.0
			var h := w * tex.get_height() / tex.get_width()
			Critter.ellipse(self, Vector2(0, -4), Vector2(w * 0.45, 9), Color(0, 0, 0, 0.18))
			draw_texture_rect(tex, Rect2(-w / 2, -h, w, h), false)
			_glint_ring(Vector2(w * 0.3, -h * 0.8))
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
