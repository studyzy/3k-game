extends Resource
class_name BuffInfo


var name = ""
var type = "buff"
var data = {}
var impact = {}
var area = {}

func _init(setting: Dictionary) -> void :
	name = setting["name"]
	if setting.has("type"):
		type = str(setting["type"])
	data = setting["data"]
	if setting.has("impact"):
		impact = setting["impact"]
	if type == "area":
		area = setting["area"]
	return

func is_area_effect() -> bool:
	return type == "area"

func get_area_terrian() -> String:
	if not is_area_effect():
		return ""
	if not "terrian" in area:
		return ""
	return str(area["terrian"])

func get_area_target() -> String:
	if not is_area_effect():
		return ""
	if not "target" in area:
		return ""
	return str(area["target"])

func get_area_type() -> String:
	if not is_area_effect():
		return ""
	if not "type" in area:
		return ""
	return str(area["type"])

func get_area_radius() -> int:
	if not is_area_effect():
		return 0
	if not "radius" in area:
		return 0
	return int(area["radius"])


func perform_to_target(fromId: int, targetId: int) -> void :
	var targetWA = DataManager.get_war_actor(targetId)
	if null == targetWA:
		return

	for key in impact:
		match key:
			"soldier":
				var dic = get_scheme_damage_env(fromId, targetId)
				_impact_for_soldier_damage(fromId, targetWA, impact[key], dic)
	return

func _impact_for_soldier_damage(fromId: int, targetWA: War_Actor, formula: String, dic: Dictionary) -> void :
	var targetActor = ActorHelper.actor(targetWA.actorId)
	var damage = int(Global.count_formula_number(formula, fromId, targetWA.actorId, dic))
	damage = min(targetActor.get_soldiers(), damage)
	if damage > 0:
		DataManager.damage_sodiers(fromId, targetWA.actorId, damage)
	return

func get_data_val(key: String, defVal: String = "") -> String:
	if not key in data:
		return defVal
	return str(data[key])

func get_label() -> String:
	return get_data_val("label")

func get_description() -> String:
	return get_data_val("desc")

func get_scene() -> String:
	return get_data_val("scene")

func get_settlement() -> String:
	return get_data_val("settlement")

func is_negative() -> bool:
	return get_data_val("type", "") == "负面"

func get_scheme_damage_env(fromId: int, targetId: int) -> Dictionary:
	
	var fromActor = ActorHelper.actor(fromId)
	var targetWA = DataManager.get_war_actor(targetId)
	var addedWisdom = fromActor.get_equip_feature_total("计策附加智力")
	var targetWisdom = targetWA.actor().get_wisdom()
	var dic = {
		"a.知": addedWisdom, 
		"b.知": 0, 
	}
	DataManager.set_env("计策.ONCE.附加智力", addedWisdom)
	DataManager.set_env("计策.ONCE.目标智力", targetWisdom)
	
	SkillHelper.auto_trigger_skill(fromId, 20029, "")
	dic["a.知"] = DataManager.get_env_int("计策.ONCE.附加智力")
	dic["b.知"] = DataManager.get_env_int("计策.ONCE.目标智力") - targetWisdom
	DataManager.unset_env("计策.ONCE.附加智力")
	DataManager.unset_env("计策.ONCE.目标智力")
	return dic
