class_name DialogueParser
extends RefCounted
## 解析 res://dialogue/*.txt 的對話腳本。語法見 docs/dialogue-format.md。

const KNOWN_OPS := ["set", "unset", "sus", "conduct", "courage", "goto", "if", "end", "wait", "bg", "event"]
const KNOWN_BG := ["none", "black", "train", "dream", "grey_train", "white"]

var cmds: Array = []
var labels := {}
var errors: Array = []


func parse_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		errors.append("找不到檔案：%s" % path)
		return
	parse_text(f.get_as_text(), path.get_file())


func parse_text(text: String, source := "") -> void:
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line == "" or line.begins_with("//"):
			continue
		var where := "%s:%d" % [source, n]
		if line.begins_with("==="):
			cmds.append({"t": "end"})
			_add_label(line.substr(3).strip_edges(), where)
			continue
		if line.begins_with("# "):
			_add_label(line.substr(2).strip_edges(), where)
			continue
		var cond := ""
		if line.begins_with("["):
			var close := line.find("]")
			if close < 0:
				errors.append("%s 條件缺少 ]" % where)
				continue
			cond = line.substr(1, close - 1)
			line = line.substr(close + 1).strip_edges()
		var c: Dictionary
		if line.begins_with("* "):
			c = _parse_choice(line.substr(2), where)
		elif line.begins_with("@"):
			var parts := line.substr(1).split(" ", false)
			c = {"t": "cmd", "op": parts[0], "args": Array(parts.slice(1))}
			if not parts[0] in KNOWN_OPS:
				errors.append("%s 未知指令 @%s" % [where, parts[0]])
		elif line.begins_with(">"):
			c = {"t": "say", "who": "", "text": line.substr(1).strip_edges()}
		else:
			var i := line.find("：")
			if i > 0 and i <= 10:
				c = {"t": "say", "who": line.left(i), "text": line.substr(i + 1).strip_edges()}
			else:
				c = {"t": "say", "who": "", "text": line}
		c["cond"] = cond
		c["where"] = where
		cmds.append(c)
	cmds.append({"t": "end"})


func _parse_choice(body: String, where: String) -> Dictionary:
	var c := {"t": "choice", "text": body, "target": "", "cost": 0}
	var arrow := body.find("->")
	if arrow < 0:
		errors.append("%s 選項缺少 -> 目標" % where)
		return c
	c.text = body.left(arrow).strip_edges()
	for token in body.substr(arrow + 2).split(" ", false):
		if token.begins_with("$"):
			c.cost = int(token.substr(1))
		else:
			c.target = token
	return c


func _add_label(label: String, where: String) -> void:
	if labels.has(label):
		errors.append("%s 標籤重複：%s" % [where, label])
	labels[label] = cmds.size()


## 檢查所有跳轉目標與指令參數
func validate(known_events: Array) -> Array:
	var out := errors.duplicate()
	for c in cmds:
		if c.t == "choice" and not labels.has(c.target):
			out.append("%s 選項目標不存在：%s" % [c.where, c.target])
		elif c.t == "cmd":
			match c.op:
				"goto":
					if c.args.size() != 1 or not labels.has(c.args[0]):
						out.append("%s @goto 目標不存在" % c.where)
				"if":
					if c.args.size() != 2 or not labels.has(c.args[1]):
						out.append("%s @if 目標不存在" % c.where)
				"event":
					if c.args.size() != 1 or not c.args[0] in known_events:
						out.append("%s 未知事件 %s" % [c.where, c.args])
				"bg":
					if c.args.size() != 1 or not c.args[0] in KNOWN_BG:
						out.append("%s 未知背景 %s" % [c.where, c.args])
				"set", "unset", "sus", "conduct", "courage", "wait":
					if c.args.is_empty():
						out.append("%s @%s 缺少參數" % [c.where, c.op])
	return out
