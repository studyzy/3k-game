extends "effect_20000.gd"

#同心锁定技 #胜利触发
#【同心】大战场，锁定技。你方其他武将白刃战获胜时，本回合结束前，你临时获得<策焰>和<军略>。

const BUFF_SKILLS = ["策焰", "军略"]

func on_trigger_20008() -> bool:
	if ske.actorId == actorId:
		# 自己不触发
		return false
	var winner = bf.get_winner()
	if winner == null or winner.actorId != ske.actorId:
		# 不是胜利方
		return false
	ske.cost_war_cd(1)
	for skill in BUFF_SKILLS:
		ske.add_war_skill(actorId, skill, 1)
	var msg = "同心协力，一展宏图！\n（回合结束前\n（获得【{0}】".format([
		"】【".join(BUFF_SKILLS)
	])
	me.attach_free_dialog(msg, 0)
	return false
