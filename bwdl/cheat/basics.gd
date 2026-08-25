# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：cheat/basics.gd
# 说明：作弊面板-基础设置。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends HBoxContainer

const MODES = ["全局", "武将", "城市", "势力"]


onready var menu = $menu
onready var pnl = $right

onready var notice = $notice
onready var pnlNotice = $right / notice
onready var general = $right / general
onready var actorlist = $right / actorlist
onready var actor = $right / actor
onready var citylist = $right / citylist
onready var city = $right / city
onready var vstatelist = $right / vstatelist
onready var vstate = $right / vstate

var mode: String = ""


var noticeIgnored: bool = false

func _ready():
	notice.get_cancel().text = "朕知道了"
	notice.get_ok().text = "不再提示"
	check_data()
	SceneManager.VirtualKey.connect("IGNORED_INPUT", self, "ignored_input")
	return

func reset_panel(pnl: Panel) -> void :
	if pnl == null:
		return
	for child in pnl.get_children():
		child.hide()
	return

func check_data() -> void :
	var msg = "尚未加载存档数据！"
	if DataManager.get_current_scene_id() >= 10000:
		msg = "已加载存档数据\n游戏时间：{0}年{1}月".format([
			DataManager.year, DataManager.month, 
		])
		msg += "\n活跃势力：{0}国".format([
			clVState.all_vstates(true).size()
		])
		msg += "\n出仕武将：{0}人".format([
			ActorHelper.all_officed_actors().size(), 
		])
	if mode == "":
		show_message(msg)
	return

func show_message(msg: String):
	reset_panel(pnl)
	pnlNotice.text = msg
	pnlNotice.show()
	return

func switch_mode(_mode: String = "") -> void :
	mode = ""
	for m in MODES:
		menu.get_node(m).disabled = false
	if _mode in MODES:
		mode = _mode
		menu.get_node(mode).disabled = true
	back_to_list()
	return

func actor_list() -> void :
	if DataManager.get_current_scene_id() < 10000:
		return
	reset_panel(pnl)
	actorlist.reload_list(actorlist.keyword, actorlist.page)
	actorlist.bind_operation(self, "actor_data")
	actorlist.show()
	return

func actor_data(actorId: int) -> void :
	reset_panel(pnl)
	var actor = pnl.get_node("actor")
	actor.reload_data(actorId)
	actor.show()
	return

func city_list() -> void :
	if DataManager.get_current_scene_id() < 10000:
		return
	reset_panel(pnl)
	citylist.reload_list(citylist.keyword, citylist.page)
	citylist.bind_operation(self, "city_data")
	citylist.show()
	return

func city_data(cityId: int) -> void :
	reset_panel(pnl)
	var city = pnl.get_node("city")
	city.reload_data(cityId)
	city.show()
	return

func vstate_list() -> void :
	if DataManager.get_current_scene_id() < 10000:
		return
	if DataManager.get_current_scene_id() != 10000:
		show_message("当前不在内政状态\n不能修改势力数据")
		return
	reset_panel(pnl)
	vstatelist.reload_list(vstatelist.keyword, vstatelist.page)
	vstatelist.bind_operation(self, "vstate_data")
	vstatelist.show()
	return

func vstate_data(vstateId: int) -> void :
	reset_panel(pnl)
	var vstate = pnl.get_node("vstate")
	vstate.reload_data(vstateId)
	vstate.show()
	return

func back_to_list():
	match mode:
		"全局":
			show_general()
		"武将":
			actor_list()
		"城市":
			city_list()
		"势力":
			vstate_list()
	return

func notice_confirmed():
	noticeIgnored = true
	return

func saved():
	if not noticeIgnored:
		notice.popup_centered()
	return

func reload_general():
	general.get_node("年").text = str(DataManager.year)
	general.get_node("月").text = str(DataManager.month)
	general.get_node("命令书").text = "-"
	general.get_node("命令书").readonly = true
	if DataManager.get_current_scene_id() == 10000\
	and DataManager.get_current_control_sort() >= 0:
		
		general.get_node("命令书").text = str(DataManager.orderbook)
		general.get_node("命令书").readonly = false
	return

func show_general() -> void :
	if DataManager.get_current_scene_id() < 10000:
		return
	reset_panel(pnl)
	reload_general()
	general.show()
	return

func save_general():
	var year = int(pnl.get_node("general/年").text)
	var month = int(pnl.get_node("general/月").text)
	year = max(1, year)
	year = min(99999, year)
	month = max(1, month)
	month = min(12, month)
	DataManager.year = year
	DataManager.month = month
	var scene = SceneManager.current_scene()
	if scene.has_method("update_year_month"):
		scene.update_year_month()
	var orderbook = pnl.get_node("general/命令书")
	if not orderbook.readonly and orderbook.text != "-":
		DataManager.orderbook = int(orderbook.text)
		for child in ["lsc_menu", "image_menu", "actor_dialog", "input_numbers"]:
			var ctrl = SceneManager.get_node_or_null("tool_layer/" + child)
			if ctrl == null:
				continue
			var ob = ctrl.get_node_or_null("conOrderbook")
			if ob == null:
				continue
			if ob.has_method("update_orderbook"):
				ob.update_orderbook()
	show_general()
	saved()
	return

func reset_layout_landscape() -> void :
	rect_min_size.y = 420
	rect_size = rect_min_size
	pnl.rect_min_size.y = 420
	pnl.rect_size = pnl.rect_min_size
	for lst in [actorlist, citylist, vstatelist]:
		lst.pageSize = 5
	return

func reset_layout_portrait() -> void :
	rect_min_size.y = 840
	rect_size = rect_min_size
	pnl.rect_min_size.y = 840
	pnl.rect_size = pnl.rect_min_size
	print(pnl.rect_size)
	for lst in [actorlist, citylist, vstatelist]:
		lst.pageSize = 12
	return

func ignored_input(action: String, pressed: bool) -> void :
	if not visible:
		return
	if pressed:
		return

	var focused = get_focus_owner()
	if focused != null and (focused is LineEdit or focused is TextEdit):
		return

	for lst in [actorlist, citylist, vstatelist]:
		if lst.visible:
			match action:
				"ANALOG_LEFT":
					lst.page_prev()
					return
				"ANALOG_RIGHT":
					lst.page_next()
					return
	match action:
		"ANALOG_UP":
			var modeIdx = MODES.find(mode)
			if modeIdx < 0:
				modeIdx = MODES.size() - 1
			else:
				modeIdx = (modeIdx + MODES.size() - 1) % MODES.size()
			switch_mode(MODES[modeIdx])
			return
		"ANALOG_DOWN":
			var modeIdx = MODES.find(mode)
			if modeIdx < 0:
				modeIdx = 0
			else:
				modeIdx = (modeIdx + 1) % MODES.size()
			switch_mode(MODES[modeIdx])
			return
	return
