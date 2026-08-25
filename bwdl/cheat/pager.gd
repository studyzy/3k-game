# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：cheat/pager.gd
# 说明：作弊面板-分页。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends LineEdit

var isDigit = 0
var maxLength = 0
var maxVal = 0
var minVal = - 1
signal pager_changed

func _ready():
	connect("text_changed", self, "input")
	var params = editor_description.split(",")
	if params.size() > 0:
		isDigit = int(params[0])
	if params.size() > 1:
		maxLength = int(params[1])
	if params.size() > 2:
		maxVal = int(params[2])
	if params.size() > 3:
		minVal = int(params[3])
	return

func input(changed: String):
	text = text.strip_edges()
	if isDigit > 0 and not text.is_valid_integer():
		var validated = ""
		for ch in text:
			if ch.is_valid_integer():
				validated += ch
		text = validated
	if maxLength > 0 and text.length() > maxLength:
		text = text.substr(0, maxLength)
	if maxVal > 0 and int(text) > maxVal:
		text = str(maxVal)
	if minVal >= 0 and int(text) < minVal:
		text = str(minVal)
	return

func _gui_input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			emit_signal("pager_changed")
	return
