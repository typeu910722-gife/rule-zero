extends Node
## 音量設定與第二章的配樂（Autoload：Audio）。
## - 音量（0～100%）存在跨周目資料 meta.json 的 "volume"：Music（配樂、環境音）、SFX（音效）。
## - 不新增 Audio Bus：Godot 4.3 網頁版執行中才新增的 bus 會沒有聲音（見 sound.gd），
##   所以音量直接加在每個播放器的 volume_db 上（music_db()／sfx_db()）。
## - 第一章的聲音由 Sound 負責，也會套用這裡的音量；第二章的配樂由這裡播放（淡入淡出）。

signal volume_changed

const DEFAULT_VOLUME := {"Music": 0.9, "SFX": 1.0}
## 配樂的響度修正（dB，混音 QA 2026-10-21，docs/audio_mix_qa.md）：外包配樂各首差到 7 LU，
## 這裡把每一首拉到同一個參考響度（檔案 -17 LUFS；劇本再給 -3 dB → 播放約 -20 LUFS）。
## 值＝ -17 −（tools/audio_measure.py 量到的整合響度）。換了檔案要重量。
const MUSIC_REF_LUFS := -17.0
const MUSIC_TRIM := {
	"ch2_bgm01_bleach_town.ogg": -4.2, "ch2_bgm02_evening.ogg": -1.9, "ch2_bgm03_far_shore.ogg": -3.2,
	"ch2_bgm04_dove.ogg": -3.6, "ch2_bgm05_correction_time.ogg": -4.8, "ch2_bgm06_apology.ogg": -5.1,
	"ch2_bgm07_chairs.ogg": -2.2, "ch2_bgm07_chairs_stop.ogg": -3.4, "ch2_bgm08_night.ogg": 0.9,
	"ch2_bgm09_humming.ogg": -6.5, "ch2_bgm10_nirvana.ogg": -1.5, "ch2_bgm11_memory.ogg": -2.9,
	"ch2_bgm12_graduation.ogg": -1.4, "ch2_bgm13_escape.ogg": -2.9, "ch2_bgm14_next_stop.ogg": -3.1,
	"ch2_bgm15_special_love.ogg": -1.6, "ch2_bgm16_dream.ogg": -4.1,
}
const FADE := 0.8
const SILENT := -60.0

var _music: AudioStreamPlayer
var _music_path := ""
var _music_db := 0.0
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = SILENT
	add_child(_music)


## 這個類別的音量（dB），加在播放器原本的音量上；0% 時幾乎無聲
func music_db() -> float:
	return _to_db(get_volume("Music"))


func sfx_db() -> float:
	return _to_db(get_volume("SFX"))


func _to_db(v: float) -> float:
	return SILENT if v <= 0.001 else linear_to_db(v)


## 播放第二章配樂（res:// 路徑）。同一首不會重頭播；"" 或找不到檔案 → 淡出停止。
func play_music(path: String, loop := true, volume_db := 0.0) -> void:
	if path == _music_path and _music.playing:
		return
	_music_path = path
	volume_db += music_trim(path)
	_music_db = volume_db
	var stream: AudioStream = null
	if path != "" and ResourceLoader.exists(path):
		stream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	if _fade:
		_fade.kill()
	_fade = create_tween()
	if _music.playing:
		_fade.tween_property(_music, "volume_db", SILENT, FADE * 0.5)
	_fade.tween_callback(func():
		_music.stop()
		if stream:
			_music.stream = stream
			_music.volume_db = SILENT
			_music.play())
	if stream:
		_fade.tween_property(_music, "volume_db", volume_db + music_db(), FADE)


## 這首配樂的響度修正（dB）；沒有列的是 0
func music_trim(path: String) -> float:
	return float(MUSIC_TRIM.get(path.get_file(), 0.0))


func stop_music() -> void:
	play_music("")


func music_path() -> String:
	return _music_path if _music.playing or (_fade and _fade.is_running()) else ""


## 音量 0.0～1.0
func get_volume(kind: String) -> float:
	var v: Dictionary = GameState.meta.get("volume", {})
	return clampf(float(v.get(kind, DEFAULT_VOLUME.get(kind, 1.0))), 0.0, 1.0)


func set_volume(kind: String, value: float) -> void:
	var v: Dictionary = GameState.meta.get("volume", {}).duplicate()
	v[kind] = clampf(value, 0.0, 1.0)
	GameState.meta["volume"] = v
	GameState.save_meta()
	if _music.playing and not (_fade and _fade.is_running()):
		_music.volume_db = _music_db + music_db()
	volume_changed.emit()
