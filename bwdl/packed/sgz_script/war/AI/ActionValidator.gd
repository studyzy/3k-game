# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：packed/sgz_script/war/AI/ActionValidator.gd
# 说明：服务返回 plan 后的二次校验（设计文档 §3.6 / §4.3 双防线）。
#       任一非法即整批拒绝，不做局部执行（plan 有顺序依赖）。
# ==============================================================================
extends Resource

const MAX_ACTIONS: int = 32

var _reason: String = ""

func _init() -> void:
	_reason = ""
	return

func get_reason() -> String:
	return _reason

func _index_legal(payload: Dictionary) -> Dictionary:
	var ret = {}
	for a in payload["legal_actions"]:
		ret[a["id"]] = a
	return ret

func _index_units(payload: Dictionary) -> Dictionary:
	var ret = {}
	for u in payload["units"]:
		ret[u["id"]] = u
	return ret

# 返回 true 表示整批可接受；失败原因用 get_reason() 读取
func accept_all(reply_plan, payload: Dictionary) -> bool:
	_reason = ""
	if typeof(reply_plan) != TYPE_ARRAY:
		_reason = "bad_json"
		return false
	if reply_plan.empty():
		_reason = "invalid_plan"
		return false
	if reply_plan.size() > MAX_ACTIONS:
		_reason = "invalid_plan"
		return false

	var legal = _index_legal(payload)
	var units = _index_units(payload)
	var controlled = payload["controlled_vstate_id"]
	var used = {}
	var spent = {}

	for i in range(reply_plan.size()):
		var item = reply_plan[i]
		if typeof(item) != TYPE_DICTIONARY or not item.has("id") or typeof(item["id"]) != TYPE_STRING:
			_reason = "invalid_plan"
			return false
		var id = item["id"]
		if not legal.has(id):
			_reason = "invalid_plan"
			return false
		if used.has(id):
			_reason = "invalid_plan"
			return false
		used[id] = true
		var action = legal[id]
		var actor_id = action["actor"]
		if not units.has(actor_id):
			_reason = "invalid_plan"
			return false
		var unit = units[actor_id]
		if unit["vstate"] != controlled or unit["disabled"]:
			_reason = "invalid_plan"
			return false
		var cost = action["cost"] if action.has("cost") else {}
		var cur = spent[actor_id] if spent.has(actor_id) else {"ap": 0, "poker": 0}
		cur["ap"] = cur["ap"] + (cost["ap"] if cost.has("ap") else 0)
		cur["poker"] = cur["poker"] + (cost["poker"] if cost.has("poker") else 0)
		spent[actor_id] = cur
		if cur["ap"] > unit["ap"] or cur["poker"] > unit["poker"]:
			_reason = "invalid_plan"
			return false
	return true

# 补齐 order，返回可直接消费的动作字典数组（已含 tool/actor/target/pos/skill/city）
func normalize(reply_plan: Array, payload: Dictionary) -> Array:
	var legal = _index_legal(payload)
	var ret = []
	for i in range(reply_plan.size()):
		var action = legal[reply_plan[i]["id"]].duplicate(true)
		action["order"] = i + 1
		ret.append(action)
	return ret
