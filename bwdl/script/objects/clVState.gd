extends Resource
class_name clVState

class VStateInfo:
	
	var id: int

	func _init(vstateId: int):
		id = vstateId
		return

	func _get_property_static(key: String):
		if id < 0 or id >= StaticManager.vstates_static.size():
			return null
		var vsStatic = StaticManager.vstates_static[id].duplicate(true)
		if not vsStatic.has(key):
			return null
		return vsStatic[key]

	func _get_property(key: String):
		if id < 0 or id >= DataManager.vstates.size():
			return null
		var vs = DataManager.vstates[id]
		if not vs.has(key):
			return null
		return vs[key]

	func _set_property(key: String, val) -> void :
		if id < 0 or id >= DataManager.vstates.size():
			return
		var original = Global.dic_val(DataManager.vstates[id], key, null)
		DataManager.vstates[id][key] = val
		if key == "武库" and original != null:
			var currentSke = SkillHelper.read_skill_effectinfo()
			match DataManager.get_current_scene_id():
				10000:
					
					if currentSke != null and currentSke.trigger_Id != 10021:
						SkillHelper.auto_trigger_skill(get_lord_id(), 10021)
				20000:
					
					if currentSke != null and currentSke.trigger_Id != 20044:
						
						var wf = DataManager.get_current_war_fight()
						var wv = wf.get_war_vstate(id)
						if wv != null:
							SkillHelper.auto_trigger_skill(wv.main_actorId, 20044)
		return

	func _remove_property(key: String) -> void :
		if id < 0 or id >= DataManager.vstates.size():
			return
		DataManager.vstates[id].erase(key)
		return

	func set_lord(lordId: int) -> void :
		_set_property("君主", lordId)
		return

	func get_lord_id() -> int:
		var lord = _get_property("君主")
		if lord == null:
			return - 1
		return int(lord)

	func get_lord():
		return ActorHelper.actor(get_lord_id())

	func get_lord_name() -> String:
		return get_lord().get_name()

	
	func get_dynasty_title() -> String:
		var ret = _get_property("国号")
		if ret == null:
			return ""
		return str(ret)

	
	func get_dynasty_title_or_lord_name() -> String:
		var ret = get_dynasty_title()
		if ret == "":
			ret = get_lord_name()
		return ret

	
	
	func get_stored_equipments() -> Array:
		var equipDict = Global.dicval(_get_property("武库"))
		if equipDict.empty():
			
			
			_update_equipment_storage()
		equipDict = Global.dicval(_get_property("武库"))
		var ret = []
		for type in equipDict:
			for row in equipDict[type]:
				ret.append([clEquip.equip(int(row[0]), type), int(row[1])])
		return ret

	
	
	func list_stored_equipments(excepted: PoolStringArray = []) -> Array:
		var dic = {}
		for row in get_stored_equipments():
			var equip = row[0]
			var count = int(row[1])
			var key = "{0}.{1}".format([equip.id, equip.type])
			if key in excepted:
				continue
			if not dic.has(key):
				dic[key] = [equip, 0]
			dic[key][1] += count
		var ret = dic.values()
		ret.sort_custom(self, "_equip_list_sort")
		return ret

	func _equip_list_sort(a, b) -> bool:
		var eqa = a[0]
		var eqb = b[0]
		
		var typeIdxA = StaticManager.EQUIPMENT_TYPES.find(eqa.type)
		var typeIdxB = StaticManager.EQUIPMENT_TYPES.find(eqb.type)

		var sortingA = eqa.level_score() * 1000 + (4 - typeIdxA) * 1000000 - (1000 - eqa.id)
		var sortingB = eqb.level_score() * 1000 + (4 - typeIdxB) * 1000000 - (1000 - eqb.id)
		
		return sortingA > sortingB

	
	
	
	func _update_equipment_storage() -> void :
		var oldData = Global.arrval(_get_property("装备仓库"))
		var newData = Global.dicval(_get_property("武库"))
		var ret = []
		for item in oldData:
			var equipId = int(item["ID"])
			var equipType = str(item["类型"])
			if not equipType in newData:
				newData[equipType] = []
			var found = false
			for row in newData[equipType]:
				if int(row[0]) == equipId:
					found = true
					var equip = clEquip.equip(equipId, equipType)
					if equip.level() != "S":
						row[1] += 1
					break
			if not found:
				newData[equipType].append([equipId, 1])
		_set_property("武库", newData)
		_remove_property("装备仓库")
		return

	
	
	func remove_stored_equipment(equip: clEquip.EquipInfo, removeAll: bool = false) -> int:
		var removed = 0
		var equipDict = Global.dicval(_get_property("武库"))
		if equipDict.empty():
			
			
			_update_equipment_storage()
		equipDict = Global.dicval(_get_property("武库"))
		if not equip.type in equipDict:
			return 0
		var updated = []
		for row in equipDict[equip.type]:
			if int(row[0]) == equip.id:
				var current = int(row[1])
				if removeAll:
					removed = current
					continue
				removed = 1
				if current > 1:
					updated.append([equip.id, current - 1])
				continue
			updated.append(row)
		equipDict[equip.type] = updated
		_set_property("武库", equipDict)
		return removed

	
	func add_stored_equipment(equip: clEquip.EquipInfo, count: int = 1) -> void :
		
		if equip.level() == "S":
			count = 1
		var equipDict = Global.dicval(_get_property("武库"))
		if equipDict.empty():
			
			
			_update_equipment_storage()
		equipDict = Global.dicval(_get_property("武库"))
		if not equip.type in equipDict:
			equipDict[equip.type] = []
		var found = false
		for row in equipDict[equip.type]:
			if int(row[0]) == equip.id:
				found = true
				row[1] += count
				
				if equip.level() == "S":
					row[1] = 1
				break
		if not found:
			equipDict[equip.type].append([equip.id, count])
		_set_property("武库", equipDict)
		return

	
	func init_stored_equipments() -> void :
		for type in StaticManager.EQUIPMENT_TYPES:
			add_stored_equipment(clEquip.equip(0, type))
		return

	
	func clear_stored_equipments() -> void :
		var equipDict = {}
		for type in StaticManager.EQUIPMENT_TYPES:
			equipDict[type] = []
		_set_property("武库", equipDict)
		_remove_property("装备仓库")
		return

	
	func rob_all_stored_equipments(targetVstateId: int) -> void :
		var target = VStateInfo.new(targetVstateId)
		var all = target.get_stored_equipments()
		for row in all:
			add_stored_equipment(row[0], row[1])
		target.clear_stored_equipments()
		return

	func get_status() -> String:
		return str(_get_property("状态"))

	func is_alive() -> bool:
		return get_status() != "灭亡"

	func set_alive() -> void :
		_set_property("状态", "正常")
		return

	func is_perished() -> bool:
		return get_status() == "灭亡"

	func set_perished() -> void :
		_set_property("状态", "灭亡")
		return

	
	func get_hated() -> Array:
		return Global.intarrval(_get_property_static("仇恨势力"))

	
	func get_loved() -> Array:
		return Global.intarrval(_get_property_static("友好势力"))

	
	func love(targetVstateId: int) -> bool:
		if targetVstateId in get_loved():
			return true
		if SkillRangeBuff.max_val_for_vstate("无条件友好", targetVstateId) > 0:
			return true
		return false

	
	func hate(targetVstateId: int) -> bool:
		if targetVstateId in get_hated():
			return true
		if SkillRangeBuff.max_val_for_vstate("无条件仇恨", targetVstateId) > 0:
			return true
		return false

	
	func get_relation_indexes() -> Dictionary:
		return Global.dicval(_get_property("势力关系"))

	
	func get_relation_index(targetVstateId: int) -> int:
		var dic = Global.dicval(_get_property("势力关系"))
		if not str(targetVstateId) in dic:
			return 50
		return Global.intval(dic[str(targetVstateId)])

	
	func get_relation_index_memo(targetVstateId: int) -> String:
		var idx = get_relation_index(targetVstateId)
		if idx >= 80:
			return "亲密"
		if idx >= 60:
			return "友好"
		if idx >= 40:
			return "正常"
		if idx >= 20:
			return "敌视"
		return "死敌"

	
	
	func relation_index_change(targetVstateId: int, val: int) -> int:
		var current = get_relation_index(targetVstateId)
		current += val
		current = max(0, current)
		current = min(100, current)
		var dic = get_relation_indexes()
		dic[str(targetVstateId)] = current
		_set_property("势力关系", dic)
		return current

	func set_capital_id(val: int) -> void :
		_set_property("主城", val)
		return

	func get_inheritage_candidates() -> PoolIntArray:
		var ret = []
		var val = _get_property("继承人")
		if val == null or typeof(val) != TYPE_ARRAY:
			return ret
		for id in val:
			if int(id) < 0:
				continue
			ret.append(int(id))
		return ret

	func get_target_city_id() -> int:
		var val = _get_property("目标城池")
		return Global.intval(val)

	func set_color(color: Array) -> void :
		_set_property("颜色", color)
		return

	func get_color():
		var color = Global.arrval(_get_property("颜色"))
		if color.size() != 2:
			color = Global.arrval(_get_property_static("颜色"))
		if color.size() != 2:
			
			color = _get_new_color()
			set_color(color)
		return color

	func _auto_create_color(except: Array) -> Color:
		var newColor = Color()
		var isDistinct = false

		while not isDistinct:
			newColor = Color(randf(), randf(), randf(), 1.0)
			isDistinct = true

			for color in except:
				if Global.color_distance(newColor, color) < 0.3:
					isDistinct = false
					break

		return newColor

	func _check_exists_color_array(outColor: String, inColor: String) -> bool:
		for vs in DataManager.vstates:
			var colorStrs = []
			var vsId = int(vs["ID"])
			if not vs.has("颜色") or typeof(vs["颜色"]) != TYPE_ARRAY:
				if vsId < 0 or vsId >= StaticManager.vstates_static.size():
					continue
				colorStrs = StaticManager.vstates_static[vsId]["颜色"]
			else:
				colorStrs = vs["颜色"]
			var outCol = colorStrs[0];
			var inCol = colorStrs[1];
			if outCol == outColor and inCol == inColor:
				return true;
		
		return false;

	
	func _get_new_color() -> Array:
		var color_pool: PoolStringArray = [];

		
		for vs in DataManager.vstates:
			var vsId = int(vs["ID"])
			var colorStrs = []
			if not vs.has("颜色") or typeof(vs["颜色"]) != TYPE_ARRAY:
				if vsId < 0 or vsId >= StaticManager.vstates_static.size():
					continue
				colorStrs = StaticManager.vstates_static[vsId]["颜色"]
			else:
				colorStrs = vs["颜色"]
			for colorStr in colorStrs:
				if color_pool.has(colorStr):
					continue;
				color_pool.append(colorStr);
		var new_color = Global.color_to_hex(_auto_create_color(color_pool));
		color_pool.append(new_color);
		
		
		var results = [];
		for c_out in color_pool:
			for c_in in color_pool:
				if c_out == c_in:
					continue;
				if Global.color_distance(c_out, c_in) < 0.3:
					continue;
				if _check_exists_color_array(c_out, c_in):
					continue;
				var result = [c_out, c_in];
				results.append(result);
		results.shuffle();
		return results[0];


static func vstate(id: int) -> VStateInfo:
	return VStateInfo.new(id)


static func create_new_vstate(lordId: int) -> int:
	var actor = ActorHelper.actor(lordId)
	actor.set_loyalty(100)
	var vstateId = - 1;
	var all = all_vstates()
	for vs in all:
		if vs.is_alive():
			continue
		if vs.get_lord_id() in [lordId, - 1]:
			vs.set_alive()
			vs.set_lord(lordId)
			if not vs.id in DataManager.vstates_sort:
				DataManager.vstates_sort.append(vs.id)
			return vs.id
	
	var new_vstateId = all.size()
	var data = {
		"ID": new_vstateId, 
		"君主": lordId, 
		"继承人": [lordId], 
		"目标城池": 12, 
		"仇恨势力": [], 
		"友好势力": [], 
	};
	
	DataManager.vstates.append(data);
	
	
	if not DataManager.vstates_sort.has(new_vstateId):
		DataManager.vstates_sort.append(new_vstateId);
	
	DataManager.fix_data(true);
	
	return new_vstateId;



static func get_alliance_month(vstateIdA: int, vstateIdB: int) -> int:
	var key = "{0}-{1}"
	if vstateIdA > vstateIdB:
		key = "{1}-{0}"
	key = key.format([
		vstateIdA, vstateIdB
	])
	if DataManager.vstates_alliance.has(key):
		return int(DataManager.vstates_alliance[key])
	return 0


static func set_alliance(vstateIdA: int, vstateIdB: int, month: int) -> void :
	var key = "{0}-{1}"
	if vstateIdA > vstateIdB:
		key = "{1}-{0}"
	key = key.format([
		vstateIdA, vstateIdB
	])
	DataManager.vstates_alliance[key] = month
	
	vstate(vstateIdA).relation_index_change(vstateIdB, 10)
	vstate(vstateIdB).relation_index_change(vstateIdA, 10)
	return

static func all_vstates(requiresAlive: bool = false) -> Array:
	var ret = []
	for vsData in DataManager.vstates:
		var vs = VStateInfo.new(int(vsData["ID"]))
		if requiresAlive and not vs.is_alive():
			continue
		ret.append(vs)
	return ret

static func search_vstates(keyword: String = "") -> Array:
	var ret = []
	for vsData in DataManager.vstates:
		var vs = VStateInfo.new(int(vsData["ID"]))
		if not vs.is_alive():
			continue
		if keyword == "":
			ret.append(vs)
			continue
		if StaticManager.RE_ALPHA.search(keyword) != null:
			var found = false
			for r in StaticManager.pinyin(vs.get_lord_name()):
				if keyword in r:
					found = true
					ret.append(vs)
					break
			if found:
				continue
		if keyword in vs.get_lord_name():
			ret.append(vs)
			continue
	return ret






static func add_new_static_vstates() -> void :
	var vstatesStatic = StaticManager.vstates_static.duplicate(true)
	var diff = vstatesStatic.size() - DataManager.vstates.size()
	if diff <= 0:
		return
	var beginId = DataManager.vstates.size();
	for i in diff:
		var newVstate = vstatesStatic[beginId + i]
		newVstate["状态"] = "灭亡"
		DataManager.vstates.append(newVstate)
	return


static func check_and_fix_duplicates() -> void :
	
	
	var check_dup_vs = {};
	
	var dup_vs = [];

	for vs in all_vstates():
		if not check_dup_vs.has(str(vs.id)):
			check_dup_vs[str(vs.id)] = 0;
		check_dup_vs[str(vs.id)] += 1;
		if check_dup_vs[str(vs.id)] > 1 and not dup_vs.has(vs.id):
			dup_vs.append(vs.id);
		
		if vs.is_alive():
			var lord = ActorHelper.actor(vs.get_lord_id())
			var city = DataManager.get_office_city_by_actor(lord.actorId)
			if city != null and city.get_vstate_id() == vs.id:
				
				lord.set_loyalty(100)

	if dup_vs.empty():
		return

	
	
	var dic_vss_data = {};
	for vstate in DataManager.vstates:
		var new_vstate = vstate.duplicate(true);
		var vsid = int(new_vstate["ID"]);
		if not vsid in dup_vs:
			continue;
		var lordId = int(new_vstate["君主"]);

		var key = str(vsid);
		if not dic_vss_data.has(key):
			dic_vss_data[key] = [];
		var check_no_same = true;
		for vs_data in dic_vss_data[key]:
			if int(vs_data["君主"]) == lordId:
				check_no_same = false;
				break;
		if check_no_same:
			dic_vss_data[key].append(new_vstate);

	for vsid_str in dic_vss_data:
		var vstate_data_array = Array(dic_vss_data[vsid_str]);
		var vsid = int(vsid_str);
		if vstate_data_array.size() == 1:
			continue;
		
		var new_array = [];
		for vs_data in vstate_data_array:
			var lordId = int(vs_data["君主"]);
			if lordId == - 1:
				continue;
			new_array.append(vs_data);
		if new_array.empty():
			new_array = [vstate_data_array[0].duplicate(true)];
		dic_vss_data[vsid_str] = new_array;

	var new_vstate = [];
	for vs in DataManager.vstates.duplicate(true):
		var vsId = int(vs["ID"]);
		if not str(vsId) in dic_vss_data:
			
			new_vstate.append(vs);
			continue;
		if vsId == new_vstate.size():
			var vss_array = Array(dic_vss_data[str(vsId)]);
			new_vstate.append(vss_array[0]);
		
	
	DataManager.vstates = new_vstate
	return


static func fix_vstate_status() -> void :
	for vs in all_vstates():
		var lordId = vs.get_lord_id()
		if vs.is_perished():
			if lordId < 0:
				continue
			var capital = DataManager.get_office_city_by_actor(lordId)
			if capital != null and capital.get_vstate_id() == vs.id:
				vs.set_alive()
				continue
		else:
			if lordId < 0:
				vs.set_perished()
				continue
			var capital = DataManager.get_office_city_by_actor(lordId)
			if capital == null or capital.get_vstate_id() != vs.id:
				var wf = DataManager.get_current_war_fight()
				if wf.fromVstateId == vs.id or wf.targetVstateId == vs.id:
					
					continue
				vs.set_perished()
				continue
	return
