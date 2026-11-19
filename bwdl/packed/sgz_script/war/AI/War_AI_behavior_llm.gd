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
# 最近一次移动的实际结果（走到哪/扣多少/为何停下），用于替换 outcome
var _last_move_outcome: String = ""

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
		_ensure_fallback_wab()
		return _fallback_wab.next_behavior_actor(wv)

	# 有待执行动作：交给 AI_control 选中该武将
	if not _ready.empty():
		return int(_ready["actor"])

	# 会话未开：开会话（POST /ai/turn）
	if _session_id == "":
		if _open_session(wv):
			return _current_actor if _current_actor >= 0 else wv.main_actorId
		if _local:
			_ensure_fallback_wab()
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
	DataManager.ai_debug_log("SESSION opened " + _session_id)
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
			DataManager.ai_debug_log("SESSION end reason=" + str(reply.get("reason", "")))
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
	DataManager.ai_debug_log("SHOW_REASON len={0} text={1}".format([reasoning.length(), reasoning]))
	if reasoning == "":
		return
	SceneManager.show_special_tips("敌方AI：{0}".format([reasoning]))
	DataManager.ai_debug_log("SHOW_REASON done tips_visible={0}".format([SceneManager.tips.visible]))
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
	DataManager.ai_debug_log("FALLBACK to local hard: " + reason)
	return

func _fallback(reason: String) -> void:
	_mark_local(reason)
	FlowManager.add_flow("AI_before_ready")
	return

func _ensure_fallback_wab() -> void:
	if _fallback_wab == null:
		_fallback_wab = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/War_AI_behavior_hard.gd")
	return

func _delegate_to_local(wvId: int) -> void:
	_ensure_fallback_wab()
	_fallback_wab.behavior(wvId)
	return

# wab 接口：AI_control.gd 每轮执行。执行 _ready 中的单个动作。
func behavior(wvId: int) -> void:
	if _local:
		_delegate_to_local(wvId)
		return
	if _ready.empty():
		# 本轮没有可执行动作：HTTP 回调（_on_session_opened / _on_polled /
		# _on_result_posted）到达时会自己 add_flow("AI_before_ready")，不需要在这里补。
		# 但要防「请求已结束、动作却没落到 _ready」的空转：
		# 此时没人会再驱动 flow，AI 回合会永久停在 AI_ready（画面不动、回合结束不了）。
		if not _posting:
			FlowManager.add_flow("AI_before_ready")
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
	DataManager.ai_debug_log("ACTION exec seq={0} {1} -> {2}".format([seq, str(act["tool"]), outcome]))
	if not _execute(act, wa):
		# 执行失败：仍回传失败结果，然后回退
		_pending[_pending.size() - 1]["ok"] = false
		_pending[_pending.size() - 1]["outcome"] = "执行失败：" + outcome
		_fallback("exec_failed:" + str(act["tool"]))
		return
	# 移动的 outcome 用实际结果（走到哪、扣多少、为何停下），而不是计划描述
	if str(act["tool"]) == "move" and _last_move_outcome != "":
		_pending[_pending.size() - 1]["outcome"] = _last_move_outcome
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

# 逐格移动：LLM 自己规划整条路径，这里不做前置校验，直接照着走。
# 每一步：相邻才走 → 界内 → 该格可站（无武将/墙）→ 机动力够 → 扣该格费用 → 落地。
# 任何一步不满足就【停在当前格】，已走部分照常扣费，不当作失败、不降级。
# 实际走到哪、消耗多少，写进 _last_move_outcome，随 tool result 回传给 Agent。
# 计价口径与玩家手操一致（player_move.gd:_push_move）：进入一格算一次 get_move_cost。
func _move_stepwise(wa, path: Array) -> bool:
	_last_move_outcome = ""
	if not wa.can_move():
		_last_move_outcome = "该武将现在无法移动"
		return true
	if path.empty():
		_last_move_outcome = "路径为空，未移动"
		return true
	var map = SceneManager.current_scene().war_map
	var start = wa.position
	DataManager.set_env("当前坐标", {"x": start.x, "y": start.y})

	var cur = start
	var total = {"机": 0, "点": 0}
	var walked = 0
	var stop_reason = ""
	for point in path:
		if typeof(point) != TYPE_ARRAY or point.size() != 2:
			stop_reason = "路径里有非法坐标"
			break
		var next = Vector2(int(point[0]), int(point[1]))
		var d = next - cur
		# 只能上下左右走一格，不能斜走、不能跳跃
		if abs(d.x) + abs(d.y) != 1:
			stop_reason = "第{0}步 {1} 与当前格 {2} 不相邻（只能上下左右一格）".format([walked + 1, str(next), str(cur)])
			break
		if not map.is_valid_position(next):
			stop_reason = "第{0}步 {1} 超出地图边界".format([walked + 1, str(next)])
			break
		if not wa.can_move_to_position(next):
			stop_reason = "第{0}步 {1} 无法进入（有武将或地形阻挡）".format([walked + 1, str(next)])
			break
		var step_cost = DataManager.get_move_cost(wa.actorId, next)
		if step_cost["机"] > wa.action_point or step_cost["点"] > wa.poker_point:
			stop_reason = "第{0}步 {1} 机动力不足（需要 {2}，剩余 {3}）".format([
				walked + 1, str(next), int(step_cost["机"]), int(wa.action_point)
			])
			break
		wa.action_point = max(0, wa.action_point - step_cost["机"])
		wa.poker_point = max(0, wa.poker_point - step_cost["点"])
		total["机"] = int(total["机"]) + int(step_cost["机"])
		total["点"] = int(total["点"]) + int(step_cost["点"])
		wa.position = next
		cur = next
		walked += 1

	var reached = "%s→%s" % [str(start), str(cur)]
	if walked == 0:
		_last_move_outcome = "未移动（%s）；原因：%s" % [str(start), stop_reason]
		return true
	var msg = "移动 %s，共 %d 格，消耗机动力 %d、点数 %d" % [
		reached, walked, int(total["机"]), int(total["点"])
	]
	if stop_reason != "":
		msg += "；提前停下：%s" % [stop_reason]
	if cur != Vector2(path[path.size() - 1][0], path[path.size() - 1][1]):
		msg += "；未到达预定终点"
	_last_move_outcome = msg

	DataManager.set_env("目标坐标", {"x": cur.x, "y": cur.y})
	wa.set_tmp_variable("MOVE_COST", total)
	map.cursor_position = cur
	map.draw_actors()
	map.update_ap()
	map.fix_cursor_camer()

	DataManager.set_env("移动", 1)
	DataManager.set_env("移动消耗", total)
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
	DataManager.ai_debug_log("TURN END")
	return

# wab 接口：每帧调用。复用父类实现处理对话确认等