# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：test/base.gd
# 说明：测试-基础。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Reference

func trace(msg: String):
	SceneManager.current_scene().trace(msg)
	return

func warn(msg: String):
	return trace("[color=blue]注意：" + msg + "[/color]")

func error(msg: String):
	return trace("[color=red]注意：" + msg + "[/color]")



func runAll() -> bool:
	return true


func calculate_variance(data_array):
	var n = data_array.size()
	
	if n == 0:
		return 0.0
	
	var sum = 0.0
	var mean = 0.0
	
	
	for i in range(n):
		sum += data_array[i]
	mean = sum / n
	
	
	var variance = 0.0
	for i in range(n):
		variance += (data_array[i] - mean) * (data_array[i] - mean)
	variance /= n
	variance /= mean
	variance = sqrt(variance)
	
	return variance


func initAffair(vstateId: int, isAI: bool = false):
	SceneManager.current_scene().SCENE_ID = 10000
	DataManager.vstate_no = 0
	DataManager.vstates_sort = [vstateId]
	return


func initWar(attackVstateId: int, defendVstateId: int, cityId: int) -> WarFight:
	var wf = DataManager.new_war_fight( - 1, cityId)
	wf.fromVstateId = attackVstateId
	wf.targetVstateId = defendVstateId
	SceneManager.current_scene().SCENE_ID = 20000
	var wvs = []
	var wvInfo = [["防守方", defendVstateId], ["攻击方", attackVstateId]]
	for row in wvInfo:
		var wv = War_Vstate.new(row[1])
		wv.side = row[0]
		wv.from_cityId = - 1
		wv.init_actors = []
		wv.main_actorId = - 1
		wv.from_cityId = - 1
		wv.money = 1000
		wv.rice = 1000
		wv.settled = 0
		wvs.append(wv)
	wf.defenderWV = wvs[0]
	wf.attackerWV = wvs[1]
	wf.defenderWV.from_cityId = cityId
	
	wf.init_war()
	return wf

func createWarActor(actorId: int, wvId: int, append: bool = false, vstateId: int = - 1) -> War_Actor:
	if vstateId < 0:
		vstateId = wvId
	var wf = DataManager.get_current_war_fight()
	var wa = War_Actor.new(vstateId, wvId)
	wa.actorId = actorId
	wa.action_point = 0
	wa.init_AI()
	if append:
		wa.disabled = false
		wa.position = Vector2( - 1, - 1)
		wa.recharge_action_point(true)
		wa.refresh_poker_random()
		var wv = wf.get_war_vstate(wvId)
		wv.init_actors.append(wa.actorId)
		wv.add_war_actor(wa)
		
		if wv.main_actorId < 0:
			wv.main_actorId = actorId
	return wa


func initBattle(attackerId: int, defenderId: int):
	SceneManager.current_scene().SCENE_ID = 30000
	DataManager.battle_units.clear()
	var bf = DataManager.new_battle_fight(attackerId)
	bf.set_target(defenderId)
	bf.get_attacker().battle_init()
	bf.get_defender().battle_init()
	createBattleUnit(attackerId, "将")
	createBattleUnit(attackerId, "骑")
	createBattleUnit(attackerId, "弓")
	createBattleUnit(attackerId, "步")
	createBattleUnit(attackerId, "象")
	createBattleUnit(defenderId, "将")
	createBattleUnit(defenderId, "骑")
	createBattleUnit(defenderId, "弓")
	createBattleUnit(defenderId, "步")
	createBattleUnit(defenderId, "象")
	return

func createBattleUnit(actorId: int, type: String) -> Battle_Unit:
	var bu = Battle_Unit.new(actorId)
	bu.unitId = DataManager.battle_units.size()
	bu.leaderId = actorId
	bu.direction = 1
	bu.Type = type
	bu._private_hp = 99
	bu.disabled = false
	bu.unit_position = Vector2(5, 5)
	DataManager.battle_units.append(bu)
	bu.formation_init(type)
	return bu


func initSolo(attackerId: int, defenderId: int):
	SceneManager.current_scene().SCENE_ID = 40000
	
	return

func assertEqual(val, expected, msg: String = ""):
	var failed = false
	if typeof(val) in [TYPE_ARRAY, TYPE_STRING_ARRAY, TYPE_INT_ARRAY]:
		expected = Global.arrval(expected)
		if expected.size() != val.size():
			failed = true
		else:
			for i in val.size():
				assertEqual(val[i], expected[i], msg)
			return
	else:
		failed = val != expected
		if typeof(val) == TYPE_REAL and typeof(expected) == TYPE_REAL:
			failed = val - expected > 0.001
			failed = false
	if failed:
		msg = "{0} 对比异常，{1} != {2}".format([
			msg, val, expected
		])
		error(msg)
		assert (false, msg)
	return

func assertLess(val, expected, msg: String = ""):
	var failed = val >= expected
	if failed:
		msg = "{0} 对比异常，{1} >= {2}".format([
			msg, val, expected
		])
		error(msg)
		assert (false, msg)
	return

func assertNotEqual(val, expected, msg: String = ""):
	if val == expected:
		msg = "{0} 对比异常，{1} == {2}".format([
			msg, val, expected
		])
		error(msg)
		assert (false, msg)
	return

func assertIn(val, expected, msg):
	if not val in expected:
		msg = "{0} 检查异常，{1} not in {2}".format([
			msg, val, expected
		])
		error(msg)
		assert (false, msg)
	return

func assertTrue(val, msg: String = ""):
	if not val:
		msg = "{0} 判真检查异常，{1}".format([
			msg, val
		])
		error(msg)
		assert (false, msg)
	return

func random_city() -> clCity.CityInfo:
	return clCity.city(random_city_id())

func random_city_id() -> int:
	return randi() % DataManager.citys.size()

func random_actor(excepts: PoolIntArray = []) -> ActorHelper.ActorInfo:
	return ActorHelper.actor(random_actor_id(excepts))

func random_actor_id(excepts: PoolIntArray = []) -> int:
	var ret = randi() % DataManager.actors.size()
	while ret in excepts:
		ret = randi() % DataManager.actors.size()
	return ret

func is_lord(actorId: int) -> bool:
	for vs in clVState.all_vstates():
		if vs.id == actorId:
			return true
	return false

func set_skill_var_int(actorId: int, effectId: int, val, sceneId: int = - 1):
	if sceneId < 0:
		sceneId = effectId - effectId % 10000
	SkillHelper.set_skill_variable(sceneId, effectId, actorId, val, 1)
	return

func get_skill_var_int(actorId: int, effectId: int, sceneId: int = - 1) -> int:
	if sceneId < 0:
		sceneId = effectId - effectId % 10000
	var skv = SkillHelper.get_skill_variable(sceneId, effectId, actorId)
	if skv["turn"] <= 0:
		return 0
	if typeof(skv["value"]) != TYPE_INT:
		return 0
	return int(skv["value"])

func prepare_ske(actorId: int, effect: StaticManager.SkillEffect, triggerActorId: int = - 1) -> SkillEffectInfo:
	if triggerActorId < 0:
		triggerActorId = actorId
	var ske = effect.create_ske_for(actorId)
	ske.actorId = triggerActorId
	ske.skill_actorId = actorId
	SkillHelper.save_skill_effectinfo(ske)
	return ske

func _assert_special_skill_effect_basics(skillName: String) -> StaticManager.SkillEffect:
	var skill = StaticManager.get_skill(skillName)
	assertEqual(skill.name, skillName, "技能名")
	var effects = skill.effects
	for effect in effects:
		if effect.type != "特殊":
			continue
		if effect.id != - 1:
			continue
		if effect.triggerId != - 1:
			continue
		if effect.triggerType != "":
			continue
		return effect
	return null

func _assert_lock_skill_effect_basics(skillName: String, effectId: int, triggerId: int, triggerType: String = "自己") -> StaticManager.SkillEffect:
	var skill = StaticManager.get_skill(skillName)
	assertEqual(skill.name, skillName, "技能名")
	var effects = skill.effects
	for effect in effects:
		if effect.id != effectId:
			continue
		if effect.triggerId != triggerId:
			continue
		if effect.triggerType != triggerType:
			continue
		assertEqual(effect.type, "锁定")
		var gd = Global.load_script(effect.path)
		gd.check_trigger_correct()
		return effect
	assert (false, "未找到技能效果：\n【{0}】.{1}.{2}.{3}".format([
		skillName, effectId, triggerId, triggerType
	]))
	return null

func _assert_active_skill_effect_basics(skillName: String, effectId: int) -> StaticManager.SkillEffect:
	var skill = StaticManager.get_skill(skillName)
	assertEqual(skill.name, skillName, "技能名")
	assertEqual(skill.type, "主动", "技能类型")
	for effect in skill.effects:
		if effect.id != effectId:
			continue
		if effect.type != "主动":
			continue
		assertEqual(effect.triggerId, - 1)
		assertEqual(effect.triggerType, "")
		var gd = Global.load_script(effect.path)
		gd.check_trigger_correct()
		return effect
	return null

func _remove_all_skills(actorId: int, excepted: PoolStringArray = [], updateBuff: bool = true) -> void :
	
	for skillName in SkillHelper.get_actor_default_skill_names(actorId).values():
		if skillName == "" or skillName in excepted:
			continue
		SkillHelper.ban_actor_skill(10000, actorId, skillName, 1)
	
	for skillName in SkillHelper.get_actor_skill_names(actorId):
		if skillName in excepted:
			continue
		SkillHelper.ban_actor_skill(10000, actorId, skillName, 1)
	if updateBuff:
		SkillHelper.update_all_skill_buff("TEST-REMOVE")
	return

func _attach_skill(effect, actorId: int) -> void :
	
	_remove_all_skills(actorId, [], false)
	
	SkillHelper.clear_ban_actor_skill( - 1, [actorId], [effect.skill.name])
	
	SkillHelper.add_actor_scene_skill(effect.sceneId, actorId, effect.skill.name, 1)
	
	DataManager.skill_cd.clear()
	SkillHelper.update_all_skill_buff("TEST-ATTACH")
	return

func _attach_random_city(actorId: int) -> clCity.CityInfo:
	ActorHelper.actor(actorId).set_status_officed()
	var cityId = random_city_id()
	var city = clCity.city(cityId)
	clCity.move_out(actorId)
	city.clear_actors()
	city.add_actor(actorId)
	return city

func _simulate_skill_trigger(effect, actorId: int, attachSkill: bool = true) -> SkillEffectInfo:
	if attachSkill:
		_attach_skill(effect, actorId)
	SkillHelper.auto_trigger_skill(actorId, effect.triggerId, "none")
	return effect.create_ske_for(actorId)

func _simulate_effect_step(ske: SkillEffectInfo, effect: StaticManager.SkillEffect, step: String) -> void :
	SkillHelper.save_skill_effectinfo(ske)
	var script = Global.load_script(effect.path)
	var method = "effect_{0}_{1}".format([effect.id, step])
	script.call(method)
	return
