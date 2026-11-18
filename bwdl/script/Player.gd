extends Resource
class_name Player

enum ActorLevelEnum{
	Lord = 0, 
	Satrap, 
	Normal, 
	Unoffice
}

var actorId: int = - 2;
var power_value: int = 50;
var affiars_turn_end = false;


func _init() -> void :
	return

func get_dit():
	var dit = {
		"actorId": actorId, 
		"power_value": power_value, 
		"affiars_turn_end": affiars_turn_end
	}
	return dit;

func set_dit(dit: Dictionary):
	actorId = int(dit["actorId"]);
	power_value = int(dit["power_value"]);
	affiars_turn_end = str(dit["affiars_turn_end"]).to_lower() == "true";

func set_actor(newActorId: int) -> void :
	actorId = newActorId
	return


func get_control_actors() -> PoolIntArray:
	return PoolIntArray([actorId])


func get_control_citys() -> PoolIntArray:
	var ret = []
	if get_power_level() == ActorLevelEnum.Lord:
		for city in clCity.all_cities([belong_To_vstateId()]):
			ret.append(city.ID)
		return ret
	for aid in get_control_actors():
		var city = DataManager.get_office_city_by_actor(aid)
		if city != null and not city.ID in ret:
			ret.append(city.ID)
	return ret


func belong_To_vstateId() -> int:
	if actorId < 0:
		return - 1
	for vs in clVState.all_vstates():
		if vs.is_alive() and vs.get_lord_id() == actorId:
			return vs.id
	var city = DataManager.get_office_city_by_actor(actorId)
	if city == null:
		return - 1
	return city.get_vstate_id()

func get_power_level() -> int:
	for vs in clVState.all_vstates():
		if vs.get_lord_id() == actorId:
			return ActorLevelEnum.Lord
	var vstateId = belong_To_vstateId()
	if vstateId < 0:
		return ActorLevelEnum.Unoffice
	var city = DataManager.get_office_city_by_actor(actorId)
	if city != null and city.get_leader_id() == actorId:
		return ActorLevelEnum.Satrap
	return ActorLevelEnum.Normal


func get_place() -> String:
	match get_power_level():
		ActorLevelEnum.Lord:
			return "君主"
		ActorLevelEnum.Satrap:
			return "太守"
		ActorLevelEnum.Normal:
			return "普通"
		ActorLevelEnum.Unoffice:
			return "在野"
	return "未知"
