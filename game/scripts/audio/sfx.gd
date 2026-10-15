class_name Sfx
extends RefCounted
## 第二章外包音效（game/audio/ch2/se）。同一個音效有 _01～_03 三個變化版，隨機挑一個播放。
## 沒有素材時安靜地略過（第一章、測試環境）。

const DIR := "res://audio/ch2/se/"
const FILES := {
	"text": "ch2_se01_text_%02d.wav",
	"whistle_short": "ch2_se20_whistle_short_%02d.wav",
	"whistle_long": "ch2_se20_whistle_long_%02d.wav",
	"shock_short": "ch2_se40_shock_short_%02d.wav",
	"shock_medium": "ch2_se40_shock_medium_%02d.wav",
	"shock_long": "ch2_se40_shock_long_%02d.wav",
}
static var _cache := {}


static func stream(name: String) -> AudioStream:
	if not FILES.has(name):
		return null
	var path: String = DIR + FILES[name] % randi_range(1, 3)
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func play(parent: Node, name: String, volume_db := -6.0) -> bool:
	var s := stream(name)
	if s == null or parent == null or not parent.is_inside_tree():
		return false
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return true
