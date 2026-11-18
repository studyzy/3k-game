extends "effect_20000.gd"

#知遇
#【知遇】大战场,锁定技。若你非主将，且主将拥有<仁德>或<享乐>，其每回合额外恢复8点机动力；否则，你附加<抚琴>。

func on_trigger_20013()->bool:
	var leader = me.get_leader()
	if leader == null or leader.disabled:
		return false

	if actorId != leader.actorId and SkillHelper.actor_has_skills(leader.actorId, ["仁德", "享乐"]):
		ske.change_actor_ap(leader.actorId, 8)
		ske.remove_war_skill(actorId, "抚琴")
	else:
		ske.add_war_skill(actorId, "抚琴", 99999)
	ske.war_report()
	return false
