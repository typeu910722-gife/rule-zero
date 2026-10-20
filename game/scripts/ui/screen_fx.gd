class_name ScreenFx
extends Node
## 全螢幕效果（由 Dialogue 建立，用 Dialogue.fx 取用）
##   scare()        驚悚台詞：畫面閃一下、色偏、橫向錯位（約 0.3 秒）＋低沉的一聲
##   vignette = 0~1 畫面四周變暗（森林越深越暗）

const SCARE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float seed = 0.0;
float h(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 uv = SCREEN_UV;
	float row = floor(uv.y * 26.0);
	float band = step(0.72, h(row + seed * 17.0));
	uv.x += band * (h(row * 3.1 + seed) - 0.5) * 0.07 * amount;
	float o = 0.014 * amount;
	vec3 c = vec3(texture(screen_tex, uv + vec2(o, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(o, 0.0)).b);
	float gray = dot(c, vec3(0.3, 0.59, 0.11));
	c = mix(c, vec3(gray) * vec3(1.15, 0.78, 0.82), amount * 0.55);
	c += vec3(0.3) * amount * step(0.55, h(seed * 7.3));
	COLOR = vec4(c, 1.0);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
uniform vec3 tint = vec3(0.08, 0.06, 0.12);
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(0.3, 0.95, length(p));
	COLOR = vec4(tint, v * strength);
}
"""

var vignette := 0.0:
	set(v):
		vignette = clampf(v, 0.0, 1.0)
		if _vig:
			_vig_mat.set_shader_parameter("strength", vignette * 0.85)
			_vig.visible = vignette > 0.01

var _scare: ColorRect
var _scare_mat: ShaderMaterial
var _vig: ColorRect
var _vig_mat: ShaderMaterial
var _t := 0.0
const SCARE_TIME := 0.34


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 暗角在 HUD 下面（不會蓋住文字）
	var low := CanvasLayer.new()
	low.layer = 5
	add_child(low)
	_vig = ColorRect.new()
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vig_mat = ShaderMaterial.new()
	_vig_mat.shader = Shader.new()
	_vig_mat.shader.code = VIGNETTE_SHADER
	_vig.material = _vig_mat
	_vig.visible = false
	low.add_child(_vig)
	# 驚悚效果蓋在對話框上面（連字都會抖一下）
	var high := CanvasLayer.new()
	high.layer = 52
	add_child(high)
	_scare = ColorRect.new()
	_scare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scare.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scare_mat = ShaderMaterial.new()
	_scare_mat.shader = Shader.new()
	_scare_mat.shader.code = SCARE_SHADER
	_scare.material = _scare_mat
	_scare.visible = false
	high.add_child(_scare)


func scare() -> void:
	if GameState.gentle():
		return  # 減少驚嚇：不閃屏、不放尖銳的音效
	Sound.sfx("creepy")
	if GameState.fast:
		return
	_t = SCARE_TIME
	_scare.visible = true


func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t -= delta
	if _t <= 0.0:
		_scare.visible = false
		return
	# 一開始最強，中間再抽一下
	var k := _t / SCARE_TIME
	var amount := k * (0.7 + 0.3 * sin(k * 40.0))
	_scare_mat.set_shader_parameter("amount", amount)
	_scare_mat.set_shader_parameter("seed", floor(Time.get_ticks_msec() / 45.0))
