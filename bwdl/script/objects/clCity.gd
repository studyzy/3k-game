extends Resource
class_name clCity

const CITY_PROPERTY_MAX = {
	"金": 9999, 
	"米": 9999, 
	"宝": 99, 
	"土地": 999, 
	"产业": 999, 
	"人口": 999900, 
	"防灾": 99, 
	"统治度": 100, 
	"后备兵": 999900, 
	"战乱度": 100, 
}


class CityInfo:

	var ID: int = - 1

	class DialogInfo:
		var cityId: int = - 1
		var msg = ""
		var mood = 2
		var actorId: int = - 1
		var twinkleCityIds: PoolIntArray = []
		var yn: int = 0
		var hideCityInfo: int = 0
		var bgm: String = ""
		
		func output() -> Dictionary:
			var dic = {
				"cityId": cityId, 
				"msg": msg, 
				"mood": mood, 
				"actorId": actorId, 
				"twinkleCityIds": twinkleCityIds, 
				"yn": yn, 
				"hideCityInfo": hideCityInfo, 
				"bgm": bgm, 
			}
			return dic

		func input(dic: Dictionary):
			cityId = Global.intval(dic["cityId"])
			msg = Global.strval(dic["msg"])
			mood = Global.intval(dic["mood"])
			actorId = Global.intval(dic["actorId"])
			twinkleCityIds = []
			if "twinkleCityIds" in dic:
				twinkleCityIds = Global.intarrval(dic["twinkleCityIds"])
			yn = Global.intval(Global.dic_val(dic, "yn", 0))
			hideCityInfo = Global.intval(Global.dic_val(dic, "hideCityInfo", 0))
			bgm = Global.dic_val(dic, "bgm", "")
			return

	func _init(_ID: int) -> void :
		ID = _ID
		return

	func get_property_static(prop: String):
		if ID < 0 or ID >= StaticManager.citys.size():
			return null
		if not StaticManager.citys[ID].has(prop):
			return null
		return StaticManager.citys[ID][prop]

	func get_property(prop: String):
		if ID < 0 or ID >= DataManager.citys.size():
			return null
		if not DataManager.citys[ID].has(prop):
			return null
		var val = DataManager.citys[ID][prop]
		
		if prop == "人口" and int(val) % 100 > 0:
			val = int(val / 100) * 100 + 100
		return val

	func set_property(prop: String, value) -> void :
		if ID < 0 or ID >= DataManager.citys.size():
			return
		if prop in CITY_PROPERTY_MAX:
			var val = int(value)
			val = max(0, val)
			val = min(val, CITY_PROPERTY_MAX[prop])
			DataManager.citys[ID][prop] = val
		else:
			DataManager.citys[ID][prop] = value
		return

	
	func get_actor_ids() -> PoolIntArray:
		var ret = []
		var actorIds = Global.arrval(get_property("武将"))
		for id in actorIds:
			ret.append(int(id))
		return ret

	
	func get_actors_count() -> int:
		return get_actor_ids().size()

	
	func add_actor(actorId: int) -> void :
		if actorId < 0 or actorId >= StaticManager.ACTOR_ID_RENOU:
			return
		var actors = Array(get_actor_ids())
		actors.append(actorId)
		set_property("武将", actors)
		return

	
	func insert_actor(pos: int, actorId: int) -> void :
		var actors = Array(get_actor_ids())
		actors.insert(pos, actorId)
		set_property("武将", actors)
		return

	
	func remove_actor(actorId: int) -> bool:
		var actors = Array(get_actor_ids())
		var cnt = actors.size()
		actors.erase(actorId)
		set_property("武将", actors)
		if actors.size() < cnt:
			return true
		return false

	
	func clear_actors() -> void :
		set_property("武将", [])
		return

	func set_actors(actorIds: PoolIntArray) -> void :
		set_property("武将", actorIds)
		return

	
	func get_ceil_actor_ids() -> PoolIntArray:
		var ret = []
		var actorIds = get_property("监狱")
		if typeof(actorIds) != TYPE_ARRAY:
			return ret
		for id in actorIds:
			ret.append(int(id))
		return ret

	
	func ceil_add_actor(actorId: int) -> void :
		var actors = Array(get_ceil_actor_ids())
		actors.append(actorId)
		
		var actor = ActorHelper.actor(actorId)
		actor.set_loyalty(min(99, actor.get_loyalty()))
		set_property("监狱", actors)
		return

	
	func ceil_remove_actor(actorId: int) -> void :
		var actors = Array(get_ceil_actor_ids())
		actors.erase(actorId)
		set_property("监狱", actors)
		return

	
	
	func get_connected_city_ids(includeVstateIds: PoolIntArray = [], excludeVstateIds: PoolIntArray = []) -> PoolIntArray:
		var ret = []
		var connected = get_property("连接城")
		if typeof(connected) != TYPE_ARRAY:
			return ret
		for id in connected:
			id = int(id)
			if id == ID:
				continue
			var city = CityInfo.new(id)
			if not includeVstateIds.empty() and not city.get_vstate_id() in includeVstateIds:
				continue
			if not excludeVstateIds.empty() and city.get_vstate_id() in excludeVstateIds:
				continue
			ret.append(city.ID)
		return ret

	
	func get_transfer_city_ids(includingVacant: bool = false) -> PoolIntArray:
		var vstateId = get_vstate_id()
		var allowed = [vstateId]
		if includingVacant:
			allowed.append( - 1)
		var ret = get_connected_city_ids(allowed)
		if not SkillRangeBuff.find_for_vstate("跨城运输", vstateId).empty():
			for city in DataManager.citys:
				if not "归属" in city or not "ID" in city:
					continue
				var cityId = Global.intval(city["ID"])
				if cityId < 0 or cityId == ID:
					continue
				if Global.intval(city["归属"], - 2) in allowed:
					ret.append(cityId)
		return ret

	
	
	
	func add_city_property(attr: String, val: int) -> int:
		if ID < 0 or ID >= DataManager.citys.size():
			return 0
		if not attr in CITY_PROPERTY_MAX:
			return 0
		var current = int(get_property(attr))
		set_property(attr, current + val)
		return int(get_property(attr)) - current
	
	
	func get_door_hp(pos: Vector2) -> int:
		var info = Global.dicval(get_property("城门血量"))
		var key = "({0},{1})".format([pos.y, pos.x])
		if not key in info:
			
			return 100
		return Global.intval(info[key])
	
	
	func set_door_hp(pos: Vector2, hp: int) -> void :
		var info = Global.dicval(get_property("城门血量"))
		var key = "({0},{1})".format([pos.y, pos.x])
		info[key] = int(min(100, max(0, hp)))
		set_property("城门血量", info)
		return

	
	func get_all_door_position() -> PoolVector2Array:
		var city: Dictionary = DataManager.citys[ID];
		if not city.has("城门血量"):
			return PoolVector2Array([]);
		var result = [];
		var dic_hp: Dictionary = city["城门血量"];
		for key in dic_hp.keys():
			var str_key: String = str(key).split("(")[1].split(")")[0];
			var str_key_array = str_key.split(",");
			result.append(Vector2(int(str_key_array[1]), int(str_key_array[0])));
		return result;

	func change_vstate(vstateId: int) -> void :
		var current = get_vstate_id()
		if current == vstateId:
			return
		set_vstate_id(vstateId)
		set_property("委任", 0)
		return

	func set_vstate_id(vstateId: int) -> void :
		set_property("归属", vstateId)
		return

	func get_vstate_id() -> int:
		var val = get_property("归属")
		if val == null:
			return - 1
		return int(val)

	func vstate() -> clVState.VStateInfo:
		return clVState.vstate(get_vstate_id())

	
	func get_lord_id() -> int:
		return vstate().get_lord_id()

	
	func get_lord():
		return ActorHelper.actor(get_lord_id())

	
	func get_lord_name() -> String:
		var lordId = get_lord_id()
		if lordId < 0:
			return "-"
		return get_lord().get_name()

	
	func get_leader_id() -> int:
		var actors = get_actor_ids()
		if actors.empty():
			return - 1
		return actors[0]

	
	func get_leader():
		return ActorHelper.actor(get_leader_id())

	
	func get_leader_name() -> String:
		return get_leader().get_name()

	func add_gold(val: int) -> int:
		return add_city_property("金", val)

	func get_gold() -> int:
		return int(get_property("金"))

	func add_rice(val: int) -> int:
		return add_city_property("米", val)

	func get_rice() -> int:
		return int(get_property("米"))

	func add_treasures(val: int) -> int:
		return add_city_property("宝", val)

	func get_treasures() -> int:
		return int(get_property("宝"))

	func get_pop() -> int:
		return int(get_property("人口"))

	func get_land() -> int:
		return int(get_property("土地"))

	func get_eco() -> int:
		return int(get_property("产业"))

	func get_loyalty() -> int:
		var val = Global.intval(get_property("统治度"))
		for srb in SkillRangeBuff.find_for_city("政提升统治度", ID):
			var actor = ActorHelper.actor(srb.actorId)
			if actor.get_politics() + 1 > val:
				val = actor.get_politics() + 1
		return val

	
	func add_loyalty(val: int) -> int:
		return add_city_property("统治度", val)

	func get_defence() -> int:
		return int(get_property("防灾"))

	func get_name() -> String:
		return Global.strval(get_property("城池名"))

	func get_full_name() -> String:
		var ret = get_name()
		if ret == "":
			return "本城"
		if ret.length() == 1:
			ret += "城"
		return ret

	func get_rice_sell_price() -> int:
		var ret = int(get_property("卖米价"))
		if ret <= 0:
			return 60
		return ret

	func get_rice_buy_price() -> int:
		var ret = int(get_property("买米价"))
		if ret <= 0:
			return 60
		return ret

	func well_developed() -> bool:
			return get_land() >= 999 and get_eco() >= 999 and get_pop() >= 50000

	func get_location() -> Vector2:
		var location = get_property("城池坐标")
		if typeof(location) != TYPE_DICTIONARY:
			return Vector2( - 1, - 1)
		return Vector2(int(location["x"]), int(location["y"]))

	
	func get_equip_shop_type() -> int:
		var shopTypes = get_property_static("装备店")
		if typeof(shopTypes) != TYPE_DICTIONARY:
			return 0
		if not "内政" in shopTypes:
			return 0
		return int(shopTypes["内政"])

	
	func get_war_equip_shop_type() -> int:
		var shopTypes = get_property_static("装备店")
		if typeof(shopTypes) != TYPE_DICTIONARY:
			return 0
		if not "战场" in shopTypes:
			return 0
		return int(shopTypes["战场"])

	func get_chaos_score() -> int:
		var val = get_property("战乱度")
		if val == null:
			return 50
		return int(val)

	func add_chaos_score(val: int) -> int:
		set_property("战乱度", get_chaos_score() + val)
		return get_chaos_score()

	
	func chance_for_disaster(disasterName: String) -> bool:
		var setting = get_property(disasterName)
		if setting == null or not setting:
			return false
		if SkillRangeBuff.max_val_for_city("佛光普照", ID) > 0:
			return false
		
		return Global.get_rate_result(20)

	
	func chance_for_rebellion() -> bool:
		var rates = [50, 30, 10, 5]
		var metrics = [20, 30, 40, 50]
		var rate = 0
		for i in metrics.size():
			if get_loyalty() < metrics[i]:
				rate = rates[i]
				break
		if not Global.get_rate_result(rate):
			return false
		if SkillRangeBuff.max_val_for_city("佛光普照", ID) > 0:
			return false
		return true

	
	func at_left_part() -> bool:
		return get_location().x < 298

	
	func set_fully_developed() -> void :
		for key in ["金", "米", "宝", "土地", "产业", "人口", "防灾", "统治度"]:
			set_property(key, CITY_PROPERTY_MAX[key])
		
		set_property("后备兵", 9999)
		return

	
	func selling_special_horse() -> bool:
		if DataManager.month == 4:
			if well_developed():
				return true
			if "武" in str(get_property("集市")):
				return true
		for steed in get_selling_equips()["坐骑"]:
			if steed.level() == "S":
				return true
		return false

	
	func get_region() -> String:
		var ret = get_property_static("地域")
		if ret == null:
			return ""
		return str(ret)

	
	func get_soldier_price() -> int:
		var price = 20
		var bargain = SkillRangeBuff.min_val_for_city("征兵折扣", ID)
		if bargain > 0:
			price = int(price * bargain / 100.0)
		return price

	
	func has_feature(feature: String) -> bool:
		var cityStatic = StaticManager.get_city_static(ID)
		if not cityStatic.has("特性"):
			return false
		return feature in cityStatic["特性"]

	
	
	func get_special_equips() -> Dictionary:
		var ret = {}
		var keys = ["内", "外"]
		for key in keys:
			ret[key] = []
		var dics = [get_selling_equips(), get_selling_equips(true)]
		for i in dics.size():
			for type in dics[i]:
				var actualType = type
				if not type in StaticManager.EQUIPMENT_TYPES:
					
					actualType = "武器"
				for selling in dics[i][type]:
					if selling.level() == "S":
						ret[keys[i]].append(selling)
		return ret

	
	func get_war_selling_equips() -> Dictionary:
		return get_selling_equips(true)

	
	
	func get_selling_equips(fromWar: bool = false) -> Dictionary:
		var ret = {}
		var setting = StaticManager.get_equip_shop_setting()
		var dic = setting[str(get_equip_shop_type())]
		if fromWar:
			dic = setting[str(get_war_equip_shop_type())]
		for type in dic:
			var actualType = type
			if not type in StaticManager.EQUIPMENT_TYPES:
				
				actualType = "武器"
			var ids = dic[type]
			for id in ids:
				var equip = clEquip.equip(int(id), actualType)
				if not type in ret:
					ret[type] = []
				ret[type].append(equip)
			if type == "坐骑":
				
				if ID == StaticManager.CITY_ID_XIANGPING\
				or DataManager.month == 4\
				or SkillRangeBuff.max_val_for_city("白驹售卖", ID) > 0:
					ret[type].append(clEquip.equip(StaticManager.STEED_BAIJU, type))
				
				if ID == StaticManager.CITY_ID_WUWEI\
				or DataManager.month == 4\
				or SkillRangeBuff.max_val_for_city("汗血售卖", ID) > 0:
					ret[type].append(clEquip.equip(StaticManager.STEED_HANXUE, type))
				
				if ID == StaticManager.CITY_ID_WUWEI:
					var lfs = clEquip.equip(StaticManager.STEED_LIFEISHA, "坐骑")
					if lfs.remaining() > 0:
						
						var rate = 5
						if StaticManager.ACTOR_ID_MACHAO in get_actor_ids():
							rate = 45
						var key = "内政.MONTHLY.里飞沙随机"
						var rnd = DataManager.get_env_int(key)
						if rnd < 0:
							rnd = randi() % 100
							DataManager.set_env(key, rnd)
						if rnd < rate:
							ret[type][0] = lfs
			if has_feature("大"):
				match actualType:
					"道具":
						for item in clEquip.all_equips("道具"):
							if item.id in ids:
								continue
							if item.level_score() >= 9:
								continue
							ret[type].append(item)
					"防具":
						var best = clEquip.best_normal_equip(actualType, "")
						if not best.id in ids:
							ret[type].append(best)
					"武器":
						var best = clEquip.best_normal_equip(actualType, type)
						if not best.id in ids:
							ret[type].append(best)
		return ret

	
	
	
	func better_equip(equip: clEquip.EquipInfo, actorId: int) -> clEquip.EquipInfo:
		var type = equip.type
		if equip.type == "武器":
			type = equip.subtype()
		var sellings = get_selling_equips()
		if not type in sellings:
			return null
		var score = equip.level_score()
		var ret = null
		for selling in sellings[type]:
			
			if selling.remaining() >= 0:
				continue
			if selling.subtype() != equip.subtype():
				continue
			if selling.price() > get_gold() / 2:
				continue
			if not selling.actor_can_use(actorId):
				continue
			
			var level = selling.level()
			if level == "S":
				continue
			if selling.level_score() <= score:
				continue
			score = selling.level_score()
			ret = selling
		return ret

	func set_delegated(b: bool) -> void :
		set_property("委任", (get_vstate_id() + 1) if b else 0)
		return

	func is_delegated() -> bool:
		if Global.intval(get_property("委任")) != get_vstate_id() + 1:
			return false
		if get_actor_ids().empty():
			return false
		if get_leader_id() == get_lord_id():
			return false
		return true

	func get_auto_embattle_positions(dir: int) -> PoolVector2Array:
		var ret = []
		var dic = Global.dicval(get_property("自动布阵"))
		if not str(dir) in dic:
			return ret
		for posInfo in Global.arrval(dic[str(dir)]):
			var p = Global.strval(posInfo).split("|")
			if p.size() == 2:
				var pos = Vector2(int(p[0]), int(p[1]))
				ret.append(pos)
		return ret

	func set_auto_embattle_positions(dir: int, positions: PoolVector2Array) -> void :
		var posInfo = []
		for pos in positions:
			posInfo.append("{0}|{1}".format([pos.x, pos.y]))
		var setting = Global.dicval(get_property("自动布阵"))
		setting[str(dir)] = posInfo
		set_property("自动布阵", setting)
		return

	func get_backup_soldiers() -> int:
		return Global.intval(get_property("后备兵"), 0)

	func attach_free_dialog(
		msg: String, actorId: int = - 1, mood: int = 2, 
		twinkleCityIds: PoolIntArray = [], hideCityInfo: int = 0, bgm: String = ""
		) -> void :
		var d = DialogInfo.new()
		d.cityId = ID
		d.msg = msg
		d.actorId = actorId
		d.mood = mood
		d.twinkleCityIds = twinkleCityIds
		d.hideCityInfo = hideCityInfo
		d.bgm = bgm
		var dialogs = Global.arrval(get_property("内政对话"))
		dialogs.append(d.output())
		set_property("内政对话", dialogs)
		return

	func next_free_dialog() -> DialogInfo:
		var dialogs = Global.arrval(get_property("内政对话"))
		if dialogs.empty():
			return null
		var data = dialogs.pop_front()
		set_property("内政对话", dialogs)
		var d = DialogInfo.new()
		d.input(data)
		return d

	
	
	
	func fix_lord_position() -> bool:
		if get_vstate_id() < 0:
			return false
		var leaderId = get_leader_id()
		if leaderId < 0:
			return false
		var leader = ActorHelper.actor(leaderId)
		if leader.get_loyalty() >= 100:
			return false
		var actorIds = get_actor_ids()
		for i in range(1, actorIds.size()):
			var actor = ActorHelper.actor(actorIds[i])
			if actor.get_loyalty() >= 100:
				actorIds.erase(actor.actorId)
				actorIds.insert(0, actor.actorId)
				set_actors(actorIds)
				print("ERROR: 城池【{0}】#{1}中君主{2}#{3}不是太守，已修复".format([
					get_name(), ID, actor.get_name(), actor.actorId, 
				]))
				return true
		return false

	func mark_inspected(byVstateId: int) -> void :
		var inspected = get_inspected()
		var timing = DataManager.year * 12 + DataManager.month
		inspected[str(byVstateId)] = timing
		set_property("侦察标记", inspected)
		return

	func get_inspected() -> Dictionary:
		return Global.dicval(get_property("侦察标记"))

	func inspection_left(byVstateId: int) -> int:
		var inspected = get_inspected()
		if not str(byVstateId) in inspected:
			return 0
		var timing = DataManager.year * 12 + DataManager.month
		var left = int(inspected[str(byVstateId)]) + 12 - timing
		if left < 0:
			return 0
		return left

	
	
	
	
	func get_ranged_buff_min_val(tag: String) -> int:
		var MAX_VAL = 999999
		var ret = SkillRangeBuff.min_val_for_city(tag, ID, MAX_VAL)
		ret = min(ret, SkillRangeBuff.min_val_for_vstate(tag, get_vstate_id(), MAX_VAL))
		if ret == MAX_VAL:
			ret = - 1
		return ret

	
	
	
	
	func get_ranged_buff_max_val(tag: String) -> int:
		var MIN_VAL = - 1
		var ret = SkillRangeBuff.min_val_for_city(tag, ID, MIN_VAL)
		ret = max(ret, SkillRangeBuff.min_val_for_vstate(tag, get_vstate_id(), MIN_VAL))
		return ret



static func city(id: int) -> CityInfo:
	return CityInfo.new(id)


static func get_unoffice_actors(cityId: int) -> PoolIntArray:
	var is_random_place = false
	if DataManager.get_game_setting("出仕地点") == "随机":
		is_random_place = true
	var actorIds = []
	var city = CityInfo.new(cityId)
	
	for follow_info in DataManager.actor_follower:
		var parent = ActorHelper.actor(follow_info["父将"])
		var child = ActorHelper.actor(follow_info["子将"])
		
		if not is_random_place:
			if not (parent.is_status_dead() or parent.is_status_disabled()):
				continue
			if parent.get_exiled_city_id() != cityId:
				continue
		if not child.is_status_unofficed():
			continue
		var appearYear = child.get_appear_year(int(follow_info["登场年"]))
		if appearYear > DataManager.year:
			continue
		actorIds.append(child.actorId)
	
	for dic in DataManager.citys_unoffice:
		if not is_random_place and int(dic["城池"]) != cityId:
			continue
		var actorId = int(dic["武将"])
		var actor = ActorHelper.actor(actorId)
		if not actor.is_status_unofficed():
			continue
		var appearYear = actor.get_appear_year(int(dic["登场年"]))
		if appearYear > DataManager.year:
			continue
		actorIds.append(actorId)
	
	for actor in ActorHelper.all_exiled_actors():
		var exiledCityId = actor.get_exiled_city_id()
		if is_random_place\
		or exiledCityId == cityId\
		or exiledCityId in city.get_connected_city_ids():
			actorIds.append(actor.actorId)
	
	if is_random_place:
		actorIds.shuffle()
	
	return actorIds

static func add_city_property(cityId: int, attr: String, val: int) -> int:
	var ci = CityInfo.new(cityId)
	return ci.add_city_property(attr, val)



static func move_to(actorId: int, toCityId: int, keptActorIds: PoolIntArray = []):
	var actor = ActorHelper.actor(actorId)
	var city = CityInfo.new(toCityId)
	move_out(actorId)
	actor.set_status_officed()
	actor._set_attr("所在城", city.ID)
	
	var prevIdx = keptActorIds.find(actorId)
	if prevIdx >= 0:
		
		var located = false
		var currentActorIds = city.get_actor_ids()
		for i in range(prevIdx - 1, - 1, - 1):
			
			var referecedActorId = keptActorIds[i]
			var currentIdx = currentActorIds.find(referecedActorId)
			if currentIdx >= 0:
				
				located = true
				city.insert_actor(currentIdx + 1, actorId)
				break
		if not located:
			
			
			city.insert_actor(0, actorId)
			located = true
	else:
		
		
		city.add_actor(actorId)
	
	var lordId = city.get_lord_id()
	if lordId in city.get_actor_ids():
		city.remove_actor(lordId)
		city.insert_actor(0, lordId)
		ActorHelper.actor(lordId).set_loyalty(100)
	else:
		
		
		if city.get_vstate_id() >= 0:
			actor.set_loyalty(min(99, actor.get_loyalty()))
	
	var removed = actor.remove_extra_soldiers()
	if removed > 0:
		city.add_city_property("后备兵", removed)
	return


static func move_out(actorId: int):
	for cityData in DataManager.citys:
		var city = CityInfo.new(cityData["ID"])
		city.remove_actor(actorId)
		city.ceil_remove_actor(actorId)
	var actor = ActorHelper.actor(actorId)
	actor._set_attr("所在城", - 1)
	return


static func move_to_ceil(actorId: int, toCityId: int):
	var actor = ActorHelper.actor(actorId)
	var toCity = CityInfo.new(toCityId)
	move_out(actorId)
	actor.set_status_captured()
	toCity.ceil_add_actor(actorId)
	return


static func find_new_home(actorId: int) -> bool:
	var actor = ActorHelper.actor(actorId)
	var dislikeVstateId = actor.get_dislike_vstate_id()
	var availables = []
	for city in all_cities():
		if city.get_vstate_id() == dislikeVstateId:
			continue
		if actor.get_exiled_city_id() == city.ID:
			continue
		availables.append(city.ID)
	if availables.empty():
		return false
	availables.shuffle()
	actor.set_exile_city(availables[0])
	return true

static func all_cities(vstateIds: PoolIntArray = []) -> Array:
	var ret = []
	for city in DataManager.citys:
		var c = CityInfo.new(int(city["ID"]))
		if not vstateIds.empty() and not c.get_vstate_id() in vstateIds:
			continue
		ret.append(c)
	return ret

static func all_city_ids(vstateIds: PoolIntArray = []) -> PoolIntArray:
	var ret = []
	for city in all_cities(vstateIds):
		ret.append(city.ID)
	return ret

static func search_cities(keyword: String = "") -> Array:
	var ret = []
	for city in DataManager.citys:
		var c = CityInfo.new(int(city["ID"]))
		if keyword == "":
			ret.append(c)
			continue
		if StaticManager.RE_ALPHA.search(keyword) != null:
			var found = false
			for r in StaticManager.pinyin(c.get_name()):
				if keyword in r:
					found = true
					ret.append(c)
					break
			if found:
				continue
			for r in StaticManager.pinyin(c.get_lord_name()):
				if keyword in r:
					found = true
					ret.append(c)
					break
			if found:
				continue
		if keyword in c.get_full_name():
			ret.append(c)
			continue
		if keyword in c.get_lord_name():
			ret.append(c)
			continue
	return ret

static func random_city_id() -> int:
	var all = all_city_ids()
	all.shuffle()
	return all[0]


static func get_capital_city(vstateId: int) -> CityInfo:
	if vstateId < 0:
		return null
	for city in all_cities([vstateId]):
		var actors = city.get_actor_ids()
		if actors.empty():
			continue
		if actors[0] == city.get_lord_id():
			
			clVState.vstate(vstateId).set_capital_id(city.ID)
			return city
	return null



static func list_stored_equipments_paged(vstateId: int, includingAllCity: bool = false, excludeSpecials: bool = false, specifiedTypes: PoolStringArray = []) -> Array:
	var vs = clVState.vstate(vstateId)
	var page = DataManager.get_env_int("列表页码")
	
	var list = vs.list_stored_equipments()
	if not specifiedTypes.empty():
		var updated = []
		for item in list:
			if not item[0].type in specifiedTypes:
				continue
			updated.append(item)
		list = updated
	if excludeSpecials:
		var updated = []
		for item in list:
			if item[0].level() == "S":
				continue
			updated.append(item)
		list = updated
	elif includingAllCity:
		if list.size() % 2 == 1:
			list.append([null, 0])
		
		for city in all_cities([vstateId]):
			for actorId in city.get_actor_ids():
				for type in StaticManager.EQUIPMENT_TYPES:
					var equip = ActorHelper.actor(actorId).get_equip(type)
					if equip.level() == "S":
						list.append([equip, 1, actorId, city.ID])
						list.append([null, 0])
	var pageSize = 12
	var maxPage = int(ceil((list.size() - 1) / pageSize))
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	DataManager.set_env("列表页码", page)
	DataManager.set_env("列表页数", maxPage)
	var from = page * pageSize
	var to = min(list.size(), from + pageSize) - 1
	list = list.slice(from, to)
	var items = []
	var values = []
	for item in list:
		var equip = item[0]
		if equip == null:
			items.append("")
			values.append({"ID": - 1, "类型": "", "装备库数量": 0})
			continue
		var dic = {
			"ID": equip.id, 
			"类型": equip.type, 
			"装备库数量": item[1], 
		}
		var label = "{0} x{1}".format([equip.name(), item[1]])
		if item[1] == 1:
			label = equip.name()
		if item.size() == 4:
			var actor = ActorHelper.actor(item[2])
			var city = city(item[3])
			label += "　".repeat(5 - equip.name().length())
			if city.ID != DataManager.player_choose_city:
				label += "（{0} {1}）"
			else:
				label += "（{0}）"
			label = label.format([
				actor.get_name(), city.get_name(), 
			])
			dic["装备武将"] = actor.actorId
		var code = equip.get_name_color_code()
		if code != "":
			label += code
		items.append(label)
		values.append(dic)
	for i in range(items.size(), 14):
		items.append("")
		values.append("")
	if maxPage > 0:
		items.append("下一页")
		values.append({"ID": - 1, "类型": "下一页"})
		items.append("上一页")
		values.append({"ID": - 1, "类型": "上一页"})
	return [items, values]

static func get_city_distance(from: int, to: int, checkVState: bool = false) -> int:
	if from == to:
		return 0
	var fromCity = city(from)
	var vstateIds = []
	if checkVState:
		vstateIds = [ - 1, fromCity.get_vstate_id()]
	var checkings = {from: 0}
	var checked = []
	while not checkings.empty():
		var id = checkings.keys()[0]
		var distance = checkings[id]
		checkings.erase(id)
		if id in checked:
			continue
		checked.append(id)
		var city = city(id)
		for next in city.get_connected_city_ids(vstateIds):
			if next == to:
				return distance + 1
			checkings[next] = distance + 1
	return 0



static func get_attackable_city_ids(from: CityInfo) -> Dictionary:
	var fromVstateId = from.get_vstate_id()
	var targetIds = from.get_connected_city_ids([], [fromVstateId])
	var ret = {}
	var checked = []
	for targetId in targetIds:
		var targetCity = city(targetId)
		var targetVstateId = targetCity.get_vstate_id()
		if not clVState.get_alliance_month(fromVstateId, targetVstateId) > 0:
			ret[targetId] = [from.ID]
		if targetVstateId in checked:
			continue
		checked.append(targetVstateId)
		if SkillRangeBuff.max_val_for_vstate("引狼入室", targetVstateId) >= 1:
			for invitedCity in all_cities([targetVstateId]):
				for extraId in invitedCity.get_connected_city_ids([], [fromVstateId, targetVstateId]):
					if extraId in ret:
						continue
					var extraCity = city(extraId)
					if clVState.get_alliance_month(fromVstateId, extraCity.get_vstate_id()) > 0:
						continue
					
					var route = get_route_via_cities(from.ID, extraId, [targetVstateId])
					if route.empty():
						continue
					ret[extraId] = route
	return ret



static func get_movable_city_ids(from: CityInfo) -> Dictionary:
	var ret = {}
	var fromVstateId = from.get_vstate_id()
	for connectedId in from.get_connected_city_ids([ - 1, fromVstateId]):
		ret[connectedId] = [from.ID]
	return ret






static func get_route_via_cities(fromId: int, targetId: int, allowedVstateIds: PoolIntArray, prevRoute: Array = []) -> Array:
	
	prevRoute = prevRoute.duplicate()
	prevRoute.append(fromId)
	if fromId == targetId:
		return prevRoute
	var fromCity = city(fromId)
	var connected = fromCity.get_connected_city_ids()
	if targetId in connected:
		prevRoute.append(targetId)
		return prevRoute
	if prevRoute.size() > 10:
		
		return []
	var possibles = []
	for nextId in connected:
		if nextId in prevRoute:
			
			continue
		var nextCity = city(nextId)
		if not nextCity.get_vstate_id() in allowedVstateIds:
			
			continue
		var next = get_route_via_cities(nextId, targetId, allowedVstateIds, prevRoute)
		if next.empty():
			continue
		
		possibles.append(next)
	var maxLength = 99
	var shortest = []
	
	for route in possibles:
		if route.size() < maxLength:
			maxLength = route.size()
			shortest = route
	
	return shortest




static func transfer_to(actorId: int, targetCityId: int) -> bool:
	var current = DataManager.get_office_city_by_actor(actorId)
	var currentVstateId = - 1 if current == null else current.get_vstate_id()
	move_out(actorId)
	if current != null and current.get_actors_count() == 0:
		current.change_vstate( - 1)
	var targetCity = city(targetCityId)
	if targetCity.get_vstate_id() == - 1 and currentVstateId >= 0:
		targetCity.change_vstate(currentVstateId)
	move_to(actorId, targetCity.ID)
	var actor = ActorHelper.actor(actorId)
	actor.set_status_officed()
	return true
