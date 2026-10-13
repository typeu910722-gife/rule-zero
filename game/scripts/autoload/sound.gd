extends Node
## 背景音樂與音效。
##   Sound.bgm("day" / "night" / "memory" / "")   切換背景音樂（約 1 秒交叉淡入淡出）
##   Sound.override_bgm("memory")                  暫時蓋過（夢境），傳 "" 恢復
##   Sound.sfx("interact")                          播放音效
## 音樂：game/audio/bgm_*.ogg（原創合成，見 docs）；音效：game/audio/sfx_*.wav

const BGM := {
	"day": "res://audio/bgm_01_day_town.ogg",
	"night": "res://audio/bgm_02_night_exploration.ogg",
	"memory": "res://audio/bgm_03_memory_reveal.ogg",
}
const SFX := {
	"talk": "res://audio/sfx_talk.wav",
	"interact": "res://audio/sfx_interact.wav",
	"choice": "res://audio/sfx_choice.wav",
	"menu": "res://audio/sfx_menu.wav",
	"door": "res://audio/sfx_door.wav",
	"step": "res://audio/sfx_step.wav",
	"strange": "res://audio/sfx_strange.wav",
}
const BGM_DB := -8.0
const DUCK_DB := -22.0
const FADE := 1.0
const SILENT := -60.0

var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _base := ""
var _override := ""
var _current := ""
var _ducked := false
var _sfx_pool: Array[AudioStreamPlayer] = []
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT
		add_child(p)
		_players.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)


func bgm(name: String) -> void:
	_base = name
	_apply()


func override_bgm(name: String) -> void:
	_override = name
	_apply()


func duck(on: bool) -> void:
	_ducked = on
	var p := _players[_active]
	if p.playing:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", _target_db(), 0.4)


func sfx(name: String) -> void:
	if not SFX.has(name):
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = _load(SFX[name])
			p.volume_db = -4.0 if name != "step" else -10.0
			p.pitch_scale = randf_range(0.92, 1.08) if name in ["step", "talk"] else 1.0
			p.play()
			return


func _target_db() -> float:
	return DUCK_DB if _ducked else BGM_DB


func _apply() -> void:
	var want := _override if _override != "" else _base
	if want == _current:
		return
	_current = want
	var old := _players[_active]
	_active = 1 - _active
	var new := _players[_active]
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", SILENT, FADE)
		tw.tween_callback(old.stop)
	if want == "":
		return
	var st: AudioStream = _load(BGM[want])
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	new.stream = st
	new.volume_db = SILENT
	new.play()
	var tw2 := create_tween()
	tw2.tween_property(new, "volume_db", _target_db(), FADE)


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]
