extends Control

onready var lblTitle = get_node("lblTitle")
onready var lsc = get_node("lsc")
onready var conActor = get_node("conActor")
onready var nprFace = get_node("conActor/nprFace")
onready var lblName = get_node("conActor/lblName")
onready var txtDescription = get_node("txtDescription")


var tacticList = []

var skillList = []

var itactic;
var _actorId;


func _ready() -> void :
	itactic = Global.load_script(DataManager.mod_path + "sgz_script/battle/ITactic.gd")
	return

func init_data(actorId: int):
	_actorId = actorId
	var wa = DataManager.get_war_actor(actorId)
	var tactics = itactic.get_actor_tactic(actorId)
	tacticList.clear()
	skillList.clear()
	lsc.items = []

	lblTitle.text = "战术值     {0}".format([wa.battle_tactic_point])
	if wa.get_buff_label_turn(["战术禁用"]) > 0:
		lblTitle.text = "战术（禁用）".format([wa.battle_tactic_point])
	
	var desparateFight = wa.get_buff_label_turn(["全军死战"]) > 0
	for tactic in tactics:
		if desparateFight and not tactic in ["咒缚", "挑衅"]:
			continue
		var isSkill: bool = "<" in tactic
		if not isSkill:
			var cost = itactic.get_tactic_cost(wa, tactic)
			var text = "{0}  {1}".format([tactic, cost])
			lsc.items.append(text)
			tacticList.append(tactic)
		else:
			skillList.append(tactic)
	if lsc.items.size() + skillList.size() <= 6:
		for skill in skillList:
			var text = "{0}  ★".format([skill.replace("<", "").replace(">", "")])
			tacticList.append(skill)
			lsc.items.append(text)
	else:
		tacticList.append("主动技")
		lsc.items.append("主动技 >>")
	lsc._set_data()

	nprFace.set_actor(actorId)
	lblName.text = ActorHelper.actor(actorId).get_name()
	show_description()
	return

func show_active_skills() -> void :
	lblTitle.text = "主动技"
	tacticList.clear()
	lsc.items = []
	for skill in skillList:
		var text = "{0}  ★".format([skill.replace("<", "").replace(">", "")])
		lsc.items.append(text)
		tacticList.append(skill)
	lsc._set_data()
	lsc.cursor_index = 0
	show_description()
	return


func get_select_tactic_name() -> String:
	if lsc.cursor_index < 0:
		return ""
	if lsc.cursor_index >= tacticList.size():
		return ""
	return tacticList[lsc.cursor_index]

func show_description(tacticName: String = ""):
	if tacticName == "":
		tacticName = get_select_tactic_name()
	var description = ""
	if tacticName == "":
		description = ""
	elif tacticName == "主动技":
		description = "　武将有多个小战场主动技\n　可选择发动"
	elif tacticName.match ("<*>"):
		var skillName = tacticName.trim_prefix("<").trim_suffix(">")
		var skill = StaticManager.get_skill(skillName)
		if skill != null:
			description = skill.get_runtime_description(_actorId)
	else:
		description = "【{0}】{1}".format([tacticName, itactic.get_tactic_description(_actorId, tacticName)])
	txtDescription.bbcode_text = description;
	txtDescription.show()
	return

func hide_description():
	txtDescription.hide()
	return

func move_up():
	lsc.move_up()
	show_description()
	return

func move_down():
	lsc.move_down()
	show_description()
	return

func move_left():
	lsc.move_left()
	show_description()
	return

func move_right():
	lsc.move_right()
	show_description()
	return

func _process(delta: float) -> void :
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 408)
	return

func reset_layout_portrait():
	rect_position = Vector2(20, 408)
	return
