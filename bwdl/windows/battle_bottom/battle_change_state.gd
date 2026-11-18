extends Control

const state_type_array = ["前进", "包围", "待机", "战术", "后退"];
const default_unit_types = ["将", "骑", "象", "弓", "步"]

var state_array = ["前进", "前进", "前进", "前进"];
var unit_type_array = ["将", "骑", "弓", "步"];
var is_init = false;

onready var lsc = get_node("lsc")

var attacking: bool = true
var actorId = - 1
var enemyId = - 1
var actorInfoState = - 1
var tipsShown: bool = false


func _ready() -> void :
	return

func init_data(targetId: int, isInit: bool = false) -> void :
	SceneManager.hide_all_tool();
	is_init = isInit
	
	var bf = DataManager.get_current_battle_fight()
	var unit_types = []
	if targetId == bf.get_defender_id():
		attacking = false
		unit_types = bf.get_defender_unit_types()
		actorId = targetId
		enemyId = bf.get_attacker_id()
	elif targetId == bf.get_attacker_id():
		unit_types = bf.get_attacker_unit_types()
		actorId = targetId
		enemyId = bf.get_defender_id()
	else:
		return

	
	if unit_types.size() == 4:
		unit_type_array.clear()
		unit_type_array.append_array(unit_types)
	else:
		unit_type_array = default_unit_types.duplicate(true)
		
		if not "象" in unit_types:
			unit_type_array.erase("象")
		for ut in unit_types:
			var loc = unit_type_array.find(ut)
			if loc < 0 or loc >= 4:
				
				unit_type_array.erase(ut)
				unit_type_array.insert(1, ut)
	unit_type_array.resize(4)
	state_array.clear()
	lsc.items.clear()
	for ut in unit_type_array:
		var st = bf.get_units_state(actorId, ut)
		state_array.append(st)
		lsc.items.append("{0}   {1}".format([ut, st]))
	lsc._set_data()

	lsc.show()
	_update_actor_data($left, actorId)
	$left.show()
	$right.hide()
	return

func _update_actor_data(con: Control, targetId: int) -> void :
	if targetId < 0:
		return
	var actor = ActorHelper.actor(targetId)
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return

	con.get_node("conActor/nprFace").set_actor(targetId)
	con.get_node("conActor/lblName").text = actor.get_name()
	_display_property_value(con.get_node("actorinfo/hp/Value"), int(ceil(actor.get_hp())), actor.get_max_hp())
	_display_property_value(con.get_node("actorinfo/str/Value"), wa.get_battle_power(), actor._get_attr_int_original("武"))
	_display_property_value(con.get_node("actorinfo/com/Value"), wa.battle_lead, actor._get_attr_int_original("统"))
	_display_property_value(con.get_node("actorinfo/cou/Value"), wa.battle_courage, actor._get_attr_int_original("胆"))
	_display_property_value(con.get_node("actorinfo/tt/Value"), wa.battle_tactic_point)
	update_top_msg()
	return

func update_top_msg():
	if state_array[0] == "包围":
		$lblTopMsg.text = "小提示：包围状态下，武将不会射箭"
		$lblTopMsg.visible = true
	elif not tipsShown:
		$lblTopMsg.text = "小提示：按「开始」键，可同时调整全兵种的行动"
		$lblTopMsg.visible = true
		tipsShown = true
	else:
		$lblTopMsg.visible = false
	return

func switch_actor_info(stepChange: int = 1) -> bool:
	SceneManager.actor_info.hide()
	$right.hide()
	lsc.show()
	_update_actor_data($left, actorId)
	if stepChange == 0:
		actorInfoState = - 1
		return false
	actorInfoState = actorInfoState + stepChange
	if actorInfoState < 0:
		actorInfoState = 2
	if actorInfoState > 2:
		actorInfoState = 0
	match actorInfoState:
		0:
			SceneManager.show_actor_info(actorId)
			return true
		1:
			var wa = DataManager.get_war_actor(actorId)
			if wa != null:
				var enemy = wa.get_battle_enemy_war_actor()
				if enemy != null:
					SceneManager.show_actor_info(enemy.actorId)
					return true
		2:
			lsc.hide()
			if attacking:
				_update_actor_data($right, enemyId)
			else:
				_update_actor_data($left, enemyId)
				_update_actor_data($right, actorId)
			$right.show()
			return true
	return true

func move_left():
	var unit_name = unit_type_array[lsc.cursor_index];
	var state_types = self.state_type_array.duplicate();
	
	if is_init or unit_name != "将":
		state_types.erase("战术")
		state_types.erase("投降")

	var current_state: String = state_array[lsc.cursor_index];
	var current_state_index: int = state_types.find(current_state);
	
	
	current_state_index -= 1;
	if (current_state_index < 0):
		current_state_index = state_types.size() - 1;
	var new_state: String = state_types[current_state_index];
	var text = "{0}   {1}".format([unit_name, new_state]);
	state_array[lsc.cursor_index] = new_state;
	lsc.set_items_text(lsc.cursor_index, text);
	update_top_msg()

func move_right():
	var unit_name = unit_type_array[lsc.cursor_index];
	var state_types = self.state_type_array.duplicate();
	
	if is_init or unit_name != "将":
		state_types.erase("战术")
		state_types.erase("投降")
	
	var current_state: String = state_array[lsc.cursor_index];
	var current_state_index: int = state_types.find(current_state);
	
	
	current_state_index += 1;
	if (current_state_index > state_types.size() - 1):
		current_state_index = 0;
	var new_state: String = state_types[current_state_index];
	var text = "{0}   {1}".format([unit_name, new_state]);
	state_array[lsc.cursor_index] = new_state;
	lsc.set_items_text(lsc.cursor_index, text);
	update_top_msg()

func move_up():
	lsc.move_up();

func move_down():
	lsc.move_down();

func get_array() -> PoolStringArray:
	return PoolStringArray(state_array.duplicate());

func get_dict() -> Dictionary:
	var ret = {}
	for i in unit_type_array.size():
		if i >= state_array.size():
			break
		ret[unit_type_array[i]] = state_array[i]
	return ret

func _display_property_value(lbl: Label, val: int, original: int = - 1):
	lbl.text = str(val)
	if original == - 1 or original == val:
		lbl.set("custom_colors/font_color", Color(0, 0, 0))
	elif original > val:
		lbl.set("custom_colors/font_color", Color(255, 0, 0))
	else:
		lbl.set("custom_colors/font_color", Color(0, 0, 255))
	return

func all_state_next():
	if state_array.empty():
		return
	var found = state_type_array.find(state_array[0])
	if found < 0:
		found = - 1
	found = (found + 1) % state_type_array.size()
	while state_type_array[found] in ["战术"]:
		found = (found + 1) % state_type_array.size()
	var state = state_type_array[found]
	for i in state_array.size():
		state_array[i] = state
		var unit_name = str(unit_type_array[i])[0];
		var text = "{0}   {1}".format([unit_name, state])
		lsc.set_items_text(i, text)
	update_top_msg()
	return

func keyin() -> void :
	if Input.is_action_just_pressed("ANALOG_UP"):
		move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		move_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		move_right()
	if Input.is_action_just_pressed("EMU_START"):
		all_state_next()
	return
