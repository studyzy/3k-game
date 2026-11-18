extends Resource


const PERSUADE_RESULTS: Array = [
	
	[
		
		[
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 1, 1, 2, 2, 2, 2], 
		], 
		
		[
			
			[1, 1, 1, 1, 1, 1, 1, 2], 
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 1, 1, 2, 2, 3, 3], 
		], 
		
		[
			
			[1, 1, 1, 1, 1, 1, 4, 4], 
			
			[1, 1, 3, 3, 4, 4, 4, 4], 
			
			[2, 2, 2, 2, 4, 4, 4, 4], 
		]
	], 
	
	[
		
		[
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 1, 1, 1, 1, 2, 2], 
			
			[1, 1, 1, 1, 1, 1, 2, 2], 
		], 
		
		[
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 1, 1, 2, 2, 3, 3], 
			
			[1, 1, 1, 1, 2, 2, 2, 2], 
		], 
		
		[
			
			[1, 1, 1, 1, 3, 3, 4, 4], 
			
			[1, 1, 3, 3, 3, 3, 4, 4], 
			
			[1, 1, 3, 3, 4, 4, 4, 4], 
		]
	], 
	
	[
		
		[
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 1, 1, 2, 2, 2, 2], 
		], 
		
		[
			
			[1, 1, 1, 1, 1, 1, 1, 1], 
			
			[1, 1, 2, 2, 2, 2, 3, 3], 
			
			[1, 1, 2, 2, 3, 3, 3, 3]
		], 
		
		[
			
			[1, 1, 1, 1, 4, 4, 4, 4], 
			
			[1, 1, 2, 2, 4, 4, 4, 4], 
			
			[1, 1, 4, 4, 4, 4, 4, 4]
		]
	]
]


class_name SoloFight




var status: int = 0


var turns: int = 0


var leftId: int = - 1


var rightId: int = - 1


var currentId: int = - 1


var fromIdx: int = 0



var env: Dictionary = {}

func _init(_leftId: int, _rightId: int):
	reset()
	leftId = _leftId
	rightId = _rightId
	return

func reset() -> void :
	status = 0
	turns = 0
	leftId = - 1
	rightId = - 1
	currentId = - 1
	fromIdx = 0
	env = {}
	return


func get_save_data() -> Dictionary:
	var ret = {}
	ret["status"] = status
	ret["turns"] = turns
	ret["leftId"] = leftId
	ret["rightId"] = rightId
	ret["currentId"] = currentId
	ret["fromIdx"] = fromIdx
	ret["env"] = env
	return ret


func load_from_save_data(dic: Dictionary) -> void :
	reset()
	for key in [
		"status", "turns", "leftId", "rightId", 
		"currentId", "fromIdx"
		]:
		if key in dic:
			set(key, Global.intval(dic[key]))
	for key in ["env"]:
		if key in dic:
			set(key, Global.dicval(dic[key]))
	return


func rebuild_from_env() -> void :
	reset()
	if DataManager.solo_run and DataManager.solo_actors.size() == 2:
		status = 1
	if DataManager.solo_sort.size() == 2:
		if DataManager.solo_sort[0] == "右":
			fromIdx = 1
	if DataManager.solo_actors.size() == 2:
		leftId = DataManager.solo_actors[0]
		rightId = DataManager.solo_actors[1]
	currentId = leftId
	if DataManager.solo_sort_no == 1:
		currentId = rightId
	return

func unset_env(key: String) -> void :
	env.erase(key)
	return

func set_env(key: String, val) -> void :
	env[key] = val
	return

func get_env_int(key: String, defVal: int = - 1) -> int:
	if not key in env:
		return defVal
	return Global.intval(env[key], defVal)

func get_env_str(key: String) -> String:
	if not key in env:
		return ""
	return Global.strval(env[key])

func get_env_array(key: String) -> Array:
	if not key in env:
		return []
	return Global.arrval(env[key])

func get_env_int_array(key: String) -> Array:
	if not key in env:
		return []
	return Global.intarrval(env[key])

func get_env_dict(key: String) -> Dictionary:
	if not key in env:
		return {}
	return Global.dicval(env[key])

func running() -> bool:
	return status == 1

func prepare() -> void :
	turns = 0
	status = 1
	SkillHelper.auto_trigger_skill(leftId, 40010)
	SkillHelper.auto_trigger_skill(rightId, 40010)
	return

func finish() -> void :
	status = 2

	
	for actorId in [leftId, rightId]:
		var wa = DataManager.get_war_actor(actorId)
		wa.clear_buff_by_where("单挑")

	
	DataManager.unset_env("白兵.攻击目标")
	DataManager.unset_env("白兵.攻击来源")

	return


func get_actor_ids() -> PoolIntArray:
	var ret = [leftId, rightId]
	if fromIdx == 1:
		ret = [rightId, leftId]
	return ret


func current() -> War_Actor:
	return DataManager.get_war_actor(currentId)


func target() -> War_Actor:
	if currentId == leftId:
		return DataManager.get_war_actor(rightId)
	return DataManager.get_war_actor(leftId)


func opponent(actorId: int) -> War_Actor:
	if actorId == currentId:
		return target()
	return current()


func end_action() -> void :
	var wa = current()
	wa.decrease_buff_by_where("单挑")

	
	if currentId == leftId:
		currentId = rightId
	else:
		currentId = leftId

	
	if currentId == get_actor_ids()[0]:
		next_turn()
	return


func next_turn() -> void :
	turns += 1
	return



func persuade_result() -> int:
	var fromActor = current().actor()
	var targetActor = target().actor()
	var d12 = fromActor.get_wisdom() + fromActor.get_moral()
	var a = 0
	if d12 < 180:
		a += 1
	if d12 < 130:
		a += 1
	var b = 0
	var loy = targetActor.get_loyalty()
	if loy < 80:
		b += 1
	if loy < 50:
		b += 1
	var c = 0
	var hp = targetActor.get_hp()
	if hp < 65:
		c += 1
	if hp < 40:
		c += 1
	var results = Array(PERSUADE_RESULTS[a][b][c]).duplicate()
	results.shuffle()
	var result = results[0]
	if targetActor.get_loyalty() == 100 and result in [3, 4]:
		result = 1
	return result
