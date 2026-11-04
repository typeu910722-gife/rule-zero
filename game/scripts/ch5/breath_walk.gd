extends Ch3Mini
## 第五章 終章 A「醒來」：第一次用人類的身體走路。
## 按住＝往前走（很慢）；走的時候「呼吸」會越來越急，滿了就喘不過氣、跌坐下來（要等它降回來）。
## 放開＝停下來深呼吸。走到走廊盡頭就結束。回傳：喘不過氣的次數。

const LENGTH := 1.0
var pos := 0.0           # 0..1
var breath := 0.0        # 0..1
var down_t := 0.0        # 跌坐的時間
var falls := 0


func _setup() -> void:
	title = "呼吸"
	hint = "按住：往前走　放開：停下來呼吸（喘不過氣就會跌坐下來）"
	bg_color = Color("#eef0ee")
	fast_result = 0


func _tick(delta: float) -> void:
	if down_t > 0.0:
		down_t -= delta
		breath = maxf(0.0, breath - delta * 0.35)
		return
	if held:
		pos = minf(LENGTH, pos + delta * 0.055)
		breath = minf(1.0, breath + delta * (0.16 + pos * 0.08))
		if breath >= 1.0:
			falls += 1
			down_t = 2.2
			sfx("res://audio/ch4/breath.ogg", -4.0)
	else:
		breath = maxf(0.0, breath - delta * 0.3)
	if pos >= LENGTH:
		finish(falls)


func _paint(c: Control) -> void:
	var f: Font = GameState.font
	var sit := down_t > 0.0
	var bg := art4("bg_hospital_side")
	var me_tex := _haruka_frame(sit)
	if bg != null and me_tex != null:
		# 真的醫院的走廊（側面）：走的時候背景慢慢往左移，盡頭的窗戶很亮
		c.draw_texture_rect(bg, Rect2(-pos * 320.0, -40, 1600, 900), false)
		var feet := Vector2(240 + pos * 760, 660)
		# 追逐戰的全身圖：512 格、腳底在 488；人大約 300 高
		Ch3Mini.draw_art_h(c, me_tex, feet + Vector2(0, 16), 350)
	else:
		# 醫院的走廊（真的醫院：普通、有一點舊）
		c.draw_rect(Rect2(0, 120, 1280, 380), Color("#e3e6e2"))
		c.draw_rect(Rect2(0, 500, 1280, 120), Color("#cfd3cd"))
		for k in 6:
			var x := 60.0 + k * 210.0 - pos * 300.0
			c.draw_rect(Rect2(x, 220, 110, 230), Color("#d2d6d1"))
			c.draw_rect(Rect2(x, 220, 110, 230), Color("#b1b7b0"), false, 3.0)
		# 遙：一個很瘦的人影，扶著牆
		var me := Vector2(240 + pos * 760, 500)
		var h := 120.0 if sit else 190.0
		c.draw_rect(Rect2(me + Vector2(-22, -h), Vector2(44, h)), Color("#7d8a8e"))
		c.draw_circle(me + Vector2(0, -h - 24), 24, Color("#7d8a8e"))
	# 呼吸
	var bar := Rect2(440, 112, 400, 20) if bg != null else Rect2(440, 590, 400, 20)
	c.draw_rect(bar, Color(0, 0, 0, 0.08))
	c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * breath, bar.size.y)), RED if breath > 0.75 else SOFT)
	c.draw_string(f, Vector2(0, bar.position.y - 10), "……喘不過氣。" if sit else ("呼吸" if breath < 0.75 else "呼吸——停下來"), HORIZONTAL_ALIGNMENT_CENTER, 1280, 20, INK)
	# 外面那片很亮的光（走廊盡頭）
	c.draw_rect(Rect2(1180, 160, 100, 340) if bg == null else Rect2(1220, 0, 60, 720), Color(1, 1, 0.92, 0.9 if bg == null else 0.35 + pos * 0.5))
	if breath > 0.6 and not GameState.gentle():
		c.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, (breath - 0.6) * 0.5))


## 遙（病人服）的全身圖：坐下＝喘氣、按住往前＝走路的格子（慢）、停下＝站著
func _haruka_frame(sit: bool) -> Texture2D:
	var pose := "idle"
	if sit or breath > 0.75:
		pose = "breath"
	elif held:
		pose = "run_%02d" % (int(t * 5.0) % 8)
	var p := "res://art/human/chase/h_haruka_chase_gown_%s.png" % pose
	return Ch3Mini.art("h_haruka_chase_gown_" + pose, "res://art/human/chase/") if ResourceLoader.exists(p) else null
