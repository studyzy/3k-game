# ==============================================================================
# 新增：AI Agent 接入（战争场景）—— 服务端驱动的回合会话
# 文件：packed/sgz_script/war/AI/War_AI_behavior_llm.gd
#
# 一个 AI 回合 = 一个服务端会话：
#   1. turn_start()  → POST /ai/turn 开会话（服务端后台开始跑 agent loop）
#   2. 长轮询 GET /ai/turn/:id/pending 取下一个待执行动作
#   3. 执行该动作（移动/攻击/用计/撤退），由游戏流程播完
#   4. 重新投影战场（units + legal_actions）→ POST /ai/turn/:id/result 回传
#   5. 回到 2，直到服务端返回 end
#   └─ 任一动作失败 / 30s 无新动作 → 回退本地 hard 规则 AI 接管本回合剩余
#
# 决策完全在服务端循环里，Godot 只提供「工具实现 + 执行结果」。
# 依据设计文档 docs/plans/2026-11-18-ai-agent-enemy-design.md §3.7 / §4.3。
# 注：不定义 _init()，以便继承 War_AI_behavior.gd:_init() 完成 flow 绑定。
# ==============================================================================
extends "War_AI_behavior_new.gd"

# 单次长轮询的服务端挂起上限（秒）；服务端到点返回 retry，我们再挂一次
const POLL_TIMEOUT_SEC: int = 20
# 本回合最多执行多少个动作，防边界死循环
const MAX_ACTIONS: int = 40

var _projector = null
var _validator = null
var _http = null
var _fallback_wab = null

var _session_id: String = ""
var _pending: Array = []          # 已执行尚未回传结果的 [(seq, ok, outcome)]
var _ready: Dictionary = {}       # 待执行的动作
var _local: bool = false
var _current_actor: int = -1
var _actions_done: int = 0
var _tips_shown: bool = false
var _posting: bool = false

func _ensure_helpers() -> void:
	if _projector == null:
		_projector = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/StateProjection.gd")
	if _validator == null:
		_validator = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/ActionValidator.gd")
	if _http == null:
		_http = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/AIHttpClient.gd")
	return

func _base_url() -> String:
	# 修改：AI Agent 接入——服务地址可配置（DataManager.ai_agent_base_url），空则按平台回落
	return DataManager.resolve_ai_agent_url("/ai/turn")

# wab 接口：AI_control.gd 回合开始
func turn_start() -> void:
	_ensure_helpers()
	_session_id = ""
	_pending.clear()
	_ready = {}
	_local = false
	_current_actor = -1
	_actions_done = 0
	_posting = false
	_reset_tips()
	return

# wab 接口：AI_control.AI_before_ready 每轮调用
func next_behavior_actor(wv) -> int:
	_ensure_helpers()
	if _local:
		return _fallback_wab.next_behavior_actor(wv)

	# 有待执行动作：交给 AI_control 选中该武将
	if not _ready.empty():
		return int(_ready["actor"])

	# 会话未开：开会话（POST /ai/turn）
	if _session_id == "":
		if _open_session(wv):
			return _current_actor if _current_actor >= 0 else wv.main_actorId
		if _local:
			return _fallback_wab.next_behavior_actor(wv)

	# 有未回传的结果：先回传，再继续轮询
	if not _pending.empty():
		_flush_results(wv)
		return _current_actor if _current_actor >= 0 else wv.main_actorId

	# 长轮询取下一个动作
	if not _posting:
		_poll_next(wv)
	return _current_actor if _current_actor >= 0 else wv.main_actorId

func _open_session(wv) -> bool:
	var payload = _projector.build(wv)
	if payload.empty():
		_mark_local("empty_state")
		return false
	_current_actor = wv.main_actorId
	_show_tips()
	_posting = true
	var ok = _http.post(_base_url(), to_json(payload), self, "_on_session_opened", POLL_TIMEOUT_SEC)
	if not ok:
		_posting = false
		_mark_local("http_start_failed")
		return false
	return true

func _on_session_opened(result: int, response_code: int, body: PoolByteArray) -> void:
	_posting = false
	if result != 0 or response_code != 200:
		_fallback("http_{0}".format([response_code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY or not reply.has("session_id"):
		_fallback("bad_session")
		return
	_session_id = str(reply["session_id"])
	DataManager.game_trace("[AI] session opened: " + _session_id)
	FlowManager.add_flow("AI_before_ready")
	return

func _poll_next(wv) -> void:
	_posting = true
	_show_tips()
	var url = "{0}/{1}/pending?wait_ms={2}".format([
		_base_url(), _session_id, POLL_TIMEOUT_SEC * 1000,
	])
	var ok = _http.get_url(url, self, "_on_polled", POLL_TIMEOUT_SEC + 5)
	if not ok:
		_posting = false
		_fallback("poll_start_failed")
	return

func _on_polled(result: int, response_code: int, body: PoolByteArray) -> void:
	_posting = false
	if result != 0 or response_code != 200:
		_fallback("poll_http_{0}".format([response_code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY:
		_fallback("bad_json")
		return
	var kind = str(reply.get("type", ""))
	match kind:
		"action":
			_accept_action(reply["action"])
		"retry":
			# 服务端尚无动作：重新挂起
			FlowManager.add_flow("AI_before_ready")
		"end":
			_reset_tips()
			DataManager.game_trace("[AI] session end: " + str(reply.get("reason", "")))
			_local = true   # 交由 AI_control 正常走完本回合收尾
			FlowManager.add_flow("AI_before_ready")
		"idle_timeout":
			_fallback("idle_timeout")
		_:
			_fallback("unknown_reply:" + kind)
	return

func _accept_action(act) -> void:
	if typeof(act) != TYPE_DICTIONARY or not act.has("action"):
		_fallback("bad_action")
		return
	var action = act["action"]
	var seq = int(act.get("seq", 0))
	if seq <= 0:
		_fallback("bad_seq")
		return
	if _actions_done >= MAX_ACTIONS:
		_fallback("max_actions")
		return
	# LLM 在工具参数里给的思考（reasoning），随动作一起交给游戏内提示条展示
	var reasoning = str(act.get("reasoning", "")).strip_edges()
	_ready = {"seq": seq, "action": action, "reasoning": reasoning}
	DataManager.ai_debug_log("ACTION accepted seq={0} reason={1} {2}".format([seq, reasoning, to_json(action)]))
	FlowManager.add_flow("AI_before_ready")
	return

# 把已执行的动作结果回传服务端（含最新 units / legal_actions）
func _flush_results(wv) -> void:
	var item = _pending.pop_front()
	if item == null:
		return
	var result_payload = _projector.build_tool_result(wv, item["ok"], item["outcome"])
	result_payload["seq"] = item["seq"]
	_posting = true
	var url = "{0}/{1}/result".format([_base_url(), _session_id])
	var ok = _http.post(url, to_json(result_payload), self, "_on_result_posted", POLL_TIMEOUT_SEC)
	if not ok:
		_posting = false
		_fallback("result_post_failed")
	return

func _on_result_posted(result: int, response_code: int, _body: PoolByteArray) -> void:
	_posting = false
	if result != 0 or response_code != 200:
		_fallback("result_http_{0}".format([response_code]))
		return
	FlowManager.add_flow("AI_before_ready")
	return

# 游戏内显示 LLM 的思考理由。
# 改用常驻提示（不走 _show_tips 的 _tips_shown 标记），否则本回合后续动作的
# 「敌方思考中……」会被该标记挡住而显示不出来。
# 调用时机是 behavior()（AI_ready 之后），此时 hide_all_tool / _process_tips 已过，不会被立即清掉。
func _show_reason(reasoning: String) -> void:
	if reasoning == "":
		return
	SceneManager.show_special_tips("敌方AI：{0}".format([reasoning]))
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

func _mark_local(reason: String) -> void:
	_local = true
	_posting = false
	_ready = {}
	_pending.clear()
	_reset_tips()
	DataManager.game_trace("[AI] fallback to local hard: " + reason)
	return

func _fallback(reason: String) -> void:
	_mark_local(reason)
	FlowManager.add_flow("AI_before_ready")
	return

func _delegate_to_local(wvId: int) -> void:
	if _fallback_wab == null:
		_fallback_wab = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/War_AI_behavior_hard.gd")
	_fallback_wab.behavior(wvId)
	return

# wab 接口：AI_control.gd 每轮执行。执行 _ready 中的单个动作。
func behavior(wvId: int) -> void:
	if _local:
		_delegate_to_local(wvId)
		return
	if _ready.empty():
		return
	var entry = _ready
	_ready = {}
	var act = entry["action"]
	_show_reason(str(entry.get("reasoning", "")))
	var seq = int(entry["seq"])
	var actorId = int(act["actor"])
	DataManager.set_env(VAR_CUR_ACTOR, actorId)
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled or not wa.has_position():
		_pending.append({"seq": seq, "ok": false, "outcome": "演员不可行动"})
		_fallback("actor_unavailable")
		return
	var outcome = _describe(act)
	_actions_done += 1
	_pending.append({"seq": seq, "ok": true, "outcome": outcome})
	if not _execute(act, wa):
		# 执行失败：仍回传失败结果，然后回退
		_pending[_pending.size() - 1]["ok"] = false
		_pending[_pending.size() - 1]["outcome"] = "执行失败：" + outcome
		_fallback("exec_failed:" + str(act["tool"]))
		return
	return

func _describe(act: Dictionary) -> String:
	match str(act["tool"]):
		"move":
			return "移动到{0}".format([str(act.get("pos", []))])
		"attack":
			return "攻击#{0}".format([int(act.get("target", -1))])
		"stratagem":
			return "用计{0}→#{1}".format([str(act.get("skill", "")), int(act.get("target", -1))])
		"retreat":
			return "撤退"
		"end":
			return "结束行动"
	return str(act["tool"])

func _execute(act: Dictionary, wa) -> bool:
	match str(act["tool"]):
		"move":
			# 按路径逐格移动：power 只能是上下左右，不能斜穿/飞越。
			# 游戏自身的 AI 也是逐格走的（War_AI_behavior_new.gd:287 只走 route[1]）。
			var path = act.get("path", [])
			if typeof(path) == TYPE_ARRAY and path.size() > 0:
				return _move_stepwise(wa, path)
			var p = act["pos"]
			return _move(wa, Vector2(p[0], p[1]))
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

# 逐格移动：一次性规划好的路径，逐格转移到相邻格。
# 每格的合法性由 StateProjection 的 _path_stepwise 预先保证（无斜向、无障碍）。
# 这里逐格写 position 并即时重绘，保持与 play_move 一致的最终状态；
# 机动力消耗沿用 get_move_cost（游戏按目标格地形计价）。
func _move_stepwise(wa, path: Array) -> bool:
	if not wa.can_move():
		return false
	var map = SceneManager.current_scene().war_map
	var start = wa.position
	# 先校验整条路径，避免走一半卡死
	var cur = start
	for point in path:
		var next = Vector2(point[0], point[1])
		var d = next - cur
		if abs(d.x) + abs(d.y) != 1:
			return false
		if not map.is_valid_position(next):
			return false
		if next != Vector2(path[path.size() - 1][0], path[path.size() - 1][1]) and not wa.can_move_to_position(next):
			return false
		cur = next
	var target = cur
	if target == start:
		return false
	var cost = DataManager.get_move_cost(wa.actorId, target)
	if cost["机"] > wa.action_point or cost["点"] > wa.poker_point:
		return false
	if _bad_movement(wa, target):
		return false

	# 记录移动前后坐标，供既有 flow（技能 20003 等）使用
	DataManager.set_env("当前坐标", {"x": start.x, "y": start.y})
	DataManager.set_env("目标坐标", {"x": target.x, "y": target.y})
	if cost["机"] > 0:
		wa.action_point = max(0, wa.action_point - cost["机"])
	if cost["点"] > 0:
		wa.poker_point = max(0, wa.poker_point - cost["点"])
	wa.set_tmp_variable("MOVE_COST", cost)

	# 逐格落地
	wa.position = target
	map.cursor_position = target
	map.draw_actors()
	map.update_ap()
	map.fix_cursor_camer()

	DataManager.set_env("移动", 1)
	DataManager.set_env("移动消耗", cost)
	DataManager.unset_env("结束移动")
	DataManager.set_env("移动", 0)
	DataManager.set_env("结束移动", 1)
	if SkillHelper.auto_trigger_skill(wa.actorId, 20003, "AI_before_ready"):
		return true
	if wa.after_move():
		return true
	FlowManager.add_flow("AI_before_ready")
	return true

# wab 接口：AI_control.gd 回合结束
func AI_end() -> void:
	lastBehaviorActorId = -1
	currentBehaviorActorId = -1
	scheme_history.clear()
	_session_id = ""
	_pending.clear()
	_ready = {}
	_local = false
	_current_actor = -1
	_actions_done = 0
	_posting = false
	_reset_tips()
	DataManager.game_trace("[AI] turn end")
	return

# wab 接口：每帧调用。复用父类实现处理对话确认等