extends "effect_20000.gd"

#清俭主动技
#【清俭】大战场，主动技。每次你恢复机动力发生溢出，溢出的机动力转为等量的“俭”标记（至多X个，X=你的等级+2）。你可以发动：你可指定1名其他己方武将，其获得你“俭”标记数量的机动力，之后你的“俭”清零。

const EFFECT_ID = 20209
const FLAG_NAME = "俭"
const FLOW_BASE = "effect_" + str(EFFECT_ID)

func effect_20209_start() -> void:
	if not assert_flag_count(me.actorId, 20000, EFFECT_ID, FLAG_NAME, 1):
		return
	var targets = get_teammate_targets(me)
	var msg = "选择队友发动【{0}】".format([
		ske.skill_name,
	])
	if not wait_choose_actors(targets, msg):
		return
	LoadControl.set_view_model(2000)
	return

func on_view_model_2000() -> void:
	wait_for_choose_actor(FLOW_BASE + "_selected")
	return

func effect_20209_selected() -> void:
	var targetId = DataManager.get_env_int("目标")
	var flag = ske.get_skill_flags(20000, EFFECT_ID, FLAG_NAME)
	var msg = "将 {1}个[{0}]\n转化为{2}的机动力\n可否？".format([
		FLAG_NAME, flag, ActorHelper.actor(targetId).get_name()
	])
	play_dialog(actorId, msg, 2, 2001, true)
	return

func on_view_model_2001() -> void:
	wait_for_yesno(FLOW_BASE + "_confirmed")
	return

func effect_20209_confirmed() -> void:
	var targetId = DataManager.get_env_int("目标")
	var flags = ske.get_skill_flags(20000, EFFECT_ID, FLAG_NAME)
	perform_cost()
	ske.change_actor_ap(targetId, flags)
	ske.war_report()
	var msg = "把握战机，只在点滴之间\n（{0}机动力增加{1}".format([
		ActorHelper.actor(targetId).get_name(), flags,
	])
	play_dialog(actorId, msg, 2, 2999)
	return

# 锁定技部分
func on_trigger_20013() -> bool:
	var exceededKey = "战争.机动力溢出.{0}".format([me.actorId])
	var apOverflow = get_env_int(exceededKey)
	if apOverflow <= 0:
		return false
	ske.add_skill_flags(20000, EFFECT_ID, FLAG_NAME, apOverflow, actor.get_level() + 2)
	ske.war_report()
	return false

func perform_cost() -> void:
	var flags = ske.get_skill_flags(20000, EFFECT_ID, FLAG_NAME)
	ske.cost_skill_flags(20000, EFFECT_ID, FLAG_NAME, flags)
	return
