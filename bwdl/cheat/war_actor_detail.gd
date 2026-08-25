# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：cheat/war_actor_detail.gd
# 说明：作弊面板-战争武将详情。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

const FIVE_PHASES = {
	"金": War_Character.FivePhases_Enum.Metal, 
	"木": War_Character.FivePhases_Enum.Wood, 
	"水": War_Character.FivePhases_Enum.Water, 
	"火": War_Character.FivePhases_Enum.Fire, 
	"土": War_Character.FivePhases_Enum.Earth, 
}

var wvId: int = - 1
var actorId: int = - 1

onready var attrs = $attrs

signal saved
signal basics
signal cancel

var sbButtonHighlighted: StyleBoxFlat = StyleBoxFlat.new()

func _ready():
	
	sbButtonHighlighted.bg_color = Color.white
	return

func reload_data(_wvId: int = - 1, _actorId: int = - 1) -> void :
	if _wvId >= 0:
		wvId = _wvId
	if _actorId >= 0:
		actorId = _actorId
	Global.load_actor_avatar(actorId, $avatar, 3)
	var actor = ActorHelper.actor(actorId)
	$name.text = actor.get_name()
	var wf = DataManager.get_current_war_fight()
	var wv = wf.get_war_vstate(wvId)
	if wv == null:
		cancel()
		return
	var wa = wv.get_war_actor(actorId)
	if wa == null:
		cancel()
		return
	attrs.get_node("机动").text = str(wa.action_point)
	attrs.get_node("点数").text = str(wa.poker_point)
	attrs.get_node("X").text = str(wa.position.x)
	attrs.get_node("Y").text = str(wa.position.y)
	var buffBtn = attrs.get_node("buff")
	buffBtn.hide()
	var buffCount = 0
	for buff in StaticManager.WAR_BUFF_STATUSES:
		var btn = attrs.get_node_or_null(buff)
		if btn == null:
			btn = buffBtn.duplicate()
			attrs.add_child(btn)
		btn.text = StaticManager.WAR_BUFF_STATUSES[buff]
		var buffTurns = int(wa.get_buff(buff)["回合数"])
		var buffInfo = StaticManager.get_buff(buff)
		var tips = "{0}：{1}".format([
			buff, buffInfo.get_description(), buffTurns, 
		])
		btn.editor_description = "{0},{1}".format([buff, buffTurns])
		update_buff_status(btn)
		var x = (buffCount % 13) * buffBtn.rect_size.x
		var y = 110 + int(buffCount / 13) * 50
		btn.rect_position = Vector2(x, y)
		btn.name = buff
		Global.bind_button_tooltip(btn, tips)
		btn.connect("pressed", self, "toggle_buff_status", [buff])
		btn.show()
		buffCount += 1
	set_five_phases(wa.get_five_phases_str())
	return

func set_five_phases(val: String):
	for fp in FIVE_PHASES.keys():
		attrs.get_node(fp).disabled = false
	var checked = attrs.get_node_or_null(val)
	if checked is Button:
		checked.disabled = true
	return

func cancel():
	emit_signal("cancel")
	hide()
	return

func save_data() -> void :
	var wf = DataManager.get_current_war_fight()
	var wv = wf.get_war_vstate(wvId)
	if wv == null:
		return
	var wa = wv.get_war_actor(actorId)
	if wa == null:
		return
	
	var prevSke = SkillHelper.read_skill_effectinfo()
	var ske = SkillHelper.new_ske_from_cheater()
	var fpVal = wa.five_phases
	for fp in FIVE_PHASES.keys():
		if attrs.get_node(fp).disabled:
			fpVal = FIVE_PHASES[fp]
			break
	var pt = int(attrs.get_node("点数").text)
	ske.change_actor_five_phases(wa.actorId, fpVal, pt)
	var ap = int(attrs.get_node("机动").text)
	ap = max(0, ap)
	ap = min(999, ap)
	ske.change_actor_ap(wa.actorId, ap - wa.action_point)
	var x = int(attrs.get_node("X").text)
	x = max(0, x)
	x = min(31, x)
	var y = int(attrs.get_node("Y").text)
	y = max(0, y)
	y = min(18, y)
	ske.change_war_actor_position(wa.actorId, Vector2(x, y))
	
	for buff in StaticManager.WAR_BUFF_STATUSES:
		var btn = attrs.get_node_or_null(buff)
		if not btn is Button:
			continue
		var statuses = btn.editor_description.split(",")
		if not statuses.size() == 2:
			continue
		var turns = int(statuses[1])
		if wa.get_buff(buff)["回合数"] != turns:
			if turns > 0:
				ske.set_war_buff(wa.actorId, buff, turns, true)
			else:
				ske.remove_war_buff(wa.actorId, buff)
	ske.war_report()
	
	SkillHelper.save_skill_effectinfo(prevSke)
	reload_data()
	emit_signal("saved")
	return

func reset():
	reload_data()
	return

func go_basics():
	hide()
	emit_signal("basics", wvId, actorId)
	return

func toggle_buff_status(name: String) -> void :
	var btn = attrs.get_node_or_null(name)
	if btn == null or not btn is Button:
		return
	var statuses = Array(btn.editor_description.split(","))
	if statuses.size() != 2:
		return
	if int(statuses[1]) > 0:
		statuses[1] = "0"
	else:
		statuses[1] = "1"
	btn.editor_description = ",".join(statuses)
	update_buff_status(btn)
	return

func update_buff_status(btn: Button) -> void :
	var statuses = btn.editor_description.split(",")
	if statuses.size() != 2:
		return
	if int(statuses[1]) > 0:
		for t in ["hover", "pressed", "focus", "disabled", "normal"]:
			btn.add_stylebox_override(t, sbButtonHighlighted)
		for t in ["", "_pressed", "_disabled", "_hover", "_normal", "_focus"]:
			btn.add_color_override("font_color" + t, Color.black)
	else:
		for t in ["hover", "pressed", "focus", "disabled", "normal"]:
			btn.remove_stylebox_override(t)
		for t in ["", "_pressed", "_disabled", "_hover", "_normal", "_focus"]:
			btn.add_color_override("font_color" + t, Color.white)
	return
