extends "effect_20000.gd"

#策焰效果实现
#【策焰】大战场，锁定技。你使用[火计]，随机减少所需机动力，最多减少原消耗的1/2。

func on_trigger_20006() -> bool:
	var se = DataManager.get_current_stratagem_execution()
	if se.name != "火计":
		return false

	var settings = DataManager.get_env_int_array("计策.扣减")
	var cost = settings[0]
	var prev = settings[1]
	var current = settings[2]
	if cost <= 0:
		return false
	# 最多减到 1/2
	var reduce = int(cost/2.0)
	reduce = DataManager.pseduo_random_war() % reduce + 1
	if reduce <= 0:
		return false
	# 已经扣减了，默默返还，不需要技能日志留痕
	cost = cost - reduce
	current += reduce
	DataManager.set_env("计策.扣减", [cost, prev, current])

	var msg = "【{0}】减少计策消耗{1}".format([
		ske.skill_name, reduce,
	])
	se.append_result(ske.skill_name, msg, reduce, actorId)
	# 不需要单独做技能汇报
	return false
