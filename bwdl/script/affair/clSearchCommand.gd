# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/affair/clSearchCommand.gd
# 说明：「搜索」内政命令。处理搜寻在野人才、招募武将的流程。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource




class_name SearchCommand

# 势力 / 城市 / 君主 / 执行搜索的武将
var vstateId: int
var cityId: int
var lordId: int
var fromId: int
# 搜索结果：1=缴获金 2=捐米 3=捐金 4=得宝 5/6/7=发现武将 8=无果 9=拒绝 10=特殊拒绝
var result: int
var gold: int = 0
var rice: int = 0
var treasure: int = 0
var buffed: int = 0
var specifiedFoundActorId: int = - 1
var foundActorId: int = - 1
var actorJoin: int = 0
var actorCost: int = 0
var mood: int = 0

# 相性距离（决定武将是否愿意加入及初始忠诚度）
var distance: int

# 加入后的忠诚度上下限
var minLoyalty: int = 30
var maxLoyalty: int = 99

var done: int = 0

# 对话序列
var dialogs: Array = []


func _init(_cityId: int, _fromId: int) -> void :
	cityId = _cityId
	fromId = _fromId
	lordId = city().get_lord_id()
	vstateId = city().get_vstate_id()
	result = 8
	return

func vstate() -> clVState.VStateInfo:
	return clVState.vstate(vstateId)

func city() -> clCity.CityInfo:
	return clCity.city(cityId)

func lord() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(lordId)

func actioner() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(fromId)

func found_actor() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(foundActorId)


# 决定搜索结果：根据执行武将的「德」「政」查表，再随机取一个结果
func decide_result() -> int:
	specifiedFoundActorId = - 1
	# 默认无果
	result = 8

	var results = StaticManager.get_search_setting()
	var actor = actioner()
	var list = []
	# 遍历结果表，找到首个「德」「政」均不超过执行武将的档位，取该档的结果列表
	for r in results:
		var mor = int(r["德"])
		var pol = int(r["政"])
		if mor < actor.get_moral() or pol < actor.get_politics():
			continue
		list.append_array(r["List"])
		break

	# 随机取一个结果
	if not list.empty():
		list.shuffle()
		result = list[0]
	if not result in [5, 6, 7]:
		return result
	# 结果是「发现武将」时，若城中没有在野武将则换一个非武将类结果
	var unoffices = clCity.get_unoffice_actors(cityId)
	if not unoffices.empty():
		return result
	
	var relist = []
	for r in list:
		if r in [5, 6, 7, 8]:
			continue
		relist.append(r)
	if relist.empty():
		# 没有候选结果则退化为无果
		result = 3
	relist.shuffle()
	result = relist[0]
	return result


# 执行搜索结果：根据 result 结算金/米/宝/武将
func execute() -> void :
	gold = 0
	rice = 0
	treasure = 0
	buffed = 0
	foundActorId = - 1
	mood = 1
	dialogs.clear()
	
	var goldRate = SkillRangeBuff.max_val_for_actor("搜金倍率", fromId, 100) / 100.0
	var riceRate = SkillRangeBuff.max_val_for_actor("搜米倍率", fromId, 100) / 100.0

	var msg = ""
	match result:
		1:
			gold = Global.get_random(30, 70)
			buffed = int(gold * goldRate) - gold
			msg = "于城外搜集情报之时\n遭遇并消灭强盗\n缴获{0}{1}两金"
			city().add_gold(gold + buffed)
		2:
			rice = Global.get_random(50, 90)
			buffed = int(rice * riceRate) - rice
			msg = "城邑中偶遇富豪\n获得捐赠{0}{1}石米"
			city().add_rice(rice + buffed)
		3:
			gold = Global.get_random(80, 120)
			buffed = int(gold * goldRate) - gold
			msg = "城邑中偶遇富豪\n获得捐赠{0}{1}两金"
			city().add_gold(gold + buffed)
		4:
			treasure = Global.get_random(1, 3)
			buffed = 0
			msg = "发现{0}{1}件宝物\n已置入仓库内"
			city().add_treasures(treasure + buffed)
		8:
			mood = 3
			msg = "非常可惜\n并无值得一提之事"
		_:
			if specifiedFoundActorId >= 0:
				foundActorId = specifiedFoundActorId
			else:
				var unoffices = clCity.get_unoffice_actors(cityId)
				if unoffices.empty():
					result = 8
				else:
					foundActorId = unoffices[0]
			msg = "遇见一位前途无量之武将"

	
	var memo = ""
	if buffed > 0:
		memo = "(+{0})".format([buffed])
	if gold > 0:
		msg = msg.format([gold, memo])
	elif rice > 0:
		msg = msg.format([rice, memo])
	elif treasure > 0:
		msg = msg.format([treasure, memo])
	add_dialog(msg, fromId, 2)

	if foundActorId >= 0:
		decide_actor_result()

	return


# 决定被发现的武将是否加入：
# 核心依据是「相性距离」(personality_distance)，距离越小越愿意加入、初始忠诚度越高。
func decide_actor_result():
	actorJoin = 1
	actorCost = 0

	var found = found_actor()

	# 若武将厌恶本势力，通常直接拒绝（除非有「解仇」技能）
	if found.get_dislike_vstate_id() == vstateId:
		for srb in SkillRangeBuff.find_for_vstate("解仇", vstateId):
			if srb.effectTagVal > 0:
				var buffActor = ActorHelper.actor(srb.actorId)
				add_dialog("某虽不才，不事无义之主！", foundActorId, 0)
				var title = "我主"
				if buffActor.actorId == city().get_lord_id():
					title = "孤"
				var msg = "前事实有诸般不得己\n今{1}诚意相招\n望{0}大量，新生不念旧怨".format([
					DataManager.get_actor_honored_title(foundActorId, buffActor.actorId), title
				])
				add_dialog(msg, buffActor.actorId, 1)
				msg = "…… ……\n{0}意诚，某亦感念\n往事不论。愿效犬马之劳！".format([
					DataManager.get_actor_honored_title(buffActor.actorId, found.actorId), 
				])
				add_dialog(msg, found.actorId, 2)
				actorCost = 0
				
				distance = buffActor.personality_distance(found)
				accept_actor()
				
				dialogs.pop_back()
				return
		
		result = 9
		actorJoin = 0
		add_dialog("无义小人!吾宁死不随也!", foundActorId, 0)
		
		clCity.find_new_home(foundActorId)
		return

	# 武将身价 = (体力 + 武力 + 智力) / 3，决定招募所需花费
	var actorValue = int((found.get_hp() + found.get_power() + found.get_wisdom()) / 3)
	# 「唯才是举」技能可无视相性距离
	if SkillRangeBuff.max_val_for_city("唯才是举", cityId) > 0:
		distance = 0
	elif SkillRangeBuff.max_val_for_vstate("唯才是举", vstateId) > 0:
		distance = 0
	else:
		# 取与执行武将、君主两人中更近的相性距离
		distance = found.personality_distance(actioner())
		distance = min(distance, found.personality_distance(lord()))
	if distance == 0:
		# 相性完全一致：免费加入（甚至可能带钱/宝物来投）
		result = 6
		actorJoin = 1
		actorCost = - actorValue
		# 20% 概率带来 999 金（等价于宝物）
		if Global.get_rate_result(20):
			actorCost = - 999
	elif distance <= 10:
		# 相性接近：免费加入
		result = 5
		actorCost = 0
	elif result == 6:
		# 相性一般：需按身价支付金钱
		actorJoin = 1
		
		actorCost = actorValue
		if actorCost == 0:
			result = 5

	
	var easyVstates = get_easy_find_vstate_by_actor()
	if result != 7:
		if not easyVstates.empty():
			
			result = 7

	if result == 7:
		var refusedTimes = get_special_refuse_times()
		var refuseRate = int(ceil(13.0 / 15.0 * 100))
		if vstateId in easyVstates:
			refuseRate = int(ceil(2.0 / 15.0 * 100))
		else:
			
			refuseRate = max(50, refuseRate - refusedTimes * 20)

		if Global.get_rate_result(refuseRate):
			add_special_refuse_times()
			
			result = 10
			actorJoin = 0
			var msg = "在下久居山野\n请恕实在不能从命…\n(已被拒绝{0}次)".format([
				refusedTimes + 1
			])
			
			dialogs.pop_back()
			add_dialog(msg, foundActorId, 2)
			SkillHelper.auto_trigger_skill(fromId, 10005)
			return

		
		actorJoin = 1
		actorCost = 0
		add_dialog("闲谈之中此人似乎无意出山\n大人是否亲自劝说？", fromId, 2, true)
	else:
		
		var msg = "是否收入麾下？"
		if actorCost > 0:
			msg = "该武将索要{0}两金\n是否给予？".format([actorCost])
		elif actorCost < 0:
			msg = "该武将带来{0}两金\n是否收下？".format([abs(actorCost)])
			if actorCost <= - 100:
				msg = "该武将带来1个宝物\n是否收下？"
		add_dialog(msg, fromId, 2, true)
	return





# 根据相性距离决定加入武将的初始忠诚度：
# 距离越小忠诚越高；距离很大时忠诚上限被压低。
func decide_loyalty_by_distance() -> void :
	var msg = "愿效犬马之劳"
	var mood = 2
	minLoyalty = 30
	maxLoyalty = 99
	if distance == 0:
		msg = "凤非梧不栖\n终遇明主矣"
		mood = 1
		minLoyalty = 90
	elif distance <= 10:
		msg = "良臣择主而事\n今偿所愿矣"
		mood = 1
		minLoyalty = 85 - distance
	elif distance >= 40:
		msg = "暂且栖身此处吧 ……"
		mood = 3
		maxLoyalty = 50 - int(distance / 5)
	else:
		minLoyalty = max(30, 70 - int(distance / 2))
	var buffed = SkillRangeBuff.max_val_for_actor("加入最低忠诚度", lordId)
	minLoyalty = max(minLoyalty, buffed)
	add_dialog(msg, foundActorId, mood)
	return


# 确认武将加入：扣除金钱（或收钱/宝物），把武将转入本城并设置忠诚度
func accept_actor() -> bool:
	if done:
		return false
	done = 1

	if city().get_gold() < actorCost:
		
		actorJoin = 0
		add_dialog("城内金钱不足", fromId, 3)
		return false

	
	decide_loyalty_by_distance()

	var found = found_actor()
	if actorCost <= - 100:
		city().add_treasures(1)
	else:
		city().add_gold( - actorCost)
	clCity.transfer_to(foundActorId, cityId)
	found.set_status_officed(vstateId)
	found.set_soldiers(0)
	if found.get_loyalty() < minLoyalty:
		found.set_loyalty(minLoyalty + randi() % 5)
	if found.get_loyalty() > maxLoyalty:
		found.set_loyalty(maxLoyalty - randi() % 5)
	var msg = "- <y{0}>加入<y{1}>军，出仕于<g{2}>".format([
		found.get_name(), city().get_lord_name(), city().get_full_name(), 
	])
	DataManager.record_affair_log(msg)
	return true



func force_actor_join(targetId: int) -> void :
	result = 5
	foundActorId = targetId
	actorJoin = 1
	actorCost = 0
	if SkillRangeBuff.max_val_for_city("唯才是举", cityId) > 0:
		distance = 0
	elif SkillRangeBuff.max_val_for_vstate("唯才是举", vstateId) > 0:
		distance = 0
	else:
		distance = found_actor().personality_distance(actioner())
	decide_loyalty_by_distance()
	accept_actor()
	return


func get_easy_find_vstate_by_actor() -> PoolIntArray:
	var result = []
	var settings = StaticManager.get_vstate_easy_actor_setting()
	for vs in settings.keys():
		var list = PoolIntArray(settings[vs])
		if foundActorId in list:
			result.append(int(vs))
	return result


func get_special_refuse_times() -> int:
	var key = "内政.搜索被拒"
	var history = DataManager.get_env_dict(key)
	var subkey = "{0}.{1}".format([cityId, foundActorId])
	if not subkey in history:
		return 0
	return Global.intval(history[subkey])


func add_special_refuse_times() -> void :
	var key = "内政.搜索被拒"
	var history = DataManager.get_env_dict(key)
	var subkey = "{0}.{1}".format([cityId, foundActorId])
	if not subkey in history:
		history[subkey] = 0
	history[subkey] += 1
	DataManager.set_env(key, history)
	return


func update_special_actor_history():
	var key = "内政.搜索被拒"
	var history = DataManager.get_env_dict(key)
	for subkey in history.keys():
		var pieces = subkey.split(".")
		if pieces.size() != 2:
			continue
		var cityId = int(pieces[0])
		var actorId = int(pieces[1])
		var actor = ActorHelper.actor(actorId)
		if actor.is_status_unofficed():
			continue
		if actor.is_status_exiled():
			continue
		history.erase(subkey)
	DataManager.set_env(key, history)
	return


func get_save_data() -> Dictionary:
	var ret = {}
	
	for prop in get_property_list():
		match prop.type:
			TYPE_INT:
				ret[prop.name] = get(prop.name)
			TYPE_STRING:
				ret[prop.name] = get(prop.name)
	var dialogData = []
	for d in dialogs:
		dialogData.append(d.output())
	ret["dialogs"] = dialogData
	return ret


func load_from_save_data(dic: Dictionary) -> void :
	
	for prop in get_property_list():
		if not prop.name in dic:
			continue
		match prop.type:
			TYPE_INT:
				set(prop.name, Global.intval(dic[prop.name]))
			TYPE_REAL:
				set(prop.name, Global.intval(dic[prop.name]))
			TYPE_STRING:
				set(prop.name, Global.strval(dic[prop.name]))
	dialogs = []
	if "dialogs" in dic:
		for dialogData in dic["dialogs"]:
			var d = clCity.CityInfo.DialogInfo.new()
			d.input(dialogData)
			dialogs.append(d)
	return


func affair_report() -> void :
	DataManager.record_affair_log("  - <r{0}>巡检四野".format([
		actioner().get_name(), 
	]), true)
	match result:
		1:
			DataManager.record_affair_log("  - 消灭强盗，缴获金<y{0}>-><y{1}>".format([
				gold, city().get_gold(), 
			]), true)
		2:
			DataManager.record_affair_log("  - 富豪捐赠，获得米<y{0}>-><y{1}>".format([
				rice, city().get_rice(), 
			]), true)
		3:
			DataManager.record_affair_log("  - 富豪捐赠，获得金<y{0}>-><y{1}>".format([
				gold, city().get_gold(), 
			]), true)
		4:
			DataManager.record_affair_log("  - 搜索秘藏，获得宝<y{0}>-><y{1}>".format([
				treasure, city().get_treasures(), 
			]), true)
		_:
			DataManager.record_affair_log("  - 很遗憾，一无所获", true)
	return

func add_dialog(msg: String, actorId: int, mood: int, asking: bool = false) -> clCity.CityInfo.DialogInfo:
	var d = clCity.CityInfo.DialogInfo.new()
	d.cityId = cityId
	d.actorId = actorId
	d.msg = msg
	d.mood = mood
	if asking:
		d.yn = 1
	dialogs.append(d)
	return d

func next_dialog() -> clCity.CityInfo.DialogInfo:
	return dialogs.pop_front()
