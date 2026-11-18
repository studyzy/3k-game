extends Control

const LINE_DELTA_VALUE = 32
const PAGE_DELTA_VALUE = 128

onready var conHistory = get_node("Window/history")
onready var lblTitle = get_node("Window/lblTitle")

func update_data():
	lblTitle.text = "{0}年{1}月".format([
		DataManager.year, DataManager.month, 
	])
	var history = DataManager.affair_log.duplicate()
	history.invert()
	var content = []
	var colors = ["yellow", "green", "red"]
	var regexps = {}
	for color in colors:
		var r = RegEx.new()
		r.compile("<" + color[0] + "([^>]+)>")
		regexps[color] = r
	for msg in history:
		for color in regexps:
			var r = regexps[color]
			msg = r.sub(msg, "[color=" + color + "]$1[/color]", true)
		content.append(msg)
	conHistory.bbcode_text = "\n".join(content)
	conHistory.scroll_to_line(0)
	return

func scroll_up():
	var vsc: VScrollBar = conHistory.get_v_scroll()
	vsc.value = max(vsc.value - LINE_DELTA_VALUE, vsc.min_value)
	return

func scroll_down():
	var vsc: VScrollBar = conHistory.get_v_scroll()
	vsc.value = min(vsc.value + LINE_DELTA_VALUE, vsc.max_value)
	return

func scroll_page_up():
	var vsc: VScrollBar = conHistory.get_v_scroll()
	vsc.value = max(vsc.value - PAGE_DELTA_VALUE, vsc.min_value)
	return

func scroll_page_down():
	var vsc: VScrollBar = conHistory.get_v_scroll()
	vsc.value = min(vsc.value + PAGE_DELTA_VALUE, vsc.max_value)
	return
