class_name UiSkin
extends RefCounted
## 布料風格的 UI 素材（art/ui_*.png）做成 StyleBox，給對話框、選項、日記、按鈕共用。


static func tex(name: String, l: float, t: float, r: float, b: float, content := Vector4(-1, -1, -1, -1)) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://art/%s.png" % name)
	sb.texture_margin_left = l
	sb.texture_margin_top = t
	sb.texture_margin_right = r
	sb.texture_margin_bottom = b
	if content.x >= 0:
		sb.content_margin_left = content.x
		sb.content_margin_top = content.y
		sb.content_margin_right = content.z
		sb.content_margin_bottom = content.w
	return sb


## 選項／按鈕：綠色布條，選到時變成黃色
static func button(b: Button, font_size := 22) -> void:
	var normal := tex("ui_choice", 34, 0, 34, 0, Vector4(44, 10, 44, 12))
	var focus := tex("ui_choice_focus", 34, 0, 34, 0, Vector4(44, 10, 44, 12))
	var off := tex("ui_choice_off", 34, 0, 34, 0, Vector4(44, 10, 44, 12))
	off.modulate_color = Color(1, 1, 1, 0.65)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("pressed", focus)
	b.add_theme_stylebox_override("hover", focus)
	b.add_theme_stylebox_override("focus", focus)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size.y = 60
	b.add_theme_color_override("font_color", Color("#33301f"))
	b.add_theme_color_override("font_hover_color", Color("#5a2f1c"))
	b.add_theme_color_override("font_focus_color", Color("#5a2f1c"))
	b.add_theme_color_override("font_pressed_color", Color("#5a2f1c"))
	b.add_theme_color_override("font_disabled_color", Color("#d9d4c4"))
