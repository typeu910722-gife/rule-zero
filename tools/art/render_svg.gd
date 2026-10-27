extends SceneTree
## 用法：-- <輸入.svg> <輸出.png> [...]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i + 1 < a.size():
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(a[i]), 1.0)
		if err != OK:
			printerr("FAIL ", a[i], " ", err)
		else:
			img.save_png(a[i + 1])
		i += 2
	quit()
