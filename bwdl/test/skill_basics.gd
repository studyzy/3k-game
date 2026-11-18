extends "base.gd"



const CASES = [
	["技能变量", "_case_skill_variable"], 
]

func runAll() -> bool:
	SceneManager.is_test_running = true
	SceneManager.current_scene().SCENE_ID = 10000
	var cnt = 0
	for case in CASES:
		var scene = case[0]
		var method = case[1]
		var time = Time.get_ticks_usec()
		var ret = call(method)
		time = Time.get_ticks_usec() - time
		if not ret:
			return error("{0} FAILED with {1}，耗时：{2}秒".format([
				scene, method, time / 1000.0 / 1000.0, 
			]))
		trace("{0} PASS with {1}，耗时：{2}秒".format([
			scene, method, time / 1000.0 / 1000.0, 
		]))
		cnt += 1
	trace("{0}个【技能框架】cases passed".format([cnt]))
	
	SkillHelper.remove_all_skill_trigger()
	SceneManager.is_test_running = false
	return true

func _case_skill_variable():
	trace("技能变量")
	for i in 100:
		var effectId = 10000 + randi() % 40000
		var sceneId = effectId - effectId % 10000
		var actorId = random_actor_id()
		var val = randi() % 10 + 1
		SkillHelper.set_skill_variable(sceneId, effectId, actorId, val, 2)
		var skv = SkillHelper.get_skill_variable(sceneId, effectId, actorId)
		var v = SkillHelper.get_skill_variable_int(sceneId, effectId, actorId)
		assertEqual(2, skv["turn"])
		assertEqual(val, skv["value"])
		assertEqual(val, v)
		SkillHelper.decrease_skill_variable(sceneId)
		skv = SkillHelper.get_skill_variable(sceneId, effectId, actorId)
		v = SkillHelper.get_skill_variable_int(sceneId, effectId, actorId)
		assertEqual(1, skv["turn"])
		assertEqual(val, skv["value"])
		assertEqual(val, v)
		SkillHelper.decrease_skill_variable(sceneId)
		skv = SkillHelper.get_skill_variable(sceneId, effectId, actorId)
		v = SkillHelper.get_skill_variable_int(sceneId, effectId, actorId)
		assertEqual(0, skv["turn"])
		assertEqual(null, skv["value"])
		assertEqual( - 1, v)
	return true
