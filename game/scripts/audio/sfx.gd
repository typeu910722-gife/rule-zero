class_name Sfx
extends RefCounted
## 第二章外包音效（game/audio/ch2/se）。同一個音效有 _01～_03 三個變化版，隨機挑一個播放。
## 沒有素材時安靜地略過（第一章、測試環境）。

const DIR := "res://audio/ch2/se/"
const FILES := {
	"text": "ch2_se01_text_%02d.ogg",
	"confirm": "ch2_se02_confirm_%02d.ogg",
	"cursor": "ch2_se02_cursor_%02d.ogg",
	"conduct_down": "ch2_se03_conduct_down_%02d.ogg",
	"conduct_up": "ch2_se03_conduct_up_%02d.ogg",
	"rule_break": "ch2_se04_rule_break_%02d.ogg",
	"paper": "ch2_se05_paper_%02d.ogg",
	"save": "ch2_se06_save_%02d.ogg",
	"title_card": "ch2_se07_title_card_%02d.ogg",
	"ambience": "ch2_se10_ambience_%02d.ogg",
	"fence_hum": "ch2_se11_fence_hum_%02d.ogg",
	"fence_off": "ch2_se11_fence_off_%02d.ogg",
	"river": "ch2_se12_river_%02d.ogg",
	"chime": "ch2_se13_chime_%02d.ogg",
	"broadcast": "ch2_se14_broadcast_%02d.ogg",
	"negative_hum": "ch2_se15_negative_hum_%02d.ogg",
	"monitor_beat": "ch2_se16_monitor_beat_%02d.ogg",
	"monitor_flat": "ch2_se16_monitor_flat_%02d.ogg",
	"whistle_long": "ch2_se20_whistle_long_%02d.ogg",
	"whistle_short": "ch2_se20_whistle_short_%02d.ogg",
	"dove_crouch": "ch2_se21_dove_crouch_%02d.ogg",
	"dove_step": "ch2_se21_dove_step_%02d.ogg",
	"dove_clap": "ch2_se22_dove_clap_%02d.ogg",
	"mask_crack": "ch2_se23_mask_crack_%02d.ogg",
	"projector": "ch2_se24_projector_%02d.ogg",
	"shutter": "ch2_se24_shutter_%02d.ogg",
	"fold": "ch2_se25_fold_%02d.ogg",
	"broom_snap": "ch2_se26_broom_snap_%02d.ogg",
	"knock": "ch2_se27_knock_%02d.ogg",
	"bird_eye": "ch2_se28_bird_eye_%02d.ogg",
	"bird_peck": "ch2_se28_bird_peck_%02d.ogg",
	"drag": "ch2_se29_drag_%02d.ogg",
	"train_arrive": "ch2_se30_train_arrive_%02d.ogg",
	"train_door": "ch2_se30_train_door_%02d.ogg",
	"train_run": "ch2_se30_train_run_%02d.ogg",
	"train_whistle": "ch2_se30_train_whistle_%02d.ogg",
	"rail_switch": "ch2_se31_rail_switch_%02d.ogg",
	"shock_long": "ch2_se40_shock_long_%02d.ogg",
	"shock_medium": "ch2_se40_shock_medium_%02d.ogg",
	"shock_short": "ch2_se40_shock_short_%02d.ogg",
	"meter_max": "ch2_se41_meter_max_%02d.ogg",
	"hold_buzz": "ch2_se42_hold_buzz_%02d.ogg",
	"brush": "ch2_se43_brush_%02d.ogg",
	"bubble": "ch2_se43_bubble_%02d.ogg",
	"seam_rip": "ch2_se44_seam_rip_%02d.ogg",
	"found": "ch2_se45_found_%02d.ogg",
	"wrong": "ch2_se45_wrong_%02d.ogg",
	"card_flip": "ch2_se46_card_flip_%02d.ogg",
	"chant": "ch2_se46_chant_%02d.ogg",
	"snip": "ch2_se47_snip_%02d.ogg",
	"snip_flesh": "ch2_se47_snip_flesh_%02d.ogg",
	"wind": "ch2_se48_wind_%02d.ogg",
	"wind_stop": "ch2_se48_wind_stop_%02d.ogg",
	"chair_drag": "ch2_se49_chair_drag_%02d.ogg",
	"chair_sit": "ch2_se49_chair_sit_%02d.ogg",
	"sew": "ch2_se50_sew_%02d.ogg",
	"stuff_in": "ch2_se50_stuff_in_%02d.ogg",
	"stuff_out": "ch2_se50_stuff_out_%02d.ogg",
	"unstitch": "ch2_se50_unstitch_%02d.ogg",
	"stitch_tick": "ch2_se51_stitch_tick_%02d.ogg",
	"memory_snip": "ch2_se52_memory_snip_%02d.ogg",
}
static var _cache := {}


static func stream(name: String) -> AudioStream:
	if not FILES.has(name):
		return null
	var path: String = DIR + FILES[name] % randi_range(1, 3)
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func play(parent: Node, name: String, volume_db := -3.0) -> bool:
	var s := stream(name)
	if s == null or parent == null or not parent.is_inside_tree():
		return false
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db + Audio.sfx_db()
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return true
