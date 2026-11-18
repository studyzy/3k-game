extends Panel

onready var unit = $unit
onready var units = $units

var leaderId: int = - 1

func _ready() -> void :
	reload_data()
	return

func reload_data() -> void :
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	if leaderId < 0:
		return
	var wa = DataManager.get_war_actor(leaderId)
	if wa == null:
		return
	Global.clearNode(units)
	for bu in bf.battle_units(wa.actorId):
		var node = unit.duplicate()
		node.editor_description = str(bu.unitId)
		var type = bu.get_unit_type()
		if type == "城门":
			type = "门"
		node.get_node("name").text = "{0}#{1}{2}".format([
			type, "0" if bu.unitId < 10 else "", bu.unitId, 
		])
		node.get_node("hp").text = str(int(ceil(bu.get_hp())))
		node.get_node("hp").editor_description = type
		node.get_node("X").text = str(bu.unit_position.x)
		node.get_node("Y").text = str(bu.unit_position.y)
		node.show()
		units.add_child(node)
	return

func save_data() -> void :
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	
	var prevSke = SkillHelper.read_skill_effectinfo()
	var ske = SkillHelper.new_ske_from_cheater()
	for child in units.get_children():
		var unitId = int(child.editor_description)
		var bu = bf.battle_unit(unitId)
		if bu == null:
			continue
		var hp = int(child.get_node("hp").text)
		var change = hp - int(ceil(bu.get_hp()))
		if change != 0:
			ske.battle_change_unit_hp(bu, change)
		var name = child.get_node("name").text
		var x = int(child.get_node("X").text)
		var y = int(child.get_node("Y").text)
		var pos = Vector2(x, y)
		if pos != bu.unit_position:
			bu.unit_position = pos
			var msg = "将{0}移动到<{1},{2}>".format([
				name, pos.x, pos.y
			])
			ske.append_message(msg)
	ske.battle_report()
	
	SkillHelper.save_skill_effectinfo(prevSke)
	reload_data()
	return

func full_data():
	for child in units.get_children():
		var hp = child.get_node("hp")
		if hp.editor_description == "将":
			hp.text = "99"
		else:
			hp.text = "300"
	return
