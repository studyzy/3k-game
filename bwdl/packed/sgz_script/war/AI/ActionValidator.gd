# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：packed/sgz_script/war/AI/ActionValidator.gd
# 说明：服务返回动作后的二次校验（设计文档 §3.6 / §4.3 双防线）。
#       回合会话下每次只校验一个动作；任一非法即回退本地 hard 规则 AI。
#       注意：end 不再是「动作工具」——它由服务端在 LLM 调用后直接结束会话，
#       不会经由 pending 通道下发，因此这里只校验 move/attack/stratagem/retreat。
# ==============================================================================
extends Resource

const MAX_ACTIONS: int = 32
const ACT_TOOLS: Array = ["move", "attack", "stratagem", "retreat"]

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

# 逐步交互：校验服务返回的单个动作。
# 返回补齐后的动作字典（可直接消费）；不合法返回空字典，原因用 get_reason() 读取。
# history 用于拒绝「重复执行同一个动作」。
func accept_action(reply_action, payload: Dictionary, history: Array) -> Dictionary:
	_reason = ""
	if typeof(reply_action) != TYPE_DICTIONARY or not reply_action.has("id"):
		_reason = "bad_json"
		return {}
	var id = reply_action["id"]
	if typeof(id) != TYPE_STRING:
		_reason = "invalid_action"
		return {}
	var legal = _index_legal(payload)
	if not legal.has(id):
		_reason = "invalid_action"
		return {}
	var action = legal[id]
	if not ACT_TOOLS.has(action["tool"]):
		_reason = "invalid_action"
		return {}
	# 该演员是否已经有成功执行的同名动作（避免模型反复提交同一个动作）
	for h in history:
		if h["id"] == id and h["ok"]:
			_reason = "duplicate_action"
			return {}
	var actor_id = action["actor"]
	var units = _index_units(payload)
	if not units.has(actor_id):
		_reason = "invalid_action"
		return {}
	var unit = units[actor_id]
	if unit["vstate"] != payload["controlled_vstate_id"] or unit["disabled"]:
		_reason = "invalid_action"
		return {}
	var cost = action["cost"] if action.has("cost") else {}
	var ap = cost["ap"] if cost.has("ap") else 0
	var poker = cost["poker"] if cost.has("poker") else 0
	if ap > unit["ap"] or poker > unit["poker"]:
		_reason = "invalid_action"
		return {}
	return action.duplicate(true)

# 返回 true 表示整批可接受；失败原因用 get_reason() 读取
# （备份路径：若服务仍返回整批 plan，可按整批校验）
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
