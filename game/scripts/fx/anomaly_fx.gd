class_name AnomalyFX
extends ColorRect
## 恐怖畫面效果：放在對話層裡、背景之上、對話框之下（場景、小遊戲、夢境背景都會被影響，字幕不會）。
## 對話腳本用 @fx 控制（docs/dialogue-format.md）：
##   @fx dream          夢境：褪色、紙張色、顆粒、暗角（@bg dream 會自動套用，離開夢境自動關掉）
##   @fx mirror         鏡子：一點點顆粒與暗角
##   @fx glitch 0.5     短暫的色差＋畫面錯位（秒數可省略）
##   @fx flash 文字      文字在畫面中央閃一下
##   @fx off            全部關掉
## GDD 5.5：異常不配提示音、不解釋，所以這裡只有畫面。

const PRESETS := {
	"off": {"desaturate": 0.0, "grain": 0.0, "vignette": 0.0, "paper_mix": 0.0},
	"dream": {"desaturate": 0.75, "grain": 0.16, "vignette": 0.45, "paper_mix": 0.6},
	"mirror": {"desaturate": 0.15, "grain": 0.1, "vignette": 0.35, "paper_mix": 0.0},
}

var preset := "off"
var _base := {}
var _glitch := 0.0
var _flash: Label
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/anomaly.gdshader")
	material = mat
	_flash = Label.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash.add_theme_font_size_override("font_size", 120)
	_flash.add_theme_color_override("font_color", Color(0.12, 0.08, 0.1, 0.0))
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	set_preset("off")


## 依對話腳本的 @fx 參數執行
func command(args: Array) -> void:
	if args.is_empty():
		return
	match args[0]:
		"glitch":
			glitch(float(args[1]) if args.size() > 1 else 0.5, 0.7)
		"flash":
			flash(" ".join(args.slice(1)))
		_:
			set_preset(args[0])


## 全部關掉（含正在退的錯位）
func clear() -> void:
	if _tween:
		_tween.kill()
	_glitch = 0.0
	set_preset("off")


func set_preset(name: String) -> void:
	if not PRESETS.has(name):
		push_warning("未知的畫面效果：%s" % name)
		return
	preset = name
	_base = PRESETS[name]
	for k in _base:
		material.set_shader_parameter(k, _base[k])
	_refresh()


## 短暫的色差與錯位，慢慢退掉
func glitch(seconds := 0.5, strength := 1.0) -> void:
	if GameState.fast:
		return
	if _tween:
		_tween.kill()
	_glitch = strength
	_refresh()
	_tween = create_tween()
	_tween.tween_method(_set_glitch, strength, 0.0, maxf(seconds, 0.05)).set_ease(Tween.EASE_IN)


func flash(text: String, seconds := 0.18) -> void:
	if GameState.fast or text == "":
		return
	_flash.text = text
	visible = true
	var t := create_tween()
	t.tween_property(_flash, "theme_override_colors/font_color:a", 0.55, 0.03)
	t.tween_property(_flash, "theme_override_colors/font_color:a", 0.0, seconds)
	t.tween_callback(_refresh)


func is_active() -> bool:
	return visible


func _set_glitch(v: float) -> void:
	_glitch = v
	_refresh()


func _refresh() -> void:
	material.set_shader_parameter("aberration", _glitch)
	material.set_shader_parameter("jitter", _glitch)
	# 全部是 0 的時候整個關掉：手機上不用每一格都多讀一次畫面
	var flashing: bool = _flash.get_theme_color("font_color").a > 0.001
	visible = preset != "off" or _glitch > 0.001 or flashing
