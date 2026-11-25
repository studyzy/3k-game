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
#   └─ 任一动作失败 / 30s 无 Agent 活动（任何工具调用都算）→ 回退本地 hard 规则 AI 接管本回合剩余
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
var _estimator = null

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
	if _estimator == null:
		_estimator = Global.load_script(DataManager.mod_path + "sgz_script/war/AI/StratagemProjection.gd")
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
	_clear_agent_message()
	return

# wab 接口：AI_control.AI_before_ready 每轮调用
func next_behavior_actor(wv) -> int:
	_ensure_helpers()
	if _local:
		_ensure_fallback_wab()
		return _fallback_wab.next_behavior_actor(wv)

	# 有待执行动作：交给 AI_control 选中该武将。
	# 注意动作存在 _ready["action"] 里（_accept_action 的结构是 {seq, action, reasoning}），
	# 直接读 _ready["actor"] 会拿到 null → actor 0 → 后续 AI_before_ready 中断、动作不执行。
	if not _ready.empty():
		var act = _ready.get("action", {})
		if typeof(act) == TYPE_DICTIONARY and act.has("actor"):
			return int(act["actor"])
		return _current_actor if _current_actor >= 0 else wv.main_actorId

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
		"ask":
			# 只读查询（用计预估）：模型没有动作在飞时直接问，走与 /result 捎带相同的回填逻辑
			DataManager.ai_debug_log("ASK recv n={0} sid={1} raw={2}".format([
				str(reply.get("asks", []).size() if typeof(reply.get("asks", [])) == TYPE_ARRAY else - 1),
				_session_id, to_json(reply),
			]), true)
			var posted = _answer_asks(reply.get("asks", []), _session_id)
			DataManager.ai_debug_log("ASK posted={0}".format([str(posted)]), true)
			if not posted:
				FlowManager.add_flow("AI_before_ready")
			return
		"progress":
			# Agent 的中间进度（思考文本 / 只读侦察），只展示，不执行
			_show_progress(str(reply.get("text", "")))
			FlowManager.add_flow("AI_before_ready")
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
	DataManager.ai_debug_log("RESULT POST seq={0} ok={1} outcome={2}".format([
		item["seq"], str(item["ok"]), str(item["outcome"]),
	]), true)
	var ok = _http.post(url, to_json(result_payload), self, "_on_result_posted", POLL_TIMEOUT_SEC)
	if not ok:
		_posting = false
		_fallback("result_post_failed")
	return

func _on_result_posted(result: int, response_code: int, body: PoolByteArray) -> void:
	_posting = false
	if result != 0 or response_code != 200:
		_fallback("result_http_{0}".format([response_code]))
		return
	# 服务端可能在同一响应里附带「用计预估」查询（模型想先看命中率和结果再决定是否用计）
	var reply = _parse_json_object(body)
	var asks = reply.get("estimates")
	if typeof(asks) != TYPE_ARRAY or asks.empty():
		FlowManager.add_flow("AI_before_ready")
		return
	var sid = _session_id
	if str(reply.get("sid", "")) != "":
		sid = str(reply["sid"])
	if _answer_asks(asks, sid):
		return
	FlowManager.add_flow("AI_before_ready")
	return

# 把一组用计预估查询交给引擎现算并回传服务端。
# 两条通道共用：/pending 长轮询的 ask 响应（模型无动作在飞时的只读查询）、
# /result 响应捎带的下发。返回 true 表示已发出 POST，回调会继续驱动 flow。
func _answer_asks(asks, sid: String) -> bool:
	DataManager.ai_debug_log("ASK parse type={0} n={1} sid='{2}'".format([
		typeof(asks), str(asks.size() if typeof(asks) == TYPE_ARRAY else - 1), sid,
	]), true)
	if typeof(asks) != TYPE_ARRAY or asks.empty() or sid == "":
		DataManager.ai_debug_log("ASK abort: bad input", true)
		return false
	var answers = []
	for q in asks:
		if typeof(q) != TYPE_DICTIONARY:
			continue
		if str(q.get("kind", "estimate_stratagem")) != "estimate_stratagem":
			continue
		# 只回传「中计概率 + 中计后的结果」这段文字，逐目标的原始明细模型读不懂也用不上
		var summary = _estimate_summary(
			int(q.get("actor", - 1)), int(q.get("target", - 1)), str(q.get("skill", ""))
		)
		answers.append({"id": int(q.get("id", 0)), "data": {"ok": summary != "预估失败", "summary": summary}})
	if answers.empty():
		DataManager.ai_debug_log("ASK abort: no answers built", true)
		return false
	# 回传失败不阻塞决策：按正常流程继续，模型下轮会重新要
	return _post_estimates(answers, sid)

# 用计预估的文字结论（给模型看）：命中率 + 中计后的结果，不夹带原始 JSON 明细。
func _estimate_summary(actorId: int, targetId: int, skill: String) -> String:
	var res = _estimator.estimate(actorId, targetId, skill)
	if typeof(res) != TYPE_DICTIONARY:
		return "预估失败"
	var text = str(res.get("summary", ""))
	if text == "":
		return "预估失败"
	return text

# 把用计预估结果回传服务端（不带动作），成功后等服务端回包再继续
func _post_estimates(answers: Array, sid: String) -> bool:
	var url = DataManager.resolve_ai_agent_url("/ai/turn/{0}/estimate".format([sid]))
	var body = to_json({"answers": answers})
	DataManager.ai_debug_log("EST POST " + url + " body=" + body, true)
	_posting = true
	var ok = _http.post(url, body, self, "_on_estimates_posted", POLL_TIMEOUT_SEC)
	if not ok:
		_posting = false
	DataManager.ai_debug_log("EST POST ok=" + str(ok), true)
	return ok

func _on_estimates_posted(_result: int, _response_code: int, _body: PoolByteArray) -> void:
	DataManager.ai_debug_log("EST DONE result={0} code={1} body={2}".format([
		_result, _response_code, _body.get_string_from_utf8(),
	]), true)
	_posting = false
	# 无论成败都回到正常流程；服务端没收会重发查询
	FlowManager.add_flow("AI_before_ready")
	return

func _parse_json_object(body: PoolByteArray) -> Dictionary:
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY:
		return {}
	return reply

# 游戏内显示 LLM 的思考理由。
# 战争界面的顶部提示条会被 SceneManager._process_tips 立刻隐藏（只对 10000 场景生效），
# 所以进度/理由统一写到 scene_war 底部的黄色消息区，并保留最近几步。
# 调用时机是 behavior()（AI_ready 之后）。
func _show_reason(reasoning: String) -> void:
	DataManager.ai_debug_log("SHOW_REASON len={0} text={1}".format([reasoning.length(), reasoning]))
	if reasoning == "":
		return
	_agent_message(reasoning)
	return

func _show_progress(text: String) -> void:
	DataManager.ai_debug_log("PROGRESS " + text)
	var s = text.replace("\n", " ").strip_edges()
	if s == "":
		return
	# 只取第一句，避免把模型的长段落整段塞进消息区
	var dot = s.find("。")
	if dot > 0:
		s = s.substr(0, dot)
	_agent_message(s)
	return

# 新增：把文本交给战争场景的底部消息区（scene_war.show_agent_progress）
func _agent_message(text: String) -> void:
	var scene = SceneManager.current_scene()
	if scene != null and scene.has_method("show_agent_progress"):
		scene.show_agent_progress(text)
	return

func _clear_agent_message() -> void:
	var scene = SceneManager.current_scene()
	if scene != null and scene.has_method("clear_agent_progress"):
		scene.clear_agent_progress()
	return

func _show_tips() -> void:
	if _tips_shown:
		return
	_tips_shown = true
	# 首轮决策要等模型数秒，先在底部消息区给个反馈（顶部 tips 在战争场景会被立即隐藏）
	_agent_message("正在分析战况…")
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
	_clear_agent_message()
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
	# end 这类工具没有 actor 参数（它结束的是整个回合），此时沿用 AI_before_ready
	# 选定的当前行动武将；直接读 act["actor"] 会在这里报错中断，动作和回传都发不出去。
	var actorId = int(act["actor"]) if act.has("actor") else DataManager.get_env_int(VAR_CUR_ACTOR)
	DataManager.set_env(VAR_CUR_ACTOR, actorId)
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled or not wa.has_position():
		_pending.append({"seq": seq, "ok": false, "outcome": "演员不可行动"})
		_fallback("actor_unavailable")
		return
	var outcome = _describe(act)
	_actions_done += 1
	_pending.append({"seq": seq, "ok": true, "outcome": outcome})
	DataManager.ai_debug_log("ACTION exec seq={0} actor={1} {2} -> {3}".format([
		seq, actorId, str(act["tool"]), outcome,
	]), true)
	if not _execute(act, wa):
		# 执行失败：仍回传失败结果，然后回退
		_pending[_pending.size() - 1]["ok"] = false
		_pending[_pending.size() - 1]["outcome"] = "执行失败：" + outcome
		_fallback("exec_failed:" + str(act["tool"]))
		return
	# 移动的 outcome 用实际结果（走到哪、扣多少、为何停下），而不是计划描述
	if str(act["tool"]) == "move" and _last_move_outcome != "":
		_pending[_pending.size() - 1]["outcome"] = _last_move_outcome
	# move / end 在自己的实现里已经 add_flow；attack / stratagem / retreat 只是把
	# 目标写进环境，真正的结算由下一轮 AI_before_ready（bf.pending_start / 计策流程）接手。
	# 这里不补这一句，AI 回合会停在 AI_ready，动作结果永远回传不出去。
	var tool_name = str(act["tool"])
	if tool_name == "attack" or tool_name == "strategem" or tool_name == "retreat":
		FlowManager.add_flow("AI_before_ready")
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
	# 下面几处提前返回都必须驱动 flow：behavior() 执行完不会再补 add_flow，
	# 少了这一句整个 AI 回合会停在 AI_ready，动作结果永远回传不出去。
	if not wa.can_move():
		_last_move_outcome = "该武将现在无法移动"
		FlowManager.add_flow("AI_before_ready")
		return true
	if path.empty():
		_last_move_outcome = "路径为空，未移动"
		FlowManager.add_flow("AI_before_ready")
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
		# 模型有时会把起点也塞进 path（schema 要求不含起点）。重复点直接跳过，不当错误。
		if next == cur:
			continue
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
		if stop_reason == "":
			stop_reason = "路径没有可走的格子（可能全是重复点）"
		_last_move_outcome = "未移动（%s）；原因：%s" % [str(start), stop_reason]
		FlowManager.add_flow("AI_before_ready")
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
	_clear_agent_message()
	DataManager.game_trace("[AI] turn end")
	DataManager.ai_debug_log("TURN END")
	return

# wab 接口：每帧调用。复用父类实现处理对话确认等