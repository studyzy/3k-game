# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：packed/sgz_script/war/AI/War_AI_behavior_llm.gd
# 说明：实现 wab 接口的远程决策器。全知状态 → /ai/decide → 整侧联合 plan →
#       复用父类 _move/_attack/_strategem/_retreat 落地到既有 flow 链；
#       超时 / 非法 / 服务不可用 → 全回合回退本地 hard 规则 AI。
#       依据设计文档 docs/plans/2026-11-18-ai-agent-enemy-design.md §3.2/§3.4/§3.7。
# 注：不定义 _init()，以便继承 War_AI_behavior.gd:_init() 完成 flow 绑定。
# ==============================================================================
extends "War_AI_behavior_new.gd"

const TIMEOUT_BY_DIFFICULTY = {2: 8, 3: 15, 4: 25}

var _projector = null
var _validator = null
var _http = null
var _fallback_wab = null

var _plan: Array = []
var _payload: Dictionary = {}
var _pending: bool = false
var _requested: bool = false
var _local: bool = false

func _ensure_helpers() -> void:
	if _projector == null:
		_projector = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/StateProjection.gd")
	if _validator == null:
		_validator = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/ActionValidator.gd")
	if _http == null:
		_http = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/AIHttpClient.gd")
	return

func _base_url() -> String:
	if OS.has_feature("HTML5"):
		var origin = String(JavaScript.eval("window.location.origin", true))
		if origin != "" and origin != "null":
			return origin + "/ai/decide"
	return "http://127.0.0.1:8060/ai/decide"

# wab 接口：AI_control.gd:72 调用
func turn_start() -> void:
	_ensure_helpers()
	_plan.clear()
	_payload = {}
	_pending = false
	_requested = false
	_local = false
	return

# wab 接口：AI_control.gd:118 调用
# 等待远程响应期间返回主将 id 作为占位，AI_control.AI_before_ready 仍可安全推进；
# 真正的动作由回调重新 add_flow("AI_before_ready") 后执行。
func next_behavior_actor(wv) -> int:
	if _local:
		return _fallback_wab.next_behavior_actor(wv)
	if not _plan.empty():
		return int(_plan[0]["actor"])
	if not _requested:
		_request_plan(wv)
	return wv.main_actorId

func _request_plan(wv) -> void:
	_requested = true
	_payload = _projector.build(wv)
	if _payload.empty():
		# 同步路径：不额外 add_flow，让 AI_control.AI_before_ready 自己继续
		_mark_local("empty_state")
		return
	var timeout_sec = TIMEOUT_BY_DIFFICULTY.get(DataManager.diffculities, 15)
	_pending = true
	var ok = _http.post(_base_url(), to_json(_payload), self, "_on_remote_completed", timeout_sec)
	if not ok:
		_pending = false
		_mark_local("http_start_failed")
	return

# AIHttpClient 回调签名：result, response_code, body
func _on_remote_completed(result: int, response_code: int, body: PoolByteArray) -> void:
	if not _pending:
		return
	_pending = false
	if result != 0 or response_code != 200:
		_fallback("http_{0}".format([response_code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY:
		_fallback("bad_json")
		return
	if not _validator.accept_all(reply.get("plan", []), _payload):
		_fallback("invalid_plan:{0}".format([_validator.get_reason()]))
		return
	_plan = _validator.normalize(reply["plan"], _payload)
	DataManager.game_trace("[AI] plan accepted: {0} actions, {1}ms".format([
		_plan.size(), reply.get("elapsed_ms", -1)
	]))
	FlowManager.add_flow("AI_before_ready")
	return

func _mark_local(reason: String) -> void:
	_local = true
	_plan.clear()
	DataManager.game_trace("[AI] fallback to local hard: " + reason)
	return

# 异步回调路径：流程机已空转，必须重新入队才能继续
func _fallback(reason: String) -> void:
	_pending = false
	_mark_local(reason)
	FlowManager.add_flow("AI_before_ready")
	return

func _delegate_to_local(wvId: int) -> void:
	if _fallback_wab == null:
		_fallback_wab = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/War_AI_behavior_hard.gd")
	_fallback_wab.behavior(wvId)
	return

# wab 接口：AI_control.gd:210 调用
func behavior(wvId: int) -> void:
	if _pending:
		return
	if _local or _plan.empty():
		_delegate_to_local(wvId)
		return
	var actorId = DataManager.get_env_int(VAR_CUR_ACTOR)
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled or not wa.has_position():
		_end_action(wa)
		return
	var act = _plan.pop_front()
	if _execute(act, wa):
		return
	DataManager.game_trace("[AI] exec_failed: " + str(act["tool"]))
	_end_action(wa)
	return

func _execute(act: Dictionary, wa) -> bool:
	match act["tool"]:
		"move":
			return _move(wa, Vector2(act["pos"][0], act["pos"][1]))
		"attack":
			return _attack(wa, int(act["target"]))
		"stratagem":
			return _strategem(wa, int(act["target"]), str(act["skill"]))
		"retreat":
			return _retreat(wa)
		"end":
			_end_action(wa)
			return true
	return false

# wab 接口：AI_control.gd:245 调用
func AI_end() -> void:
	lastBehaviorActorId = -1
	currentBehaviorActorId = -1
	scheme_history.clear()
	_plan.clear()
	_pending = false
	_requested = false
	_local = false
	DataManager.game_trace("[AI] turn end")
	return

# wab 接口：AI_control.gd:259 每帧调用。复用父类实现处理对话确认等，
# 超时由 AIHttpClient 的 HTTPRequest.timeout 兜底（此处不覆盖 _input_key）。
