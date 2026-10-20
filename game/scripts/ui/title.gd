extends CanvasLayer
## 標題畫面。會依跨周目記錄（GameState.meta）悄悄改變：
##   第一章通關前：繼續／新遊戲／解開的謎團／蒐藏過的東西
##   第一章通關後：繼續／選擇篇章／蒐集過的東西
## 月台上的小布（遙）會隨著記憶越深、越接近真相，變得越來越沉重：
## 天空褪色、變冷、變暗，只剩他身上還有一點光；棉花像雪一樣落下來；
## 拿回名字以後，小布抱著拆下來的「小布」名牌。

signal new_game
signal continue_game
signal chapter2

const LOGO_TEX := "res://art/branding/logo.png"
var _logo_tex: Texture2D

const BG := preload("res://art/title_platform.jpg")
## 月台上的小布：期待 → 疑惑 → 沉重 → 記起自己（抱著拆下來的名牌）
const BU_POSES := [preload("res://art/title_bu_1.png"), preload("res://art/title_bu_2.png"),
	preload("res://art/title_bu_3.png"), preload("res://art/title_bu_4.png")]
const BU_RECT := Rect2(723, 291, 366, 366)
const TICKET := preload("res://art/item_ticket.png")
const TICKET_STAMPED := preload("res://art/item_ticket_stamped.png")
const SUBTITLES := [
	"一個溫柔的世界，藏著被遺忘的規則。",
	"……好像，來過這裡。",
	"……記得接下來的每一句話。",
	"……記得大家的臉。",
	"……記得自己。",
	"……名字的地方，還空著。",
]
const SHADER := """
shader_type canvas_item;
uniform float heavy : hint_range(0.0, 1.0) = 0.0;
uniform vec2 focus = vec2(0.708, 0.72);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c.rgb, vec3(l), heavy * 0.78);
	g *= mix(vec3(1.0), vec3(0.70, 0.76, 0.95), heavy);
	float d = distance(UV * vec2(1.78, 1.0), focus * vec2(1.78, 1.0));
	float spot = smoothstep(0.5, 0.1, d);
	g *= mix(1.0, mix(0.32, 0.92, spot), heavy);
	COLOR = vec4(g, c.a);
}
"""

var _area: Control
var _bu: TextureRect
var _bg: TextureRect
var _heavy := 0
var _flakes: Array = []
var _t := 0.0
var _menu: VBoxContainer
var _panel: PanelContainer
var _panel_text: RichTextLabel
var _panel_tabs: HBoxContainer
var _panel_chapters: VBoxContainer
var _return_focus: Control
var _tab := "mystery"


func _ready() -> void:
	layer = 70
	_heavy = GameState.heaviness()
	Sound.set_wear(_heavy)
	Sound.bgm("memory")
	# 主旋律：標題出現一下下之後，音樂盒小小聲地彈一次
	get_tree().create_timer(1.6).timeout.connect(func(): Motif.play(self, "musicbox", -12.0))
	_bg = TextureRect.new()
	_bg.texture = BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("heavy", _heavy / 5.0)
	_bg.material = mat
	add_child(_bg)
	_bu = TextureRect.new()
	_bu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bu.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bu.texture = BU_POSES[bu_pose()]
	_bu.position = BU_RECT.position
	_bu.size = BU_RECT.size
	_bu.pivot_offset = Vector2(BU_RECT.size.x / 2, BU_RECT.size.y * 0.9)
	_bu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 他身上一直留著一點光，只是越來越冷
	_bu.modulate = Color(1, 1, 1).lerp(Color(0.8, 0.8, 0.9), _heavy / 5.0 * 0.7)
	add_child(_bu)
	_area = Control.new()
	_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.draw.connect(_draw_area)
	add_child(_area)
	for i in _heavy * 14:
		_flakes.append(_new_flake(true))

	_menu = VBoxContainer.new()
	_menu.position = Vector2(120, 370)
	_menu.custom_minimum_size = Vector2(320, 0)
	_menu.add_theme_constant_override("separation", 10)
	add_child(_menu)
	var cleared := GameState.chapter1_cleared()
	var cont := _button("繼續", func(): continue_game.emit())
	cont.disabled = not GameState.has_save()
	_menu.add_child(cont)
	if cleared:
		_menu.add_child(_button("選擇篇章", func(): _open_chapters()))
		_menu.add_child(_button("蒐集過的東西", func(): _open_panel("mystery")))
	else:
		_menu.add_child(_button("新遊戲", func(): new_game.emit()))
		_menu.add_child(_button("解開的謎團", func(): _open_panel("mystery")))
		_menu.add_child(_button("蒐藏過的東西", func(): _open_panel("items")))
	if not OS.has_feature("web"):
		_menu.add_child(_button("離開", func(): get_tree().quit()))
	(cont if not cont.disabled else _menu.get_child(1)).grab_focus.call_deferred()
	_build_panel()


## 小布的姿態：還沒想起來（期待）→ 開始懷疑 → 沉重 → 拿回名字（抱著名牌）
func bu_pose() -> int:
	if GameState.ever("true_name"):
		return 3
	if _heavy == 0:
		return 0
	return 1 if _heavy <= 2 else 2


func _button(text: String, cb: Callable, size := 24) -> Button:
	var b := Button.new()
	b.text = text
	UiSkin.button(b, size)
	b.pressed.connect(func():
		Sound.sfx("choice")
		cb.call())
	return b


func _new_flake(anywhere := false) -> Dictionary:
	return {"p": Vector2(randf_range(0, 1280), randf_range(-40, 720) if anywhere else -20.0),
		"v": randf_range(14, 34), "r": randf_range(2.0, 5.5), "ph": randf() * TAU, "a": randf_range(0.35, 0.8)}


func _process(delta: float) -> void:
	_t += delta
	# 呼吸：越沉重，越慢、越淺
	var breath := sin(_t * (1.6 - _heavy * 0.18)) * (0.012 - _heavy * 0.0016)
	_bu.scale = Vector2(1.0 - breath * 0.4, 1.0 + breath)
	for f in _flakes:
		f.p.y += f.v * delta
		f.p.x += sin(_t * 0.7 + f.ph) * 10.0 * delta
		if f.p.y > 740:
			var n := _new_flake()
			f.p = n.p
	_area.queue_redraw()


func _draw_area() -> void:
	var f: Font = GameState.font
	var h := _heavy / 5.0
	# 落下來的棉花（越重越多）
	for fl in _flakes:
		_area.draw_circle(fl.p, fl.r, Color(0.95, 0.93, 0.95, fl.a * (0.5 + 0.5 * h)))
	# 左邊淡淡的一層，讓標題字看得清楚（越重越暗）
	var veil := Color(1, 0.95, 0.96).lerp(Color(0.16, 0.13, 0.18), h)
	for k in 40:
		_area.draw_rect(Rect2(k * 14, 0, 14, 720), Color(veil.r, veil.g, veil.b, 0.8 * (1.0 - k / 40.0)))
	var halo := Color(1, 0.97, 0.97, 0.75 * (1.0 - h))
	# 正式 Logo（docs/marketing/logo_rule_zero.png）；越重越黯淡。缺檔時退回文字標題
	if ResourceLoader.exists(LOGO_TEX):
		if _logo_tex == null:
			_logo_tex = load(LOGO_TEX)
		_area.draw_texture_rect(_logo_tex, Rect2(100, 4, 310, 310), false, Color(1, 1, 1).lerp(Color(0.78, 0.74, 0.82), h))
	else:
		var ink := Color("#6d4c5c").lerp(Color("#e9dde6"), h)
		_area.draw_string_outline(f, Vector2(110, 200), "第零條規則", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, 10, Color(1, 0.97, 0.97, 0.9 * (1.0 - h)))
		_area.draw_string(f, Vector2(110, 200), "第零條規則", HORIZONTAL_ALIGNMENT_LEFT, -1, 84, ink)
		_area.draw_string_outline(f, Vector2(116, 258), "Rule Zero", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, halo)
		_area.draw_string(f, Vector2(116, 258), "Rule Zero", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("#b56576").lerp(Color("#c9a3b8"), h))
	var sub: String = SUBTITLES[_heavy]
	if _heavy >= 5 and GameState.ever("true_name"):
		sub = "我叫遙。"
	_area.draw_string_outline(f, Vector2(116, 344), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, halo)
	_area.draw_string(f, Vector2(116, 344), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#8e6f7e").lerp(Color("#d8c6d2"), h))

	# 車票：結束過一輪以上，背面就蓋著戳章
	var stamps := clampi(GameState.loop_number() - GameState.FIRST_LOOP, 0, 15)
	var tk: Texture2D = TICKET_STAMPED if stamps > 0 else TICKET
	var ticket := Rect2(560, 560, 240, 240.0 * tk.get_height() / tk.get_width())
	_area.draw_set_transform(ticket.get_center(), -0.08, Vector2.ONE)
	_area.draw_texture_rect(tk, Rect2(-ticket.size / 2, ticket.size), false, Color(1, 1, 1).lerp(Color(0.7, 0.72, 0.8), h))
	_area.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if GameState.is_repeat():
		_area.draw_string_outline(f, Vector2(0, 700), "歡迎回來。", HORIZONTAL_ALIGNMENT_RIGHT, 1250, 18, 5, Color(0, 0, 0, 0.35))
		_area.draw_string(f, Vector2(0, 700), "歡迎回來。", HORIZONTAL_ALIGNMENT_RIGHT, 1250, 18, Color("#fbe7ee"))


# ───────── 蒐集／謎團／結局 面板 ─────────

func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(470, 40)
	_panel.custom_minimum_size = Vector2(770, 640)
	_panel.add_theme_stylebox_override("panel", UiSkin.tex("ui_diary", 100, 100, 100, 100, Vector4(92, 64, 84, 56)))
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_panel_tabs = HBoxContainer.new()
	_panel_tabs.add_theme_constant_override("separation", 8)
	v.add_child(_panel_tabs)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(36, 0)
	_panel_tabs.add_child(pad)
	for pair in [["mystery", "謎團"], ["items", "東西"], ["endings", "結局"]]:
		var id: String = pair[0]
		var b := _button(pair[1], func(): _show_tab(id), 18)
		b.custom_minimum_size = Vector2(120, 46)
		_panel_tabs.add_child(b)
	_panel_text = RichTextLabel.new()
	_panel_text.bbcode_enabled = true
	_panel_text.fit_content = false
	_panel_text.scroll_active = true
	_panel_text.custom_minimum_size = Vector2(560, 400)
	_panel_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_text.add_theme_color_override("default_color", Color("#4a3b47"))
	_panel_text.focus_mode = Control.FOCUS_ALL
	v.add_child(_panel_text)
	_panel_chapters = VBoxContainer.new()
	_panel_chapters.add_theme_constant_override("separation", 10)
	_panel_chapters.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_panel_chapters)
	var close := _button("關閉", func(): _close_panel(), 18)
	close.custom_minimum_size.y = 46
	v.add_child(close)


func _open_panel(tab: String) -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	_panel.visible = true
	_menu.visible = false
	_panel_tabs.visible = true
	_panel_text.visible = true
	_panel_chapters.visible = false
	_show_tab(tab)


func _close_panel() -> void:
	_panel.visible = false
	_menu.visible = true
	if is_instance_valid(_return_focus):
		_return_focus.grab_focus.call_deferred()


func _show_tab(tab: String) -> void:
	_tab = tab
	for i in 3:
		var b: Button = _panel_tabs.get_child(i + 1)
		b.modulate = Color(1, 1, 1) if ["mystery", "items", "endings"][i] == tab else Color(1, 1, 1, 0.55)
	match tab:
		"mystery": _panel_text.text = mystery_text()
		"items": _panel_text.text = items_text()
		"endings": _panel_text.text = endings_text()
	_panel_text.scroll_to_line(0)
	_panel_tabs.get_child(["mystery", "items", "endings"].find(tab) + 1).grab_focus.call_deferred()


static func mystery_text() -> String:
	var solved: Array = GameState.MYSTERIES.filter(func(m): return GameState.ever(m.key))
	var t := "[font_size=26]解開的謎團　%d / %d[/font_size]\n\n" % [solved.size(), GameState.MYSTERIES.size()]
	for m in GameState.MYSTERIES:
		if GameState.ever(m.key):
			t += "[color=#7b4fa0]◆ %s[/color]\n[color=#5d4a58]　　%s[/color]\n\n" % [m.q, m.a]
		else:
			t += "[color=#a99aa6]◇ %s\n　　？？？[/color]\n\n" % m.q
	return t


static func items_text() -> String:
	var got: Array = GameState.COLLECTIBLES.keys().filter(func(k): return GameState.has_collected(k))
	var t := "[font_size=26]蒐藏過的東西　%d / %d[/font_size]\n\n" % [got.size(), GameState.COLLECTIBLES.size()]
	for k in GameState.COLLECTIBLES:
		t += ("・%s\n" % GameState.COLLECTIBLES[k]) if k in got else "[color=#a99aa6]・？？？[/color]\n"
	var tufts: Array = GameState.ever_tufts()
	t += "\n[font_size=22][color=#c2558a]記憶碎片　%d / %d[/color][/font_size]\n" % [tufts.size(), GameState.TUFT_TEXT.size()]
	for k in GameState.TUFT_TEXT:
		t += ("[color=#c2558a]・%s[/color]\n" % GameState.TUFT_TEXT[k]) if k in tufts else "[color=#a99aa6]・……[/color]\n"
	var pages: Array = GameState.STORY_TEXT.keys().filter(func(k): return GameState.ever(k))
	t += "\n[font_size=22][color=#3f6f8f]想起來的事　%d / %d[/color][/font_size]\n" % [pages.size(), GameState.STORY_TEXT.size()]
	for k in GameState.STORY_TEXT:
		t += ("[color=#3f6f8f]・%s[/color]\n" % GameState.STORY_TEXT[k]) if k in pages else "[color=#a99aa6]・……[/color]\n"
	var stamps := maxi(GameState.loop_number() - GameState.FIRST_LOOP, 0)
	t += "\n車票上的戳章　%s\n" % ("數不清" if stamps >= 10 else "%d 個" % stamps)
	return t


static func endings_text() -> String:
	var seen: Array = GameState.meta.get("endings", [])
	var t := "[font_size=26]看過的結局　%d / %d[/font_size]\n\n" % [GameState.ENDING_ORDER.filter(func(e): return e in seen).size(), GameState.ENDING_ORDER.size()]
	for e in GameState.ENDING_ORDER:
		var info: Dictionary = GameState.ENDINGS[e]
		if e in seen:
			t += "[color=#7b4fa0]◆ %s[/color]\n[color=#5d4a58]　　%s[/color]\n\n" % [info.title, info.desc]
		else:
			t += "[color=#a99aa6]◇ ？？？\n　　%s[/color]\n\n" % GameState.ENDING_HINTS.get(e, "")
	return t


# ───────── 選擇篇章 ─────────

const CHAPTERS := [
	["第一章　歡迎回來", "從還沒開始輪迴的第一天，重新開始。看過的結局和蒐藏會留著。"],
	["第二章　漂白鎮", "「壞孩子」被送去的鎮。從灰色的車廂開始。"],
	["第三章", "製作中。"],
	["第四章", "製作中。"],
	["第五章", "製作中。"],
	["第六章", "製作中。"],
]


func _open_chapters() -> void:
	_return_focus = get_viewport().gui_get_focus_owner()
	_panel.visible = true
	_menu.visible = false
	_panel_tabs.visible = false
	_panel_text.visible = false
	_panel_chapters.visible = true
	for c in _panel_chapters.get_children():
		c.queue_free()
	var done := int(GameState.meta.get("chapters_done", 0))
	var first: Button = null
	# 只顯示玩過的章節＋下一章（還沒玩到的章節不出現）
	for i in mini(done + 1, CHAPTERS.size()):
		var label: String = CHAPTERS[i][0]
		if i < done:
			label += "　✓"
		var idx := i
		var b := _button("%s\n%s" % [label, CHAPTERS[i][1]], func():
			if idx == 1:
				chapter2.emit()
				return
			# 第一章：從還沒開始輪迴的第一天、空白的紀錄開始（看過的結局和蒐藏會留著）
			GameState.restart_chapter1()
			new_game.emit(), 18)
		b.custom_minimum_size = Vector2(560, 70)
		b.disabled = i > 1
		_panel_chapters.add_child(b)
		if first == null:
			first = b
	first.grab_focus.call_deferred()


## E（互動鍵）也可以按下目前選中的按鈕；Esc／Tab 關閉面板
func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and (event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_close_panel()
		return
	if event.is_action_pressed("interact") and not event.is_action_pressed("ui_accept"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and not (f as Button).disabled:
			get_viewport().set_input_as_handled()
			(f as Button).pressed.emit()
