# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：test/actor_info.gd
# 说明：测试-武将信息。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "base.gd"

const CLASS_CASES = [
	["_classStatus", "STATUS"], 
	["_classBasicProps", "BASIC_PROPS"], 
]

func runAll() -> bool:
	return runClassTest()\
	and runDataManager()

func runClassTest() -> bool:
	trace("【ActorInfo 基类测试】")
	for case in CLASS_CASES:
		if call(case[0]):
			trace("[{0}] PASS".format([case[1]]))
			continue
		error("[{0}] FAILED!".format([case[1]]))
		return false
	trace("基类测试 PASS\n")
	return true

func _classBasicProps() -> bool:
	randomize()
	var basicIntProps = [
		"武", "知", "忠", "德", "政", "统", "胆", 
		"大限", "流放地", "兵力", "等级"
	]
	var basicFloatProps = ["体", "经验值"]
	for prop in basicIntProps:
		var times = 1000
		for i in times:
			var actorId = randi() % ActorHelper.actors_count()
			var actor = ActorHelper.actor(actorId)
			var val = randi() % 100
			actor._set_attr_int(prop, val)
			assertEqual(actor._get_attr_int_original(prop), DataManager.actors[actorId][prop], prop + "属性")
	for type in ["武器", "防具", "道具", "坐骑"]:
		var times = 1000
		for i in times:
			var actorId = randi() % ActorHelper.actors_count()
			var actor = ActorHelper.actor(actorId)
			
			var val = randi() % 7
			actor._set_attr_int(type, val)
			assertEqual(actor._get_attr_int(type), int(DataManager.actors[actorId][type]), type + "ID")
			assertEqual(actor.get_equip(type).id, int(DataManager.actors[actorId][type]), type + "ID")
	for prop in basicFloatProps:
		var times = 1000
		for i in times:
			var actorId = randi() % ActorHelper.actors_count()
			var actor = ActorHelper.actor(actorId)
			var val = randf() * 100
			actor._set_attr_int(prop, val)
			assertEqual(actor._get_attr_float(prop), float(DataManager.actors[actorId][prop]), prop + "属性")
	return true

func _classStatus() -> bool:
	randomize()
	assertEqual(ActorHelper.actors_count(), DataManager.actors.size(), "全部武将数")
	var statuses = ["出仕", "隐藏", "在野", "流放", "隐居", "俘虏", "死亡", "禁用"]
	var statusDict = {}
	for st in statuses:
		statusDict[st] = 0
	for actorId in DataManager.actors.size():
		DataManager.actors[actorId]["状态"] = ""
	for actorId in ActorHelper.actors_count():
		var actor = ActorHelper.actor(actorId)
		statuses.shuffle()
		var st = statuses[0]
		actor._set_attr_str("状态", st)
		statusDict[st] += 1
	
	assertEqual(ActorHelper.all_actors().size(), DataManager.actors.size(), "全部武将")
	for actor in ActorHelper.all_actors():
		assertIn(actor.get_status(), statusDict.keys(), "状态集合")
	
	assertEqual(ActorHelper.all_available_actors().size(), DataManager.actors.size() - statusDict["禁用"], "可用武将")
	for actor in ActorHelper.all_available_actors():
		assertIn(actor.get_status(), statusDict.keys(), "可用状态")
		assertNotEqual(actor.get_status(), "禁用", "可用状态")
		assertTrue( not actor.is_status_disabled(), "可用状态异常：actor#{0}".format([actor.actorId]))
	
	assertEqual(ActorHelper.all_dead_actors().size(), statusDict["死亡"], "可用武将")
	for actor in ActorHelper.all_dead_actors():
		assertEqual(actor.get_status(), "死亡", "死亡状态")
		assertTrue(actor.is_status_dead(), "死亡状态异常：actor#{0}".format([actor.actorId]))
	
	assertEqual(ActorHelper.all_exiled_actors().size(), statusDict["流放"], "流放武将")
	for actor in ActorHelper.all_exiled_actors():
		assertEqual(actor.get_status(), "流放", "流放状态")
		assertTrue(actor.is_status_exiled(), "流放状态异常：actor#{0}".format([actor.actorId]))
	
	assertEqual(ActorHelper.all_hidden_actors().size(), statusDict["隐藏"], "隐藏武将")
	for actor in ActorHelper.all_hidden_actors():
		assertEqual(actor.get_status(), "隐藏", "隐藏状态")
		assertTrue(actor.is_status_hidden(), "隐藏状态异常：actor#{0}".format([actor.actorId]))
	
	assertEqual(ActorHelper.all_officed_actors().size(), statusDict["出仕"], "出仕武将")
	for actor in ActorHelper.all_officed_actors():
		assertEqual(actor.get_status(), "出仕", "出仕状态")
		assertTrue(actor.is_status_officed(), "出仕状态异常：actor#{0}".format([actor.actorId]))
	
	assertEqual(ActorHelper.all_unofficed_actors().size(), statusDict["在野"], "出仕武将")
	for actor in ActorHelper.all_unofficed_actors():
		assertEqual(actor.get_status(), "在野", "在野状态")
		assertTrue(actor.is_status_unofficed(), "在野状态异常：actor#{0}".format([actor.actorId]))
	return true

func runDataManager() -> bool:
	trace("【DataManager】")
	randomize()
	
	var vstateId = StaticManager.VSTATEID_CAOCAO
	var actorId = StaticManager.ACTOR_ID_DIY
	var teammateId = StaticManager.ACTOR_ID_ZHUGELIANG
	initWar(vstateId, - 1, - 1)
	var me = createWarActor(actorId, vstateId, true)
	var teammate = createWarActor(teammateId, vstateId, true)
	
	var before = 1000 + randi() % 50
	var lvl: int = 1
	DataManager.actors[actorId]["经验值"] = before
	DataManager.actors[actorId]["等级"] = lvl
	DataManager.actors[teammateId]["经验值"] = 0
	DataManager.actors[teammateId]["等级"] = 1
	trace("武将：{0}，经验：{1}，等级：{2}".format([
		DataManager.actors[actorId]["姓名"], 
		DataManager.actors[actorId]["经验值"], 
		DataManager.actors[actorId]["等级"], 
	]))
	trace("队友：{0}，经验：{1}，等级：{2}".format([
		DataManager.actors[teammateId]["姓名"], 
		DataManager.actors[teammateId]["经验值"], 
		DataManager.actors[teammateId]["等级"], 
	]))
	
	
	var times = 10
	var total: float = 0
	for i in times:
		
		var val: float = 10 + randi() * 4990
		DataManager.actor_add_Exp(actorId, val)
		total += val

	
	var expectedLevel = 0
	var levelUpSettings = StaticManager.get_levelup_setting()
	var need_exps = levelUpSettings["所需经验"]
	var after: float = before + total
	need_exps.invert()
	for i in need_exps.size():
		if after >= need_exps[i]:
			expectedLevel = 8 - i
			break
	trace("{0}次累计获得经验：{1}".format([times, total * 100]))
	var actualAfter = DataManager.actors[actorId]["经验值"]
	trace("武将：{0}，经验：{1}，等级：{2}".format([
		DataManager.actors[actorId]["姓名"], 
		DataManager.actors[actorId]["经验值"], 
		DataManager.actors[actorId]["等级"], 
	]))
	trace("队友：{0}，经验：{1}，等级：{2}".format([
		DataManager.actors[teammateId]["姓名"], 
		DataManager.actors[teammateId]["经验值"], 
		DataManager.actors[teammateId]["等级"], 
	]))
	var diff: float = (after - actualAfter) * 100.0
	trace("武将浮点数偏差：{0}".format([diff]))
	if abs(diff) > times:
		warn("武将经验值偏差过大")
	if int(DataManager.actors[actorId]["等级"]) != expectedLevel:
		error("等级不符预期，应为：{0}".format([expectedLevel]))
		return false
	
	var teammateAfter = DataManager.actors[teammateId]["经验值"]
	diff = teammateAfter - total * 0.125
	trace("队友浮点数偏差：{0}".format([diff]))
	if abs(diff) > times:
		warn("队友经验值偏差过大")
	
	trace("拉满试试")
	DataManager.actor_add_Exp(actorId, 90000, false)
	trace("武将：{0}，经验：{1}，等级：{2}".format([
		DataManager.actors[actorId]["姓名"], 
		DataManager.actors[actorId]["经验值"], 
		DataManager.actors[actorId]["等级"], 
	]))
	trace("队友：{0}，经验：{1}，等级：{2}".format([
		DataManager.actors[teammateId]["姓名"], 
		DataManager.actors[teammateId]["经验值"], 
		DataManager.actors[teammateId]["等级"], 
	]))
	if DataManager.actors[actorId]["经验值"] != 99999:
		error("未满经验")
	if DataManager.actors[actorId]["等级"] != 8:
		error("未满八级")
	trace("DataManager PASS\n")
	return true

func runAffairBase() -> bool:
	
	trace("【AffairBase】")
	randomize()
	var actorId = StaticManager.ACTOR_ID_DIY
	var script = Global.load_script("res://resource/sgz_script/affiars/affairs_base.gd")
	var before: float = randi() % 10000
	var lvl: int = randi() % 8 + 1
	DataManager.actors[actorId]["经验值"] = before
	DataManager.actors[actorId]["等级"] = lvl
	trace("{0}：经验：{1}，等级：{2}".format([
		DataManager.actors[actorId]["姓名"], 
		DataManager.actors[actorId]["经验值"], 
		DataManager.actors[actorId]["等级"], 
	]))
	DataManager.clear_common_variable(["内政.ONCE"])
	DataManager.player_choose_city = 0
	var rate = 1
	var times = 100
	var total: int = 0
	for i in times:
		
		var val = randi() % 500
		script.gain_dev_exp(actorId, val)
		total += int(val * rate)
	trace("{0}次累计获得经验：{1}".format([times, total]))
	var after = DataManager.actors[actorId]["经验值"]
	trace("{0}：经验：{1}，等级：{2}".format([
		DataManager.actors[actorId]["姓名"], 
		DataManager.actors[actorId]["经验值"], 
		DataManager.actors[actorId]["等级"], 
	]))
	var diff = after - before - total
	trace("浮点数偏差：{0}".format([diff]))
	if abs(diff) > 1:
		warn("经验值偏差过大")
	if int(DataManager.actors[actorId]["等级"]) != lvl:
		error("武将不应升级")
		return false
	trace("拉满试试")
	script.gain_dev_exp(actorId, (99999 - after * 100) / rate + 2)
	trace("{0}：经验：{1}，等级：{2}".format([
		DataManager.actors[actorId]["姓名"], 
		DataManager.actors[actorId]["经验值"], 
		DataManager.actors[actorId]["等级"], 
	]))
	if DataManager.actors[actorId]["经验值"] != 99999:
		error("未满经验")
	trace("AffairsBase PASS\n")
	return true
