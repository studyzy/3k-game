# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/effects_base.gd
# 说明：特效基类。定义战场特效的通用接口与生命周期。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "clEnvBase.gd"

const KEY_VALUE = "值"
const KEY_RESULTS = "结果"


var actorId: int = - 1


var triggerId: int = - 1


var ske: SkillEffectInfo


var actor: ActorHelper.ActorInfo


var me: War_Actor


var enemy: War_Actor


var enemyActor: ActorHelper.ActorInfo


var wf: WarFight


var bf: BattleFight


var map

var trace = false

func _init() -> void :
	init_vars()
	auto_bind_flow_methods()
	return

func _input_key(delta: float):
	var method = "on_view_model_{0}".format([get_view_model()])
	if has_method(method):
		return call(method)
	method += "_delta"
	if has_method(method):
		return call(method, delta)
	return

func get_view_model() -> int:
	return LoadControl.get_view_model()

func set_view_model(vm: int) -> void :
	LoadControl.set_view_model(vm)
	return


func init_vars():
	ske = SkillHelper.read_skill_effectinfo()
	if ske != null:
		actorId = ske.skill_actorId
		triggerId = ske.trigger_Id
		actor = ActorHelper.actor(actorId)
	wf = DataManager.get_current_war_fight()
	return


func auto_bind_flow_methods() -> void :
	for k in get_method_list():
		if k.name.begins_with("effect_"):
			FlowManager.bind_import_flow(k.name, self)
		if k.name == "back_to_skill_menu":
			FlowManager.bind_import_flow(k.name, self)
	return


func goto_step(step: String) -> void :
	LoadControl.set_view_model( - 1)
	var nextFlow = "effect_{0}_{1}".format([ske.effect_Id, step])
	FlowManager.add_flow(nextFlow)
	return

func skill_name():
	return DataManager.player_choose_skill;


func check_trigger_correct() -> bool:
	var method = "on_trigger_{0}".format([ske.trigger_Id])
	if has_method(method):
		return call(method)
	return false


func check_AI_perform() -> bool:
	return false

func is_flow():
	return true;

func trace(info):
	if self.trace:
		print(info)


func appended_skill_list() -> PoolStringArray:
	return PoolStringArray([])


func get_actor_names(targetIds: PoolIntArray) -> PoolStringArray:
	var names = []
	for targetId in targetIds:
		if names.size() >= 3:
			break
		names.append(ActorHelper.actor(targetId).get_name())
	if targetIds.size() > 3:
		names[names.size() - 1] += "等{0}人".format([targetIds.size()])
	return names




func skill_end_clear(clearNextFlow: bool = false):
	if map != null:
		map.clear_can_choose_actors()
	LoadControl.end_script()
	var st = SkillHelper.get_current_skill_trigger()
	if st != null:
		st.wait = false
		if clearNextFlow:
			st.next_flow = ""
	return



func get_skill_triggered_times(actorId: int, effectId: int, sceneId: int = - 1) -> int:
	if sceneId < 0:
		sceneId = effectId - effectId % 10000
	var skv = SkillHelper.get_skill_variable(sceneId, effectId, actorId)
	if skv["turn"] <= 0 or skv["value"] == null:
		return 0
	return Global.intval(skv["value"])



func inc_skill_triggered_times(actorId: int, effectId: int, turns: int = - 1, sceneId: int = - 1) -> int:
	if sceneId < 0:
		sceneId = effectId - effectId % 10000
	if turns < 0:
		turns = 1
	var times = get_skill_triggered_times(actorId, effectId, sceneId)
	SkillHelper.set_skill_variable(sceneId, effectId, actorId, times + 1, turns)
	return times + 1



func clear_skill_triggered_times(actorId: int, effectId: int, sceneId: int = - 1):
	if sceneId < 0:
		sceneId = effectId - effectId % 10000
	SkillHelper.set_skill_variable(sceneId, effectId, actorId, 0, 0)
	return


func change_stratagem_list(actorId: int, schemes: Array, msg: String = ""):
	set_env("战争.计策列表", schemes)
	if msg != "":
		set_env("战争.计策提示", msg)
	return




func get_target_id(targetIds: PoolIntArray) -> int:
	for targetId in targetIds:
		if SkillRangeBuff.max_val_for_actor("技能强制选中", targetId) > 0:
			var wa = DataManager.get_war_actor(targetId)
			if me.is_enemy(wa):
				return targetId
	return DataManager.get_env_int("目标")




func cost_action_point(wa: War_Actor, ap: int, isActiveSkill: bool = true) -> int:
	if ap <= 0:
		return 0
	ap = min(ap, wa.action_point)
	wa.action_point -= ap
	if isActiveSkill:
		set_env("战争.技能消耗机动力", ap)
		
		SkillHelper.auto_trigger_skill(wa.actorId, 20032, "")
		unset_env("战争.技能消耗机动力")
	return ap


func wait_for_skill_option(backFlow: String = "", endOnBack: bool = false) -> int:
	if backFlow != "" and Global.is_action_pressed_BY():
		if not SceneManager.dialog_msg_complete():
			return - 1
		if endOnBack:
			LoadControl.end_script()
		LoadControl.set_view_model( - 1)
		FlowManager.add_flow(backFlow)
		return - 1
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		SceneManager.actor_dialog.lsc.move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		SceneManager.actor_dialog.lsc.move_right()
	if Input.is_action_just_pressed("ANALOG_UP"):
		SceneManager.actor_dialog.lsc.move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		SceneManager.actor_dialog.lsc.move_down()
	if not Global.is_action_pressed_AX():
		return - 1
	if not SceneManager.dialog_msg_complete(true):
		return - 1
	return SceneManager.actor_dialog.lsc.cursor_index

func wait_for_multiple_number_input(nextFlow: String) -> void :
	var con = SceneManager.input_numbers
	var current = con.get_current_input_node()
	if Input.is_action_just_pressed("ANALOG_UP"):
		current.cursor_number_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		current.cursor_number_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		current.cursor_move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		current.cursor_move_right()
	if Input.is_action_just_pressed("EMU_SELECT"):
		current.set_number(current.min_number)
	if Input.is_action_just_pressed("EMU_START"):
		current.set_number(current.max_number)
	if Global.is_action_pressed_BY():
		if not con.is_msg_complete():
			return
		if con.pre_input_index():
			current = SceneManager.input_numbers.get_current_input_node()
			current.set_number(0, true)
			return
		back_to_skill_menu()
		return
	if not Global.is_action_pressed_AX():
		return
	if not con.is_msg_complete():
		con.show_all_msg()
		return

	var numbers = con.get_numbers()
	DataManager.set_env("多项数值", numbers)
	var total = 0
	for n in numbers:
		total += n
	var number = current.get_number()
	if not con.is_last_input():
		con.next_input_index()
		return
	elif total > 0:
		LoadControl.set_view_model( - 1)
		FlowManager.add_flow(nextFlow)
	return


func back_to_skill_menu():
	return
