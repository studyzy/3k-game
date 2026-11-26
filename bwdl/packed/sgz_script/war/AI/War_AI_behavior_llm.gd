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
# 本次会话 AI 控制的 vstate id（投影时记录，用于区分敌我以选对机动力口径）
var _controlled_wv_id: int = -1

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
	# 记录受控阵营：estimate_move 用它区分「我方看剩余机动力 / 敌方看下轮刷新值」
	if wv != null:
		_controlled_wv_id = int(wv.id)
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
	# 用计结算摘要在执行时就已算好（那时结算记录还在），这里只负责原样带出去
	var extra = {}
	for key in ["stratagem", "battle"]:
		if item.has(key):
			if key == "stratagem":
				extra["stratagem"] = item[key]
			else:
				extra["battle"] = item[key]
	var result_payload = _projector.build_tool_result(wv, item["ok"], item["outcome"], extra)
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
		var kind = str(q.get("kind", "estimate_stratagem"))
		var summary = "预估失败"
		if kind == "estimate_stratagem":
			# 只回传「中计概率 + 中计后的结果」这段文字，逐目标的原始明细模型读不懂也用不上
			summary = _estimate_summary(
				int(q.get("actor", - 1)), int(q.get("target", - 1)), str(q.get("skill", ""))
			)
		elif kind == "estimate_move":
			summary = _estimate_move_summary(int(q.get("actor", - 1)), q.get("to", []), bool(q.get("free", false)))
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

# 行军预估的文字结论（给模型看）：逐目标一行，写「够不够机动力、几格、耗多少机、路径怎么走」。
# 用引擎 A*（权重就是每格的机动力消耗）算最短路线，按 War_Actor.can_move_to_position 判阻挡，
# 与玩家点着走时能到的地方完全一致。to 里每个点单独算，不互相影响。
# 该武将是否属于本次 AI 控制的阵营。
# 会话投影的 controlled_id 就是 AI 方 War_Vstate 的 id；这里用同样的口径：
# 与「最近一次投影的受控阵容」比较。_controlled_ids 由 _ensure_helpers 记录。
func _is_self_side(wa: War_Actor) -> bool:
	if wa == null or _controlled_wv_id < 0:
		return false
	return int(wa.wvId) == _controlled_wv_id

# free=true：只算「理论上几天能到」，忽略其他武将（队友+敌军）的阻挡。
# 判敌情 / 判主攻门用这个口径——远处敌将此刻被自己人挡着，不代表它后天到不了。
func _estimate_move_summary(actorId: int, to, free: bool = false) -> String:
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled:
		return "预估失败"
	if typeof(to) != TYPE_ARRAY or to.empty():
		return "预估失败"
	var map = SceneManager.current_scene().war_map
	map.aStar.update_map_for_actor(wa)
	# 预算按「下一天刷新的机动力」算，不用当前剩余 action_point：
	# 侦察敌将时它当天的机动力通常已经用光，拿剩余值算会把敌人误判成走不动。
	# 机动力每天重置回上限（第一节），所以上限就是它下一轮能用的量；
	# 查询的是我自己时才用剩余 action_point（当天还剩多少）。
	# 我方 = 当前 AI 控制的那个 War_Vstate（_projector 持同一份投影口径）
	var is_self = _is_self_side(wa)
	var total_ap = int(wa.get_max_action_ap()) if not is_self else int(wa.action_point)
	var ap_label = "下轮可动" if not is_self else "剩"
	var name_text = wa.get_name()
	var lines = []
	if free:
		# 估价不看谁挡路，只算地形消耗；查完立刻恢复
		map.aStar.enable_brothers()
		map.aStar.enable_enemies()
	# 敌人按「下轮可动」估几天到门，这就是判主攻门的全部依据，所以敌情查询只回这一行结论。
	var per_day = max(1, total_ap) if not is_self else max(1, int(wa.get_max_action_ap()))
	var results = []
	for raw in to:
		if typeof(raw) != TYPE_ARRAY or raw.size() < 2:
			continue
		var target = Vector2(int(raw[0]), int(raw[1]))
		var head = name_text + " → [" + str(int(target.x)) + "," + str(int(target.y)) + "] "
		if not map.is_valid_position(target):
			lines.append(head + "地图外")
			continue
		if map.get_blockCN_by_position(target) == "不可进入":
			lines.append(head + "不可站（地图外或不可进入格）")
			continue
		# 只看地形能不能站，谁占着这一格不影响估价结果（估价的是"走到这里要花多少机／怎么走"）
		var occupier = DataManager.get_war_actor_by_position(target, [actorId])
		if occupier != null and not occupier.disabled and not free:
			lines.append(head + "站着 " + occupier.get_name() + "，本回合不能走到这一格（路线按绕过它算）")
		var route = map.aStar.get_path(wa.position, target)
		if route.empty():
			lines.append(head + "无路可达")
			continue
		# route 含起点：去掉起点后逐格累加机动力（只读估价，不改战场状态）
		var steps = route.size() - 1
		var ap = 0
		for i in range(1, route.size()):
			ap += _estimate_step_ap(wa, route[i])
		var text = head + str(steps) + " 格，" + str(ap) + " 机（" + ap_label + " " + str(total_ap) + " 机"
		if ap <= total_ap:
			text += "，1 天到）"
		else:
			text += "，约 " + str(int(ceil(float(ap) / float(per_day)))) + " 天到）"
		results.append({"ap": ap, "text": text})
	if free:
		map.aStar.disable_brothers()
		map.aStar.disable_enemies()
	if results.empty():
		if lines.empty():
			return "预估失败"
		return PoolStringArray(lines).join("\n")
	# 批量敌情查询（free）只回「最便宜的那个目标」：模型要的是"它最可能打哪个门、几天到"，
	# 把每个目标各一行会一次吐出几十行，真正有用的只有最小值那行。
	if free:
		var best = results[0]
		for r in results:
			if int(r["ap"]) < int(best["ap"]):
				best = r
		lines.append(best["text"])
	else:
		for r in results:
			lines.append(r["text"])
	return PoolStringArray(lines).join("\n")

# 单格行军的机动力估价（只读）。
# 不调 DataManager.get_move_cost：那个会写 env 并触发 20007，打乱当前状态。
# 口径与它一致：地形表[地形][军种][兵力档]，装备「X军移动」取较低值，迟滞 +2、潜行 -1（最低 1）。
func _estimate_step_ap(wa: War_Actor, pos: Vector2) -> int:
	var troopsType = wa.actor().get_troops_type()
	if troopsType == "仙":
		return 0
	var setting = StaticManager.get_move_ap_setting()
	var terrain = SceneManager.current_scene().war_map.get_blockCN_by_position(pos)
	if not setting.has(terrain):
		terrain = "平原"
	var b_index = 1 if wa.actor().get_soldiers() <= 500 else 0
	var costAP = int(setting[terrain][troopsType][b_index])
	for expectedType in ["平", "山", "水"]:
		if troopsType != expectedType and wa.actor().get_equip_feature_max(expectedType + "军移动") > 0:
			costAP = min(costAP, int(setting[terrain][expectedType][b_index]))
	if wa.get_buff_label_turn(["迟滞"]) > 0:
		costAP += 2
	if wa.get_buff_label_turn(["潜行"]) > 0:
		costAP = max(1, costAP - 1)
	return costAP

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
	# 逐格移动走完后要用它回传结果；behavior 只有 wvId，这里取回 War_Vstate 对象
	var wf_now = DataManager.get_current_war_fight()
	_walk_wv = wf_now.get_war_vstate(wvId) if wf_now != null else null
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
	# 逐格移动是异步的（每格停 STEP_DELAY_SEC）：此刻还没走完，_last_move_outcome 是空的。
	# 这时回传会把 outcome 留成「移动到[]」，服务端就以为已经走完了。
	# 所以逐格移动只记下 wv，等 _walk_finish() 走完再回传。
	if not _walk_plan.empty():
		_walk_pending_wv = _walk_wv
		return
	# 移动的 outcome 用实际结果（走到哪、扣多少、为何停下），而不是计划描述
	if str(act["tool"]) == "move" and _last_move_outcome != "":
		_pending[_pending.size() - 1]["outcome"] = _last_move_outcome
	# 用计：把结算明细整理成「是否成功 + 每个受影响武将的变化」，随结果一起回传。
	# 结算（perform_to_targets）就是在上面的 _execute 里同步跑完的，这里直接读它留下的记录。
	if str(act["tool"]) == "stratagem":
		_pending[_pending.size() - 1]["stratagem"] = _stratagem_result(wa, act)
	# 攻击同理：白兵战结算后 bf 里留着双方战损与胜负，整理成同一套 effects 结构
	if str(act["tool"]) == "attack":
		var atk = _attack_result(wa, act)
		if not atk.empty():
			_pending[_pending.size() - 1]["battle"] = atk
	# move / end 在自己的实现里已经 add_flow；attack / stratagem / retreat 只是把
	# 目标写进环境，真正的结算由下一轮 AI_before_ready（bf.pending_start / 计策流程）接手。
	# 这里不补这一句，AI 回合会停在 AI_ready，动作结果永远回传不出去。
	var tool_name = str(act["tool"])
	if tool_name == "attack" or tool_name == "strategem" or tool_name == "retreat":
		FlowManager.add_flow("AI_before_ready")
	return

# 用计结算摘要：返回 {ok, name, caster, effects:[{id, name, note, soldiers, hp, status}, ...]}。
# effects 只列真正被改变的武将；soldiers/hp/status 是结算后的当前值。
func _stratagem_result(wa, act: Dictionary) -> Dictionary:
	var ret = {"ok": false, "name": str(act.get("skill", "")), "caster": wa.get_name(), "effects": []}
	var se = DataManager.get_current_stratagem_execution()
	if se == null or se.results == null or se.results.empty():
		return ret
	if se.results.has("失败"):
		return ret
	ret["ok"] = true
	# results 的键 → 画面上给玩家看的中文标签
	var labels = {
		"伤兵量": "兵力下降", "兵力流失": "兵力流失", "伤体量": "体力下降",
		"扣米量": "军米减少", "反伤": "受到反伤", "免伤": "免伤",
		"状态": "获得状态", "战术状态": "战术状态",
	}
	var by_target = {}
	var order = []
	for key in se.results.keys():
		if key == "失败":
			continue
		for row in se.results[key]:
			var targetId = int(row[2])
			if targetId <= 0:
				continue
			if not by_target.has(targetId):
				by_target[targetId] = {}
				order.append(targetId)
			var note = labels.get(key, str(key))
			var num = int(row[1])
			# 伤兵等按数值给变化量；状态类是文字（row[1] 是 0）
			if num != 0:
				note += str(abs(num))
			elif str(row[0]) != "":
				note = str(row[0])
			if not by_target[targetId].has(note):
				by_target[targetId][note] = true
	for targetId in order:
		var twa = DataManager.get_war_actor(targetId)
		if twa == null:
			continue
		var snap = _unit_snapshot(targetId)
		ret["effects"].append({
			"id": targetId,
			"name": twa.get_name(),
			"note": "、".join(PoolStringArray(by_target[targetId].keys())),
			"soldiers": int(snap.get("soldiers", 0)),
			"hp": int(snap.get("hp", 0)),
			"status": snap.get("status", []),
		})
	return ret

# 查询某个武将此刻的兵力/体力/状态，用回传时刻的最新值（计策结算可能延后落地）。
func _unit_snapshot(actorId: int) -> Dictionary:
	var twa = DataManager.get_war_actor(actorId)
	if twa == null:
		return {}
	var statuses = []
	for buff in StaticManager.WAR_BUFF_STATUSES:
		var turn = twa.get_buff(buff)["回合数"]
		if turn > 0:
			statuses.append("{0}:{1}".format([buff, min(99, turn)]))
	return {
		"soldiers": int(twa.get_soldiers()),
		"hp": int(twa.actor().get_hp()),
		"status": statuses,
	}

# 攻击（白兵战）摘要：{ok, attacker, defender, effects:[...]}。
# 战损取 bf 记录的结算值（attackerRemaining/defenderRemaining），
# 当前值用回传时刻的快照，避免读到结算过程中的中间态。
func _attack_result(wa, act: Dictionary) -> Dictionary:
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return {}
	var targetId = int(act.get("target", -1))
	# status<=1 表示这场白兵战还没打完（remaining 仍是初值 9999），只报「已发起」
	if bf.status <= 1:
		var snap0 = _unit_snapshot(wa.actorId)
		return {"ok": true, "name": "白兵战", "caster": wa.get_name(), "loser": "", "effects": [{
			"id": wa.actorId, "name": wa.get_name(), "note": "发起白兵战",
			"soldiers": int(snap0.get("soldiers", 0)), "hp": int(snap0.get("hp", 0)),
			"status": snap0.get("status", []),
		}]}
	var effects = []
	for pair in [
		[bf.get_attacker_id(), bf.attackerSoldiers, bf.attackerRemaining],
		[bf.get_defender_id(), bf.defenderSoldiers, bf.defenderRemaining],
	]:
		var aid = int(pair[0])
		var before = int(pair[1])
		var after = int(pair[2])
		if aid <= 0:
			continue
		var snap = _unit_snapshot(aid)
		if snap.empty():
			continue
		var note = ""
		if before > after:
			note = "战损兵力" + str(before - after)
		else:
			note = "兵力未损"
		effects.append({
			"id": aid,
			"name": str(snap.get("name", "")),
			"note": note,
			"soldiers": int(snap["soldiers"]),
			"hp": int(snap["hp"]),
			"status": snap["status"],
		})
	# 名字在 snapshot 里没有，补一次
	for e in effects:
		var twa = DataManager.get_war_actor(int(e["id"]))
		e["name"] = twa.get_name() if twa != null else str(e["id"])
	var ret = {
		"ok": true,
		"name": "白兵战",
		"caster": wa.get_name(),
		"effects": effects,
		"loser": "",
	}
	if bf.loserId >= 0:
		var lwa = DataManager.get_war_actor(int(bf.loserId))
		ret["loser"] = lwa.get_name() if lwa != null else str(bf.loserId)
	return ret

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

	# 逐格走：每走一格就刷新画面，再等 STEP_DELAY_SEC 秒走下一格，
	# 让玩家能看清 AI 的每一步（之前是一次性算完再统一重绘，画面只看到瞬移）。
	_walk_plan = {
		"wa": wa, "path": path, "cur": start, "start": start,
		"total": {"机": 0, "点": 0}, "walked": 0, "stop_reason": "",
	}
	_walk_tick()
	return true

# 单步停顿秒数（逐格动画用）。调大更慢，调小更快。
const STEP_DELAY_SEC = 0.5

var _walk_plan: Dictionary = {}
# 逐格移动期间暂存的 War_Vstate：走完要用它把最新状态投影成 tool result 回传
# behavior(wvId) 只有 wvId，这里用 wf.get_war_vstate(wvId) 取回对象
var _walk_pending_wv = null
var _walk_wv = null

# 走一格：能走就落格并刷新；不能走就记下停因准备收尾。
# 每格之间用 SceneTreeTimer 延时，保证画面真的停一下。
func _walk_tick() -> void:
	if _walk_plan.empty():
		return
	var wa = _walk_plan["wa"]
	var path: Array = _walk_plan["path"]
	var cur: Vector2 = _walk_plan["cur"]
	var map = SceneManager.current_scene().war_map
	var next = _next_step(wa, cur, path, _walk_plan)
	# next 为 null 表示路径走完；为字典 {"stop": ...} 表示卡住，两者都要收尾
	if next == null or typeof(next) == TYPE_DICTIONARY:
		if typeof(next) == TYPE_DICTIONARY:
			_walk_plan["stop_reason"] = str(next["stop"])
		_walk_finish()
		return
	var step_cost = DataManager.get_move_cost(wa.actorId, next)
	wa.action_point = max(0, int(wa.action_point - int(step_cost["机"])))
	wa.poker_point = max(0, int(wa.poker_point - int(step_cost["点"])))
	var total: Dictionary = _walk_plan["total"]
	total["机"] = int(total["机"]) + int(step_cost["机"])
	total["点"] = int(total["点"]) + int(step_cost["点"])
	wa.position = next
	_walk_plan["cur"] = next
	_walk_plan["walked"] = int(_walk_plan["walked"]) + 1
	# 立刻重绘一格，然后停一下再继续
	map.draw_actors()
	map.update_ap()
	map.fix_cursor_camer()
	var timer = SceneManager.current_scene().get_tree().create_timer(STEP_DELAY_SEC)
	timer.connect("timeout", self, "_walk_tick")
	return

# 取下一格：返回 Vector2（可以走），null（路径已走完），{"stop": 原因}（卡住）。
func _next_step(wa, cur: Vector2, path: Array, plan: Dictionary):
	var map = SceneManager.current_scene().war_map
	var walked = int(plan["walked"])
	var idx = int(plan["step_idx"]) if plan.has("step_idx") else 0
	while idx < path.size():
		var point = path[idx]
		idx += 1
		plan["step_idx"] = idx
		if typeof(point) != TYPE_ARRAY or point.size() != 2:
			return {"stop": "路径里有非法坐标"}
		var next = Vector2(int(point[0]), int(point[1]))
		# 模型有时会把起点也塞进 path（schema 要求不含起点）。重复点直接跳过，不当错误。
		if next == cur:
			continue
		var d = next - cur
		if abs(d.x) + abs(d.y) != 1:
			return {"stop": "第{0}步 {1} 与当前格 {2} 不相邻（只能上下左右一格）".format([walked + 1, str(next), str(cur)])}
		if not map.is_valid_position(next):
			return {"stop": "第{0}步 {1} 超出地图边界".format([walked + 1, str(next)])}
		if not wa.can_move_to_position(next):
			return {"stop": "第{0}步 {1} 无法进入（有武将或地形阻挡）".format([walked + 1, str(next)])}
		var step_cost = DataManager.get_move_cost(wa.actorId, next)
		if step_cost["机"] > wa.action_point or step_cost["点"] > wa.poker_point:
			return {"stop": "第{0}步 {1} 机动力不足（需要 {2}，剩余 {3}）".format([
				walked + 1, str(next), int(step_cost["机"]), int(wa.action_point)
			])}
		return next
	return null

# 走完（或被挡住）：写回结果、收尾，再驱动 flow。
func _walk_finish() -> void:
	var plan = _walk_plan
	_walk_plan = {}
	var wa = plan["wa"]
	var start: Vector2 = plan["start"]
	var cur: Vector2 = plan["cur"]
	var total: Dictionary = plan["total"]
	var walked = int(plan["walked"])
	var stop_reason = str(plan["stop_reason"])
	var path: Array = plan["path"]
	var map = SceneManager.current_scene().war_map
	var reached = "%s→%s" % [str(start), str(cur)]
	if walked == 0:
		if stop_reason == "":
			stop_reason = "路径没有可走的格子（可能全是重复点）"
		_last_move_outcome = "未移动（%s）；原因：%s" % [str(start), stop_reason]
		_walk_flush_result()
		FlowManager.add_flow("AI_before_ready")
		return
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
	_walk_flush_result()
	if SkillHelper.auto_trigger_skill(wa.actorId, 20003, "AI_before_ready"):
		return
	if wa.after_move():
		return
	FlowManager.add_flow("AI_before_ready")
	return

# 逐格移动走完后，用真实 outcome 替掉 _pending 里的计划描述，并立刻回传服务端。
# 不走 _flush_results(wv) 的原因：此时拿不到 wv；_walk_pending_wv 是 behavior() 暂存的同一对象。
func _walk_flush_result() -> void:
	if _pending.empty():
		return
	_pending[_pending.size() - 1]["outcome"] = _last_move_outcome
	var wv = _walk_pending_wv
	_walk_pending_wv = null
	if wv == null:
		return
	_flush_results(wv)
	return



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