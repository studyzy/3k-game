extends "base.gd"




const SKILL_CASES = [
	["内政开发装备效果", "_case_develop_equip_effect"], 
	["嘲讽效果", "_case_battle_taunt"], 
	["咒缚成功率", "_case_stop_rate"], 
	["小战场攻击伤害", "_case_battle_damage"], 
	["小战场攻击C值", "_case_battle_damage_C"], 
	["武将回体", "_case_monthly_recover"], 
	["AI换装", "_case_AI_equip"], 
	["AI回体", "_case_AI_heal"], 
]

func get_script_path(effectId: int) -> String:
	return "{0}/sgz_script/effects/30000-battle/effect_{1}.gd".format([
		DataManager.mod_path, effectId
	])

func runAll() -> bool:
	SceneManager.is_test_running = true
	SceneManager.current_scene().SCENE_ID = 10000
	var cnt = 0
	for case in SKILL_CASES:
		var scene = case[0]
		var method = case[1]
		var time = Time.get_ticks_usec()
		trace("\n==== starting {0}".format([method]))
		var ret = call(method)
		time = Time.get_ticks_usec() - time
		if not ret:
			return error("{0} FAILED with {1}，耗时：{2}秒".format([
				scene, method, time / 1000.0 / 1000.0, 
			]))
		trace("==== {0} PASSED for {1}\n==== 耗时：{2}秒\n".format([
			method, scene, time / 1000.0 / 1000.0, 
		]))
		cnt += 1
	trace("{0}个【功能回归】cases passed".format([cnt]))
	
	SkillHelper.remove_all_skill_trigger()
	SceneManager.is_test_running = false
	return true

func _case_AI_heal():
	trace("AI 治疗")
	var vstateId = randi() % 10
	initAffair(vstateId, true)
	var cityIds = []
	for i in 3:
		var city = clCity.city(randi() % 30)
		city.set_vstate_id(vstateId)
		
		city.set_property("土地", 500)
		city.set_property("产业", 500)
		city.set_property("人口", 50000)
		city.set_property("统治度", 100)
		city.set_property("防灾", 99)
		city.clear_actors()
		for j in 3 + randi() % 5:
			city.add_actor(random_actor_id())
		cityIds.append(city.ID)
	DataManager.set_env("内政.AI城池", cityIds)
	DataManager.diffculities = 0
	var script = Global.load_script("res://resource/sgz_script/affiars/auto_events/AI/develop.gd")
	
	
	for i in 10:
		cityIds.shuffle()
		var city = clCity.city(cityIds[0])
		var actors = Array(city.get_actor_ids())
		actors.shuffle()
		var actor = ActorHelper.actor(actors[0])
		city.set_property("金", 1000 + randi() % 100)
		var gold = city.get_gold()
		var goldExpected = gold - 50 + 1
		var full = actor.get_max_hp()
		var hp = full - 1 - randi() % 40
		
		var heal = 5 * 10
		if randi() % 3 == 0:
			actor.set_hp(full)
			goldExpected = gold + 1
		else:
			actor.set_hp(hp)
			assertTrue(actor.is_injured(), "受伤")
		assertTrue(script.AI_Develop())
		assertTrue( not actor.is_injured(), "治疗")
		assertEqual(actor.get_hp(), min(full, hp + heal), "体力")
		assertLess(city.get_gold(), goldExpected, "城市金")
	return true

func _case_AI_equip():
	trace("AI 换装")
	var vstateId = randi() % 10
	initAffair(vstateId, true)
	var cityIds = []
	for i in 3:
		var city = clCity.city(randi() % 30)
		city.set_vstate_id(vstateId)
		city.clear_actors()
		for j in 3 + randi() % 5:
			city.add_actor(random_actor_id())
		cityIds.append(city.ID)
	DataManager.set_env("内政.AI城池", cityIds)
	var types = StaticManager.EQUIPMENT_TYPES.duplicate(true)
	
	types.erase("道具")
	var script = Global.load_script("res://resource/sgz_script/affiars/auto_events/AI/develop.gd")
	for i in 100:
		DataManager.orderbook = 100
		DataManager.diffculities = i % 5
		cityIds.shuffle()
		var cityId = cityIds[0]
		var city = clCity.city(cityId)
		var actors = Array(city.get_actor_ids())
		actors.shuffle()
		var actorId = actors[0]
		var actor = ActorHelper.actor(actorId)
		
		actor.set_level(2)
		types.shuffle()
		var caseName = "{0}#{1}{2}#{3}{4}换装测试".format([
			actor.get_name(), actor.actorId, 
			city.get_full_name(), city.ID, types[0]
		])
		trace(caseName)
		city.set_property("金", 9000)
		var gold = city.get_gold()
		var goldExpected = gold - 100 + 1
		for type in types:
			actor.set_equip(clEquip.equip(6, type))
		var current = clEquip.equip(0, types[0])
		actor.set_equip(current)
		assertTrue(script.AI_BuyEquip())
		var switched = actor.get_equip(types[0])
		if city.better_equip(current, actor.actorId) == null:
			assertEqual(0, switched.id, caseName)
			assertLess(city.get_gold(), goldExpected, "城市金")
		else:
			assertLess(0, switched.id, caseName)
			trace("{0}#{1}{2}换装{3}".format([
				actor.get_name(), actor.actorId, types[0], switched.name(), 
			]))
	return true

func _case_monthly_recover():
	trace("武将每月回体")
	var vstateId = randi() % 10
	initAffair(vstateId, true)
	
	var actors = []
	for city in clCity.all_cities():
		city.set_vstate_id(vstateId)
		city.clear_actors()
		for j in 3 + randi() % 5:
			var actorId = random_actor_id()
			while actorId in actors:
				actorId = random_actor_id()
			actors.append(actorId)
			city.add_actor(actorId)
			var actor = ActorHelper.actor(actorId)
			actor.set_hp(actor.get_max_hp())
			if actorId % 3 == 1:
				
				actor.set_hp(actor.get_max_hp() - 1 - randi() % 19)
				trace("{0}轻伤：{1}/{2}".format([actor.get_name(), actor.get_hp(), actor.get_max_hp()]))
			elif actorId % 3 == 2:
				
				actor.set_hp(actor.get_max_hp() - 21 - randi() % 10)
				trace("{0}重伤：{1}/{2}".format([actor.get_name(), actor.get_hp(), actor.get_max_hp()]))
	var script = Global.load_script("res://resource/sgz_script/affiars/auto_events/affiars_month_events.gd")
	script.city_data_deal()
	for actorId in actors:
		var actor = ActorHelper.actor(actorId)
		match actorId % 3:
			0:
				assertEqual(actor.get_hp(), actor.get_max_hp(), actor.get_name() + "满体")
			1:
				assertEqual(actor.get_hp(), actor.get_max_hp(), actor.get_name() + "轻伤")
			2:
				assertLess(actor.get_hp(), actor.get_max_hp(), actor.get_name() + "重伤")
	return true

func _case_develop_equip_effect() -> bool:
	trace("内政开发装备效果")
	var vstateId = 1
	initAffair(vstateId, true)
	DataManager.player_choose_city = random_city_id()
	var script = Global.load_script("res://resource/sgz_script/affiars/town_develop.gd")
	var city = clCity.city(DataManager.player_choose_city)
	
	var types = ["土地", "产业"]
	for type in types:
		var theOther = types[1 - types.find(type)]
		trace("开发" + type)
		for i in 20:
			var minVal = 23 - 1
			var maxVal = 39 + 1
			var actorId = random_actor_id()
			var cmd = DataManager.new_develop_command(type, actorId, city.ID)
			cmd.decide_cost()
			cmd.cost = 26
			cmd.actionAttr = 90
			var actor = cmd.actioner()
			
			actor.set_equip(clEquip.equip(0, "道具"))
			city.set_property("土地", 0)
			city.set_property("产业", 0)
			city.set_property("人口", 0)
			script.develop_5()
			assertLess(city.get_property(type), maxVal)
			assertLess(minVal, city.get_property(type))
			assertEqual(city.get_property(theOther), 0)
			assertEqual(city.get_property("人口"), 0)
			
			actor.set_equip(clEquip.equip(2, "道具"))
			city.set_property("土地", 0)
			city.set_property("产业", 0)
			city.set_property("人口", 0)
			script.develop_5()
			assertLess(city.get_property(type), maxVal + 10)
			assertLess(minVal + 10, city.get_property(type))
			assertEqual(city.get_property(theOther), 0)
			assertEqual(city.get_property("人口"), 0)
			
			actor.set_equip(clEquip.equip(10, "道具"))
			city.set_property("土地", 0)
			city.set_property("产业", 0)
			city.set_property("人口", 0)
			script.develop_5()
			assertLess(city.get_property(type), maxVal + 6)
			assertLess(minVal + 6, city.get_property(type))
			assertEqual(city.get_property(theOther), 0)
			assertEqual(city.get_property("人口"), 0)
			
			actor.set_equip(clEquip.equip(1, "道具"))
			city.set_property("土地", 0)
			city.set_property("产业", 0)
			city.set_property("人口", 0)
			script.develop_5()
			assertLess(city.get_property(type), maxVal)
			assertLess(minVal, city.get_property(type))
			assertEqual(city.get_property(theOther), 0)
			assertEqual(city.get_property("人口"), 1000)

	var type = "人口"
	trace("开发" + type)
	for i in 20:
		var minVal = 2300 - 1
		var maxVal = 3900 + 1
		var actorId = random_actor_id()
		var cmd = DataManager.new_develop_command(type, actorId, city.ID)
		cmd.decide_cost()
		cmd.cost = 26
		cmd.actionAttr = 90
		var actor = cmd.actioner()
		
		actor.set_equip(clEquip.equip(0, "道具"))
		city.set_property("土地", 0)
		city.set_property("产业", 0)
		city.set_property("人口", 0)
		script.develop_5()
		assertLess(city.get_property(type), maxVal)
		assertLess(minVal, city.get_property(type))
		assertEqual(city.get_property("土地"), 0)
		assertEqual(city.get_property("产业"), 0)
		
		actor.set_equip(clEquip.equip(2, "道具"))
		city.set_property("土地", 0)
		city.set_property("产业", 0)
		city.set_property("人口", 0)
		script.develop_5()
		assertLess(city.get_property(type), maxVal + 500)
		assertLess(minVal + 500, city.get_property(type))
		assertEqual(city.get_property("土地"), 0)
		assertEqual(city.get_property("产业"), 0)
		
		actor.set_equip(clEquip.equip(10, "道具"))
		city.set_property("土地", 0)
		city.set_property("产业", 0)
		city.set_property("人口", 0)
		script.develop_5()
		assertLess(city.get_property(type), maxVal + 300)
		assertLess(minVal + 300, city.get_property(type))
		assertEqual(city.get_property("土地"), 0)
		assertEqual(city.get_property("产业"), 0)
		
		actor.set_equip(clEquip.equip(1, "道具"))
		city.set_property("土地", 0)
		city.set_property("产业", 0)
		city.set_property("人口", 0)
		script.develop_5()
		assertLess(city.get_property(type), maxVal)
		assertLess(minVal, city.get_property(type))
		assertEqual(city.get_property("土地"), 0)
		assertEqual(city.get_property("产业"), 0)
	return true

func _case_battle_damage_C() -> bool:
	trace("小战场攻击C值")
	var script = Global.load_script("res://resource/sgz_script/battle/IBattle_Damage.gd")
	for i in 100:
		var actorId = random_actor_id()
		actorId = 385
		var enemyId = random_actor_id([actorId])
		initWar(0, 1, 0)
		var me = createWarActor(actorId, 0, true)
		createWarActor(enemyId, 1, true)
		initBattle(actorId, enemyId)
		var hp = randi() % 55
		if i % 2 == 0:
			
			me.actor().set_equip(clEquip.equip(StaticManager.WEAPON_ID_GUANSHI, "武器"))
			hp = me.actor().get_max_hp()
		else:
			me.actor().set_equip(clEquip.equip(0, "武器"))
		me.actor().set_hp(hp)
		var bu = me.battle_actor_unit()
		bu.set_hp(hp, true)
		var C = script.get_attack_C_val(bu)
		if hp <= 7:
			assertEqual(C, 20)
		elif hp <= 17:
			assertEqual(C, 40)
		elif hp < 30:
			assertEqual(C, 50)
		elif hp < 40:
			assertEqual(C, 70)
		elif hp < 45:
			assertEqual(C, 85)
		elif hp < 50:
			assertEqual(C, 95)
		else:
			assertEqual(C, 100)
	return true

func _case_battle_damage() -> bool:
	trace("小战场攻击伤害")
	var script = Global.load_script("res://resource/sgz_script/battle/IBattle_Damage.gd")
	for i in 100:
		var actorId = random_actor_id()
		var enemyId = random_actor_id()
		while enemyId == actorId:
			enemyId = random_actor_id()
		initWar(0, 1, 0)
		var me = createWarActor(actorId, 0, true)
		var enemy = createWarActor(enemyId, 1, true)
		initBattle(actorId, enemyId)
		var from = me.battle_actor_unit()
		var target = enemy.battle_actor_unit()
		from.set_hp(100)
		me.battle_power = 50
		me.battle_courage = 50
		
		me.actor().set_equip(clEquip.equip(0, "武器"))
		
		var expectedAttack = me.get_battle_power() * me.battle_courage / 100.0 * 0.7
		expectedAttack += me.actor().get_equip_attr_total("攻击力")
		
		expectedAttack = expectedAttack * (100 - target.get_damage_avoid_rate()) / 100
		
		expectedAttack *= int(from.get_melee_damage_rate() / 100)
		
		enemy.actor().set_equip(clEquip.equip(0, "防具"))
		enemy.battle_courage = 80
		
		var expectedDefence = (enemy.battle_courage / 8.0 + enemy.actor().get_equip_attr_total("防御力")) / 2.0
		var damage = script.calc_classic_damage(from, target)
		
		var expectedDamage = expectedAttack - expectedDefence
		expectedDamage = max(0.5, expectedDamage)
		expectedDamage = min(12, expectedDamage)
		var msg = "{0}对{1}造成{2}伤害".format([
			me.get_name(), enemy.get_name(), damage, 
		])
		trace(msg)
		assertLess(int(expectedDamage), damage, msg)
		assertLess(damage, int(expectedDamage) + 1, msg)
	return true

func _case_stop_rate() -> bool:
	trace("咒缚成功率")
	var script = Global.load_script("res://resource/sgz_script/battle/ITactic.gd")
	for i in 100:
		var actorId = random_actor_id()
		var enemyId = random_actor_id()
		while enemyId == actorId:
			enemyId = random_actor_id()
		initWar(0, 1, 0)
		var me = createWarActor(actorId, 0, true)
		var enemy = createWarActor(enemyId, 1, true)
		initBattle(actorId, enemyId)
		if i % 2 == 0:
			me.actor().set_equip(clEquip.equip(StaticManager.JEWELRY_ID_TONGBENMA, "道具"))
		else:
			me.actor().set_equip(clEquip.equip(0, "道具"))
		var rate = script.get_stop_tactic_rate(me.actorId)
		if i % 2 == 0:
			var msg = "{0}咒缚成功率{1}".format([me.get_name(), rate])
			trace(msg)
			assertEqual(rate, 50 + int(me.actor().get_politics() / 3))
		else:
			assertEqual(rate, 50)
	return true

func _case_battle_taunt() -> bool:
	DataManager.grouped_trace_reset()
	trace("嘲讽效果")
	var script = Global.load_script("res://resource/sgz_script/battle/IUnitLogic.gd")
	for i in 100:
		DataManager.grouped_trace("")
		var actorId = random_actor_id()
		var enemyId = random_actor_id([actorId])
		initWar(0, 1, 0)
		DataManager.grouped_trace("初始化战场")
		var me = createWarActor(actorId, 0, true)
		var enemy = createWarActor(enemyId, 1, true)
		initBattle(actorId, enemyId)
		DataManager.grouped_trace("初始化战斗")
		if i % 2 == 0:
			me.actor().set_equip(clEquip.equip(StaticManager.JEWELRY_ID_CHAOFENGLING, "道具"))
		else:
			me.actor().set_equip(clEquip.equip(0, "道具"))
		enemy.actor().set_equip(clEquip.equip(0, "道具"))
		DataManager.grouped_trace("初始化装备")
		var bu = DataManager.battle_units[randi() % DataManager.battle_units.size()]
		var taunted = script._get_taunt_by_enemy(bu)
		if i % 2 == 1\
		or bu.leaderId == enemyId\
		or bu.get_unit_type() == "将":
			assertEqual(taunted, [])
		else:
			var msg = "{0}被{1}嘲讽".format([
				bu.get_unit_type(), "、".join(taunted), 
			])
			trace(msg)
			assertEqual(taunted, ["步"])
		DataManager.grouped_trace("检查嘲讽")
	DataManager.grouped_trace_output()
	return true
