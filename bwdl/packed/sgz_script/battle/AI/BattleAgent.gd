# 白兵战异步 AI：每 3 秒一拍，快照进、计划出。
# 请求周期完全不进 FlowManager；只把「用计」排队到安全点执行。
extends Resource

const TICK_INTERVAL_MS := 3000
const PAUSED_TICK_INTERVAL_MS := 10000
const MAX_ERRORS := 3
const TACTIC_TTL_MS := 8000
const REQUEST_TIMEOUT_SEC := 25
const CURRENT_STEP_KEY := "白兵战-当前步骤"

var _projection = null
var _http = null

var _session_id := ""
var _actor_id := -1
var _tick := 0
var _in_flight := false
var _opening := false
var _local := false
var _errors := 0
var _next_tick_at := 0
var _started_ms := 0
var _last_plan = null
var _last_plan_at := 0
var _reopens := 0
var _tactic_queue = null
var _tactic_busy := false
var _tactic_sent_at := 0
var _tactic_sent_name := ""
var _tactic_points_before := 0
var _tactic_buff_before := 0
var _request_kind := ""
var _request_started_at := 0

func _init() -> void:
	# Global.load_script 命中缓存会再次调用 _init()；已有会话时保持原状。
	if _actor_id >= 0:
		return
	_reset()
	return

func _reset() -> void:
	_session_id = ""
	_actor_id = -1
	_tick = 0
	_in_flight = false
	_opening = false
	_local = false
	_errors = 0
	_next_tick_at = 0
	_started_ms = 0
	_last_plan = null
	_last_plan_at = 0
	_reopens = 0
	_tactic_queue = null
	_tactic_busy = false
	_tactic_sent_at = 0
	_tactic_sent_name = ""
	_tactic_points_before = 0
	_tactic_buff_before = 0
	_request_kind = ""
	_request_started_at = 0
	return

func _ensure() -> void:
	if _projection == null:
		_projection = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/BattleProjection.gd")
	if _http == null:
		_http = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/BattleHttpClient.gd")
	return

func _base() -> String:
	return DataManager.resolve_ai_agent_url("/ai/battle")

func attach(bf) -> void:
	if _actor_id >= 0 or bf == null:
		return
	for wa in [bf.get_attacker(), bf.get_defender()]:
		if wa == null or wa.disabled:
			continue
		if wa.get_controlNo() < 0:
			_actor_id = wa.actorId
			_started_ms = OS.get_ticks_msec()
			DataManager.ai_debug_log("B_ATTACH actor={0}".format([_actor_id]), true)
			return
	_local = true
	return

func get_actor_id() -> int:
	return _actor_id

func get_session_id() -> String:
	return _session_id

func is_local() -> bool:
	return _local

func is_managed(actorId: int) -> bool:
	return _actor_id >= 0 and actorId == _actor_id

func is_busy() -> bool:
	return _in_flight or _opening

func tick() -> void:
	var bf = DataManager.get_current_battle_fight()
	if bf == null or not DataManager.battle_run:
		end_battle()
		return
	if _actor_id < 0:
		attach(bf)
	if _local or _actor_id < 0:
		return
	_ensure()
	var now = OS.get_ticks_msec()
	# 看门狗：HTTPRequest 卡死时也要把战场让回本地规则，不能整场停在等待。
	if (_in_flight or _opening) and now - _request_started_at > (REQUEST_TIMEOUT_SEC + 5) * 1000:
		_http.cancel()
		_in_flight = false
		_opening = false
		_request_kind = ""
		_fail("http_watchdog")
	_try_execute_tactic(bf)
	if _in_flight or _opening:
		return
	if now < _next_tick_at:
		return
	if _session_id == "":
		_open(bf)
		return
	_send_tick(bf)
	return

func _enemy_id(bf) -> int:
	var wa = DataManager.get_war_actor(_actor_id)
	if wa == null:
		return -1
	var enemy = wa.get_battle_enemy_war_actor()
	return enemy.actorId if enemy != null else -1

func _open(bf) -> void:
	if _http.is_pending():
		# post() 对「忙」和「启动失败」都返回 false：忙不是失败，清标记、下帧再试。
		_opening = false
		_in_flight = false
		_request_kind = ""
		return
	var payload = {
		"battle_key": "b{0}-b{1}".format([bf.get_attacker_id(), bf.get_defender_id()]),
		"controlled_actor_id": _actor_id,
		"enemy_actor_id": _enemy_id(bf),
		"side": "attacker" if _actor_id == bf.get_attacker_id() else "defender",
		"diffculities": DataManager.diffculities,
	}
	_opening = true
	_request_kind = "open"
	_request_started_at = OS.get_ticks_msec()
	var ok = _http.post(_base(), to_json(payload), self, "_on_open", REQUEST_TIMEOUT_SEC)
	if not ok:
		_opening = false
		_request_kind = ""
		_fail("open_post")
	return

func _on_open(result: int, code: int, body: PoolByteArray) -> void:
	if _request_kind != "open":
		return
	_opening = false
	_request_kind = ""
	if result != 0 or code != 200:
		_fail("open_http_{0}".format([code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY or not reply.has("battle_session_id"):
		_fail("open_bad_json")
		return
	_session_id = str(reply["battle_session_id"])
	# 不在这里清 _errors：410 → 重开 → 410 会被无限刷成零，永远到不了 fallback。
	_next_tick_at = OS.get_ticks_msec()
	DataManager.ai_debug_log("B_OPEN sid=" + _session_id, true)
	DataManager.game_trace("[BattleAI] session " + _session_id)
	return

func _send_tick(bf) -> void:
	if _http.is_pending():
		_in_flight = false
		_opening = false
		_request_kind = ""
		return
	_tick += 1
	if _last_plan != null:
		_last_plan["age_ms"] = OS.get_ticks_msec() - _last_plan_at
	var snapshot = _projection.build(bf, _actor_id, _tick, _last_plan, OS.get_ticks_msec() - _started_ms)
	if snapshot.empty():
		end_battle()
		return
	_in_flight = true
	_request_kind = "tick"
	_request_started_at = OS.get_ticks_msec()
	var url = "{0}/{1}/tick".format([_base(), _session_id])
	var ok = _http.post(url, to_json(snapshot), self, "_on_tick", REQUEST_TIMEOUT_SEC)
	if not ok:
		_in_flight = false
		_request_kind = ""
		_fail("tick_post")
	return

func _on_tick(result: int, code: int, body: PoolByteArray) -> void:
	if _request_kind != "tick":
		return
	_in_flight = false
	_request_kind = ""
	if result != 0 or code == 0:
		_fail("tick_transport")
		return
	if code == 409:
		# 串行客户端不该撞上（上一拍未结束）；持续 409 说明会话卡死，计入错误走 3 次兜底。
		_errors += 1
		_next_tick_at = OS.get_ticks_msec() + _interval()
		if _errors >= MAX_ERRORS:
			_fallback("tick_conflict")
		return
	if code == 410:
		_session_id = ""
		_reopens += 1
		_errors += 1
		_next_tick_at = OS.get_ticks_msec()
		if _reopens > 2:
			_fallback("session_reopen_limit")
			return
		if _errors >= MAX_ERRORS:
			_fallback("session_ended")
		return
	if code != 200:
		_fail("tick_http_{0}".format([code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY or typeof(reply.get("plan")) != TYPE_DICTIONARY:
		_errors = 0
		_next_tick_at = OS.get_ticks_msec() + _interval()
		return
	# timeout:true 是服务端等模型超时后返回的兜底计划，同样算一次模型失败。
	if bool(reply.get("timeout", false)):
		_errors += 1
	else:
		_errors = 0
		_reopens = 0
	_tick = int(reply.get("tick", _tick))
	_apply_plan(reply["plan"], reply.get("rejected", []), _tick)
	_next_tick_at = OS.get_ticks_msec() + _interval()
	if _errors >= MAX_ERRORS:
		_fallback("tick_timeout")
	return

func _apply_plan(plan: Dictionary, rejected, plan_tick: int) -> void:
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	var orders = plan.get("orders", {})
	if typeof(orders) != TYPE_DICTIONARY:
		orders = {}
	var diff = {}
	var applied = []
	var local_rejected = []
	for unit in orders.keys():
		var order = str(orders[unit])
		if not str(unit) in ["将", "骑", "象", "弓", "步"] or not order in ["前进", "待机", "后退"]:
			local_rejected.append({"unit": str(unit), "reason": "非法兵种或命令"})
			continue
		if DataManager.battle_unit_type_hp(_actor_id, str(unit)) <= 0:
			local_rejected.append({"unit": str(unit), "reason": "该兵种已灭"})
			continue
		if bf.get_units_state(_actor_id, str(unit)) != order:
			diff[unit] = order
			applied.append(str(unit))
	var server_tactic = null
	if typeof(rejected) == TYPE_ARRAY:
		for r in rejected:
			if typeof(r) != TYPE_DICTIONARY:
				continue
			if str(r.get("kind", "")) == "tactic":
				# 计策不是兵种命令，不能混进 orders_rejected。
				server_tactic = r
				continue
			local_rejected.append({
				"unit": str(r.get("value", r.get("unit", ""))),
				"reason": str(r.get("reason", "")),
			})
	if not diff.empty():
		bf.set_unit_state(_actor_id, diff)
	_last_plan = {
		"tick": plan_tick,
		"orders": orders,
		"orders_applied": applied,
		"orders_rejected": local_rejected,
		"tactic": null,
		"tactic_status": "none",
		"reason": "",
		"age_ms": 0,
	}
	var tactic = ""
	if plan.get("tactic") != null:
		tactic = str(plan.get("tactic", "")).strip_edges()
	if tactic != "":
		_queue_tactic(tactic, plan_tick)
	elif server_tactic != null:
		_last_plan["tactic"] = str(server_tactic.get("value", ""))
		_last_plan["tactic_status"] = "rejected"
		_last_plan["reason"] = str(server_tactic.get("reason", ""))
	elif _tactic_queue != null:
		# 本拍没给新计，让模型看到之前排队的计策仍在等待执行。
		_last_plan["tactic"] = str(_tactic_queue["tactic"])
		_last_plan["tactic_status"] = "pending"
		_last_plan["reason"] = "排队中"
	_last_plan_at = OS.get_ticks_msec()
	DataManager.ai_debug_log("B_PLAN tick={0} orders={1} tactic={2}".format([
		plan_tick, to_json(orders), tactic,
	]), true)
	return

func _queue_tactic(tactic: String, plan_tick: int) -> void:
	_last_plan["tactic"] = tactic
	if _tactic_queue != null:
		if tactic == str(_tactic_queue["tactic"]):
			_last_plan["tactic_status"] = "pending"
			_last_plan["reason"] = "已在队列中"
		else:
			_last_plan["tactic_status"] = "rejected"
			_last_plan["reason"] = "已有计策排队，本拍未入队"
		return
	var wa = DataManager.get_war_actor(_actor_id)
	if wa == null:
		_reject_tactic(tactic, "取不到武将")
		return
	if not StaticManager.TACTICS.has(tactic):
		_reject_tactic(tactic, "不是白兵战战术")
		return
	var iTactic = Global.load_script(DataManager.mod_path + "sgz_script/battle/ITactic.gd")
	var cost = iTactic.get_tactic_cost(wa, tactic)
	if cost > int(wa.battle_tactic_point):
		_reject_tactic(tactic, "战术值不足")
		return
	if int(wa.get_buff(tactic)["回合数"]) > 0:
		_reject_tactic(tactic, "同名战术已生效")
		return
	_tactic_queue = {
		"tactic": tactic,
		"expires_at": OS.get_ticks_msec() + TACTIC_TTL_MS,
		"plan_tick": plan_tick,
	}
	_last_plan["tactic_status"] = "pending"
	return

func _reject_tactic(tactic: String, reason: String) -> void:
	_last_plan["tactic"] = tactic
	_last_plan["tactic_status"] = "rejected"
	_last_plan["reason"] = reason
	return

func _try_execute_tactic(bf) -> void:
	# 验算块必须在排队守卫之前：施计后队列已清空，但通道仍被 _tactic_busy 占着，
	# 放在守卫之后会让状态永远停在 pending。
	if _tactic_busy:
		var now = OS.get_ticks_msec()
		var elapsed = now - _tactic_sent_at
		# 若期间已换了新计划，别拿旧施计的凭据去改新计划的状态。
		var plan_tactic = ""
		if _last_plan != null and _last_plan.get("tactic") != null:
			plan_tactic = str(_last_plan.get("tactic"))
		var owns_plan = _tactic_sent_name != "" and plan_tactic == _tactic_sent_name
		if elapsed > 10000:
			# flow 卡住：强制解锁，不能一直占着用计通道。
			if owns_plan:
				_last_plan["tactic_status"] = "rejected"
				_last_plan["reason"] = "用计超时"
			_tactic_busy = false
			_tactic_sent_name = ""
		elif elapsed > 500 \
				and not FlowManager.has_task() \
				and int(DataManager.get_env_int(CURRENT_STEP_KEY, 0)) in [2, 4, 5, 6]:
			# 战术流程已走完：核对战术值/状态是否真的变了，再解锁。
			if owns_plan:
				var cast = false
				var wa_now = DataManager.get_war_actor(_actor_id)
				if wa_now != null:
					if int(wa_now.battle_tactic_point) < _tactic_points_before:
						cast = true
					elif _tactic_sent_name != "挑衅" \
							and int(wa_now.get_buff(_tactic_sent_name)["回合数"]) > _tactic_buff_before:
						cast = true
				_last_plan["tactic_status"] = "applied" if cast else "rejected"
				_last_plan["reason"] = "" if cast else "用计未生效"
			_tactic_busy = false
			_tactic_sent_name = ""
		return
	if _tactic_queue == null:
		return
	if OS.get_ticks_msec() > int(_tactic_queue["expires_at"]):
		var expired = str(_tactic_queue["tactic"])
		_tactic_queue = null
		_reject_tactic(expired, "用计排队超时")
		return
	if FlowManager.has_task():
		return
	if not int(DataManager.get_env_int(CURRENT_STEP_KEY, 0)) in [4, 5, 6, 7]:
		return
	var scene = SceneManager.current_scene()
	if scene != null:
		if scene.battle_state.visible:
			return
	if SceneManager.actor_dialog != null and SceneManager.actor_dialog.visible:
		return
	if LoadControl.get_view_model() >= 0:
		return
	var tactic = str(_tactic_queue["tactic"])
	_tactic_queue = null
	var wa = DataManager.get_war_actor(_actor_id)
	if wa == null:
		_reject_tactic(tactic, "取不到武将")
		return
	if not wa.can_use_tactic():
		var why = str(DataManager.get_env_str("战斗.战术禁用原因")).strip_edges()
		_reject_tactic(tactic, why if why != "" else "战术被禁用")
		return
	if tactic == "挑衅" and bf != null and bf.solo_disabled():
		_reject_tactic(tactic, "本场禁用单挑")
		return
	if int(wa.get_buff(tactic)["回合数"]) > 0:
		_reject_tactic(tactic, "同名战术已生效")
		return
	var iTactic = Global.load_script(DataManager.mod_path + "sgz_script/battle/ITactic.gd")
	var cost = int(iTactic.get_tactic_cost(wa, tactic))
	if cost > int(wa.battle_tactic_point):
		_reject_tactic(tactic, "战术值不足")
		return
	_tactic_points_before = int(wa.battle_tactic_point)
	_tactic_buff_before = int(wa.get_buff(tactic)["回合数"])
	DataManager.set_env("当前武将", _actor_id)
	DataManager.set_env("值", tactic)
	_tactic_sent_name = tactic
	_tactic_sent_at = OS.get_ticks_msec()
	_tactic_busy = true
	var added = FlowManager.add_flow("before_AI_tactic")
	if not added:
		_tactic_busy = false
		_tactic_sent_at = 0
		_tactic_sent_name = ""
		_last_plan["tactic_status"] = "rejected"
		_last_plan["reason"] = "flow 忙，未执行"
		return
	_last_plan["tactic_status"] = "pending"
	_last_plan["reason"] = ""
	DataManager.ai_debug_log("B_TACTIC " + tactic, true)
	return

func _interval() -> int:
	var scene = SceneManager.current_scene()
	if scene != null:
		if scene.battle_state.visible:
			return PAUSED_TICK_INTERVAL_MS
	if SceneManager.actor_dialog != null and SceneManager.actor_dialog.visible:
		return PAUSED_TICK_INTERVAL_MS
	if LoadControl.get_view_model() >= 0:
		return PAUSED_TICK_INTERVAL_MS
	return TICK_INTERVAL_MS

func _fail(reason: String) -> void:
	_errors += 1
	_next_tick_at = OS.get_ticks_msec() + _interval()
	DataManager.ai_debug_log("B_TICK FAIL {0} errors={1}".format([reason, _errors]), true)
	if _errors >= MAX_ERRORS:
		_fallback(reason)
	return

func _fallback(reason: String) -> void:
	_local = true
	_in_flight = false
	_opening = false
	_tactic_queue = null
	_tactic_busy = false
	DataManager.ai_debug_log("B_FALLBACK reason=" + reason, true)
	DataManager.game_trace("[BattleAI] fallback to local: " + reason)
	return

func _on_ended(_result: int, _code: int, _body: PoolByteArray) -> void:
	return

func end_battle() -> void:
	# 重复调用（tick 里 bf 为空会再次进来）不得取消首个 /end 请求。
	if _session_id == "" and not _in_flight and not _opening:
		_reset()
		return
	if _http != null:
		_http.cancel()
	if _session_id != "" and _http != null:
		var url = "{0}/{1}/end".format([_base(), _session_id])
		_http.post(url, "{}", self, "_on_ended", REQUEST_TIMEOUT_SEC)
	_reset()
	return
