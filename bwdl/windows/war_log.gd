# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/war_log.gd
# 说明：战争日志 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const LINE_DELTA_VALUE = 32
const PAGE_DELTA_VALUE = 128

onready var conHistory = get_node("Window2/history")
onready var lblCity = get_node("Window2/lblCity")
onready var lblEndless = get_node("Window2/lblEndless")

func update_data():
	var wf = DataManager.get_current_war_fight()
	var warCity = wf.target_city()
	lblCity.text = "{0}之战 - {2}月{1}日".format([
		warCity.get_name(), wf.date, DataManager.month, 
	])
	var history = DataManager.war_log.duplicate()
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
	lblEndless.hide();
	if DataManager.endless_mode:
		var type = "【守城战】";
		if EndlessGame.war_vstate_no_player == 1:
			type = "【攻城战】";
		lblEndless.text = "【{0}】无尽第{1}关{2}".format([
			StaticManager.DIFFICULTY_NAMES[DataManager.diffculities], 
			EndlessGame.pass_no + 1, type
		]);
		lblEndless.show()
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
