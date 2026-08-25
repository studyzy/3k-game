# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clStratagem.gd
# 说明：计策信息对象。描述一条计策的名称、消耗、效果与触发条件。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "res://script/clEnvBase.gd"
class_name StratagemInfo

enum SchemeStatus{
	OK = 0, 
	AP_COST = 1, 
	MISC_COST = 2, 
	SELF_TERRIAN = 3, 
	NO_TARGETS = 4, 
	CD = 6, 
	UNKNOWN = 99, 
}


var name = ""
var data = {}
var learn = {}
var cost = {}
var impact = {}
var targeting = {}

var status = SchemeStatus.OK

func _init(setting: Dictionary) -> void :
	name = setting["name"]
	data = setting["data"]
	learn = setting["learn"]
	cost = setting["cost"]
	impact = setting["impact"]
	targeting = setting["targeting"]
	status = SchemeStatus.OK
	return


func match_skill_mode() -> bool:
	if not data.has("requireSkill"):
		return true
	var mode = DataManager.get_game_setting("技能系统")
	match int(data["requireSkill"]):
		- 1:
			return mode == "否"
		1:
			return mode == "是"
	return false


func get_cd_round() -> int:
	if not data.has("cd"):
		return 0
	if typeof(data["cd"]) != TYPE_DICTIONARY:
		return 0
	if not data["cd"].has("round"):
		return 0
	return int(data["cd"]["round"])


func get_cd_type() -> String:
	if not data.has("cd"):
		return ""
	if typeof(data["cd"]) != TYPE_DICTIONARY:
		return ""
	if not data["cd"].has("type"):
		return ""
	return str(data["cd"]["type"])





func actor_learned(actorId: int, replacedInt: int = - 1, replacedLevel: int = - 1) -> bool:
	var actor = ActorHelper.actor(actorId)
	if replacedInt == - 1:
		replacedInt = actor.get_wisdom()
	if replacedLevel == - 1:
		replacedLevel = actor.get_level()
	if actor.get_equip_feature_max("全计策") > 0:
		replacedInt = 99
		replacedLevel = 8
	if int(learn["minInt"]) > replacedInt:
		return false
	if int(learn["maxInt"]) < replacedInt:
		return false
	if int(learn["minLevel"]) > replacedLevel:
		return false
	if int(learn["maxLevel"]) < replacedLevel:
		return false
	var actorIds = Array(learn["actorIds"])
	if actorIds.size() > 0 and not actorId in actorIds:
		return false
	return true



func get_cost_ap(actorId: int) -> int:
	var actor = ActorHelper.actor(actorId)
	var ap = int(cost["ap"])
	var equipCostReduce = actor.get_equip_feature_total("计策消耗减少")
	ap = max(1, ap - equipCostReduce)
	return ap



func performable(actorId: int) -> bool:
	var info = get_cost_info(actorId)
	var cost = info[0]
	var current = info[1]
	return current >= 0 and current >= cost





func get_cost_info(actorId: int) -> PoolIntArray:
	var ret = [ - 1, - 1]
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled:
		return ret
	
	if wa.dic_skill_cd.has(name):
		if wa.dic_skill_cd[name] > 0:
			status = SchemeStatus.CD
			return ret
	
	var cost = get_cost_ap(actorId)
	var current = wa.action_point

	if is_stratagem():
		var settings = {
			"计策": name, 
			"所需": cost, 
			"当前": current, 
		}
		DataManager.set_env("计策.消耗", settings)
		SkillHelper.auto_trigger_skill(actorId, 20005)
		settings = DataManager.get_env_dict("计策.消耗")
		cost = int(settings["所需"])
		current = int(settings["当前"])
		if "至多" in settings:
			cost = int(min(cost, int(settings["至多"])))
		if "至少" in settings:
			cost = int(max(cost, int(settings["至少"])))
		if "固定" in settings:
			cost = int(settings["固定"])
		DataManager.unset_env("计策.消耗")

	ret[0] = cost
	ret[1] = current
	return ret



func perform_cost(actorId: int) -> int:
	status = SchemeStatus.OK

	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled:
		status = SchemeStatus.UNKNOWN
		return - 1

	var info = get_cost_info(actorId)
	var cost = info[0]
	var current = info[1]
	if cost < 0 and current < 0:
		status = SchemeStatus.CD
		return - 1
	if current < cost:
		status = SchemeStatus.AP_COST
		return - 1

	wa.action_point = max(0, current - cost)
	DataManager.set_env("计策.扣减", [cost, current, wa.action_point])
	SkillHelper.auto_trigger_skill(actorId, 20006)
	var changed = DataManager.get_env_int_array("计策.扣减")
	cost = changed[0]
	current = changed[1]
	wa.action_point = changed[2]
	DataManager.unset_env("计策.扣减")

	var cd = get_cd_round()
	if cd > 0:
		wa.dic_skill_cd[name] = cd
	status = SchemeStatus.OK
	return cost



func is_area_targeting() -> bool:
	return get_targeting_val("type") == "area"





func get_available_targets(fromId: int, excluded: PoolIntArray = []) -> Array:
	status = SchemeStatus.OK
	var fromWA = DataManager.get_war_actor(fromId)
	if fromWA == null or fromWA.disabled or not fromWA.has_position():
		status = SchemeStatus.UNKNOWN
		return [PoolIntArray([]), {}]
	if not _self_terrian_ok(fromWA):
		status = SchemeStatus.SELF_TERRIAN
		return [PoolIntArray([]), {}]

	var targets = []
	var wf = DataManager.get_current_war_fight()
	for wa in wf.get_war_actors(false, true):
		if wa.get_buff_label_turn(["潜行"]) > 0:
			continue
		if wa in targets:
			continue
		if wa.actorId in excluded:
			continue
		
		var related = get_all_related_targets(fromWA, wa)
		
		if related.empty():
			continue
		targets.append(wa)
	if targets.empty():
		if status == SchemeStatus.OK:
			status = SchemeStatus.NO_TARGETS
		return [PoolIntArray([]), {}]
	var comp = Global.DistanceComparator.new(fromWA.position)
	targets.sort_custom(comp, "_sort_custom")
	var ret = []
	var disabledTargets = {}
	for wa in targets:
		var disabledReason = _check_special_skills(fromWA, wa)
		if not disabledReason.empty():
			disabledTargets[str(wa.actorId)] = disabledReason
			continue
		ret.append(wa.actorId)
	status = SchemeStatus.OK
	return [ret, disabledTargets]




func get_all_related_targets(fromWA: War_Actor, targetWA: War_Actor) -> PoolIntArray:
	var ret = []
	
	if not _side_available(fromWA, targetWA):
		return ret
	
	if not _role_available(fromWA, targetWA):
		return ret
	
	if not _range_available(fromWA, targetWA.position):
		return ret
	
	
	var terrianResult = _terrian_available(fromWA, targetWA)
	
	if not terrianResult:
		return ret
	
	
	if not _buff_available(fromWA, targetWA):
		return ret
	
	if not _neighbour_available(fromWA, targetWA):
		return ret
	
	return _get_extended_targets(fromWA, targetWA)

func _side_available(fromWA: War_Actor, targetWA: War_Actor) -> bool:
	var key = "战争.DAILY.目标无视阵营.{0}".format([targetWA.actorId])
	if DataManager.get_env_int(key) > 0 and may_damage_soldier():
		return true

	match get_targeting_val("side", "敌方"):
		"任意":
			return true
		"己方":
			return targetWA.is_teammate(fromWA)
		"敌方":
			return targetWA.is_enemy(fromWA)
	return false

func _role_available(fromWA: War_Actor, targetWA: War_Actor) -> bool:
	if get_targeting_val("leaderOnly") == "1":
		return targetWA.get_main_actor_id() == targetWA.actorId
	return true


func get_targeting_range(fromWA: War_Actor) -> int:
	var rng = int(get_targeting_val("range", "6"))
	if fromWA != null and rng == - 1:
		var formula = get_targeting_val("rangeFormula")
		rng = int(Global.count_formula_number(formula, fromWA.actorId))
	return rng


func get_fixed_targeting_range(fromWA: War_Actor) -> int:
	var rng = get_targeting_range(fromWA)
	
	var setting = get_fixed_distance_setting()
	if setting.has("无限"):
		rng = 99
	if setting.has("范围修正"):
		rng += int(setting["范围修正"])
	return rng



func get_runtime_distance(fromWA: War_Actor, pos: Vector2) -> int:
	
	var disv = pos - fromWA.position
	var distance = max(abs(disv.x), abs(disv.y))
	match get_targeting_cursor_type():
		"十字":
			distance = abs(disv.x) + abs(disv.y)
		"仅十字":
			if disv.x * disv.y != 0:
				distance = 10000
	var setting = get_fixed_distance_setting()
	if setting.has("固定"):
		distance = int(setting["固定"])
	return distance



func get_effective_distance(fromWA: War_Actor, pos: Vector2) -> int:
	
	var disv = pos - fromWA.position
	var distance = max(abs(disv.x), abs(disv.y))
	match get_targeting_cursor_type():
		"十字":
			distance = abs(disv.x) + abs(disv.y)
		"仅十字":
			if disv.x * disv.y != 0:
				distance = 10000
	var setting = get_fixed_distance_setting()
	if setting.has("距离修正"):
		distance += int(setting["距离修正"])
	if setting.has("最大距离"):
		distance = min(distance, int(setting["最大距离"]))
	if setting.has("固定"):
		distance = int(setting["固定"])
	return distance

func _range_available(fromWA: War_Actor, pos: Vector2) -> bool:
	var rng = get_fixed_targeting_range(fromWA)
	var distance = get_runtime_distance(fromWA, pos)
	return distance <= rng



func _self_terrian_ok(fromWA: War_Actor) -> bool:
	if fromWA == null or fromWA.disabled:
		return false
	var war_map = SceneManager.current_scene().war_map
	var allowed = get_targeting_val("selfTerrian")
	var current = war_map.get_blockCN_by_position(fromWA.position)

	if is_stratagem():
		
		if name == "连弩":
			if SkillHelper.actor_has_skills(fromWA.actorId, ["伏矢"]):
				allowed += "、山地"

	if allowed == "":
		return true
	return current in allowed



func _terrian_available(fromWA: War_Actor, targetWA: War_Actor) -> bool:
	var war_map = SceneManager.current_scene().war_map
	var targetAllowed = get_targeting_terrian()
	var fromAllowed = get_targeting_val("selfTerrian")
	var fromTerrian = war_map.get_blockCN_by_position(fromWA.position)
	var targetTerrian = war_map.get_blockCN_by_position(targetWA.position)

	
	
	if name in ["火计", "连弩"]:
		var skillNames = SkillHelper.get_actor_skill_names(fromWA.actorId)
		match name:
			"火计":
				if "火攻" in skillNames:
					if not targetTerrian in StaticManager.CITY_BLOCKS_CN:
						targetAllowed += "、" + targetTerrian
				elif "军略" in skillNames:
					targetAllowed += "、山地"
			"连弩":
				if "伏矢" in skillNames:
					fromAllowed += "、山地"

	
	if "道术" in get_feature():
		if fromWA.actor().get_equip_feature_max("天遁") > 0:
			targetAllowed += "、城墙"

	if fromAllowed != "":
		if not fromTerrian in fromAllowed:
			return false
	if targetAllowed != "":
		if not targetTerrian in targetAllowed:
			return false

	return true


func _buff_available(fromWA: War_Actor, targetWA: War_Actor) -> bool:
	if not "excludedBuffLabels" in targeting:
		return true
	var labels = targeting["excludedBuffLabels"]
	if typeof(labels) != TYPE_ARRAY:
		return true
	return targetWA.get_buff_label_turn(labels) <= 0

func _neighbour_available(fromWA: War_Actor, targetWA: War_Actor) -> bool:
	if get_targeting_val("neighbourRequired") != "1":
		return true
	return _get_neighbour_targets(fromWA, targetWA).size() > 0


func _get_neighbour_targets(fromWA: War_Actor, targetWA: War_Actor) -> PoolIntArray:
	var ret = []
	if get_targeting_val("neighbourIncluded") != "1":
		if name != "火计":
			return ret
		var skillNames = SkillHelper.get_actor_skill_names(fromWA.actorId)
		if not "火攻" in skillNames:
			return ret
	var positions = []
	
	
	var neighbourRange = int(get_targeting_val("neighbourRange", "1"))
	for i in range(neighbourRange):
		for dir in StaticManager.NEARBY_DIRECTIONS:
			positions.append(targetWA.position + dir * (i + 1))
	var war_map = SceneManager.current_scene().war_map
	var neighbourTerrian = get_targeting_neighbour_terrian()
	var wf = DataManager.get_current_war_fight()
	for wa in wf.get_war_actors(false, true):
		if not wa.position in positions:
			continue
		if not _side_available(fromWA, wa):
			continue
		if not _role_available(fromWA, wa):
			continue
		if not _buff_available(fromWA, wa):
			continue
		
		if neighbourTerrian != "":
			var terrian = war_map.get_blockCN_by_position(wa.position)
			if not terrian in neighbourTerrian:
				continue
		if not wa.actorId in ret:
			ret.append(wa.actorId)
	return ret


func _get_extended_targets(fromWA: War_Actor, targetWA: War_Actor) -> PoolIntArray:
	
	var ret = []
	ret.append(targetWA.actorId)

	var war_map = SceneManager.current_scene().war_map

	
	var chainTriggered = false

	
	
	var chained = []
	var wf = DataManager.get_current_war_fight()
	
	
	
	var se = DataManager.get_current_stratagem_execution()
	if se.get_env_int("兵力流失") <= 0 and get_nature() in ["火", "雷"]:
		for wa in wf.get_war_actors(false, true):
			if wa.get_buff_label_turn(["铁索"]) > 0:
				chained.append(wa)
				
				if wa.actorId in ret:
					chainTriggered = true

	
	var checking = []
	checking.append(targetWA)
	
	var checked = []
	while not checking.empty():
		
		if chainTriggered:
			for wa in chained:
				
				if not wa.actorId in ret:
					ret.append(wa.actorId)
				
				if wa.actorId in checked:
					continue
				if wa in checking:
					continue
				checking.append(wa)
			
			chained.clear()
		var currentChecking = checking.pop_front()
		checked.append(currentChecking.actorId)
		
		for actorId in _get_neighbour_targets(fromWA, currentChecking):
			if not actorId in ret:
				ret.append(actorId)
			var wa = DataManager.get_war_actor(actorId)
			
			if not chainTriggered:
				if wa in chained:
					chainTriggered = true
			
			if get_targeting_val("neighbourExtend") == "1":
				if not wa in checking and not wa.actorId in checked:
					checking.append(wa)
	return ret





func get_targeting_range_radius() -> int:
	if get_targeting_range_type() == "":
		return 0
	return int(get_targeting_val("rangeRadius", "0"))

func get_message() -> String:
	return get_data_val("message", "")

func get_description() -> String:
	return get_data_val("desc", "")

func get_animation() -> String:
	return get_data_val("anim", "")


func get_raw_rate(fromId: int, targetId: int) -> int:
	return get_rate(fromId, targetId, true)






func get_rate(fromId: int, targetId: int, raw: bool = false, performing: bool = false) -> int:
	var rate = 100
	var formula = str(data["formula"])
	if formula == "" or formula == "100":
		return rate

	if targetId == - 1:
		
		
		return int(Global.count_formula_number(formula, fromId))

	var fromWA = DataManager.get_war_actor(fromId)
	var targetWA = DataManager.get_war_actor(targetId)

	var distance = get_effective_distance(fromWA, targetWA.position)
	if not raw:
		
		var epuipDistance = fromWA.actor().get_equip_feature_min("计视距离")
		if epuipDistance > 0:
			distance = min(epuipDistance, distance)
	formula = formula.replace("距离", str(distance))

	
	var addedWisdom = 0
	
	var targetWisdom = targetWA.actor().get_wisdom()
	var dic = {
		"a.知": addedWisdom, 
		"b.知": 0, 
	}
	if raw:
		rate = int(Global.count_formula_number(formula, fromId, targetId, dic))
	else:
		DataManager.unset_env("计策.ONCE.限定概率")
		addedWisdom = fromWA.actor().get_equip_feature_total("计策附加智力")
		DataManager.set_env("计策.ONCE.附加智力", addedWisdom)
		DataManager.set_env("计策.ONCE.计策目标", targetId)
		DataManager.set_env("计策.ONCE.目标智力", targetWisdom)
		DataManager.set_env("计策.ONCE.执行", 1 if performing else 0)
		
		
		rate = int(Global.count_formula_number(formula, fromId, targetId, dic))
		DataManager.set_env("计策.ONCE.模拟概率", rate)
		SkillHelper.auto_trigger_skill(fromId, 20017)
		addedWisdom = DataManager.get_env_int("计策.ONCE.附加智力")
		targetWisdom = DataManager.get_env_int("计策.ONCE.目标智力")
		dic["a.知"] = addedWisdom
		dic["b.知"] = targetWisdom - targetWA.actor().get_wisdom()
		DataManager.unset_env("计策.ONCE.附加智力")
		DataManager.unset_env("计策.ONCE.计策目标")
		DataManager.unset_env("计策.ONCE.目标智力")
		DataManager.unset_env("计策.ONCE.模拟概率")
		DataManager.unset_env("计策.ONCE.执行")

		var specifiedRate = DataManager.get_env_int("计策.ONCE.限定概率")
		if specifiedRate >= 0:
			
			rate = specifiedRate
			DataManager.unset_env("计策.ONCE.限定概率")
		else:
			
			rate = int(Global.count_formula_number(formula, fromId, targetId, dic))
			
			if fromWA.get_buff_label_turn(["伤神"]) > 0:
				rate = int(rate / 2)
	rate = min(100, rate)
	rate = max(0, rate)

	return rate



func _impact_for_soldier_damage(fromWA: War_Actor, targets: PoolIntArray, formula: String, isStratagem: bool = true) -> Dictionary:
	var ret = {}
	
	var addedWisdom = fromWA.actor().get_equip_feature_total("计策附加智力")
	var map = SceneManager.current_scene().war_map
	for targetId in targets:
		var targetWA = DataManager.get_war_actor(targetId)
		if targetWA == null or targetWA.disabled or not targetWA.has_position():
			continue

		
		if "道术" in get_feature() and targetId != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue

		var allTargetsCount = targets.size()
		allTargetsCount = max(allTargetsCount, get_env_int("计策.ONCE.目标数"))
		formula = formula.replace("命中人数", str(allTargetsCount))
		var targetWisdom = targetWA.actor().get_wisdom()
		var dic = {
			"a.知": addedWisdom, 
			"b.知": 0, 
		}
		DataManager.set_env("计策.ONCE.公式属性", dic)
		DataManager.set_env("计策.ONCE.附加智力", addedWisdom)
		DataManager.set_env("计策.ONCE.目标智力", targetWisdom)
		
		SkillHelper.auto_trigger_skill(fromWA.actorId, 20029)
		dic = DataManager.get_env_dict("计策.ONCE.公式属性")
		dic["a.知"] = DataManager.get_env_int("计策.ONCE.附加智力")
		dic["b.知"] = DataManager.get_env_int("计策.ONCE.目标智力") - targetWisdom
		DataManager.unset_env("计策.ONCE.附加智力")
		DataManager.unset_env("计策.ONCE.目标智力")
		var damage = int(Global.count_formula_number(formula, fromWA.actorId, targetId, dic))
		if isStratagem:
			
			var weakened = get_targeting_weakened_terrian()
			if weakened != "":
				var targetBlock = map.get_blockCN_by_position(targetWA.position)
				if targetBlock in weakened:
					damage = int(damage / 2)
		
		if fromWA.get_buff_label_turn(["伤神"]) > 0:
			damage = int(damage / 2)
		
		if is_stratagem():
			DataManager.set_env("计策.ONCE.基础伤害", damage)
			DataManager.set_env("计策.ONCE.伤害", damage)
			DataManager.set_env("计策.ONCE.伤害武将", targetId)
			SkillHelper.auto_trigger_skill(fromWA.actorId, 20011)
			
			
			if isStratagem:
				SkillHelper.auto_trigger_skill(targetId, 20002)
			
			_equip_effect_on_damage(fromWA, targetWA)
			damage = DataManager.get_env_int("计策.ONCE.伤害")
		damage = min(targetWA.get_soldiers(), damage)
		if damage > 0:
			var expFactor = max(1, SkillRangeBuff.max_val_for_actor("大战场敌方计策经验倍率", targetId))
			DataManager.damage_sodiers(fromWA.actorId, targetId, damage, expFactor)
			if is_stratagem():
				DataManager.set_env("计策.ONCE.伤害武将", targetId)
				DataManager.set_env("计策.ONCE.伤害", damage)
				SkillHelper.auto_trigger_skill(fromWA.actorId, 20037, "")
		DataManager.unset_env("计策.ONCE.基础伤害")
		DataManager.unset_env("计策.ONCE.伤害")
		DataManager.unset_env("计策.ONCE.伤害武将")
		ret[targetId] = damage
	return ret


func _impact_for_rice_damage(fromWA: War_Actor, targets: PoolIntArray, formula: String) -> Dictionary:
	var ret = {}
	for targetId in targets:
		var targetWA = DataManager.get_war_actor(targetId)
		if targetWA == null or targetWA.disabled:
			continue
		var wv = targetWA.war_vstate()
		formula = formula.replace("b.米", str(wv.rice))
		var damage = int(Global.count_formula_number(formula, fromWA.actorId, targetId))
		damage = min(wv.rice, damage)
		if damage > 0:
			wv.rice -= damage
			ret[targetId] = damage
	return ret


func _impact_for_hp_damage(fromWA: War_Actor, targets: PoolIntArray, formula: String) -> Dictionary:
	var ret = {}
	for targetId in targets:
		var targetWA = DataManager.get_war_actor(targetId)
		if targetWA == null or targetWA.disabled:
			continue

		
		if "道术" in get_feature() and targetId != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue

		var damage = int(Global.count_formula_number(formula, fromWA.actorId, targetId))
		
		if fromWA.get_buff_label_turn(["伤神"]) > 0:
			damage = int(damage / 2)
		if name == "陷阱" and targetWA.get_buff_label_turn(["免疫陷阱"]) > 0:
			damage = 0

		if is_stratagem():
			DataManager.common_variable["计策.ONCE.减体"] = damage
			
			SkillHelper.auto_trigger_skill(targetId, 20025, "")
			damage = int(DataManager.common_variable["计策.ONCE.减体"])
			DataManager.common_variable.erase("计策.ONCE.减体")

		if damage <= 0:
			continue
		targetWA.actor().set_hp(targetWA.actor().get_hp() - damage)
		ret[targetId] = damage
	return ret


func _impact_for_hp_heal(fromWA: War_Actor, targets: PoolIntArray, formula: String) -> Dictionary:
	var ret = {}
	for targetId in targets:
		var targetWA = DataManager.get_war_actor(targetId)
		if targetWA == null or targetWA.disabled:
			continue
		if targetWA.is_enemy(fromWA):
			continue
		
		if "道术" in get_feature() and targetId != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue
		var heal = int(Global.count_formula_number(formula, fromWA.actorId, targetId))
		heal = targetWA.actor().recover_hp(heal)
		if heal <= 0:
			continue
		ret[targetId] = heal
	return ret


func _impact_for_buff(fromWA: War_Actor, targets: PoolIntArray, setting: Dictionary) -> Dictionary:
	var ret = {}
	for targetId in targets:
		var targetWA = DataManager.get_war_actor(targetId)
		if targetWA == null or targetWA.disabled:
			continue
		
		if not targetWA.is_enemy(fromWA):
			continue
		
		if "道术" in get_feature() and targetId != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue
		var buff = str(setting["name"])
		var turns = 0
		if "round" in setting:
			turns = int(setting["round"])
		if turns <= 0:
			if "formula" in setting:
				turns = int(Global.count_formula_number(setting["formula"], fromWA.actorId, targetId))
		if turns <= 0:
			continue
		if targetWA.set_buff(buff, turns, fromWA.actorId) <= 0:
			continue
		var buffInfo = StaticManager.get_buff(buff)
		var labels = buffInfo.get_label()
		var msg = "{0}被附加{1}状态"
		if "乱石阵" in labels:
			msg = "{0}已误入石阵"
		elif "禁止移动" in labels:
			msg = "{0}已不可移动"
		elif "铁索" in labels:
			msg = "{0}已被铁索连起来"
		msg = msg.format([targetWA.get_name(), buff])
		ret[targetId] = [buff, turns, msg]
	return ret


func _impact_for_special_effect(fromWA: War_Actor, targets: PoolIntArray, effect: String, se = null) -> Dictionary:
	var ret = {}
	var map = SceneManager.current_scene().war_map
	for targetId in targets:
		var targetWA = DataManager.get_war_actor(targetId)
		if targetWA == null or targetWA.disabled:
			continue
		
		if "道术" in get_feature() and targetId != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue
		match effect:
			"笼络":
				if targetWA.is_enemy(fromWA):
					if targetWA.actor_surrend_to(fromWA.wvId):
						ret[targetId] = ["笼络", "", 1]
					else:
						
						if targetWA.actor().faked:
							ret[targetId] = ["其他", "「{0}」灵力消散".format([targetWA.get_name()]), 1]
			"撤退":
				var wv = targetWA.war_vstate()
				if wv != null and wv.from_cityId >= 0:
					var fromCity = clCity.city(wv.from_cityId)
					if fromCity.get_vstate_id() == wv.vstate().id:
						targetWA.retreat_to(fromCity.ID)
						ret[targetId] = ["劝退", "", fromCity.ID]
					else:
						ret[targetId] = ["劝退", "", - 1]
			"随机位移":
				var positions = DataManager.get_env_array("计策.ONCE.覆盖位置")
				var allTargets = DataManager.get_env_int_array("计策.ONCE.所有目标")
				while not positions.empty():
					positions.shuffle()
					if se != null:
						var x = se.get_env_int("风向X", 99)
						var y = se.get_env_int("风向Y", 99)
						if x != 99 and y != 99:
							var center = DataManager.get_env_dict("计策.ONCE.目标位置")
							if "x" in center and "y" in center:
								var sorter = Global.VectorSorter.new()
								sorter.direction = Vector2(x, y)
								sorter.center = Vector2(int(center["x"]), int(center["y"]))
								positions.sort_custom(sorter, "by_direction")
					var pos = positions.pop_front()
					DataManager.set_env("计策.ONCE.覆盖位置", positions)
					var blockCN = map.get_blockCN_by_position(pos)
					if blockCN in StaticManager.CITY_BLOCKS_CN:
						continue
					var occupier = DataManager.get_war_actor_by_position(pos)
					if occupier != null and not (occupier.actorId in allTargets):
						continue
					targetWA.position = pos
					
					ret[targetId] = ["位移", "敌军阵型已乱\n可相机而动", - 1, true]
					break
			"机动力回复":
				fromWA.action_point += 1
				ret[fromWA.actorId] = ["机动力", "", 1]
	return ret


func may_damage_soldier() -> bool:
	return impact.has("soldier")


func may_damage_hp() -> bool:
	return impact.has("hp")



func check_area_correct(fromId: int, position: Vector2, removePrevious: bool = false) -> String:
	var map = SceneManager.current_scene().war_map
	var wa = DataManager.get_war_actor(fromId)
	if not _range_available(wa, position):
		return "当前地貌不可发动"
	
	
	
	var terrian = map.get_blockCN_by_position(position)
	var terrianAllowed = get_targeting_terrian()
	if terrianAllowed != "":
		if not terrian in terrianAllowed:
			return "当前地形不可发动"
	
	if name in wa.dic_areas:
		var dic = wa.dic_areas[name]
		if dic["回合数"] > 0:
			if removePrevious:
				var pos = Vector2(dic["影响坐标"]["x"], dic["影响坐标"]["y"])
				wa.dic_areas.erase(name)
				map.mark_area_trapped(false, pos, 2)
			else:
				return "不可发动多个{0}".format([name])
	return ""


func get_nature() -> String:
	return get_data_val("nature", "")


func get_feature() -> String:
	return get_data_val("feature", "")



func get_data_val(key: String, defVal: String = "") -> String:
	if not key in data:
		return defVal
	return str(data[key])



func get_targeting_val(key: String, defVal: String = "") -> String:
	if not key in targeting:
		return defVal
	return str(targeting[key])



func get_targeting_terrian() -> String:
	var ret = get_targeting_val("targetTerrian")
	if ret == "":
		return ret
	var weaken = get_targeting_weakened_terrian()
	if weaken != "":
		ret += "、" + weaken
	return ret



func get_targeting_neighbour_terrian() -> String:
	var ret = get_targeting_val("neighbourTerrian")
	if ret == "":
		return ret
	var weaken = get_targeting_weakened_terrian()
	if weaken != "":
		ret += "、" + weaken
	return ret



func get_targeting_weakened_terrian() -> String:
	return get_targeting_val("weakenedTerrian")


func get_targeting_range_type() -> String:
	return get_targeting_val("rangeType")



func get_selectable_positions(fromWA: War_Actor) -> PoolVector2Array:
	var ret = []
	if fromWA == null:
		return ret
	var rng = get_fixed_targeting_range(fromWA)
	if rng >= 99:
		return ret
	var cursorType = get_targeting_cursor_type()
	var pos = fromWA.position
	for x in range(pos.x - rng, pos.x + rng + 1):
		if x < 0:
			continue
		for y in range(pos.y - rng, pos.y + rng + 1):
			if y < 0:
				continue
			var p = Vector2(x, y)
			if p in ret:
				continue
			match cursorType:
				"仅十字":
					if x == pos.x or y == pos.y:
						ret.append(p)
				"十字":
					var disv = pos - p
					if abs(disv.x) + abs(disv.y) <= rng:
						ret.append(p)
				_:
					ret.append(p)
	return ret


func get_targeting_cursor_type() -> String:
	return get_targeting_val("cursorType")




func get_error_message() -> String:
	match status:
		SchemeStatus.OK:
			return ""
		SchemeStatus.SELF_TERRIAN:
			return "当前地形，不可施放{0}".format([name])
		SchemeStatus.NO_TARGETS:
			return "当前没有可施放{0}的目标".format([name])
	return "当前不可施放{0}".format([name])



func get_fixed_distance_setting() -> Dictionary:
	var dic = DataManager.get_env_dict("计策.ONCE.距离")
	var setting = {}
	
	if dic.has("ALL"):
		setting = dic["ALL"].duplicate(true)
	
	
	if dic.has(name):
		for key in ["固定", "无限", "最大距离"]:
			if key in dic[name]:
				if key in setting:
					setting[key] = min(setting[key], dic[name][key])
				else:
					setting[key] = dic[name][key]
		for key in ["范围修正", "距离修正"]:
			if key in dic[name]:
				if key in setting:
					setting[key] += dic[name][key]
				else:
					setting[key] = dic[name][key]
	return setting

func is_stratagem() -> bool:
	return get_data_val("type", "计策") == "计策"






func _check_special_skills(from: War_Actor, target: War_Actor) -> Array:
	if not is_stratagem():
		
		return []
	if from == null or from.disabled or not from.has_position():
		return []
	if target == null or target.disabled or not target.has_position():
		return []
	var map = SceneManager.current_scene().war_map
	var fromSkillNames = SkillHelper.get_actor_skill_names(from.actorId)
	var targetTerrian = map.get_blockCN_by_position(target.position)
	var targetSkillNames = SkillHelper.get_actor_skill_names(target.actorId)

	
	if "千追" in fromSkillNames:
		
		var marked = SkillHelper.get_skill_variable_int(20000, 20548, from.actorId, - 1)
		if marked >= 0 and marked != target.actorId:
			var markedWA = DataManager.get_war_actor(marked)
			if markedWA == null or not markedWA.disabled:
				return [from.actorId, "千追"]
	
	if may_damage_soldier() and "毅重" in targetSkillNames:
		match from.five_phases:
			War_Character.FivePhases_Enum.Metal:
				return [target.actorId, "毅重"]
			War_Character.FivePhases_Enum.Water:
				return [target.actorId, "毅重"]
	
	if may_damage_soldier() and target.is_defender() and from.action_point > 10:
		if "守关" in targetSkillNames:
			return [target.actorId, "守关"]
	
	if targetTerrian == "山地" and Global.get_distance(from.position, target.position) != 1:
		if "驻山" in targetSkillNames:
			return [target.actorId, "驻山"]
	
	if targetTerrian in StaticManager.CITY_BLOCKS_CN:
		if "溃围" in targetSkillNames:
			return [target.actorId, "溃围"]
	
	if targetTerrian in ["山地"]:
		if "高势" in targetSkillNames:
			return [target.actorId, "高势"]
	
	if name == "笼络":
		for dir in StaticManager.NEARBY_DIRECTIONS:
			var teammate = DataManager.get_war_actor_by_position(target.position + dir)
			if teammate == null or teammate.disabled or not target.is_teammate(teammate):
				continue
			if SkillHelper.actor_has_skills(teammate.actorId, ["忌奸"]):
				return [teammate.actorId, "忌奸"]
	
	if from.is_enemy(target):
		var srbs = SkillRangeBuff.find_for_war_vstate("恃远", target.wvId)
		if not srbs.empty():
			var attackable = false
			for wa in from.war_vstate().get_war_actors(false, true):
				if wa.get_name() == "刘虞" and target.get_name() == "司马懿":
					pass
				var distance = Global.get_distance(target.position, wa.position)
				var rng = wa.get_attack_distance()
				if distance <= rng:
					attackable = true
					break
			if not attackable:
				return [srbs[0].actorId, srbs[0].skillName]
	
	if "卫士" in targetSkillNames:
		var leader = target.get_leader()
		if leader != null and leader.actorId != target.actorId:
			if Global.get_range_distance(target.position, leader.position) <= 1:
				return [target.actorId, "卫士"]
	
	if "名士" in targetSkillNames:
		
		var wf = DataManager.get_current_war_fight()
		if wf.date <= 10 and SkillHelper.get_skill_variable_int(20000, 20335, target.actorId, 0) <= 0:
			return [target.actorId, "名士"]
	
	if name == "伪击转杀":
		var srbs = SkillRangeBuff.find_for_war_vstate("禁伪击", target.wvId)
		if not srbs.empty():
			return [srbs[0].actorId, srbs[0].skillName]
	
	for srb in SkillRangeBuff.find_for_war_vstate("计策嘲讽", target.wvId):
		var markedId = SkillHelper.get_skill_variable_int(20000, srb.effectTagVal, from.actorId)
		if markedId >= 0 and markedId != target.actorId:
			return [srb.actorId, srb.skillName]
	return []


func _equip_effect_on_damage(fromWA: War_Actor, targetWA: War_Actor) -> void :
	
	if get_nature() != "火":
		return
	var basicDamage = DataManager.get_env_int("计策.ONCE.基础伤害")
	var damage = DataManager.get_env_int("计策.ONCE.伤害")
	var resistance = targetWA.actor().get_equip_feature_max("计策火抗")
	if resistance <= 0:
		return
	damage -= int(basicDamage * resistance / 100)
	damage = max(0, damage)
	DataManager.set_env("计策.ONCE.伤害", damage)
	var msg = "装备减伤{0}%".format([resistance])
	var se = DataManager.get_current_stratagem_execution()
	se.append_result("装备", msg, resistance, targetWA.actorId)
	return
