extends "effect_20000.gd"

# 抚琴主动技
#【抚琴】大战场，主动技。你焚香操琴，给沉闷的战场带来一些安宁：你消耗X点体力，使己方其他武将机动力+3，体力+5，每回合限一次。X=你方人数-1。同一回合，你方<抚琴>限1次。

const EFFECT_ID = 20735
const FLOW_BASE = "effect_" + str(EFFECT_ID)

const AP_BONUS = 3
const HP_BONUS = 5

func check_AI_perform_20000() -> bool:
	if ske.is_war_common_cd():
		return false
	var teammates = me.get_teammates(false, true)
	if teammates.size() == 0:
		return false
	var hp = actor.get_hp()
	# 体力保护
	if hp <= teammates.size() or hp < 20:
		return false
	return true

func effect_20735_AI_start() -> void:
	goto_step("confirmed")
	return

func effect_20735_start() -> void:
	if ske.is_war_common_cd():
		var msg = "余音犹在，何必嘲哳？\n（本回合不可再次【{0}】".format([ske.skill_name])
		play_dialog(actorId, msg, 2, 2999)
		return

	var teammates = me.get_teammates(false, true)
	var cost = teammates.size()

	if cost == 0:
		var msg = "既无知音\n【{0}】谁听？".format([ske.skill_name])
		play_dialog(actorId, msg, 2, 2999)
		return

	if actor.get_hp() <= cost:
		var msg = "体力不足\n须 > {0}".format([cost])
		play_dialog(actorId, msg, 3, 2999)
		return

	var msg = "消耗{0}体，发动【{1}】\n队友机动力+{2}，体力+{3}\n可否？".format([
		cost, ske.skill_name, AP_BONUS, HP_BONUS,
	])
	play_dialog(actorId, msg, 2, 2000, true)
	return

func on_view_model_2000() -> void:
	wait_for_yesno(FLOW_BASE + "_confirmed")
	return

func effect_20735_confirmed() -> void:
	var teammates = me.get_teammates(false, true)
	var cost = teammates.size()

	perform_cost()

	for teammate in teammates:
		ske.change_actor_ap(teammate.actorId, AP_BONUS, false)
		ske.change_actor_hp(teammate.actorId, HP_BONUS)
	SkillHelper.update_all_skill_buff(ske.skill_name)
	ske.war_report()

	var msg = "焚香操琴，以安军心\n（消耗{0}体力".format([cost])
	report_skill_result_message(ske, 2001, msg, 1)
	return

func on_view_model_2001() -> void:
	wait_for_pending_message(FLOW_BASE + "_report")
	return

func effect_20735_report() -> void:
	report_skill_result_message(ske, 2001)
	return

func perform_cost() -> void:
	var teammates = me.get_teammates(false, true)
	var cost = teammates.size()
	ske.cost_war_cd(1)
	ske.set_war_common_cd()
	ske.cost_hp(cost)
	return
