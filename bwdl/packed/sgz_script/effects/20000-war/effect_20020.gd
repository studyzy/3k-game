extends "effect_20000.gd"

#曲顾效果
#【曲顾】大战场，锁定技。你的队友用计失败时，你获得其用计消耗的一半机动力。同一回合，每位队友仅限触发一次。场上其他武将拥有<顾曲>、<观星>时，你附加<抚琴>。


func on_trigger_20013() -> bool:
	ske.remove_war_skill(actorId, "抚琴")
	for wa in me.get_teammates(false, true):
		if SkillHelper.actor_has_skills(wa.actorId, ["顾曲", "观星"]):
			ske.add_war_skill(actorId, "抚琴", 99999)
			break
	ske.war_report()
	return false

func on_trigger_20009() -> bool:
	var se = DataManager.get_current_stratagem_execution()
	# 计策成功不触发
	if se.succeeded > 0:
		return false
	if se.fromId == actorId:
		# 自己不触发
		return false
	var ap = int(se.cost / 2)
	if ap <= 0:
		return false
	var triggered = ske.get_war_skill_val_int_array()
	if ske.actorId in triggered:
		return false
	triggered.append(ske.actorId)
	ske.set_war_skill_val(triggered, 1)
	ske.change_actor_ap(actorId, ap)
	var msg = "因【{0}】效果\n{1}回复{2}机动力".format([
		ske.skill_name, me.get_name(), ap
	])
	se.append_result(ske.skill_name, msg, ap, actorId)
	map.update_ap()
	return false
