# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：test/skills_10000.gd
# 说明：测试-技能组 10000。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "base.gd"

const SKILL_CASES = [
	
	["事半", "_case_SHIBAN"], 
	["功倍", "_case_GONGBEI"], 
	["涉猎", "_case_SHELIE"], 
	["仁德", "_case_RENDE"], 
	["米道", "_case_MIDAO"], 
	["明政", "_case_MINGZHENG"], 
	["纳蛮", "_case_NAMAN"], 
	["收越", "_case_SHOUYUE"], 
	["收羌", "_case_SHOUQIANG"], 
	
	["躬亲", "_case_GONGQIN"], 
]

func runAll() -> bool:
	SceneManager.is_test_running = true
	SceneManager.current_scene().SCENE_ID = 10000
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
		yield(SceneManager.current_scene(), "traced")
	trace("{0}个【内政技能】cases passed".format([cnt]))
	
	SkillHelper.remove_all_skill_trigger()
	SceneManager.is_test_running = false
	return true





func _case_SHIBAN(name: String) -> bool:
	trace("事半开发效果")
	var effect = _assert_lock_skill_effect_basics("事半", 10005, 10002)
	_assert_develop_results(effect, 0.5, 1.0)
	return true

func _case_GONGBEI(name: String) -> bool:
	trace("功倍开发效果")
	var effect = _assert_lock_skill_effect_basics("功倍", 10028, 10002)
	_assert_develop_results(effect, 2.0, 1.5)
	return true

func _case_SHELIE(name: String) -> bool:
	trace("涉猎加经验")
	var effect = _assert_lock_skill_effect_basics("涉猎", 10032, 10001)
	var jewelrys = clEquip.all_equips("道具")
	var traced = 0
	for i in 100:
		var actorId = random_actor_id()
		var actor = ActorHelper.actor(actorId)
		jewelrys.shuffle()
		actor.set_equip(jewelrys[0])
		actor.set_exp(0)
		_simulate_skill_trigger(effect, actorId)
		var expected = actor.get_equip_feature_total("计策附加智力") * 30
		assertEqual(actor.get_exp(), expected)
		if traced < 3:
			traced += 1
			trace("{0}【{1}】因{2}经验增加{3}".format([
				actor.get_name(), effect.skill.name, 
				actor.get_jewelry().name(), expected, 
			]))
	return true

func _case_RENDE(name: String) -> bool:
	trace("仁德效果")
	trace("每月初：同城武将，忠＜85时，忠+4；若你为君主，势力其他城市武将，忠＜85时，忠 +2。")
	var script = Global.load_script("res://resource/sgz_script/affiars/auto_events/affiars_month_events.gd")
	var traced = 0
	for i in 10:
		var actor = random_actor()
		var city = _attach_random_city(actor.actorId)
		
		city.set_vstate_id(99)
		SkillHelper.add_actor_scene_skill(10000, actor.actorId, "仁德", 1)
		SkillHelper.update_all_skill_buff("TEST")
		var actorCount = 30 + randi() % 10
		for j in actorCount:
			var followerId = random_actor_id(city.get_actor_ids())
			
			while is_lord(followerId):
				followerId = random_actor_id(city.get_actor_ids())
			clCity.move_out(followerId)
			city.add_actor(followerId)
		var prevLoyalties = {}
		for actorId in city.get_actor_ids():
			var loyalty = 60 + randi() % 40
			ActorHelper.actor(actorId).set_loyalty(loyalty)
			prevLoyalties[actorId] = loyalty
		script.city_data_deal()
		for actorId in city.get_actor_ids():
			var prevLoyalty = prevLoyalties[actorId]
			var member = ActorHelper.actor(actorId)
			var loyaltyAdded = member.get_loyalty() - prevLoyalty
			if prevLoyalty < 70:
				
				assertEqual(loyaltyAdded, 7)
			elif prevLoyalty < 85:
				assertEqual(loyaltyAdded, 4)
			else:
				assertEqual(loyaltyAdded, 0)
			if traced < 10:
				traced += 1
				trace("{0}忠 {1} +{2} -> {3}".format([
					member.get_name(), prevLoyalty, 
					loyaltyAdded, member.get_loyalty(), 
				]))
	return true

func _case_MIDAO(name: String) -> bool:
	trace("米道生效")
	var effect = _assert_lock_skill_effect_basics("米道", 10001, 10001)
	_assert_monthly_changes(effect, {"米": 100, "后备兵": 50})
	return true

func _case_MINGZHENG(name: String) -> bool:
	trace("明政生效")
	var effect = _assert_lock_skill_effect_basics("明政", 10002, 10001)
	_assert_monthly_changes(effect, {"统治度": 5, "经验": 200, "whenFull": 1})
	return true

func _case_NAMAN(name: String) -> bool:
	trace("纳蛮生效")
	var effect = _assert_lock_skill_effect_basics("纳蛮", 10048, 10001)
	_assert_monthly_changes(effect, {"ifFeature": "蛮", "人口": 300, "经验": 200})
	return true

func _case_SHOUYUE(name: String) -> bool:
	trace("收越生效")
	var effect = _assert_lock_skill_effect_basics("收越", 10047, 10001)
	_assert_monthly_changes(effect, {"ifFeature": "越", "人口": 300, "经验": 200})
	return true

func _case_SHOUQIANG(name: String) -> bool:
	trace("收羌生效")
	var effect = _assert_lock_skill_effect_basics("收羌", 10046, 10001)
	_assert_monthly_changes(effect, {"ifFeature": "羌", "人口": 300, "经验": 200})
	return true

func _assert_monthly_changes(effect, changesExpected: Dictionary) -> void :
	var feature = ""
	if "ifFeature" in changesExpected:
		feature = changesExpected["ifFeature"]
		changesExpected.erase("ifFeature")
	var whenFull = false
	if "whenFull" in changesExpected:
		whenFull = true
		changesExpected.erase("whenFull")
	var expExpected = 0
	if "经验" in changesExpected:
		expExpected = changesExpected["经验"]
	var traced = 0
	for i in 100:
		prepare_for_affair()
		var actor = random_actor()
		var city = _attach_random_city(actor.actorId)
		actor.set_exp(ActorHelper.ActorInfo.EXP_MAX - expExpected + randi() % (expExpected + 1))
		var prevExp = actor.get_exp()
		var prevValues = {}
		var limits = {}
		limits["经验"] = ActorHelper.ActorInfo.EXP_MAX
		var isFull = true
		for attr in clCity.CITY_PROPERTY_MAX:
			var limit = clCity.CITY_PROPERTY_MAX[attr]
			limits[attr] = limit
			var expected = 0
			if attr in changesExpected:
				expected = changesExpected[attr]
				city.set_property(attr, limit - expected * 2 + randi() % (expected * 2 + 1))
				if attr == "人口":
					city.set_property(attr, limit - expected * 2 + randi() % (expected / 100 * 2 + 1) * 100)
			else:
				city.set_property(attr, limit * randf())
			prevValues[attr] = city.get_property(attr)
			if attr in changesExpected and prevValues[attr] < limits[attr]:
				isFull = false
		_simulate_skill_trigger(effect, actor.actorId)
		var currents = {}
		var changes = {}
		currents["经验"] = actor.get_exp()
		changes["经验"] = currents["经验"] - prevExp
		for attr in clCity.CITY_PROPERTY_MAX:
			currents[attr] = city.get_property(attr)
			changes[attr] = currents[attr] - prevValues[attr]
		if feature != "" and not city.has_feature(feature):
			for attr in changes:
				assertEqual(0, changes[attr])
			continue
		for attr in changes:
			var change = changes[attr]
			if attr == "经验" and whenFull and not isFull:
				assertEqual(change, 0)
				continue
			if not attr in changesExpected:
				var msg = "{0}【{1}】在{2}，{3}不变".format([
					actor.get_name(), effect.skill.name, 
					city.get_name(), attr
				])
				assertEqual(change, 0, msg)
			else:
				var msg = "{0}【{1}】在{2}，{3}增加{4}->{5}".format([
					actor.get_name(), effect.skill.name, 
					city.get_name(), attr, 
					change, currents[attr], 
				])
				assertTrue(attr in changesExpected, msg)
				if change < changesExpected[attr]:
					assertEqual(currents[attr], limits[attr], msg)
				else:
					assertEqual(change, changesExpected[attr], msg)
				if traced < 10:
					traced += 1
					trace(msg)
	return

func _assert_develop_results(effect, costRate: float, effectRate: float) -> void :
	var types = ["土地", "产业", "人口"]
	var traced = 0
	for i in 100:
		prepare_for_affair()
		types.shuffle()
		var type = types[0]
		
		var actorId = random_actor_id()
		
		ActorHelper.actor(actorId).set_equip(clEquip.equip(0, "道具"))
		
		var city = clCity.city(random_city_id())
		for t in types:
			city.set_property(t, 0)
		_attach_skill(effect, actorId)
		
		var cmd = DataManager.new_develop_command(type, actorId, city.ID)
		cmd.decide_cost()
		cmd.execute()
		assertEqual(cmd.realCost, int(cmd.cost * costRate))
		for t in types:
			if t != cmd.type:
				assertEqual(city.get_property(t), 0)
				continue
			if traced < 3:
				traced += 1
				trace("{0}【{1}】花费{2}令{3}{4}上升{5}".format([
					cmd.actioner().get_name(), effect.skill.name, cmd.realCost, 
					cmd.city().get_name(), cmd.type, city.get_property(t), 
				]))
	return





func _case_GONGQIN(name: String) -> bool:
	trace("躬亲生效")
	var effect = _assert_active_skill_effect_basics("躬亲", 10012)
	assertTrue(effect.skill.has_feature("全境发动"))
	var actor = random_actor()
	var city = _attach_random_city(actor.actorId)
	prepare_ske(actor.actorId, effect)
	var script = Global.load_script(effect.path)
	script.actorId = actor.actorId
	actor.set_hp(19)
	var orders = randi() % 10
	DataManager.orderbook = orders
	script.effect_10012_start()
	assertEqual(LoadControl.get_view_model(), 2001)
	actor.set_hp(29)
	script.effect_10012_start()
	assertEqual(LoadControl.get_view_model(), 2000)
	assertEqual(actor.get_hp(), 29)
	assertEqual(DataManager.orderbook, orders)
	script.effect_10012_2()
	assertEqual(actor.get_hp(), 9)
	assertEqual(DataManager.orderbook, orders + 1)
	assertEqual(LoadControl.get_view_model(), 2001)
	return true

func prepare_for_affair() -> void :
	DataManager.actor_ban_scene_skill.clear()
	DataManager.actor_scene_skill.clear()
	DataManager.skill_cd.clear()
	DataManager.skill_variable.clear()
	return
