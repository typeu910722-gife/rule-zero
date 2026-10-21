extends Node
## 背景音樂與音效。
##   Sound.bgm("day" / "night" / "memory" / "chase" / "")   切換背景音樂（約 1 秒交叉淡入淡出）
##   Sound.override_bgm("memory")                  暫時蓋過（夢境），傳 "" 恢復
##   Sound.sfx("interact")                          播放音效
##   Sound.ambience("forest" / "night" / "")        環境音（疊在音樂下面，交叉淡入淡出）
## 音樂：game/audio/bgm_*.ogg（原創合成，見 docs）；音效：game/audio/sfx_*.wav

const BGM := {
	"day": "res://audio/bgm_01_day_town.ogg",
	"night": "res://audio/bgm_02_night_exploration.ogg",
	"memory": "res://audio/bgm_03_memory_reveal.ogg",
	"chase": "res://audio/bgm_04_chase.ogg",
}
const SFX := {
	"talk": "res://audio/sfx_talk.wav",
	"interact": "res://audio/sfx_interact.wav",
	"choice": "res://audio/sfx_choice.wav",
	"menu": "res://audio/sfx_menu.wav",
	"door": "res://audio/sfx_door.wav",
	"step": "res://audio/sfx_step.wav",
	"strange": "res://audio/sfx_strange.wav",
	"bell_far": "res://audio/sfx_bell_far.ogg",
	"creepy": "res://audio/sfx_creepy.wav",
	"glitch": "res://audio/sfx_glitch.wav",
	"heartbeat": "res://audio/sfx_heartbeat.wav",
	"stab": "res://audio/sfx_stab.wav",
	"tear": "res://audio/sfx_tear.wav",
	"boom": "res://audio/sfx_boom.wav",
	"whoosh": "res://audio/sfx_whoosh.wav",
	"growl": "res://audio/sfx_growl.wav",
	"impact": "res://audio/sfx_impact.wav",
}
const AMB := {
	"forest": "res://audio/amb_forest.ogg",
	"night": "res://audio/amb_night.ogg",
}
## 混音（2026-10-21 混音 QA，docs/audio_mix_qa.md）：播放響度＝檔案響度＋這裡的 dB。
## 目標：配樂約 -20 LUFS、環境音約 -28、一般音效（最大瞬時響度）約 -17～-21、很頻繁的小聲音（腳步、打字）約 -28～-32。
## 環境音檔約 -21.4 LUFS → -7 → 約 -28
const AMB_DB := -7.0
## 各音效的音量（沒列的用 -4）。改過的：talk -4→-5、menu -4→0、door -4→+1、step -10→-4、tear 0→-2、boom 0→-1、growl -1→-8
## （growl 檔案本身很大聲：瞬時 -7.9，原本播放約 -9，比其他音效大 7 LU）
const SFX_DB := {"talk": -5.0, "menu": 0.0, "door": 1.0, "step": -4.0, "bell_far": -9.0, "creepy": -3.0, "glitch": -8.0,
	"heartbeat": -2.0, "stab": 0.0, "tear": -2.0, "boom": -1.0, "growl": -8.0, "impact": 0.0, "whoosh": -3.0}
## 第一章配樂檔約 -13.3 LUFS → -6.5 → 約 -20（和第二章以後的配樂一樣大）
const BGM_DB := -6.5
## 追逐戰的音樂大聲一點
const BGM_EXTRA := {"chase": 3.0}
const DUCK_DB := -17.0
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
var _amb: Array[AudioStreamPlayer] = []
var _amb_active := 0
var _amb_current := ""
## 記憶深度（0～5）：越深，音樂越慢、越走音、越悶（像被水泡過的錄音帶）
var _wear := 0
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 注意：網頁版（Godot 4.3）預設用瀏覽器的 Web Audio 播放，執行中才新增的 bus 會沒有聲音，
	# 所以音樂一律走 Master，「磨損」只用速度／音高／音量來做，不用 bus 效果。
	# 玩家在日記裡調音量時，正在播的音樂和環境音跟著變（Audio 在 Sound 之前載入）
	Audio.volume_changed.connect(_on_volume_changed)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT
		add_child(p)
		_players.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_pool.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = SILENT
		add_child(p)
		_amb.append(p)


## 記憶深度改變音樂的「磨損」程度
func set_wear(depth: int) -> void:
	_wear = clampi(depth, 0, 5)
	var p := _players[_active]
	if p.playing:
		p.volume_db = _target_db()


func wear() -> int:
	return _wear


func _process(delta: float) -> void:
	_t += delta
	if _wear == 0:
		for p in _players:
			p.pitch_scale = 1.0
		return
	# 越深越慢，再加上一點點慢慢飄的走音（錄音帶）
	var base := 1.0 - 0.022 * _wear
	var wob := sin(_t * 0.55) * 0.004 * _wear + sin(_t * 1.7) * 0.0015 * _wear
	for p in _players:
		p.pitch_scale = base + wob


func ambience(name: String) -> void:
	if name == _amb_current:
		return
	_amb_current = name
	var old := _amb[_amb_active]
	_amb_active = 1 - _amb_active
	var new := _amb[_amb_active]
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", SILENT, 1.5)
		tw.tween_callback(old.stop)
	if name == "" or not AMB.has(name):
		return
	var st: AudioStream = _load(AMB[name])
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	new.stream = st
	new.volume_db = SILENT
	new.play()
	var tw2 := create_tween()
	tw2.tween_property(new, "volume_db", AMB_DB + Audio.music_db(), 2.0)


func ambience_name() -> String:
	return _amb_current


func bgm(name: String) -> void:
	if name == "memory" or name == "":
		ambience("")   # 回憶、標題、結局：只留音樂
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
			p.volume_db = SFX_DB.get(name, -4.0) + Audio.sfx_db()
			p.pitch_scale = randf_range(0.92, 1.08) if name in ["step", "talk"] else 1.0
			# 鐘聲：記憶越深越低沉
			if name == "bell_far":
				p.pitch_scale = 1.0 - 0.045 * _wear
			p.play()
			return


func _target_db() -> float:
	# 記憶越深，音樂越遠、越小聲
	return (DUCK_DB if _ducked else BGM_DB) + BGM_EXTRA.get(_current, 0.0) - 0.6 * _wear + Audio.music_db()


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


func _on_volume_changed() -> void:
	var p := _players[_active]
	if p.playing:
		p.volume_db = _target_db()
	var a := _amb[_amb_active]
	if a.playing:
		a.volume_db = AMB_DB + Audio.music_db()


func _load(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]
