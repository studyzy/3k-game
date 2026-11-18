extends HBoxContainer


onready var menu = $menu
onready var menuItem = $menuItem
onready var pnl = $right
onready var pnlNotice = $right / notice
onready var general = $right / general
onready var battle_units = $right / battle_units

var sides: Array = []
var side: int = - 1

onready var notice = $notice

var sbButtonHighlighted: StyleBoxFlat = StyleBoxFlat.new()
var noticeIgnored: bool = false

func _ready():
	sbButtonHighlighted.bg_color = Color.white
	notice.get_cancel().text = "朕知道了"
	notice.get_ok().text = "不再提示"
	for k in ["攻", "守"]:
		for btn in general.get_node(k).get_node("buff").get_children():
			btn.connect("pressed", self, "set_buff", [btn])
	check_data()
	return

func reset_panel(pnl: Panel) -> void :
	if pnl == null:
		return
	for child in pnl.get_children():
		child.hide()
	return

func check_data() -> void :
	var msg = check_status()
	if side < 0:
		show_message(msg)
	return

func check_status() -> String:
	if DataManager.get_current_scene_id() != 30000:
		return "当前不在小战场场景！"
	var bf = DataManager.get_current_battle_fight()
	var msg = "已加载存档数据"
	msg += "\n当前战斗：{0}进攻{1}".format([
		bf.get_attacker().get_name(), 
		bf.get_defender().get_name(), 
	])
	msg += "\n第 {0} 回合".format([bf.turns()])
	sides.clear()
	Global.clearNode(menu)
	var btn = menuItem.duplicate()
	btn.text = "概况"
	btn.editor_description = "-99"
	btn.connect("pressed", self, "switch_side", [ - 99])
	btn.show()
	menu.add_child(btn)
	for wa in [bf.get_attacker(), bf.get_defender()]:
		var info = wa.get_name() + "："
		var types = {}
		for bu in DataManager.battle_units:
			if bu == null or bu.leaderId != wa.actorId:
				continue
			var type = bu.get_unit_type()
			if type in ["将", "城门"]:
				continue
			if not type in types:
				types[type] = 0
			types[type] += 1
		var typeInfo = []
		for type in types:
			typeInfo.append("{0}{1}".format([type, types[type]]))
		msg += "\n{0}：{1}".format([
			wa.get_name(), "、".join(typeInfo)
		])
		sides.append(wa.actorId)
		var item = menuItem.duplicate()
		item.text = wa.get_name()
		item.editor_description = str(wa.actorId)
		item.connect("pressed", self, "switch_side", [wa.actorId])
		item.show()
		menu.add_child(item)
	return msg

func show_message(msg: String):
	reset_panel(pnl)
	var notice = pnl.get_node("notice")
	if notice == null:
		return
	notice.text = msg
	notice.show()
	return

func show_general() -> void :
	if DataManager.get_current_scene_id() != 30000:
		return
	reset_panel(pnl)
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	reset_panel(pnl)
	general.get_node("where").text = "战斗所在：" + bf.get_terrian_cn()
	general.get_node("回合").text = str(bf.turns())
	var battling = {
		"攻": bf.get_attacker(), 
		"守": bf.get_defender(), 
	}
	for k in battling:
		var p = general.get_node(k)
		var wa = battling[k]
		p.get_node("name").text = "{0}（{1}）".format([wa.get_name(), k])
		p.get_node("士气").text = str(wa.battle_morale)
		p.get_node("战术").text = str(wa.battle_tactic_point)
		p.get_node("体").text = str(int(ceil(wa.actor().get_hp())))
		p.get_node("武").text = str(wa.battle_power)
		p.get_node("统").text = str(wa.battle_lead)
		p.get_node("胆").text = str(wa.battle_courage)
		p.get_node("回合").text = "0"
		p.get_node("回合").editor_description = "0"
		for btn in p.get_node("buff").get_children():
			if not btn is Button:
				continue
			btn.editor_description = "0"
			update_button_status(btn)
			if not btn.name in StaticManager.CONTINUOUS_TACTICS:
				continue
			var turns = wa.get_buff(btn.name)["回合数"]
			if turns > 0:
				btn.editor_description = "1"
				update_button_status(btn)
				p.get_node("回合").text = str(turns)
				p.get_node("回合").editor_description = str(turns)
				break
	general.show()
	return

func notice_confirmed():
	noticeIgnored = true
	return

func saved():
	if not noticeIgnored:
		notice.popup_centered()
	return

func go_solo():
	FlowManager.add_flow("go_to_solo")
	SceneManager.cheater_finished()
	return

func switch_side(actorId: int) -> void :
	side = - 1
	for btn in menu.get_children():
		if not btn is Button:
			continue
		var id = int(btn.editor_description)
		btn.disabled = false
		if id == actorId:
			side = actorId
			btn.disabled = true
	back_to_list()
	return

func back_to_list() -> void :
	reset_panel(pnl)
	if side >= 0:
		battle_units.leaderId = side
		battle_units.reload_data()
		battle_units.show()
	elif side == - 99:
		show_general()
	return

func save_general():
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	
	var prevSke = SkillHelper.read_skill_effectinfo()
	var ske = SkillHelper.new_ske_from_cheater()
	var turns = int(general.get_node("回合").text)
	if turns != bf.turns():
		ske.append_message("战斗回合数由 {0} 变为 {1}".format([
			bf.turns(), turns
		]))
		bf.set_turns(turns)
	var battling = {
		"攻": bf.get_attacker(), 
		"守": bf.get_defender(), 
	}
	for k in battling:
		var p = general.get_node(k)
		var wa = battling[k]
		var morale = int(p.get_node("士气").text)
		ske.battle_change_morale(morale - wa.battle_morale, wa)
		var tp = int(p.get_node("战术").text)
		ske.battle_change_tactic_point(tp - wa.battle_tactic_point, wa)
		var hp = int(p.get_node("体").text)
		var bu = wa.battle_actor_unit()
		ske.battle_change_unit_hp(bu, hp - bu.get_hp())
		var power = int(p.get_node("武").text)
		ske.battle_change_power(power - wa.get_battle_power(), wa)
		var lead = int(p.get_node("统").text)
		ske.battle_change_leadership(lead - wa.battle_lead, wa)
		var courage = int(p.get_node("胆").text)
		ske.battle_change_courage(courage - wa.battle_courage, wa)
		var buffTurns = int(p.get_node("回合").text)
		if buffTurns <= 0:
			for buff in StaticManager.CONTINUOUS_TACTICS:
				if wa.get_buff(buff)["回合数"] > 0:
					ske.remove_war_buff(wa.actorId, buff)
		else:
			for btn in p.get_node("buff").get_children():
				if btn.editor_description != "1":
					continue
				for buff in StaticManager.CONTINUOUS_TACTICS:
					var current = wa.get_buff(buff)["回合数"]
					if buff == btn.name:
						if current == buffTurns:
							continue
						else:
							ske.set_war_buff(wa.actorId, btn.name, buffTurns)
					elif current > 0:
						ske.remove_war_buff(wa.actorId, buff)
				break
	ske.battle_report()
	
	SkillHelper.save_skill_effectinfo(prevSke)
	show_general()
	saved()
	return

func set_buff(btn: Button):
	if not btn.name in StaticManager.CONTINUOUS_TACTICS:
		return
	for b in btn.get_parent().get_children():
		if b == btn:
			continue
		b.editor_description = "0"
		update_button_status(b)
	toggle_button_status(btn)
	var turnsInput = btn.get_parent().get_parent().get_node("回合")
	if btn.editor_description == "1":
		if int(turnsInput.text) <= 0:
			var current = int(turnsInput.editor_description)
			if current > 0:
				turnsInput.text = str(current)
			else:
				turnsInput.text = "9"
	else:
		turnsInput.text = "0"
	return

func toggle_button_status(btn: Button) -> void :
	if btn == null or not btn is Button:
		return
	if btn.editor_description == "1":
		btn.editor_description = "0"
	else:
		btn.editor_description = "1"
	update_button_status(btn)
	return

func update_button_status(btn: Button) -> void :
	if btn.editor_description == "1":
		btn.add_stylebox_override("normal", sbButtonHighlighted)
		btn.add_stylebox_override("hover", sbButtonHighlighted)
		for t in ["", "_pressed", "_disabled", "_hover", "_normal", "_focus"]:
			btn.add_color_override("font_color" + t, Color.black)
	else:
		btn.remove_stylebox_override("normal")
		btn.remove_stylebox_override("hover")
		for t in ["", "_pressed", "_disabled", "_hover", "_normal", "_focus"]:
			btn.add_color_override("font_color" + t, Color.white)
	return

func reset_layout_landscape() -> void :
	rect_min_size.y = 420
	rect_size = rect_min_size
	pnl.rect_min_size.y = 420
	pnl.rect_size = pnl.rect_min_size
	return

func reset_layout_portrait() -> void :
	rect_min_size.y = 840
	rect_size = rect_min_size
	pnl.rect_min_size.y = 840
	pnl.rect_size = pnl.rect_min_size
	return
