# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clSoloFight.gd
# 说明：单挑结算对象（核心战斗逻辑）。计算单挑（武将一对一决斗）的过程与结果。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource

# 单挑「劝降」结果查找表：
# 三维数组 [a][b][c] -> 结果值
#  - a：进攻方「智力+魅力」档次（<180 或 <130 分别 +1）
#  - b：防守方「忠诚」档次（<80 或 <50 分别 +1）
#  - c：防守方「体力」档次（<65 或 <40 分别 +1）
# 结果值含义：1=失败，2=动摇，3=成功，4=大成功（详见 persuade_result()）
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


# 单挑状态机：status 0=未开始，1=进行中，2=已结束
var status: int = 0

# 已进行的回合数
var turns: int = 0

# 左侧单挑者 ID
var leftId: int = - 1

# 右侧单挑者 ID
var rightId: int = - 1

# 当前行动方 ID
var currentId: int = - 1

# 起始顺序（0=左先手，1=右先手）
var fromIdx: int = 0


# 单挑过程中的临时环境变量
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

# 单挑开始：回合归零、置为进行中，并触发双方「单挑开始」类技能（40010）
func prepare() -> void :
	turns = 0
	status = 1
	SkillHelper.auto_trigger_skill(leftId, 40010)
	SkillHelper.auto_trigger_skill(rightId, 40010)
	return

# 单挑结束：置为已结束，清除双方的单挑类 Buff 与白兵标记
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


# 一次行动结束：扣除当前方单挑 Buff，交换行动权，一轮双方都行动过后进入下一回合
func end_action() -> void :
	var wa = current()
	wa.decrease_buff_by_where("单挑")

	# 交换行动权
	if currentId == leftId:
		currentId = rightId
	else:
		currentId = leftId

	# 回到先手方说明一轮结束，进入下一回合
	if currentId == get_actor_ids()[0]:
		next_turn()
	return


func next_turn() -> void :
	turns += 1
	return



# 计算「劝降」结果：
# 根据进攻方「智力+魅力」、防守方「忠诚」、防守方「体力」三档查表（见 PERSUADE_RESULTS）。
# 忠诚 100 的武将无法被劝降成功（结果 3/4 会被降级为 1=失败）。
func persuade_result() -> int:
	var fromActor = current().actor()
	var targetActor = target().actor()
	# 进攻方实力 = 智力 + 魅力，按阈值分档
	var d12 = fromActor.get_wisdom() + fromActor.get_moral()
	var a = 0
	if d12 < 180:
		a += 1
	if d12 < 130:
		a += 1
	# 防守方忠诚分档
	var b = 0
	var loy = targetActor.get_loyalty()
	if loy < 80:
		b += 1
	if loy < 50:
		b += 1
	# 防守方体力分档
	var c = 0
	var hp = targetActor.get_hp()
	if hp < 65:
		c += 1
	if hp < 40:
		c += 1
	# 查表得到候选结果并随机抽取一个
	var results = Array(PERSUADE_RESULTS[a][b][c]).duplicate()
	results.shuffle()
	var result = results[0]
	# 忠诚满值的武将绝不投降
	if targetActor.get_loyalty() == 100 and result in [3, 4]:
		result = 1
	return result
