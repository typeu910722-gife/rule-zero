shader_type canvas_item;
// 異常效果（GDD 5.5：不明顯的驚悚）：褪色、顆粒、暗角、色差、橫向錯位。
// 全部參數為 0 時畫面不變；由 scripts/fx/anomaly_fx.gd 控制。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 1.0) = 0.0;
uniform float jitter : hint_range(0.0, 1.0) = 0.0;
uniform vec3 paper = vec3(0.86, 0.84, 0.80);
uniform float paper_mix : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// 橫向錯位：隨機幾條水平帶往旁邊偏一點
	if (jitter > 0.0) {
		float band = floor(uv.y * 48.0);
		float t = floor(TIME * 18.0);
		float r = hash(vec2(band, t));
		if (r > 1.0 - jitter * 0.35) {
			uv.x += (hash(vec2(t, band)) - 0.5) * 0.06 * jitter;
		}
	}
	vec3 col;
	if (aberration > 0.0) {
		vec2 off = vec2(0.006 * aberration, 0.0);
		col = vec3(textureLod(screen_tex, uv + off, 0.0).r, textureLod(screen_tex, uv, 0.0).g, textureLod(screen_tex, uv - off, 0.0).b);
	} else {
		col = textureLod(screen_tex, uv, 0.0).rgb;
	}
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), desaturate);
	col = mix(col, col * paper * 1.12, paper_mix);
	if (grain > 0.0) {
		float n = hash(uv * vec2(1280.0, 720.0) + fract(TIME) * 91.7) - 0.5;
		col += n * grain * 0.35;
	}
	if (vignette > 0.0) {
		vec2 d = SCREEN_UV - 0.5;
		col *= 1.0 - vignette * smoothstep(0.25, 0.75, length(d * vec2(1.25, 1.0)));
	}
	COLOR = vec4(col, 1.0);
}
