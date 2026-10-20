class_name Motif
extends RefCounted
## 全作的主旋律動機「棉花糖鎮的音樂盒」（tools/make_motif_audio.py 產生，game/audio/motif/）。
## Mi La Sol Mi｜Fa Mi Re｜Si——最後停在 Si，永遠沒有唱完。
## 小遊戲的音符、開始／成功／失敗、和平鴿的口哨、章節標題都用這一段，讓玩家記得住。

## 旋律的音高（Hz）：小遊戲每一步的提示音照這個順序彈
const NOTES := [659.26, 880.0, 783.99, 659.26, 698.46, 659.26, 587.33, 493.88]
const DIR := "res://audio/motif/%s.ogg"


## 這一章的音色：第一章音樂盒、第二章被漂白的音樂盒、第三章心電圖
static func world() -> String:
	match GameState.chapter:
		2:
			return "bleach"
		3:
			return "ecg"
	return "musicbox"


## 播一段：musicbox／bleach／whistle／ecg／resolved，或 start／clear／fail／sting（自動接上這一章的音色）
static func play(parent: Node, name: String, volume_db := -4.0) -> void:
	if GameState.fast or parent == null or not parent.is_inside_tree():
		return
	if name in ["start", "clear", "fail", "sting"]:
		name = "%s_%s" % [name, world()]
	var path := DIR % name
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = volume_db + Audio.sfx_db()
	parent.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## 第 i 步的提示音（音樂盒音色；第二章少兩個音、微微走音）
static func note(parent: Node, i: int, volume_db := -8.0) -> void:
	var k := i % NOTES.size()
	var f: float = NOTES[k]
	if world() == "bleach":
		if k == 2 or k == 5:
			return  # 被漂白掉的音
		f *= 1.0 + randf_range(-0.012, 0.012)
	Tones.play(parent, f, volume_db)
