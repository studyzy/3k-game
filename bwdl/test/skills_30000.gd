extends "base.gd"

const SKILL_CASES = [
	["束巧", "_case_SHUQIAO"], 
	["射戟", "_case_SHEJI"], 
	["长弓", "_case_CHANGGONG"], 
	["神威", "_case_SHENWEI"], 
	["勇决", "_case_YONGJUE"], 
	["烈弓", "_case_LIEGONG"], 
]

func runAll() -> bool:
	if SceneManager.is_test_running:
		return true
	SceneManager.is_test_running = true
	SceneManager.current_scene().SCENE_ID = 30000
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
	trace("{0}个【小战场技能】cases passed".format([cnt]))
	
	SkillHelper.remove_all_skill_trigger()
	SceneManager.is_test_running = false
	return true

func _case_SHUQIAO(name: String) -> bool:
	trace("束巧生效")
	var effect = _assert_lock_skill_effect_basics("束巧", 30147, 30008)

	var bt = SceneManager.current_scene().battle_tactic
	var pt = Global.load_script("battle/player_tactic.gd")

	var traced = 0
	var times = 20
	var stopTimes = 0
	var triggeredTimes = 0
	var tactics = ["咒缚", "咒缚", "咒缚", "咒缚", "士气向上", "火矢", "强弩"]
	for i in times:
		var bf = prepare_for_battle( - 1, - 1, effect)
		var me = bf.get_attacker()
		var tactic = prepare_for_tactic(tactics)
		
		pt.tactic_start()
		var result = DataManager.get_env_int("结果")
		if tactic != "咒缚":
			assertNotEqual(FlowManager.last_flow, "tactic_impact_0")
			assertNotEqual(FlowManager.last_flow, "tactic_end")
			continue
		stopTimes += 1
		var stopped = me.get_buff("咒缚")["回合数"]
		if FlowManager.last_flow == "tactic_impact_0":
			
			assertEqual(result, 1)
		else:
			
			assertEqual(result, 1)
			triggeredTimes += 1
			assertEqual(stopped, 1)
			assertEqual(FlowManager.last_flow, "tactic_end")
	trace("随机发动{0}次战术，其中{1}次为咒缚，{2}次触发束巧".format([
		times, stopTimes, triggeredTimes, 
	]))
	return true

func _case_SHEJI(name: String) -> bool:
	trace("射戟强化")
	var effect = _assert_lock_skill_effect_basics("射戟", 30010, 30024)

	
	var actor = random_actor()
	actor.set_equip(clEquip.equip(StaticManager.JEWELRY_ID_BINGSHU, "道具"))
	var bf = prepare_for_battle(actor.actorId, - 1, effect)
	var me = bf.get_attacker()
	var bu = me.battle_actor_unit()
	assertEqual(bu.get_shoot_distance(), 0)
	assertEqual(bu.get_shooting_damage_rate(), 70)

	
	bu.init_combat_info()
	actor.set_equip(clEquip.equip(StaticManager.JEWELRY_ID_WANDANGONG, "道具"))
	assertEqual(bu.get_shoot_distance(), 5)
	assertEqual(bu.get_shooting_damage_rate(), 80)
	return true

func _case_CHANGGONG(name: String) -> bool:
	trace("长弓强化")
	var effect = _assert_lock_skill_effect_basics("长弓", 30041, 30024)

	for i in 10:
		var me
		if i % 2 == 0:
			var bf = prepare_for_battle( - 1, - 1, effect)
			me = bf.get_attacker()
		else:
			var bf = prepare_for_battle( - 1, - 1, null, effect)
			me = bf.get_defender()
		for bu in DataManager.battle_units:
			if bu.get_unit_type() == "将":
				var equipDistance = bu.leader().actor().get_equip_feature_max("白兵射程")
				if bu.get_shoot_distance() != equipDistance:
					bu.get_shoot_distance()
				assertEqual(bu.get_shoot_distance(), equipDistance)
				continue
			if bu.get_unit_type() != "弓":
				assertEqual(bu.get_shoot_distance(), 0)
				continue
			if bu.leaderId == me.actorId:
				assertEqual(bu.get_shoot_distance(), 5)
			else:
				assertEqual(bu.get_shoot_distance(), 4)
	return true

func _case_SHENWEI(name: String) -> bool:
	trace("神威强化")
	var effect = _assert_lock_skill_effect_basics("神威", 30042, 30005)
	assertEqual(effect.role, "攻方")

	for i in 10:
		var bf = prepare_for_battle()
		var me = bf.get_attacker()
		if i % 2 == 1:
			me = bf.get_defender()
		var enemy = me.get_battle_enemy_war_actor()
		var a = me.battle_tactic_point
		var b = enemy.battle_tactic_point
		var level = me.actor().get_level()
		_simulate_skill_trigger(effect, me.actorId)
		if me.actorId == bf.get_attacker_id():
			assertEqual(me.battle_tactic_point, a + level)
			assertEqual(enemy.battle_tactic_point, max(0, b - level))
		else:
			assertEqual(me.battle_tactic_point, a)
			assertEqual(enemy.battle_tactic_point, b)
	return true

func _case_YONGJUE(name: String) -> bool:
	trace("勇决强化")
	var effect = _assert_lock_skill_effect_basics("勇决", 30062, 30024)

	var weapons = clEquip.all_equips("武器")
	var suits = clEquip.all_equips("防具")
	for i in 10:
		weapons.shuffle()
		suits.shuffle()
		
		var actor = random_actor()
		actor.set_equip(weapons[0])
		actor.set_equip(suits[0])
		var weight = weapons[0].weight() + suits[0].weight()
		var bf = prepare_for_battle(actor.actorId, - 1, effect)
		var me = bf.get_attacker()
		var bu = me.battle_actor_unit()
		assertEqual(bu.dic_combat["额外伤害"], weight / 100.0)
	return true

func _case_LIEGONG(name: String) -> bool:

	trace("烈弓强化")
	var effect = _assert_lock_skill_effect_basics("烈弓", 30011, 30024)

	var jewelrys = clEquip.all_equips("道具")
	for i in 10:
		jewelrys.shuffle()
		var jewelry = jewelrys[0]
		var actor = random_actor()
		actor.set_equip(jewelry)
		var bf = prepare_for_battle(actor.actorId, - 1, effect)
		var me = bf.get_attacker()
		var bu = me.battle_actor_unit()
		var equipDistance = me.actor().get_equip_feature_max("白兵射程")
		if equipDistance == 0:
			assertEqual(bu.get_shoot_distance(), 0)
		else:
			assertEqual(bu.get_shoot_distance(), equipDistance + 2)
			assertTrue(bu.is_far_shooting())
	return true

func prepare_for_battle(attackerId: int = - 1, defenderId: int = - 1, attackerEffect = null, defenderEffect = null) -> BattleFight:
	if attackerId < 0:
		attackerId = random_actor_id()
	if defenderId < 0:
		defenderId = random_actor_id([attackerId])

	
	DataManager.actor_scene_skill.clear()
	DataManager.actor_ban_scene_skill.clear()
	DataManager.skill_cd.clear()

	_remove_all_skills(attackerId)
	_remove_all_skills(defenderId)

	if attackerEffect != null:
		_attach_skill(attackerEffect, attackerId)
	if defenderEffect != null:
		_attach_skill(defenderEffect, defenderId)

	initWar(0, 1, 0)

	createWarActor(attackerId, 0, true)
	createWarActor(defenderId, 1, true)
	initBattle(attackerId, defenderId)

	return DataManager.get_current_battle_fight()

func prepare_for_tactic(tactics: Array = []) -> String:
	if tactics.empty():
		tactics = ["咒缚", "强弩", "士气向上", "火矢"]
	var bf = DataManager.get_current_battle_fight()
	var me = bf.get_attacker()
	tactics.shuffle()
	var tactic = tactics[0]
	
	var bt = SceneManager.current_scene().battle_tactic
	bt.set_select_tactic_name(tactic)
	DataManager.set_env("当前武将", me.actorId)
	
	me.battle_tactic_point = 99
	return tactic
