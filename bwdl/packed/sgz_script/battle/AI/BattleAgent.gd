# ==============================================================================
# 新增：AI Agent 接入（白兵战）
# 文件：packed/sgz_script/battle/AI/BattleAgent.gd
# 说明：白兵战「服务端驱动」对接层。
#       战斗开始时 POST /ai/battle 开会话；每个战斗回合用长轮询取指令
#       （set_order / use_tactic / end_turn），执行后回传最新态势；
#       end_turn 到达即交还引擎结算，并在引擎推进到下一回合时 POST /resume。
#       任一失败 → 回退本地规则（不改原有 AI 行为）。
# ==============================================================================
extends Resource

const POLL_TIMEOUT_SEC: int = 20
# 与服务端 idle_timeout_ms 对齐（每个战斗回合的空闲上限）
const IDLE_TIMEOUT_MS: int = 30000

var _projection = null
var _http = null

var _session_id: String = ""
var _actor_id: int = -1
var _pending_results: Array = []   # [{seq, ok, outcome}]
var _busy: bool = false
var _local: bool = false
var _turn_open: bool = false
var _tips_shown: bool = false

func _init() -> void:
	_reset()
	return

func _reset() -> void:
	_session_id = ""
	_actor_id = -1
	_pending_results.clear()
	_busy = false
	_local = false
	_turn_open = false
	_tips_shown = false
	return

func _ensure() -> void:
	if _projection == null:
		_projection = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/BattleProjection.gd")
		if _projection == null:
			_projection = load("res://BattleProjection.gd").new()
	if _http == null:
		_http = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/AIHttpClient.gd")
		if _http == null:
			_http = load("res://AIHttpClient.gd").new()
	return

func _base() -> String:
	# 修改：AI Agent 接入——服务地址可配置（DataManager.ai_agent_base_url），空则按平台回落
	return DataManager.resolve_ai_agent_url("/ai/battle")

func is_local() -> bool:
	return _local
func get_session_id() -> String:
	return _session_id
func has_pending_results() -> bool:
	return not _pending_results.empty()
func is_enabled() -> bool:
	return DataManager.ai_agent_mode
func is_busy() -> bool:
	return _busy

# ---------------- 开场：开战斗会话 ----------------
func open(actorId: int) -> bool:
	_ensure()
	_reset()
	_actor_id = actorId
	var bf = DataManager.get_current_battle_fight()
	var payload = _projection.build(bf, actorId)
	if payload.empty():
		_local = true
		return false
	_busy = true
	_show_tips()
	var ok = _http.post(_base(), to_json(payload), self, "_on_opened", POLL_TIMEOUT_SEC)
	if not ok:
		_busy = false
		_local = true
		DataManager.game_trace("[BattleAI] open start failed")
	return ok

func _on_opened(result: int, code: int, body: PoolByteArray) -> void:
	_busy = false
	if result != 0 or code != 200:
		_fallback("open_http_{0}".format([code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY or not reply.has("battle_session_id"):
		_fallback("battle_bad_session")
		return
	_session_id = str(reply["battle_session_id"])
	DataManager.game_trace("[BattleAI] session " + _session_id)
	_turn_open = true
	_reset_tips()
	return

# ---------------- 本回合：长轮询取指令 ----------------
func poll() -> bool:
	_ensure()
	if _local or _busy or _session_id == "":
		return false
	_busy = true
	_show_tips()
	var url = "{0}/{1}/pending?wait_ms={2}".format([_base(), _session_id, POLL_TIMEOUT_SEC * 1000])
	var ok = _http.get_url(url, self, "_on_polled", POLL_TIMEOUT_SEC + 5)
	if not ok:
		_busy = false
		_fallback("battle_poll_start_failed")
	return ok

func _on_polled(result: int, code: int, body: PoolByteArray) -> void:
	_busy = false
	if result != 0 or code != 200:
		_fallback("battle_poll_http_{0}".format([code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY:
		_fallback("battle_bad_json")
		return
	match str(reply.get("type", "")):
		"order":
			var ok = _apply_order(reply)
			_queue_result(int(reply.get("seq", 0)), ok, "兵种{0}命令→{1}".format([reply.get("unit", ""), reply.get("order", "")]))
		"tactic":
			var ok2 = _apply_tactic(reply)
			_queue_result(int(reply.get("seq", 0)), ok2, "计策 {0}".format([reply.get("tactic", "")]))
		"end_turn":
			_reset_tips()
			_turn_open = false
			_queue_result(int(reply.get("seq", 0)), true, "本回合指令下达完毕")
			_flow("battle_ai_turn_ready")
		"end_battle":
			_reset_tips()
			_local = true
			DataManager.game_trace("[BattleAI] battle ended")
		"retry":
			_flow("battle_ai_poll_again")
		"idle_timeout":
			_fallback("battle_idle_timeout")
		_:
			_fallback("battle_unknown_reply")
	return

func _apply_order(reply: Dictionary) -> bool:
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return false
	var unit = str(reply.get("unit", ""))
	var order = str(reply.get("order", ""))
	if not order in ["前进", "待机", "后退"]:
		return false
	var setting = {}
	setting[unit] = order
	bf.set_unit_state(_actor_id, setting)
	return true

func _apply_tactic(reply: Dictionary) -> bool:
	var tactic = str(reply.get("tactic", ""))
	if not StaticManager.TACTICS.has(tactic):
		return false
	var wa = DataManager.get_war_actor(_actor_id)
	if wa == null:
		return false
	var iTactic = Global.load_script(DataManager.mod_path + "sgz_script/battle/ITactic.gd")
	var cost = iTactic.get_tactic_cost(wa, tactic)
	if cost > wa.battle_tactic_point:
		return false
	# 走既有战术流程
	DataManager.set_env("值", tactic)
	FlowManager.add_flow("before_AI_tactic")
	return true

func _queue_result(seq: int, ok: bool, outcome: String) -> void:
	if seq <= 0:
		return
	_pending_results.append({"seq": seq, "ok": ok, "outcome": outcome})
	return

# ---------------- 回传结果 ----------------
func flush() -> bool:
	_ensure()
	if _local or _busy or _session_id == "" or _pending_results.empty():
		return false
	var item = _pending_results.pop_front()
	var bf = DataManager.get_current_battle_fight()
	var payload = _projection.build_result(bf, _actor_id, bool(item["ok"]), str(item["outcome"]))
	payload["seq"] = int(item["seq"])
	_busy = true
	var url = "{0}/{1}/result".format([_base(), _session_id])
	var ok = _http.post(url, to_json(payload), self, "_on_flushed", POLL_TIMEOUT_SEC)
	if not ok:
		_busy = false
		_fallback("battle_result_post_failed")
	return ok

func _on_flushed(result: int, code: int, _body: PoolByteArray) -> void:
	_busy = false
	if result != 0 or code != 200:
		_fallback("battle_result_http_{0}".format([code]))
		return
	_flow("battle_ai_after_flush")
	return

# ---------------- 引擎推进到下一战斗回合 ----------------
func resume_turn() -> void:
	if _local or _session_id == "":
		return
	var url = "{0}/{1}/resume".format([_base(), _session_id])
	_http.post(url, "{}", self, "_on_resumed", POLL_TIMEOUT_SEC)
	return

func _on_resumed(result: int, code: int, _body: PoolByteArray) -> void:
	if result != 0 or code != 200:
		DataManager.game_trace("[BattleAI] resume failed {0}".format([code]))
		return
	_turn_open = true
	return

# ---------------- 工具 ----------------
func _fallback(reason: String) -> void:
	_local = true
	_busy = false
	_pending_results.clear()
	_reset_tips()
	DataManager.game_trace("[BattleAI] fallback to local: " + reason)
	_flow("battle_ai_fallback")
	return

func _flow(name: String) -> void:
	FlowManager.add_flow(name)
	return

func _show_tips() -> void:
	if _tips_shown:
		return
	_tips_shown = true
	SceneManager.show_special_tips("敌方思考中……")
	return

func _reset_tips() -> void:
	if not _tips_shown:
		return
	_tips_shown = false
	SceneManager.reset_tips()
	return

func end_battle() -> void:
	_reset_tips()
	_reset()
	return