extends "effect_20000.gd"

#骁勇大战场锁定效果 #解除状态
#【骁勇】大战场，主动技。每个回合限1次，消耗1机动力发动：你可选择回到前3~10步之内的任意位置。以此效果进行位移后，若你相邻存在可攻击的敌将，你必须与其中一名敌将进入白刃战，并在本次白刃战结束之前，禁用对手所有技能。

const EFFECT_ID = 20012
const XIAOYONG_EFFECT_ID = 20013

#记录历史移动
func on_trigger_20003() -> bool:
	var dic = ske.get_war_skill_val_dic()
	var move_type = DataManager.get_env_int("移动")
	var move_history = DataManager.get_env_array("历史移动记录")
	
	var move_record:Array = []
	if dic.has("骁勇-历史坐标"):
		move_record = dic["骁勇-历史坐标"]

	match move_type:
		0: #开始或结束移动
			pass
		1: #移动1步
			if not move_history.empty():
				move_record.append(move_history[move_history.size()-1])
		-1: #撤销1步
			if not move_record.empty():
				move_record.pop_back()
	if move_record.size() > 10:
		#超过10时，切割旧数据
		move_record = move_record.slice(move_record.size()-10, move_record.size()-1)
	
	dic["骁勇-历史坐标"] = move_record
	ske.set_war_skill_val(dic)
	return false

# 白兵结束，清除沉默状态和可能的骁勇标记
func on_trigger_20020() -> bool:
	var enemy = me.get_battle_enemy_war_actor()

	var flag = get_skill_triggered_times(actorId, XIAOYONG_EFFECT_ID)
	# 无条件清除骁勇标记
	clear_skill_triggered_times(actorId, XIAOYONG_EFFECT_ID)
	if flag <= 0:
		return false
	# 如果有骁勇标记，战斗结束，解除沉默效果
	var buff = enemy.get_buff("沉默")
	if buff["回合数"] > 0 and buff["来源武将"] == actorId:
		ske.remove_war_buff(enemy.actorId, "沉默")
		ske.war_report()
	return false
