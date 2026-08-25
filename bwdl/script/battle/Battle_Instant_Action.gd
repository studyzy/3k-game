# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/battle/Battle_Instant_Action.gd
# 说明：战斗即时行动对象。处理战斗中的即时指令与响应。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource
class_name Battle_Instant_Action


var unitId: int = - 1

var action: String = ""

var targetUnitId: int = - 1

var targetPos: Vector2 = Vector2( - 1, - 1)

var actionTimes: int = 1

var targets: Array;

var need_state: Array = [];

const GENERAL_KEY = "白兵.即时行动"
const UNIT_KEY = "u"
const ACTION_KEY = "a"
const TARGET_KEY = "t"
const POS_X_KEY = "x"
const POS_Y_KEY = "y"
const TARGETS_KEY = "ts"
const ACTION_TIMES_KEY = "r"
const NEED_STATE_KEY = "ns"

func _init():
	self.unitId = - 1
	self.action = ""
	self.targetUnitId = - 1
	self.targetPos = Vector2( - 1, - 1)
	self.actionTimes = 1
	self.targets = []


static func pop_first() -> Battle_Instant_Action:
	var bias = load_all_from_env()
	if bias.size() == 0:
		return null

	var ret = bias.pop_front()
	save_all_to_env(bias)
	return ret



static func load_all_from_env() -> Array:
	var ret = []
	var data = DataManager.get_env_str(GENERAL_KEY)
	if data == "":
		return ret
	for item in parse_json(data):
		ret.append(load_from_json(item))
	return ret


static func save_all_to_env(bias: Array) -> bool:
	var data = []
	for bia in bias:
		var row: Dictionary = {}
		row[UNIT_KEY] = bia.unitId
		row[ACTION_KEY] = bia.action
		row[TARGET_KEY] = bia.targetUnitId
		row[POS_X_KEY] = bia.targetPos.x
		row[POS_Y_KEY] = bia.targetPos.y
		row[ACTION_TIMES_KEY] = bia.actionTimes
		row[TARGETS_KEY] = bia.targets
		row[NEED_STATE_KEY] = bia.need_state
		data.append(row)
	DataManager.set_env(GENERAL_KEY, to_json(data))
	return true




static func load_from_json(data: Dictionary) -> Battle_Instant_Action:
	var ret: Battle_Instant_Action = load("res://script/battle/Battle_Instant_Action.gd").new()
	if data.has(UNIT_KEY):
		ret.unitId = int(data[UNIT_KEY])
	if data.has(ACTION_KEY):
		ret.action = str(data[ACTION_KEY])
	if data.has(TARGET_KEY):
		ret.targetUnitId = int(data[TARGET_KEY])
	if data.has(POS_X_KEY):
		ret.targetPos.x = int(data[POS_X_KEY])
	if data.has(POS_Y_KEY):
		ret.targetPos.y = int(data[POS_Y_KEY])
	if data.has(ACTION_TIMES_KEY):
		ret.actionTimes = int(data[ACTION_TIMES_KEY])
	if data.has(TARGETS_KEY):
		ret.targets = Array(data[TARGETS_KEY])
	if data.has(NEED_STATE_KEY):
		ret.need_state = Array(data[NEED_STATE_KEY])
	return ret


func insert_to_env() -> bool:
	var bias = load_all_from_env()
	bias.push_front(self)
	return save_all_to_env(bias)


func get_unit_state() -> String:
	var bu = DataManager.battle_units[unitId];
	return bu.get_state();
