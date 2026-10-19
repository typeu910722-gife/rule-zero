extends Node
## 兩章共用的聲音管理（Autoload：Audio）。
## - 三條 Audio Bus：Music（配樂）、SFX（音效、環境音）、底下都接 Master。
## - 配樂切換時淡出舊的、淡入新的。
## - 音量設定（0～100%）存在跨周目資料 meta.json 的 "volume"。

const BUSES := ["Music", "SFX"]
const DEFAULT_VOLUME := {"Master": 1.0, "Music": 0.8, "SFX": 0.9}
const FADE := 0.8

var _music: AudioStreamPlayer
var _music_path := ""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	apply_volume()


## 播放配樂（res:// 路徑）。同一首不會重頭播；"" 或找不到檔案 → 淡出停止。
func play_music(path: String, loop := true, volume_db := 0.0) -> void:
	if path == _music_path and _music.playing:
		return
	_music_path = path
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if _music.playing:
		_fade.tween_property(_music, "volume_db", -40.0, FADE * 0.5)
	_fade.tween_callback(func():
		_music.stop()
		if stream:
			_music.stream = stream
			_music.volume_db = -40.0
			_music.play())
	if stream:
		_fade.tween_property(_music, "volume_db", volume_db, FADE)


func stop_music() -> void:
	play_music("")


func music_path() -> String:
	return _music_path if _music.playing or (_fade and _fade.is_running()) else ""


## 音量 0.0～1.0
func get_volume(bus: String) -> float:
	var v: Dictionary = GameState.meta.get("volume", {})
	return clampf(float(v.get(bus, DEFAULT_VOLUME.get(bus, 1.0))), 0.0, 1.0)


func set_volume(bus: String, value: float) -> void:
	var v: Dictionary = GameState.meta.get("volume", {}).duplicate()
	v[bus] = clampf(value, 0.0, 1.0)
	GameState.meta["volume"] = v
	apply_volume()
	GameState.save_meta()


func apply_volume() -> void:
	for bus in DEFAULT_VOLUME:
		var idx := AudioServer.get_bus_index(bus)
		if idx == -1:
			continue
		var value := get_volume(bus)
		AudioServer.set_bus_mute(idx, value <= 0.001)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.001)))
