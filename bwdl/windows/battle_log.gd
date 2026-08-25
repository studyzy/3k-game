# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/battle_log.gd
# 说明：战斗日志 UI。显示战斗过程记录。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const LINE_DELTA_VALUE = 32

onready var lblTitle = $lblTitle
onready var lblNotice = $lblNotice
onready var txtHistory = $history
onready var pnlState = $state
onready var btnShowSkill = SceneManager.get_node("Virtukey/VirtualKey/btnShowSkill")
onready var actorInfo = get_node("CanvasLayer/actor_description")

var actorInfoLoaded: bool = false
var mode: int = 0

func prepare() -> void :
	actorInfo.back()
	mode = 2
	switch_mode()
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	var history = bf.battle_log.duplicate()
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
	txtHistory.bbcode_text = "\n".join(content)
	txtHistory.scroll_to_line(0)
	return

func scroll_up():
	var vsc: VScrollBar
	if mode == 0:
		vsc = txtHistory.get_v_scroll()
	else:
		vsc = pnlState.get_v_scrollbar()
	vsc.value = max(vsc.value - LINE_DELTA_VALUE, vsc.min_value)
	return

func scroll_down():
	var vsc: VScrollBar
	if mode == 0:
		vsc = txtHistory.get_v_scroll()
	else:
		vsc = pnlState.get_v_scrollbar()
	vsc.value = min(vsc.value + LINE_DELTA_VALUE, vsc.max_value)
	return

func scroll_page_up():
	switch_mode( - 1)
	Input.action_release("ANALOG_LEFT")
	return

func scroll_page_down():
	switch_mode()
	Input.action_release("ANALOG_RIGHT")
	return

func switch_mode(delta: int = 1) -> void :
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	mode = (mode + delta + 3) % 3
	match mode:
		0:
			lblTitle.text = "战斗日志：[{2}] {0} - {1}".format([
				bf.get_attacker().get_name(), 
				bf.get_defender().get_name(), 
				bf.get_terrian_cn(), 
			])
			lblNotice.text = "<< [左] 守方状态                   攻方状态 [右] >>\n\n                  [上][下] 移动查看日志\n                  [B] 回到小战场"
			txtHistory.show()
			pnlState.hide()
			btnShowSkill.hide()
		1:
			lblTitle.text = "攻方武将：{0}".format([
				bf.get_attacker().get_name(), 
				bf.get_terrian_cn(), 
			])
			lblNotice.text = "<< [左] 战斗日志                   守方状态 [右] >>\n\n                  [上][下] 移动查看更多信息\n                  [B] 回到小战场"
			txtHistory.hide()
			prepare_wa_state(bf.get_attacker())
			pnlState.show()
			Global.clear_signals(btnShowSkill, ["pressed"])
			btnShowSkill.show()
			btnShowSkill.connect("pressed", self, "show_skill")
		2:
			lblTitle.text = "守方武将：{0}".format([
				bf.get_defender().get_name(), 
			])
			prepare_wa_state(bf.get_defender())
			lblNotice.text = "<< [左] 攻方状态                   战斗日志 [右] >>\n\n                  [上][下] 移动查看更多信息\n                  [B] 回到小战场"
			txtHistory.hide()
			pnlState.show()
			Global.clear_signals(btnShowSkill, ["pressed"])
			btnShowSkill.show()
			btnShowSkill.connect("pressed", self, "show_skill")
	actorInfoLoaded = false
	return

func prepare_wa_state(wa: War_Actor) -> void :
	pnlState.get_node("pnl/actor")._load_base(wa.actorId)
	var state = pnlState.get_node("pnl/battle_state")
	var attrs = [
		["武", wa.get_battle_power(), wa.actor().get_power()], 
		["知", wa.actor().get_wisdom(), wa.actor().get_wisdom()], 
		["统", wa.battle_lead, wa.actor().get_leadership()], 
		["胆", wa.battle_courage, wa.actor().get_courage()], 
	]
	for setting in attrs:
		var txt = state.get_node_or_null(setting[0])
		if not txt is RichTextLabel:
			continue
		var color = "black"
		if setting[2] > setting[1]:
			color = "red"
		elif setting[2] < setting[1]:
			color = "blue"
		txt.bbcode_text = "{0}：[color={2}]{1}[/color]".format([
			setting[0], setting[1], color, 
		])
	state.get_node("战术值").text = "战术值：{0}".format([wa.battle_tactic_point])
	var signChar = "+"
	if wa.battle_morale_patched < 0:
		signChar = ""
	state.get_node("士气").text = "士气：{0}({1}{2})".format([
		wa.battle_morale - wa.battle_morale_patched, 
		signChar, wa.battle_morale_patched, 
	])
	for key in ["近身倍率", "远程倍率", "免伤倍率", "格挡率"]:
		state.get_node("近身倍率").text = ""
	var bu = wa.battle_actor_unit()
	if bu != null:
		state.get_node("近身倍率").text = "近身倍率：{0}%".format([
			bu.get_melee_damage_rate(), 
		])
		state.get_node("远程倍率").text = "远程倍率：{0}%".format([
			bu.get_shooting_damage_rate(), 
		])
		state.get_node("免伤倍率").text = "免伤倍率：{0}%".format([
			bu.get_damage_avoid_rate(), 
		])
		state.get_node("格挡率").text = "格挡率：{0}%".format([
			bu.get_blocking_rate(), 
		])
	return

func show_skill() -> void :
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	var targetId = - 1
	match mode:
		1:
			targetId = bf.get_attacker_id()
		2:
			targetId = bf.get_defender_id()
	if targetId < 0:
		return
	if actorInfoLoaded:
		actorInfo.back()
		actorInfoLoaded = false
	else:
		actorInfo.init_actor(targetId)
		actorInfoLoaded = true
	return

func close_all() -> void :
	actorInfo.back()
	btnShowSkill.hide()
	hide()
	return
