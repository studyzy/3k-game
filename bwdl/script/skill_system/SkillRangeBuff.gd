extends Resource

const MAX_VAL = 1 << 31
const MIN_VAL = - (1 << 31)


class_name SkillRangeBuff

enum BuffTargetType{
	UNKNOWN = 999, 
	WAR_VSTATE = 0, 
	VSTATE = 1, 
	CITY = 2, 
	ALL_CITY = 3, 
	WAR_ENEMY_VSTATE = 4, 
	ACTOR = 5, 
}


var actorId: int


var skillName: String


var effectType: String


var sceneId: int


var effectId: int


var triggerId: int




var effectTag: String




var effectTagVal: int


var targetType: int


var targetId: int


var condition: String = ""






var continuous: int = 0

func _init():
	return

func to_string() -> String:
	var data = [
		str(actorId), skillName, effectType, 
		str(sceneId), str(effectId), str(triggerId), 
		effectTag, str(effectTagVal), 
		str(targetType), str(targetId), condition, str(continuous)
	]
	return "|".join(data)

func from_string(val: String) -> void :
	var data = val.split("|")
	if data.size() < 10:
		return
	actorId = int(data[0])
	skillName = data[1]
	effectType = data[2]
	sceneId = int(data[3])
	effectId = int(data[4])
	triggerId = int(data[5])
	effectTag = data[6]
	effectTagVal = int(data[7])
	targetType = int(data[8])
	targetId = int(data[9])
	condition = ""
	if data.size() >= 11:
		condition = str(data[10])
	continuous = 0
	if data.size() >= 12:
		continuous = int(data[11])
	return






func from_skill_effect(_actorId: int, effect) -> void :
	actorId = _actorId
	skillName = effect.skill.name
	effectType = effect.type
	sceneId = effect.sceneId
	effectId = effect.id
	triggerId = effect.triggerId
	effectTag = effect.triggerTag
	effectTagVal = effect.triggerTagVal
	if effect.triggerTagValId > 0:
		effectTagVal = SkillHelper.get_skill_variable_int(sceneId, effect.triggerTagValId, actorId)
	elif effect.triggerEval != "":
		var actor = ActorHelper.actor(_actorId)
		effectTagVal = int(Global.execute_expression(effect.triggerEval, actor))
	targetType = BuffTargetType.UNKNOWN
	targetId = - 1
	if effect.type == "光环":
		match effect.triggerType:
			"城市":
				targetType = BuffTargetType.CITY
			"势力":
				targetType = BuffTargetType.VSTATE
			"战争势力":
				targetType = BuffTargetType.WAR_VSTATE
			"战争敌方":
				targetType = BuffTargetType.WAR_ENEMY_VSTATE
			"自己":
				targetType = BuffTargetType.ACTOR
			"指定目标":
				targetType = BuffTargetType.ACTOR
			"己方女性武将":
				targetType = BuffTargetType.ACTOR
	elif effect.type in ["锁定", "诱发"]:
		match effect.triggerType:
			"己方":
				targetType = BuffTargetType.WAR_VSTATE
			"敌方":
				targetType = BuffTargetType.WAR_ENEMY_VSTATE
			"城市":
				targetType = BuffTargetType.CITY
			"势力":
				targetType = BuffTargetType.VSTATE
			"指定目标":
				targetType = BuffTargetType.ACTOR
	condition = effect.triggerCondition
	continuous = 0
	return



static func find_for_target(tag: String, targetType: int, targetId: int, sceneId: int = - 1) -> Array:
	var ret = []
	if sceneId < 0:
		sceneId = DataManager.get_current_scene_id()
	for srb in DataManager.skill_range_buff:
		if srb.sceneId > sceneId:
			continue
		if tag != "" and srb.effectTag != tag:
			continue
		if srb.targetType != targetType:
			continue
		if srb.targetId != targetId:
			continue
		ret.append(srb)
	return ret

static func find_for_actor(tag: String, actorId: int) -> Array:
	var ret = []
	var actor = ActorHelper.actor(actorId)
	for srb in find_for_target(tag, BuffTargetType.ACTOR, actorId):
		if srb.condition != "":
			if not Global.count_formula_bool(srb.condition, actorId, - 1, {}, actor):
				continue
		ret.append(srb)
	return ret

static func max_for_actor(tag: String, actorId: int) -> SkillRangeBuff:
	var maxVal = MIN_VAL
	var ret = null
	for srb in find_for_actor(tag, actorId):
		if srb.effectTagVal > maxVal:
			maxVal = srb.effectTagVal
			ret = srb
	return ret

static func min_for_actor(tag: String, actorId: int) -> SkillRangeBuff:
	var res = find_for_actor(tag, actorId)
	if res.empty():
		return null
	var ret = null
	var minVal = MAX_VAL
	for srb in res:
		if srb.effectTagVal < minVal:
			ret = srb
			minVal = srb.effectTagVal
	return ret

static func max_val_for_actor(tag: String, actorId: int, defVal: int = - 1) -> int:
	var ret = max_for_actor(tag, actorId)
	if ret == null:
		return defVal
	return ret.effectTagVal


static func min_val_for_actor(tag: String, actorId: int, defVal: int = - 1) -> int:
	var ret = min_for_actor(tag, actorId)
	if ret == null:
		return defVal
	return ret.effectTagVal

static func find_for_city(tag: String, cityId: int) -> Array:
	var ret = []
	for srb in find_for_target(tag, BuffTargetType.CITY, cityId):
		if srb.condition != "":
			if not Global.count_formula_bool(srb.condition):
				continue
		ret.append(srb)
	return ret

static func find_for_vstate(tag: String, vstateId: int) -> Array:
	var ret = []
	for srb in find_for_target(tag, BuffTargetType.VSTATE, vstateId):
		if srb.condition != "":
			if not Global.count_formula_bool(srb.condition):
				continue
		ret.append(srb)
	return ret

static func find_for_war_vstate(tag: String, wvId: int) -> Array:
	var ret = []
	for srb in find_for_target(tag, BuffTargetType.WAR_VSTATE, wvId, 20000):
		if srb.condition != "":
			if not Global.count_formula_bool(srb.condition):
				continue
		ret.append(srb)
	for srb in find_for_target(tag, BuffTargetType.WAR_ENEMY_VSTATE, wvId, 20000):
		if srb.condition != "":
			if not Global.count_formula_bool(srb.condition):
				continue
		ret.append(srb)
	return ret



static func min_val_for_city(tag: String, cityId: int, defVal: int = - 1) -> int:
	var ret = min_for_city(tag, cityId)
	if ret == null:
		return defVal
	return ret.effectTagVal

static func min_for_city(tag: String, cityId: int, defVal: int = - 1) -> SkillRangeBuff:
	var res = find_for_city(tag, cityId)
	if res.empty():
		return null
	var ret = null
	var minVal = MIN_VAL
	for srb in res:
		if srb.effectTagVal > minVal:
			ret = srb
			minVal = srb.effectTagVal
	return ret


static func max_for_city(tag: String, cityId: int) -> SkillRangeBuff:
	var res = find_for_city(tag, cityId)
	if res.empty():
		return null
	var ret = null
	var minVal = MIN_VAL
	for srb in res:
		if srb.effectTagVal > minVal:
			ret = srb
			minVal = srb.effectTagVal
	return ret


static func max_val_for_city(tag: String, cityId: int, defVal: int = - 1) -> int:
	var ret = max_for_city(tag, cityId)
	if ret == null:
		return defVal
	return ret.effectTagVal


static func max_for_vstate(tag: String, vstateId: int) -> SkillRangeBuff:
	var res = find_for_vstate(tag, vstateId)
	if res.empty():
		return null
	var ret = null
	var minVal = MIN_VAL
	for srb in res:
		if srb.effectTagVal > minVal:
			ret = srb
			minVal = srb.effectTagVal
	return ret

static func max_val_for_vstate(tag: String, vstateId: int, defVal: int = 0) -> int:
	var ret = max_for_vstate(tag, vstateId)
	if ret == null:
		return defVal
	return ret.effectTagVal


static func min_for_vstate(tag: String, vstateId: int) -> SkillRangeBuff:
	var res = find_for_vstate(tag, vstateId)
	if res.empty():
		return null
	var ret = null
	var minVal = MAX_VAL
	for srb in res:
		if srb.effectTagVal < minVal:
			ret = srb
			minVal = srb.effectTagVal
	return ret

static func min_val_for_vstate(tag: String, vstateId: int, defVal: int = - 1) -> int:
	var ret = min_for_vstate(tag, vstateId)
	if ret == null:
		return defVal
	return ret.effectTagVal


static func max_for_war_vstate(tag: String, wvId: int) -> SkillRangeBuff:
	var res = find_for_war_vstate(tag, wvId)
	if res.empty():
		return null
	var ret = null
	var minVal = MIN_VAL
	for srb in res:
		if srb.effectTagVal > minVal:
			ret = srb
			minVal = srb.effectTagVal
	return ret

static func max_val_for_war_vstate(tag: String, wvId: int, defVal: int = 0) -> int:
	var ret = max_for_war_vstate(tag, wvId)
	if ret == null:
		return defVal
	return ret.effectTagVal
