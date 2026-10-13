extends CanvasLayer
## 第一次開始新遊戲、搭上列車前的一瞬間：閃過一段 0.5 秒的影片（「相信狐狸」「快開門」）。
## 整個存檔只會出現一次（GameState.meta.flash_seen），不能跳過。

signal done

const VIDEO := preload("res://video/flash.ogv")


func _ready() -> void:
	layer = 85
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var player := VideoStreamPlayer.new()
	player.stream = VIDEO
	player.expand = true
	player.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player)
	player.finished.connect(_finish)
	player.play()
	# 保險：影片如果沒有正常結束，1.5 秒後也繼續
	get_tree().create_timer(1.5).timeout.connect(_finish)


func _finish() -> void:
	if not is_inside_tree():
		return
	done.emit()
	queue_free()
