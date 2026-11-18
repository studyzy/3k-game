extends "effect_20000.gd"

# 猇烬主动技
#【猇烬】大战场，主将主动技。发动后，你执行一次机动力恢复，你的五行点数变为“火9”，本回合，你的火计将附加 {余烬} 效果。每场战争限1次。

const EFFECT_ID = 20737
const FLOW_BASE = "effect_" + str(EFFECT_ID)

func check_AI_perform_20000() -> bool:
	if me.side() != "防守方":
		return false
	if me.action_point >= 6:
		return false
	var s = StaticManager.get_stratagem("火计")
	if s.get_available_targets(actorId).empty():
		return false
	return true

func effect_20737_AI_start() -> void:
	goto_step("confirmed")
	return

func effect_20737_start() -> void:
	var msg = "发动【{0}】\n重置五行，并增强火计\n可否？".format([
		ske.skill_name
	])
	play_dialog(actorId, msg, 2, 2000, true)
	return

func on_view_model_2000() -> void:
	wait_for_yesno(FLOW_BASE + "_confirmed")
	return

func effect_20737_confirmed() -> void:
	perform_cost()
	me.recharge_action_point()
	ske.change_actor_five_phases(actorId, War_Actor.FivePhases_Enum.Fire, 9)
	ske.set_war_buff(actorId, "余烬", 1)
	ske.war_report()

	var msg = "朱焱无情，不得已而用之！"
	report_skill_result_message(ske, 2001, msg, 1)
	return

func on_view_model_2001() -> void:
	wait_for_pending_message(FLOW_BASE + "_report")
	return

func effect_20737_report() -> void:
	report_skill_result_message(ske, 2001)
	return

func perform_cost() -> void:
	ske.cost_war_cd(999)
	return
