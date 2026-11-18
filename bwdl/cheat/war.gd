extends HBoxContainer


onready var menu = $menu
onready var menuItem = $menuItem
onready var pnl = $right
onready var pnlNotice = $right / notice
onready var general = $right / general
onready var war_actor_list = $right / war_actor_list

var sides: Array = []
var side: int = - 1

onready var notice = $notice

var noticeIgnored: bool = false

func _ready():
	notice.get_cancel().text = "朕知道了"
	notice.get_ok().text = "不再提示"
	war_actor_list.connect("saved", self, "saved")
	check_data()
	SceneManager.VirtualKey.connect("IGNORED_INPUT", self, "ignored_input")
	return

func reset_panel(pnl: Panel) -> void :
	if pnl == null:
		return
	for child in pnl.get_children():
		child.hide()
	return

func check_status() -> String:
	if DataManager.get_current_scene_id() != 20000:
		return "当前不在大战场场景！"
	var wf = DataManager.get_current_war_fight()
	if wf == null or wf.status != 1:
		return "当前不在大战场场景！"
	var msg = "已加载存档数据\n游戏时间：{0}年{1}月".format([
		DataManager.year, DataManager.month, 
	])
	msg += "\n当前战争：{0}进攻{1}的{2}".format([
		wf.from_vstate().get_lord_name(), 
		wf.target_vstate().get_lord_name(), 
		wf.target_city().get_name()
	])
	msg += "\n第 {0} 天".format([wf.date])
	sides.clear()
	Global.clearNode(menu)
	var btn = menuItem.duplicate()
	btn.text = "概况"
	btn.editor_description = "-99"
	btn.connect("pressed", self, "switch_side", [ - 99])
	btn.show()
	menu.add_child(btn)
	for wv in [wf.attackerWV, wf.defenderWV, wf.extraWV]:
		if wv == null:
			continue
		msg += "\n{0}{1}：主将 {2}，武将 {3}，士兵 {4}".format([
			wv.side, "援军" if wv.is_reinforcement() else "", 
			wv.get_leader_name(), 
			wv.get_actors_count(true), 
			wv.get_all_soldiers(true)
		])
		sides.append(wv.id)
		var item = menuItem.duplicate()
		item.text = wv.get_leader_name()
		item.editor_description = str(wv.id)
		item.connect("pressed", self, "switch_side", [wv.id])
		item.show()
		menu.add_child(item)
	return msg

func check_data() -> void :
	var msg = check_status()
	if side < 0:
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

func switch_side(wvId: int) -> void :
	side = - 1
	for btn in menu.get_children():
		if not btn is Button:
			continue
		var id = int(btn.editor_description)
		btn.disabled = false
		if id == wvId:
			side = id
			btn.disabled = true
	back_to_list()
	return

func back_to_list():
	reset_panel(pnl)
	if side >= 0:
		war_actor_list.wvId = side
		war_actor_list.reload_list(war_actor_list.keyword, war_actor_list.page)
		war_actor_list.show()
	elif side == - 99:
		show_general()
	return

func show_general() -> void :
	if DataManager.get_current_scene_id() != 20000:
		return
	var wf = DataManager.get_current_war_fight()
	if wf == null or wf.status != 1:
		return
	reset_panel(pnl)
	general.get_node("where").text = "战争所在地：" + wf.target_city().get_name()
	general.get_node("天数").text = str(wf.date)
	var idx = 1
	for wv in [wf.attackerWV, wf.defenderWV, wf.extraWV]:
		var block = general.get_node("wv" + str(idx))
		if not block is Panel:
			continue
		if wv == null:
			block.hide()
			continue
		block.show()
		var memo = wv.get_leader_name() + "（"
		if wv.side == "攻击方":
			memo += "攻"
		else:
			memo += "守"
		if wv.is_reinforcement():
			memo += "援"
		memo += "）"
		block.get_node("name").text = memo
		block.get_node("name").editor_description = str(wv.id)
		block.get_node("金").text = str(wv.money)
		block.get_node("米").text = str(wv.rice)
		block.get_node("full").text = "满兵"
		block.get_node("full").editor_description = ""
		idx += 1
	general.show()
	return

func notice_confirmed():
	noticeIgnored = true
	return

func saved():
	if not noticeIgnored:
		notice.popup_centered()
	return

func save_general():
	var wf = DataManager.get_current_war_fight()
	if wf == null:
		return
	
	var prevSke = SkillHelper.read_skill_effectinfo()
	var ske = SkillHelper.new_ske_from_cheater()
	var date = int(general.get_node("天数").text)
	ske.change_war_date(date)
	for idx in range(1, 4):
		var block = general.get_node("wv" + str(idx))
		if not block is Panel:
			continue
		var wvId = int(block.get_node("name").editor_description)
		var wv = wf.get_war_vstate(wvId)
		if wv == null:
			continue
		var gold = int(block.get_node("金").text)
		var rice = int(block.get_node("米").text)
		ske.change_wv_gold(gold - wv.money, wv)
		ske.change_wv_rice(rice - wv.rice, wv)
		var btn = block.get_node("full")
		if not btn is Button:
			continue
		if btn.editor_description == "1":
			for wa in wv.get_war_actors(false, true):
				ske.change_actor_soldiers(wa.actorId, 10000, DataManager.get_actor_max_soldiers(wa.actorId))
			for actorId in wv.camp_actors:
				ske.change_actor_soldiers(actorId, 10000, DataManager.get_actor_max_soldiers(actorId))
			for actorId in wv.capture_actors:
				ske.change_actor_soldiers(actorId, 10000, DataManager.get_actor_max_soldiers(actorId))
	ske.war_report()
	
	SkillHelper.save_skill_effectinfo(prevSke)
	show_general()
	saved()
	return

func general_full(idx: int):
	var block = general.get_node_or_null("wv" + str(idx))
	if not block is Panel:
		return
	var btn = block.get_node("full")
	if not btn is Button:
		return
	btn.text = "* 满兵"
	btn.editor_description = "1"
	return

func reset_layout_landscape() -> void :
	rect_min_size.y = 420
	rect_size = rect_min_size
	pnl.rect_min_size.y = 420
	pnl.rect_size = pnl.rect_min_size
	for lst in [war_actor_list]:
		lst.pageSize = 5
	return

func reset_layout_portrait() -> void :
	rect_min_size.y = 840
	rect_size = rect_min_size
	pnl.rect_min_size.y = 840
	pnl.rect_size = pnl.rect_min_size
	for lst in [war_actor_list]:
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

	for lst in [war_actor_list]:
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
			if sides.empty():
				return
			var sideIdx = sides.find(side)
			if sideIdx < 0:
				switch_side(sides[sides.size() - 1])
				return
			if sideIdx == 0:
				switch_side( - 99)
				return
			sideIdx = (sideIdx - 1) % sides.size()
			switch_side(sides[sideIdx])
			return
		"ANALOG_DOWN":
			if sides.empty():
				return
			var sideIdx = sides.find(side)
			if side == - 99:
				switch_side(sides[0])
				return
			if sideIdx < 0 or sideIdx == sides.size() - 1:
				switch_side( - 99)
				return
			sideIdx = (sideIdx + 1) % sides.size()
			switch_side(sides[sideIdx])
			return
	return
