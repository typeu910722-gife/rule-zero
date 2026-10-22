class_name ExploreArt
extends RefCounted
## 室內探索的畫圖工具：角色小人圖（快取）、沒有美術時的佔位家具、人類時期的人影。
## 圖一定要留在快取裡：只用區域變數的話，畫面真的畫出來之前圖就被釋放（會畫成白框）。

const SP := "res://art/ch2/characters/sprites/ch2_"
const PIP_SHEET := SP + "pip_sprite_walk_sheet.png"
const PIP_SHEET_MARKS := SP + "pip_sprite_walk_marks_sheet.png"
## 角色 → [圖, 一格大小, 腳底位置, 縮放]
const CHARS := {
	"lulu": [SP + "lulu_sprite_wave_sheet.png", 160, Vector2(80, 152), 0.5],
	"mochi": [SP + "mochi_sprite_wave_sheet.png", 160, Vector2(80, 152), 0.5],
	"popo": [SP + "popo_sprite_wave_sheet.png", 160, Vector2(80, 152), 0.5],
	"fen": [SP + "fen_sprite_stand_sheet.png", 160, Vector2(80, 152), 0.5],
	"baimian": [SP + "baimian_sprite_stand_sheet.png", 160, Vector2(80, 152), 0.5],
	"xiaoji": [SP + "xiaoji_sprite_onequill_sheet.png", 160, Vector2(80, 152), 0.5],
	"zhongzhong": [SP + "zhongzhong_sprite_stand_sheet.png", 208, Vector2(104, 200), 0.5],
	"gaga": [SP + "gaga_sprite_unsewn_sheet.png", 160, Vector2(80, 152), 0.5],
	"youyou": [SP + "youyou_sprite_sheet.png", 160, Vector2(80, 152), 0.5],
	"dove": [SP + "dove_sprite_sheet.png", 384, Vector2(192, 408), 0.42],
	"dove_unmasked": [SP + "dove_sprite_unmasked_sheet.png", 384, Vector2(192, 408), 0.42],
	"conductor": [SP + "conductor_sprite_stand_sheet.png", 384, Vector2(192, 408), 0.42],
	"staff": [SP + "staff_sprite_walk_sheet.png", 160, Vector2(80, 152), 0.6],
}

## 四方向走路圖（tools/art/make_walk_sheet.py）：res://art/walk4/<id>.png，4 列（下、左、右、上）× 4 格，每格 160px
const WALK_DIR := "res://art/walk4/%s.png"
## 人類時期的角色（h_<id>）還沒有走路圖時，用這個顏色畫簡單的人影
const HUMAN_FALLBACK := {"h_haruka": "#33415c", "h_xiaoman": "#8b9a7b", "h_tiwen": "#d9d9d4", "h_hilufei": "#e7a3b4",
	"h_xinhe": "#3a3a3a", "h_mingyue": "#3b4a73", "h_teacher": "#6f6a5e", "h_fen": "#c8642b", "h_lien": "#5b6b78",
	"h_qiuge": "#4a4a4a", "h_junzhu": "#7d7d7d", "h_principal": "#4a4f5a", "h_fen_father": "#4a4f5a", "h_nurse": "#9ec3dd", "h_whitecoat": "#eceae4"}
## 走路圖的縮放（預設 0.5＝80px 高；大隻的角色大一點）
const WALK_SCALE := {"h_principal": 0.62, "h_fen_father": 0.62, "h_teacher": 0.62, "h_nurse": 0.6, "h_whitecoat": 0.62, "h_junzhu": 0.6,
	"h_haruka": 0.56, "h_xiaoman": 0.54, "h_hilufei": 0.55, "h_mingyue": 0.58, "h_xinhe": 0.55, "h_tiwen": 0.55, "h_lien": 0.54, "h_qiuge": 0.55, "h_fen": 0.57, "zhongzhong": 0.62, "conductor": 0.75, "dove": 0.75, "director": 0.8, "staff": 0.7, "nurse": 0.7}

static var _cache := {}


## 有四方向走路圖就畫（回傳 true）。row：0 下、1 左、2 右、3 上；frame：0～3
static func draw_walk(ci: CanvasItem, id: String, foot: Vector2, row := 0, frame := 0) -> bool:
	var t := tex(WALK_DIR % id)
	if t == null:
		return false
	var sc: float = WALK_SCALE.get(id, 0.5)
	ci.draw_texture_rect_region(t, Rect2(foot - Vector2(80, 152) * sc, Vector2(160, 160) * sc), Rect2((frame % 4) * 160, row * 160, 160, 160))
	return true


## 方向（移動的向量）→ 走路圖的列
static func walk_row(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		return 1 if dir.x < 0 else 2
	return 3 if dir.y < 0 else 0


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


## 畫一個角色的第一格（站著）；沒有圖時畫一個圓圓的玩偶
static func draw_char(ci: CanvasItem, id: String, foot: Vector2, flip := false, row := -1, frame := 0) -> void:
	if id != "pip" and draw_walk(ci, id, foot, (1 if flip else 0) if row < 0 else row, frame):
		return
	if id == "pip":
		var t := tex(PIP_SHEET_MARKS if GameState.day >= 3 else PIP_SHEET)
		if t:
			ci.draw_texture_rect_region(t, Rect2(foot + Vector2(-40, -76), Vector2(80, 80)), Rect2(0, 0, 160, 160))
			return
	if id.begins_with("human:"):
		draw_human(ci, foot, id.trim_prefix("human:"))
		return
	if id.begins_with("h_"):
		draw_human(ci, foot, HUMAN_FALLBACK.get(id, "#6d7f8a"))
		return
	if CHARS.has(id):
		var c: Array = CHARS[id]
		var t := tex(c[0])
		if t:
			var fs: float = c[1]
			var sc: float = c[3]
			var size := Vector2(fs, fs) * sc
			var dst := Rect2(foot - (c[2] as Vector2) * sc, size)
			if flip:
				dst = Rect2(dst.position + Vector2(dst.size.x, 0), Vector2(-dst.size.x, dst.size.y))
			ci.draw_texture_rect_region(t, dst, Rect2(0, 0, fs, fs))
			return
	ci.draw_circle(foot + Vector2(0, -22), 18, Color("#d8d2c8"))
	ci.draw_circle(foot + Vector2(0, -44), 14, Color("#e8e2d8"))


## 人類時期（第四章、終章的真實世界）：簡單的人影。col 決定衣服顏色
static func draw_human(ci: CanvasItem, foot: Vector2, col: String, row := 0, moving := false, t := 0.0) -> void:
	var c := Color(col)
	var bob := sin(t * 12.0) * 2.0 if moving else 0.0
	var step := sin(t * 12.0) * 5.0 if moving else 0.0
	ci.draw_rect(Rect2(foot + Vector2(-9 - step * 0.3, -22), Vector2(7, 22)), c.darkened(0.45))
	ci.draw_rect(Rect2(foot + Vector2(2 + step * 0.3, -22), Vector2(7, 22)), c.darkened(0.45))
	ci.draw_rect(Rect2(foot + Vector2(-14, -58 + bob), Vector2(28, 38)), c)
	ci.draw_circle(foot + Vector2(0, -70 + bob), 13, Color("#e9d6c3"))
	# 頭髮：背面時整顆都是頭髮
	if row == 3:
		ci.draw_circle(foot + Vector2(0, -71 + bob), 13, Color("#3a302a"))
	else:
		ci.draw_rect(Rect2(foot + Vector2(-13, -84 + bob), Vector2(26, 8)), Color("#3a302a"))


## 房間的配色（沒有背景圖時）
const THEMES := {
	"hospital": {"floor": "#e6ebec", "wall": "#cfd8db", "top": "#f4f7f7", "line": "#b8c6cb"},
	"hospital_old": {"floor": "#9aa3a3", "wall": "#6d7676", "top": "#8a9393", "line": "#4f5757"},
	"basement": {"floor": "#2a3235", "wall": "#1a2023", "top": "#323c40", "line": "#3e4b4f"},
	"lab": {"floor": "#dfe6e8", "wall": "#b8c4c8", "top": "#eef3f4", "line": "#9fb0b5"},
	"platform": {"floor": "#d2d5d5", "wall": "#a9adad", "top": "#c9cdcd", "line": "#8d9292"},
	"school": {"floor": "#c9b79b", "wall": "#e2d6c2", "top": "#efe6d6", "line": "#8f7d64"},
	"school_dark": {"floor": "#8f826e", "wall": "#a99c86", "top": "#b8ab95", "line": "#5f5444"},
	"home": {"floor": "#c7b9b0", "wall": "#e5d9cf", "top": "#f0e7de", "line": "#9b8b7e"},
	"real": {"floor": "#d8dcd8", "wall": "#eef0ee", "top": "#f7f8f7", "line": "#b6bcb6"},
	"town": {"floor": "#f2dbe3", "wall": "#f8e9ee", "top": "#fff4f7", "line": "#d8aebb"},
}


static func theme(name: String) -> Dictionary:
	return THEMES.get(name, THEMES.hospital)


## 家具（佔位）：rect 是地上的佔地範圍（房間座標）
static func draw_prop(ci: CanvasItem, kind: String, r: Rect2, th: Dictionary, label := "") -> void:
	var line := Color(th.line)
	match kind:
		"bed":
			ci.draw_rect(Rect2(r.position + Vector2(0, -18), r.size + Vector2(0, 18)), Color("#ffffff"))
			ci.draw_rect(Rect2(r.position + Vector2(0, -18), r.size + Vector2(0, 18)), line, false, 2.0)
			ci.draw_rect(Rect2(r.position + Vector2(6, -12), Vector2(r.size.x - 12, 22)), Color("#eef2f3"))
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.45), Vector2(r.size.x, r.size.y * 0.55)), Color("#dbe6ea"))
		"desk", "table":
			ci.draw_rect(Rect2(r.position + Vector2(0, -24), Vector2(r.size.x, r.size.y)), Color("#c9a77c") if kind == "desk" else Color("#d9d2c4"))
			ci.draw_rect(Rect2(r.position + Vector2(0, -24), Vector2(r.size.x, r.size.y)), line, false, 2.0)
			ci.draw_rect(Rect2(r.position + Vector2(4, r.size.y - 24), Vector2(6, 24)), Color("#7d6a52"))
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 10, r.size.y - 24), Vector2(6, 24)), Color("#7d6a52"))
		"cabinet", "locker", "shelf":
			var h := 90.0 if kind != "shelf" else 110.0
			var col := Color("#b8bdb6") if kind == "cabinet" else (Color("#8fa0a6") if kind == "locker" else Color("#a7926f"))
			ci.draw_rect(Rect2(r.position + Vector2(0, -h), Vector2(r.size.x, r.size.y + h)), col)
			ci.draw_rect(Rect2(r.position + Vector2(0, -h), Vector2(r.size.x, r.size.y + h)), line, false, 2.0)
			if kind == "locker":
				for k in int(r.size.x / 40.0):
					ci.draw_line(r.position + Vector2(k * 40, -h), r.position + Vector2(k * 40, r.size.y), line, 2.0)
			else:
				for k in 3:
					ci.draw_line(r.position + Vector2(0, -h + 30 + k * 30), r.position + Vector2(r.size.x, -h + 30 + k * 30), line, 1.5)
		"chair":
			ci.draw_rect(Rect2(r.position + Vector2(0, -30), Vector2(r.size.x, 14)), Color("#9fb3ba"))
			ci.draw_rect(Rect2(r.position + Vector2(0, -16), r.size), Color("#b9c9ce"))
		"plant":
			ci.draw_circle(r.get_center() + Vector2(0, -30), r.size.x * 0.6, Color("#7f9c86"))
			ci.draw_rect(Rect2(r.position + Vector2(r.size.x * 0.25, -6), Vector2(r.size.x * 0.5, r.size.y + 6)), Color("#b08d6e"))
		"machine":
			ci.draw_rect(Rect2(r.position + Vector2(0, -60), Vector2(r.size.x, r.size.y + 60)), Color("#c4ccd0"))
			ci.draw_rect(Rect2(r.position + Vector2(8, -50), Vector2(r.size.x - 16, 30)), Color("#1c2622"))
			ci.draw_line(r.position + Vector2(12, -36), r.position + Vector2(r.size.x - 12, -36), Color("#7cc39a"), 2.0)
		"window":
			ci.draw_rect(r, Color("#cfe0e6"))
			ci.draw_rect(r, line, false, 4.0)
		"rug":
			ci.draw_rect(r, Color(1, 0.85, 0.9, 0.5))
		"blackboard":
			ci.draw_rect(r, Color("#3f5446"))
			ci.draw_rect(r, Color("#8f7d64"), false, 5.0)
		"sink":
			ci.draw_rect(Rect2(r.position + Vector2(0, -20), Vector2(r.size.x, r.size.y + 20)), Color("#f2f4f4"))
			ci.draw_rect(Rect2(r.position + Vector2(0, -20), Vector2(r.size.x, r.size.y + 20)), line, false, 2.0)
		"crate", "box":
			ci.draw_rect(Rect2(r.position + Vector2(0, -26), Vector2(r.size.x, r.size.y + 26)), Color("#b39b78"))
			ci.draw_rect(Rect2(r.position + Vector2(0, -26), Vector2(r.size.x, r.size.y + 26)), Color("#7d6a52"), false, 2.0)
		"pillar":
			ci.draw_rect(Rect2(r.position + Vector2(0, -120), Vector2(r.size.x, r.size.y + 120)), Color(th.wall))
			ci.draw_rect(Rect2(r.position + Vector2(0, -120), Vector2(r.size.x, r.size.y + 120)), line, false, 2.0)
		_:
			ci.draw_rect(Rect2(r.position + Vector2(0, -20), Vector2(r.size.x, r.size.y + 20)), Color(th.top))
			ci.draw_rect(Rect2(r.position + Vector2(0, -20), Vector2(r.size.x, r.size.y + 20)), line, false, 2.0)
	if label != "":
		ci.draw_string(GameState.font, r.position + Vector2(0, -30 if kind in ["bed", "desk", "table", "crate", "box", "sink"] else 14), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(th.line).darkened(0.35))
