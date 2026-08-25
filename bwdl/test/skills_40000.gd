# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：test/skills_40000.gd
# 说明：测试-技能组 40000。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "base.gd"

const SKILL_CASES = [
	["无前", "_case_WUQIAN_0"], 
	["无前", "_case_WUQIAN_1"], 
]

func runAll() -> bool:
	SceneManager.is_test_running = true
	SceneManager.current_scene().SCENE_ID = 40000
	var cnt = 0
	for case in SKILL_CASES:
		var skill = case[0]
		var method = case[1]
		var time = Time.get_ticks_usec()
		trace("\n==== starting {0}".format([method]))
		var ret = call(method, skill)
		time = Time.get_ticks_usec() - time
		if not ret:
			return error("{0} FAILED with {1}，耗时：{2}秒".format([
				skill, method, time / 1000.0 / 1000.0, 
			]))
		trace("==== {0} PASSED for {1}\n==== 耗时：{2}秒\n".format([
			method, skill, time / 1000.0 / 1000.0, 
		]))
		cnt += 1
	trace("{0}个【单挑技能】cases passed".format([cnt]))
	
	SkillHelper.remove_all_skill_trigger()
	SceneManager.is_test_running = false
	return true

func _case_WUQIAN_0(name: String) -> bool:
	trace("无前回体")
	var effect = _assert_lock_skill_effect_basics("无前", 40004, 40004)

	var actorId = random_actor_id()
	var enemyId = random_actor_id([actorId])
	initWar(0, 1, 0)
	var me = createWarActor(actorId, 0, true)
	var actor = me.actor()
	createWarActor(enemyId, 1, true)
	initBattle(actorId, enemyId)
	initSolo(actorId, enemyId)
	for i in 100:
		var level = 1 + randi() % 8
		actor.set_level(level)
		var damage = randi() % 30
		var currentLoss = damage - randi() % 10
		if randi() % 2 == 0:
			currentLoss = damage + randi() % 10
		var current = actor.get_max_hp() - currentLoss
		actor.set_hp(current)
		DataManager.set_env("单挑.伤害数值", damage)
		_simulate_skill_trigger(effect, actorId)
		var recover = int(damage / 100.0 * level * 5)
		assertEqual(actor.get_hp(), min(actor.get_hp(), current + recover), "体力")
	return true

func _case_WUQIAN_1(name: String) -> bool:
	trace("无前防暴击")
	var effect = _assert_lock_skill_effect_basics("无前", 40004, 40007)

	var actorId = random_actor_id()
	var enemyId = random_actor_id([actorId])
	initWar(0, 1, 0)
	var me = createWarActor(actorId, 0, true)
	var actor = me.actor()
	createWarActor(enemyId, 1, true)
	initBattle(actorId, enemyId)
	initSolo(actorId, enemyId)
	for i in 10:
		DataManager.set_env("单挑.暴击率", randi() + 10)
		_simulate_skill_trigger(effect, actorId)
		assertEqual(DataManager.get_env_int("单挑.暴击率"), 0)
	return true
