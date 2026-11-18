extends HBoxContainer

const MODES = []


onready var menu = $menu
onready var pnl = $right

var mode: String = ""

onready var notice = $notice

var noticeIgnored: bool = false

func _ready():
	notice.get_cancel().text = "朕知道了"
	notice.get_ok().text = "不再提示"
	check_data()
	return

func reset_panel(pnl: Panel) -> void :
	if pnl == null:
		return
	for child in pnl.get_children():
		child.hide()
	return

func check_data() -> void :
	var msg = "尚未加载存档数据！"
	if DataManager.get_current_scene_id() != 40000:
		msg = "当前不在单挑场景！"
	else:
		msg = "单挑修改还没做！"
	if mode == "":
		show_message(msg)
	return

func show_message(msg: String):
	reset_panel(pnl)
	var notice = pnl.get_node("notice")
	if notice == null:
		return
	notice.text = msg
	notice.show()
	return

func switch_mode(_mode: String = "") -> void :
	mode = ""
	for m in MODES:
		menu.get_node(m).disabled = false
	if _mode in MODES:
		mode = _mode
		menu.get_node(mode).disabled = true
	return

func back_to_list():
	return

func notice_confirmed():
	noticeIgnored = true
	return

func saved():
	if not noticeIgnored:
		notice.popup_centered()
	return
