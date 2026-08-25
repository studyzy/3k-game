# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：test/skills_20000.gd
# 说明：测试-技能组 20000。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "base.gd"

const SKILL_CASES = [
	
	["断肠", "_case_DUANCHANG_20024"], 
	["无言", "_case_WUYAN_20024"], 
	["天运", "_case_TIANYUN_20024"], 
	["卫士", "_case_WEISHI_20024"], 
	["中断", "_case_STOP"], 
	
	["天命", "_case_TIANMING_0"], 
	["天命", "_case_TIANMING_1"], 
	["狂言", "_case_KUANGYAN_0"], 
	["狂言", "_case_KUANGYAN_1"], 
	["智愚", "_case_ZHIYU_0"], 
	["智愚", "_case_ZHIYU_1"], 
	["长风", "_case_CHANGFENG_0"], 
	["长风", "_case_CHANGFENG_1"], 
	["长风", "_case_CHANGFENG_2"], 
	["长风", "_case_CHANGFENG_3"], 
	["顾局", "_case_GUJU_0"], 
	["顾局", "_case_GUJU_1"], 
	["顾局", "_case_GUJU_2"], 
	["进策", "_case_JINCE_0"], 
	["进策", "_case_JINCE_1"], 
	["溃围", "_case_KUIWEI_0"], 
	["水憩", "_case_SHUIQI"], 
]

func runAll() -> bool:
	SceneManager.is_test_running = true
	SceneManager.current_scene().SCENE_ID = 20000
	var cnt = 0
	for case in SKILL_CASES:
		var skill = case[0]
		var method = case[1]
		var time = Time.get_ticks_usec()
		trace("\n==== starting {0}".format([method]))
		var ret = call(method, skill)
		time = Time.get_ticks_usec() - time
		if not ret:
			error("{0} FAILED with {1}，耗时：{2}秒".format([
				skill, method, time / 1000.0 / 1000.0, 
			]))
			break
		trace("==== {0} PASSED for {1}\n==== 耗时：{2}秒\n".format([
			method, skill, time / 1000.0 / 1000.0, 
		]))
		cnt += 1
	trace("{0}个【大战场技能】cases passed".format([cnt]))
	
	SkillHelper.remove_all_skill_trigger()
	SceneManager.is_test_running = false
	return true

func _case_DUANCHANG_20024(name: String) -> bool:
	trace("断肠禁用计策效果")
	var effect = _assert_lock_skill_effect_basics("断肠", 20124, 20024, "敌方")

	_assert_scheme_forbidden(effect, "__FIVE_PHASES__=='木' or __FIVE_PHASES__=='火'", true)
	return true

func _case_WUYAN_20024(name: String) -> bool:
	trace("无言禁用计策效果")
	var effect = _assert_lock_skill_effect_basics("无言", 20164, 20024)

	_assert_scheme_forbidden(effect, "", false, - 1, ["_WUYAN_setup"])
	return true

func _WUYAN_setup(actorId: int) -> void :
	var wa = DataManager.get_war_actor(actorId)
	wa.actor().set_initial_vstate_id(wa.get_enemy_war_vstate().vstate().id)
	return

func _case_TIANYUN_20024(name: String) -> bool:
	trace("天运禁用计策效果")
	var effect = _assert_lock_skill_effect_basics("天运", 20300, 20024)

	_assert_scheme_forbidden(effect, "", false, 49, ["_TIANYUN_setup"])
	return true

func _TIANYUN_setup(actorId: int) -> void :
	var wa = DataManager.get_war_actor(actorId)
	var lord = ActorHelper.actor(wa.get_lord_id())
	lord.set_moral(51 + randi() % 49)
	return

func _case_WEISHI_20024(name: String) -> bool:
	trace("卫士禁用计策效果")
	var effect = _assert_lock_skill_effect_basics("卫士", 20325, 20024)

	
	_assert_scheme_forbidden(effect, "", false, random_actor_id())
	return true

func _case_TIANMING_0(name: String) -> bool:
	trace("天命点数和机动力")
	var effect = _assert_lock_skill_effect_basics("天命", 20299, 20013)
	
	assertTrue(effect.skill.valid_for_actor(49))
	for i in 10:
		assertTrue( not effect.skill.valid_for_actor(random_actor_id([49])))

	var traced = 0
	for i in 20:
		var actorId = 49
		if i % 2 == 0:
			actorId = random_actor_id([49])
		var actor = ActorHelper.actor(actorId)
		initWar(0, 1, 0)
		var me = createWarActor(actorId, 0, true)
		var enemyId = random_actor_id([actorId])
		var enemy = createWarActor(enemyId, 1, true)

		me.set_poker_point(0)
		me.action_point = 0
		_simulate_skill_trigger(effect, actorId)
		var msg = "{0}因【{1}】点数为{2}，机动{3}".format([
			me.get_name(), effect.skill.name, 
			me.poker_point, me.action_point
		])
		if traced < 5:
			traced += 1
			trace(msg)
		if actorId == 49:
			assertEqual(me.poker_point, 9, msg)
			assertEqual(me.action_point, me.get_max_action_ap(), msg)
		else:
			assertEqual(me.poker_point, 0, msg)
			assertEqual(me.poker_point, 0, msg)
		me.set_poker_point(20)
		me.action_point = me.get_max_action_ap() + 10
		_simulate_skill_trigger(effect, actorId)
		msg = "{0}因【{1}】点数为{2}，机动{3}".format([
			me.get_name(), effect.skill.name, 
			me.poker_point, me.action_point
		])
		if traced < 5:
			traced += 1
			trace(msg)
		if actorId == 49:
			assertEqual(me.poker_point, 9, msg)
			assertEqual(me.action_point, me.get_max_action_ap() + 10, msg)
		else:
			assertEqual(me.poker_point, 20, msg)
			assertEqual(me.action_point, me.get_max_action_ap() + 10, msg)
	return true

func _case_TIANMING_1(name: String) -> bool:
	trace("天命计防效果")
	var effect = _assert_lock_skill_effect_basics("天命", 20299, 20017, "敌方")

	_assert_scheme_chance_change(
		"__TARGET_ID__==49", "-int((__RAW_RATE__ + 1) / 2)", 
		false, false, null, null, null, effect, 
		- 1, 49)
	return true

func _case_KUANGYAN_0(name: String) -> bool:
	trace("狂言对话")
	var effect = _assert_lock_skill_effect_basics("狂言", 20175, 20009)

	var wf = prepare_war_scheme()
	var se = DataManager.get_current_stratagem_execution()
	var me = DataManager.get_war_actor(se.get_action_id())
	var enemy = DataManager.get_war_actor(se.targetId)

	trace("计策失败不触发狂言对话")
	se.succeeded = 0
	_simulate_skill_trigger(effect, me.actorId)
	assertEqual(me.wait_dialogs.size(), 0)

	trace("计策成功触发狂言对话")
	se.succeeded = 1
	_simulate_skill_trigger(effect, me.actorId)
	assertEqual(me.wait_dialogs.size(), 1)
	var d = me.wait_dialogs[0]
	assertEqual(d.actorId, me.actorId)
	assertEqual(d.mood, 1)
	assertEqual(d.sceneId, 20000)
	assertTrue(me.get_name() in d.text)
	assertTrue(wf.target_city().get_full_name() in d.text)
	trace("狂言对话：" + d.text)
	return true

func _case_KUANGYAN_1(name: String) -> bool:
	trace("狂言计策视为技能")
	var effect = _assert_lock_skill_effect_basics("狂言", 20175, 20018)

	var wf = prepare_war_scheme()
	var se = DataManager.get_current_stratagem_execution()
	var me = DataManager.get_war_actor(se.get_action_id())
	var enemy = DataManager.get_war_actor(se.targetId)

	_simulate_skill_trigger(effect, me.actorId)
	assertEqual(se.work_as_skill, 1)
	
	
	
	return true

func _case_ZHIYU_0(name: String) -> bool:
	trace("智愚启动")
	var effect = _assert_lock_skill_effect_basics("智愚", 20031, 20012)

	var wf = prepare_war_scheme()
	var se = DataManager.get_current_stratagem_execution()
	var me = DataManager.get_war_actor(se.get_action_id())
	var enemy = DataManager.get_war_actor(se.targetId)

	trace("计策失败触发智愚")
	se.rate = 40 + randi() % 10
	se.succeeded = 0
	
	var ske = _simulate_skill_trigger(effect, me.actorId)
	assertTrue(ske.get_war_skill_val_int() > 0)
	_simulate_effect_step(ske, effect, "start")
	var newSE = DataManager.get_current_stratagem_execution()
	assertNotEqual(se, newSE)
	assertEqual(se.rate, newSE.rate)
	assertEqual(LoadControl.get_view_model(), 2000)
	_simulate_effect_step(ske, effect, "1")
	assertEqual(LoadControl.get_view_model(), 2001)

	trace("计策成功不触发智愚")
	se = DataManager.new_stratagem_execution(me.actorId, "火计")
	se.set_target(enemy.actorId)
	se.succeeded = 1
	ske = _simulate_skill_trigger(effect, me.actorId)
	assertEqual(ske.get_war_skill_val_int(), 0)

	trace("非伤兵计不触发智愚")
	se = DataManager.new_stratagem_execution(me.actorId, "笼络")
	se.set_target(enemy.actorId)
	se.succeeded = 0
	ske = _simulate_skill_trigger(effect, me.actorId)
	assertEqual(ske.get_war_skill_val_int(), 0)
	return true

func _case_ZHIYU_1(name: String) -> bool:
	trace("智愚伤害结算及CD")
	var triggerEffect = _assert_lock_skill_effect_basics("智愚", 20031, 20012)
	var settleEffect = _assert_lock_skill_effect_basics("智愚", 20031, 20011)

	var wf = prepare_war_scheme()
	var se = DataManager.get_current_stratagem_execution()
	var me = DataManager.get_war_actor(se.get_action_id())
	var enemy = DataManager.get_war_actor(se.targetId)

	se.rate = 40 + randi() % 10

	trace("正常计策伤害")
	for i in 10:
		DataManager.skill_variable.clear()
		se.succeeded = 1
		var damage = 100 + randi() % 100
		DataManager.set_env("计策.ONCE.基础伤害", damage)
		DataManager.set_env("计策.ONCE.伤害", damage)
		_simulate_skill_trigger(settleEffect, me.actorId)
		assertEqual(DataManager.get_env_int("计策.ONCE.伤害"), damage)
	
	trace("智愚计策伤害")
	se.succeeded = 0
	var traced = 0
	for i in 10:
		DataManager.skill_variable.clear()
		se.rate = 40 + randi() % 10
		_simulate_skill_trigger(triggerEffect, me.actorId)
		var damage = 100 + randi() % 100
		DataManager.set_env("计策.ONCE.基础伤害", damage)
		DataManager.set_env("计策.ONCE.伤害", damage)
		var ske = _simulate_skill_trigger(settleEffect, me.actorId)
		var finalDamage = DataManager.get_env_int("计策.ONCE.伤害")
		var msg = "{0}【{1}】伤害 {2}->{3}，成功率 {4}".format([
			me.get_name(), settleEffect.skill.name, 
			damage, finalDamage, se.rate, 
		])
		assertEqual(finalDamage, int(ceil(damage * se.rate / 100.0)))
		assertEqual(ske.get_war_cd(), 1)
		assertEqual(ske.get_war_skill_val_int(), 0)
		if traced < 5:
			traced += 1
			trace(msg)
	return true

func _case_CHANGFENG_0(name: String) -> bool:
	trace("长风成功率效果")
	var effect = _assert_lock_skill_effect_basics("长风", 20411, 20017)

	_assert_scheme_chance_change("a.知<a.统 and a.统>b.知", "min(a.统-a.知, a.统-b.知)", false, false, null, effect)
	return true

func _case_CHANGFENG_1(name: String) -> bool:
	trace("长风命中率防御效果")
	var effect = _assert_lock_skill_effect_basics("长风", 20411, 20017, "敌方")

	_assert_scheme_chance_change("a.知>b.知 and b.统>b.知", "max(b.知-b.统, b.知-a.知)", false, false, null, null, null, effect)
	return true

func _case_CHANGFENG_2(name: String) -> bool:
	trace("长风伤害增效")
	var effect = _assert_lock_skill_effect_basics("长风", 20411, 20029)

	_assert_scheme_damage_range("a.统>a.知", "a.统", false, false, null, effect)
	return true

func _case_CHANGFENG_3(name: String) -> bool:
	trace("长风伤害减效")
	var effect = _assert_lock_skill_effect_basics("长风", 20411, 20029, "敌方")

	
	_assert_scheme_damage_range("a.统>a.知", "a.知", false, false, null, null, null, effect)
	return true

func _case_GUJU_0(name: String) -> bool:
	trace("顾局成功率效果")
	var effect = _assert_lock_skill_effect_basics("顾局", 20186, 20017, "己方")
	assertTrue(effect.skill.has_feature("主将"))

	_assert_scheme_chance_change("a.知<90 and b.知<90", "min(90-a.知, 90-b.知)", false, false, effect)
	return true

func _case_GUJU_1(name: String) -> bool:
	trace("顾局伤害效果")
	var effect = _assert_lock_skill_effect_basics("顾局", 20186, 20029, "己方")
	
	_assert_scheme_damage_range("a.知<90", "90", false, false, effect)
	return true

func _case_GUJU_2(name: String) -> bool:
	trace("顾局自身无效")
	var effect = _assert_lock_skill_effect_basics("顾局", 20186, 20017, "己方")

	_assert_scheme_chance_change("a.知<90 and b.知<90", "0", true, false, effect)
	_assert_scheme_damage_range("a.知<90", "a.知", true, false, effect)
	return true

func _case_JINCE_0(name: String) -> bool:
	trace("进策发动")
	var effect = _assert_active_skill_effect_basics("进策", 20262)

	var fromId = random_actor_id()
	var wf = prepare_war_scheme( - 1, fromId)
	var from = DataManager.get_war_actor(fromId)

	from.position = Vector2(6, 6)
	for wa in wf.attackerWV.get_war_actors(false):
		if wa.actorId == from.actorId:
			continue
		if wa.actorId == from.get_leader().actorId:
			
			wa.position = Vector2(20, 20)
			continue
		
		wa.position = Vector2(randi() % 13, randi() % 13)

	_attach_skill(effect, from.actorId)
	var ske = effect.create_ske_for(from.actorId)

	var ap = 9 - randi() % 5
	trace("   机动力不足，不可发动：{0}".format([ap]))
	from.action_point = ap
	_simulate_effect_step(ske, effect, "start")
	assertEqual(LoadControl.get_view_model(), 0)
	assertEqual(from.action_point, ap)
	assertEqual(ske.get_war_cd(), 0)

	ap = 10 + randi() % 10
	trace("   机动力充足，可发动：{0}".format([ap]))
	from.action_point = ap
	_simulate_effect_step(ske, effect, "start")
	assertEqual(LoadControl.get_view_model(), 2000)
	assertEqual(ske.get_war_cd(), 0)
	var targets = DataManager.get_env("可选目标")
	for wa in wf.attackerWV.get_war_actors(false):
		if wa.actorId in [from.get_leader().actorId, from.actorId]:
			assertTrue( not wa.actorId in targets)
		else:
			assertTrue(wa.actorId in targets)

	
	var targetId = targets[randi() % targets.size()]
	DataManager.set_env("目标", targetId)
	_simulate_effect_step(ske, effect, "2")
	assertEqual(LoadControl.get_view_model(), 2001)
	assertEqual(ske.get_war_cd(), 0)

	_simulate_effect_step(ske, effect, "3")
	assertEqual(from.action_point, ap - 10)
	assertEqual(LoadControl.get_view_model(), 2001)
	assertEqual(ske.get_war_cd(), 2)
	assertEqual(DataManager.player_choose_actor, targetId)
	assertEqual(FlowManager.last_flow, "actor_move_start")
	assertEqual(ske.get_war_skill_val_int(20263, targetId), 5)
	return true

func _case_JINCE_1(name: String) -> bool:
	trace("进策移动效果")
	var moveEffect = _assert_lock_skill_effect_basics("进策", 20263, 20003, "己方")
	var costEffect = _assert_lock_skill_effect_basics("进策", 20263, 20007, "己方")

	var fromId = random_actor_id()
	var wf = prepare_war_scheme( - 1, fromId)
	var from = DataManager.get_war_actor(fromId)

	_attach_skill(moveEffect, from.actorId)

	
	var target = from.get_leader()
	var movement = Global.load_script("war/player_move.gd")
	movement.actorId = fromId
	var map = SceneManager.current_scene().war_map

	
	DataManager.unset_env("历史移动记录")
	target.position = Vector2(10, 10)
	target.poker_point = 9
	var ap = 20 + randi() % 10
	target.action_point = ap
	var directions = StaticManager.NEARBY_DIRECTIONS.duplicate()
	var total = 3 + randi() % 3
	set_skill_var_int(target.actorId, moveEffect.id, total)
	var times = 20
	for i in times:
		var prevAp = target.action_point
		var prevSteps = get_skill_var_int(target.actorId, moveEffect.id)
		var prev = target.position
		var next = prev + directions[randi() % directions.size()]
		while not map.is_valid_position(next):
			next = prev + directions[randi() % directions.size()]
		DataManager.player_choose_actor = target.actorId
		movement._push_move(next - prev)
		var msg = "   进策：{0}从<{1},{2}>移动到<{3},{4}>".format([
			target.get_name(), prev.x, prev.y, next.x, next.y
		])
		var currentSteps = get_skill_var_int(target.actorId, moveEffect.id)
		msg += "\n        点数: {0} 机动: {1} 进策剩余：{2}".format([
			target.poker_point, target.action_point, currentSteps, 
		])
		trace(msg)
		assertEqual(target.poker_point, 9, msg)
		if i < total:
			
			assertEqual(currentSteps, prevSteps - 1, msg)
			assertEqual(target.position, next, msg)
			assertEqual(target.action_point, prevAp, msg)
		elif target.position == next:
			
			assertEqual(currentSteps, prevSteps - 1, msg)
			assertLess(target.action_point, prevAp, msg)
		else:
			
			assertEqual(currentSteps, prevSteps, msg)
			assertEqual(target.action_point, prevAp, msg)
	for i in times + 10:
		var prevAp = target.action_point
		var prevSteps = get_skill_var_int(target.actorId, moveEffect.id)
		var prev = target.position
		DataManager.player_choose_actor = target.actorId
		movement._pop_move()
		var next = target.position
		var msg = "   进策：{0}从<{1},{2}>返回到<{3},{4}>".format([
			target.get_name(), prev.x, prev.y, next.x, next.y
		])
		var currentSteps = get_skill_var_int(target.actorId, moveEffect.id)
		msg += "\n        点数: {0} 机动: {1} 进策剩余：{2}".format([
			target.poker_point, target.action_point, currentSteps, 
		])
		trace(msg)
		assertEqual(target.poker_point, 9, msg)
		if next == prev:
			
			assertEqual(currentSteps, prevSteps, msg)
			assertEqual(target.action_point, prevAp, msg)
		else:
			
			assertEqual(currentSteps, prevSteps + 1, msg)
			if currentSteps > 0:
				
				assertEqual(target.action_point, prevAp, msg)
			else:
				
				assertLess(prevAp, target.action_point, msg)
	
	assertEqual(target.action_point, ap, "机动力还原")
	var currentSteps = get_skill_var_int(target.actorId, moveEffect.id)
	assertEqual(currentSteps, total, "标记还原")
	return true


func _case_KUIWEI_0(name: String) -> bool:
	trace("溃围效果")
	var effect = _assert_special_skill_effect_basics("溃围")

	var wf = prepare_war_scheme()
	var se = DataManager.get_current_stratagem_execution()
	var from = wf.attackerWV.get_war_actor(se.get_action_id())
	var target = wf.defenderWV.get_war_actor(se.targetId)

	_attach_skill(effect, target.actorId)

	from.position = Vector2(0, 0)
	target.position = Vector2(1, 0)
	var times = 100
	var terrians = StaticManager.BLOCKS_EN_CN.values().duplicate()
	terrians.erase("装备店")
	terrians.erase("米屋")
	terrians.erase("医馆")
	terrians.erase("沼泽")
	terrians.erase("沙漠")
	
	var stratagems = [
		"火计", "要击", "虚兵", "乱水", 
		"连弩", "落石", "伪击转杀", 
	]
	var inCityTimes = 0
	var atWallTimes = 0
	var atGateTimes = 0
	var map = SceneManager.current_scene().war_map
	for i in times:
		terrians.shuffle()
		stratagems.shuffle()
		var schemeInfo = StaticManager.get_stratagem(stratagems[0])
		while not schemeInfo.is_stratagem():
			stratagems.shuffle()
			schemeInfo = StaticManager.get_stratagem(stratagems[0])
		var terrian = terrians[0]
		if schemeInfo.name == "连弩":
			map.set_blockCN_by_position(from.position, "太守府")
		else:
			map.set_blockCN_by_position(from.position, "山地")
		map.set_blockCN_by_position(target.position, terrian)
		var targets = schemeInfo.get_available_targets(from.actorId)[0]
		var reason = schemeInfo._check_special_skills(from, target)
		var msg = "    {0}对{1}【{2}】发动{3}".format([
			from.get_name(), target.get_name(), effect.skill.name, schemeInfo.name, 
		])
		msg += "\n    地形{0}，{1}".format([
			terrian, "可" if target.actorId in targets else "不可", 
		])
		if not reason.empty():
			msg += "\n    因{0}的{1}".format([
				ActorHelper.actor(reason[0]).get_name(), reason[1]
			])
		trace(msg)
		match terrian:
			"城门":
				atGateTimes += 1
				assertTrue( not reason.empty())
				assertTrue( not target.actorId in targets)
			"城墙":
				atWallTimes += 1
				assertTrue( not reason.empty())
				assertTrue( not target.actorId in targets)
			"太守府":
				inCityTimes += 1
				assertTrue( not reason.empty())
				assertTrue( not target.actorId in targets)
			_:
				assertTrue(reason.empty())
				if terrian in schemeInfo.get_targeting_terrian():
					assertTrue(target.actorId in targets)
				else:
					assertTrue( not target.actorId in targets)
	trace("随机计策判断{0}次，其中处于城墙、城门、太守府{1}/{2}/{3}次，结果符合预期".format([
		times, atWallTimes, atGateTimes, inCityTimes
	]))
	return true

func _case_SHUIQI(name: String) -> bool:
	trace("水憩回复效果")
	var effect = _assert_lock_skill_effect_basics("水憩", 20182, 20013)
	assertEqual(effect.terrianSpecified, ["river"])

	var wf = prepare_war_scheme()
	var se = DataManager.get_current_stratagem_execution()
	var me = DataManager.get_war_actor(se.get_action_id())
	var enemy = DataManager.get_war_actor(se.targetId)

	var map = SceneManager.current_scene().war_map

	var terrians = StaticManager.BLOCKS_EN_CN.values()
	for i in 10:
		terrians.shuffle()
		var terrian = terrians[0]
		if i % 2 == 0:
			terrian = "河流"
		map.set_blockCN_by_position(me.position, terrian)
		var hp = me.actor().get_max_hp() - 2 - randi() % 3
		me.actor().set_hp(hp)
		var ap = randi() % 40
		me.action_point = ap
		_simulate_skill_trigger(effect, me.actorId)
		var msg = "    {0}在{1}触发【{2}】".format([
			me.get_name(), terrian, effect.skill.name
		])
		msg += "\n        HP: {0}->{1}, AP: {2}->{3}".format([
			hp, me.actor().get_hp(), ap, me.action_point, 
		])
		if terrian == "河流":
			assertEqual(me.actor().get_hp(), min(hp + 3, me.actor().get_max_hp()))
			assertEqual(me.action_point, ap + 2)
		else:
			assertEqual(me.actor().get_hp(), hp)
			assertEqual(me.action_point, ap)
	return true

func prepare_war_scheme(cityId: int = - 1, fromId: int = - 1, targetId: int = - 1, 
	fromLeader: bool = false, targetLeader: bool = false) -> WarFight:
	if cityId < 0:
		cityId = random_city_id()
	var wf = initWar(0, 1, cityId)

	
	DataManager.actor_scene_skill.clear()
	DataManager.actor_ban_scene_skill.clear()
	DataManager.skill_cd.clear()

	if fromId < 0:
		fromId = random_actor_id()
	if targetId < 0:
		targetId = random_actor_id([fromId])

	var actorIds = [fromId, targetId]

	if not fromLeader:
		
		var attackLeader = createWarActor(random_actor_id(actorIds), wf.attackerWV.id, true)
		actorIds.append(attackLeader.actorId)
		
		for j in randi() % 4 + 1:
			var wa = createWarActor(random_actor_id(actorIds), wf.attackerWV.id, true)
			actorIds.append(wa.actorId)
	
	var from = createWarActor(fromId, wf.attackerWV.id, true)
	
	for j in randi() % 4 + 1:
		var wa = createWarActor(random_actor_id(actorIds), wf.attackerWV.id, true)
		actorIds.append(wa.actorId)

	if not targetLeader:
		
		var defendLeader = createWarActor(random_actor_id(actorIds), wf.defenderWV.id, true)
		actorIds.append(defendLeader.actorId)
		
		for j in randi() % 4:
			var wa = createWarActor(random_actor_id(actorIds), wf.defenderWV.id, true)
			actorIds.append(wa.actorId)
	
	var target = createWarActor(targetId, wf.defenderWV.id, true)
	
	for j in randi() % 4:
		var wa = createWarActor(random_actor_id(actorIds), wf.defenderWV.id, true)
		actorIds.append(wa.actorId)

	
	from.position = Vector2.ZERO
	target.position = Vector2(3, 0)

	
	from.actor().set_level(8)
	target.actor().set_level(8)

	
	from.actor().set_soldiers(1000)
	target.actor().set_soldiers(1000)

	
	from.actor().set_equip(clEquip.equip(StaticManager.JEWELRY_ID_CHAOFENGLING, "道具"))
	target.actor().set_equip(clEquip.equip(StaticManager.JEWELRY_ID_CHAOFENGLING, "道具"))

	
	for actorId in actorIds:
		_remove_all_skills(actorId)

	var se = DataManager.new_stratagem_execution(from.actorId, "火计")
	se.set_target(target.actorId)
	return wf

func _assert_scheme_chance_change(
	conditionFormula: String, 
	expectedChangeFormula: String, 
	fromIsLeader: bool = false, 
	targetIsLeader: bool = false, 
	effectForFromLeader: StaticManager.SkillEffect = null, 
	effectForFrom: StaticManager.SkillEffect = null, 
	effectForTargetLeader: StaticManager.SkillEffect = null, 
	effectForTarget: StaticManager.SkillEffect = null, 
	chanceForFromId: int = - 1, 
	chanceForTargetId: int = - 1
	) -> bool:

	var traced = 0
	for i in 20:
		var fromId = chanceForFromId
		var targetId = chanceForTargetId
		if i % 2 == 1:
			fromId = - 1
			targetId = - 1
		var wf = prepare_war_scheme( - 1, fromId, targetId, fromIsLeader, targetIsLeader)
		var se = DataManager.get_current_stratagem_execution()
		var fromLeader = wf.attackerWV.get_leader()
		var targetLeader = wf.defenderWV.get_leader()
		var from = wf.attackerWV.get_war_actor(se.get_action_id())
		var target = wf.defenderWV.get_war_actor(se.targetId)

		var skill = ""
		if effectForFromLeader != null:
			skill = effectForFromLeader.skill.name
			_attach_skill(effectForFromLeader, fromLeader.actorId)
		if effectForFrom != null:
			skill = effectForFrom.skill.name
			_attach_skill(effectForFrom, from.actorId)
		if effectForTargetLeader != null:
			skill = effectForTargetLeader.skill.name
			_attach_skill(effectForTargetLeader, targetLeader.actorId)
		if effectForTarget != null:
			skill = effectForTarget.skill.name
			_attach_skill(effectForTarget, target.actorId)
		
		var rawRate = se.stratagem.get_rate(from.actorId, target.actorId, true)
		var realRate = se.stratagem.get_rate(from.actorId, target.actorId)

		var msg = "== {0}：知 {1} 统 {2} {3}".format([
			from.get_name(), from.actor().get_wisdom(), from.actor().get_leadership(), 
			"" if null == effectForFrom else effectForFrom.skill.name
		])
		if effectForFromLeader != null:
			msg += "\n   {0}：知 {1} 统 {2} {3}".format([
				fromLeader.get_name(), fromLeader.actor().get_wisdom(), fromLeader.actor().get_leadership(), 
				effectForFromLeader.skill.name
			])
		msg += "\n   对 {0}：知 {1} 统 {2} {3}".format([
			target.get_name(), target.actor().get_wisdom(), target.actor().get_leadership(), 
			"" if null == effectForTarget else effectForTarget.skill.name
		])
		if effectForTargetLeader != null:
			msg += "\n   {0}：知 {1} 统 {2} {3}".format([
				targetLeader.get_name(), targetLeader.actor().get_wisdom(), targetLeader.actor().get_leadership(), 
				effectForTargetLeader.skill.name
			])
		msg += "\n   计策命中率变化：{0} -> {1}".format([rawRate, realRate])
		var formula = expectedChangeFormula
		formula = formula.replace("__RAW_RATE__", str(rawRate))
		var expectedChange = Global.count_formula_number(formula, from.actorId, target.actorId)
		if traced < 5:
			traced += 1
			trace(msg)
		var condition = conditionFormula
		condition = condition.replace("__FROM_ID__", str(from.actorId))
		condition = condition.replace("__TARGET_ID__", str(target.actorId))
		if not Global.count_formula_bool(condition, from.actorId, target.actorId):
			assertEqual(realRate, rawRate, msg)
			continue
		assertEqual(realRate, max(5, min(95, rawRate + expectedChange)), msg)
	return true

func _assert_scheme_damage_range(
	conditionFormula: String, 
	expectedWisdomFormula: String, 
	fromIsLeader: bool = false, 
	targetIsLeader: bool = false, 
	effectForFromLeader: StaticManager.SkillEffect = null, 
	effectForFrom: StaticManager.SkillEffect = null, 
	effectForTargetLeader: StaticManager.SkillEffect = null, 
	effectForTarget: StaticManager.SkillEffect = null
	) -> bool:

	var traced = 0
	for i in 20:
		var wf = prepare_war_scheme( - 1, - 1, - 1, fromIsLeader, targetIsLeader)
		var se = DataManager.get_current_stratagem_execution()
		var fromLeader = wf.attackerWV.get_leader()
		var targetLeader = wf.defenderWV.get_leader()
		var from = wf.attackerWV.get_war_actor(se.get_action_id())
		var target = wf.defenderWV.get_war_actor(se.targetId)

		var skill = ""
		if effectForFromLeader != null:
			skill = effectForFromLeader.skill.name
			_attach_skill(effectForFromLeader, fromLeader.actorId)
		if effectForFrom != null:
			skill = effectForFrom.skill.name
			_attach_skill(effectForFrom, from.actorId)
		if effectForTargetLeader != null:
			skill = effectForTargetLeader.skill.name
			_attach_skill(effectForTargetLeader, targetLeader.actorId)
		if effectForTarget != null:
			skill = effectForTarget.skill.name
			_attach_skill(effectForTarget, target.actorId)
		
		var rawRate = se.stratagem.get_rate(from.actorId, target.actorId, true)
		var realRate = se.stratagem.get_rate(from.actorId, target.actorId)

		se.set_must_success(from.actorId, "测试")
		se.perform_to_targets([target.actorId])
		var damage = se.get_soldier_damage_for(target.actorId)
		var expectedWisdom = from.actor().get_wisdom()
		if Global.count_formula_bool(conditionFormula, from.actorId, target.actorId):
			expectedWisdom = Global.count_formula_number(expectedWisdomFormula, from.actorId, target.actorId)
		var minDamage = int(expectedWisdom * 9 / 10 + 70 + 30)
		var maxDamage = int(expectedWisdom * 13 / 10 + 70 + 30)

		var msg = "== {0}：知 {1} 统 {2} {3}".format([
			from.get_name(), from.actor().get_wisdom(), from.actor().get_leadership(), 
			"" if null == effectForFrom else effectForFrom.skill.name
		])
		if effectForFromLeader != null:
			msg += "\n   {0}：知 {1} 统 {2} {3}".format([
				fromLeader.get_name(), fromLeader.actor().get_wisdom(), fromLeader.actor().get_leadership(), 
				effectForFromLeader.skill.name
			])
		msg += "\n   对 {0}：知 {1} 统 {2} {3}".format([
			target.get_name(), target.actor().get_wisdom(), target.actor().get_leadership(), 
			"" if null == effectForTarget else effectForTarget.skill.name
		])
		if effectForTargetLeader != null:
			msg += "\n   {0}：知 {1} 统 {2} {3}".format([
				targetLeader.get_name(), targetLeader.actor().get_wisdom(), targetLeader.actor().get_leadership(), 
				effectForTargetLeader.skill.name
			])
		msg += "\n   计策伤害：{0}，范围：[ {1}, {2} ]".format([
			damage, minDamage, maxDamage
		])

		if traced < 5:
			traced += 1
			trace(msg)
		assertLess(minDamage - 1, damage, msg)
		assertLess(damage, maxDamage + 1, msg)
	return true

func _assert_scheme_forbidden(
	effect: StaticManager.SkillEffect, 
	condition: String = "", 
	opposite: bool = false, 
	actorId: int = - 1, 
	initCallbacks: PoolStringArray = []) -> void :

	if condition == "" and opposite == false:
		condition = "__FROM_ID__ == __CHOSEN_ID__"

	var fromId = - 1
	var targetId = - 1
	if actorId >= 0:
		if opposite:
			targetId = actorId
		else:
			fromId = actorId
	var wf = prepare_war_scheme( - 1, fromId, targetId)
	var ps = Global.load_script("war/player_stratagem_menu.gd")

	
	var checkings = [
		[wf.attackerWV, wf.defenderWV], 
		[wf.defenderWV, wf.attackerWV], 
	]
	for checking in checkings:
		var from = checking[0]
		var target = checking[1]
		var chosen
		if actorId < 0:
			
			var members = from.get_war_actors(false)
			if opposite:
				
				members = checking[1].get_war_actors(false)
			chosen = members[randi() % members.size()]
		else:
			chosen = DataManager.get_war_actor(actorId)
		
		if effect.skill._gendersOnly.size() > 0:
			chosen.actor().set_gender(effect.skill._gendersOnly[0])
		
		for method in initCallbacks:
			call(method, chosen.actorId)
		_attach_skill(effect, chosen.actorId)

		var FIVE_PHASES = War_Character.FivePhases_Enum.values()
		var tested = 0
		var disabled = 0
		for wa in from.get_war_actors(false):
			DataManager.player_choose_actor = wa.actorId
			FIVE_PHASES.shuffle()
			wa.five_phases = FIVE_PHASES[0]
			ps.stratagem_menu()
			SceneManager.lsc_menu_top.hide()
			tested += 1
			var formula = condition
			var dict = {
				"__FIVE_PHASES__": "'{0}'".format([wa.get_five_phases_str()]), 
				"__FROM_ID__": wa.actorId, 
				"__CHOSEN_ID__": chosen.actorId, 
			}
			for key in dict:
				formula = formula.replace(key, str(dict[key]))
			if Global.count_formula_bool(formula):
				disabled += 1
				assertEqual(LoadControl.get_view_model(), 0)
			else:
				assertEqual(LoadControl.get_view_model(), 120)
		var msg = "    {0}{1}人尝试发动计策".format([from.side, tested])
		msg += "\n    因{0}【{1}】，{2}人失败".format([
			chosen.get_name(), effect.skill.name, disabled, 
		])
		trace(msg)
	return

func _case_STOP(name: String) -> bool:
	return false
