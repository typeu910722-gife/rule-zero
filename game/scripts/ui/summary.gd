extends CanvasLayer
## 章節結算畫面（縫線布告風格）。停留幾秒後自動接下一章開場，不等玩家按鍵。

signal done

const HOLD := 4.0


func _ready() -> void:
	layer = 60
	var bg := ColorRect.new()
	bg.color = Color("#2a2230")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var t := RichTextLabel.new()
	t.position = Vector2(340, 150)
	t.size = Vector2(600, 420)
	t.bbcode_enabled = true
	t.add_theme_color_override("default_color", Color("#f3e9f1"))
	t.add_theme_font_size_override("normal_font_size", 24)
	var found := GameState.secrets_found()
	var stars := "★".repeat(found.size()) + "☆".repeat(GameState.SECRETS.size() - found.size())
	var txt := "[center][font_size=36]第一章　歡迎回來　—　完[/font_size][/center]\n\n\n"
	txt += "發現的秘密　　%s　(%d / %d)\n" % [stars, found.size(), GameState.SECRETS.size()]
	var names: Array = found.map(func(k): return GameState.SECRETS[k])
	if not names.is_empty():
		txt += "[font_size=20]%s[/font_size]\n" % "、".join(names)
	txt += "\n鎮長懷疑值　　%d / 100" % GameState.suspicion
	txt += "\n記憶碎片　　　%d / 10" % GameState.tuft_count()
	txt += "\n用了幾輪　　　%d 輪" % (GameState.loop_number() - GameState.FIRST_LOOP + 1)
	t.text = txt
	add_child(t)


func show_and_wait() -> void:
	if not GameState.fast:
		await get_tree().create_timer(HOLD).timeout
	done.emit()
