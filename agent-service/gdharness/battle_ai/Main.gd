# 白兵战契约 harness：真实 BattleAgent 跑在假引擎上，按 K3G_BATTLE_SCENARIO 打印可断言标记。
extends Node

const TIMEOUT_MS := 20000
# fallback 场景打印 BATTLE_LOCAL 后先留一会儿，让测试确认「回退后不再发请求」。
const FALLBACK_LINGER_MS := 1200
# 故意用短路径：GlobalStub 按传入路径缓存，与真实 Global.load_script 同款。
const AGENT_SCRIPT := "BattleAgent.gd"

var _agent = null
var _bf = null
var _scenario = "orders"
var _done := false
var _printed_open := false
var _printed_orders := false
var _printed_tick := 0
var _printed_count := 0
var _printed_paused := false
var _last_plan_json := ""
var _local_at := -1
var _started_ms := 0

func _ready():
	_started_ms = OS.get_ticks_msec()
	_scenario = OS.get_environment("K3G_BATTLE_SCENARIO")
	if _scenario == "":
		_scenario = "orders"
	match _scenario:
		"tactic", "tactic_applied", "flow_busy":
			StaticManager.TACTICS = {"强弩": {"消耗": 7}}
			DataManager.env["白兵战-当前步骤"] = 4
		"queue_ttl":
			# 步骤 2 不是用计安全点：计策会一直排队，直到 TTL 到期被拒。
			StaticManager.TACTICS = {"强弩": {"消耗": 7}}
			DataManager.env["白兵战-当前步骤"] = 2
		"paused":
			SceneManager.current_scene().battle_state.visible = true
	# flow_busy：引擎里已有流程占着，入队必须被挡在 add_flow 之前。
	# tactic_applied：add_flow 模拟引擎副作用，验证「施计后核对」能判成 applied。
	if _scenario == "flow_busy":
		FlowManager.busy = true
	elif _scenario == "tactic_applied":
		FlowManager.apply_tactic = true

	var BF = load("res://stubs/FakeBattleFight.gd")
	var WA = load("res://stubs/FakeWarActor.gd")
	var Info = load("res://stubs/FakeActorInfo.gd")
	var BU = load("res://stubs/FakeBattleUnit.gd")

	_bf = BF.new()
	var mine = WA.new(); mine.actorId = 12; mine._info = Info.new()
	var foe = WA.new(); foe.actorId = 31; foe._info = Info.new(); foe._enemy = mine
	mine._enemy = foe
	DataManager.war_actor = mine
	DataManager.war_actor_enemy = foe
	DataManager.battle = _bf
	DataManager.battle_run = true
	Global.iTactic = load("res://stubs/ITacticStub.gd").new()

	DataManager.battle_units = []
	var specs = [
		{"id": 12, "type": "将", "pos": Vector2(6, 5), "hp": 90, "shoot": 0},
		{"id": 12, "type": "骑", "pos": Vector2(8, 5), "hp": 80, "shoot": 0},
		{"id": 12, "type": "弓", "pos": Vector2(8, 3), "hp": 60, "shoot": 4},
		{"id": 12, "type": "步", "pos": Vector2(7, 4), "hp": 70, "shoot": 0},
		{"id": 31, "type": "将", "pos": Vector2(12, 5), "hp": 88, "shoot": 0},
		{"id": 31, "type": "弓", "pos": Vector2(11, 4), "hp": 50, "shoot": 4},
	]
	for s in specs:
		var bu = BU.new()
		bu.leaderId = int(s["id"])
		bu.unit_position = s["pos"]
		bu._type = str(s["type"])
		bu._hp = int(s["hp"])
		bu._shoot = int(s["shoot"])
		DataManager.battle_units.append(bu)
	if _scenario == "no_units":
		# 布阵完成前 battle_units 为空：Agent 不应开会话、不应发快照。
		DataManager.battle_units = []

	if _scenario == "normalize":
		# 引擎真实会给出包围/战术这类快照契约外的命令，这里固定一组越界值。
		_bf._states = {"将": "包围", "骑": "未知", "弓": "待机", "步": "前进"}

	# 允许测试通过环境变量指定服务地址，验证尾斜杠规范化
	var env_url = OS.get_environment("K3G_AI_URL")
	if env_url != "":
		DataManager.ai_agent_base_url = env_url
	print("BATTLE_BASE=", DataManager.resolve_ai_agent_url("/ai/battle"))

	var proj = load("res://BattleProjection.gd").new()
	print("BATTLE_PAYLOAD=", to_json(proj.build(_bf, 12, 1, null, 0)))
	if _scenario == "normalize":
		_finish()
		return

	_agent = Global.load_script(AGENT_SCRIPT)
	_agent.attach(_bf)
	if _scenario == "reinit":
		# 真实 Global.load_script 命中缓存会对同一实例再调 _init()。
		# 这里同时打出「是否同一实例」与「attach 的 actor 是否还在」，以实测为准。
		var again = Global.load_script(AGENT_SCRIPT)
		print("BATTLE_REINIT_SAME=", again == _agent)
		print("BATTLE_REINIT_ACTOR=", again.get_actor_id())
		_finish()
		return
	if _scenario == "paused":
		print("BATTLE_INTERVAL=", _agent._interval())
	_agent.tick()
	return

func _process(_delta):
	if _done:
		return
	if OS.get_ticks_msec() - _started_ms > TIMEOUT_MS:
		print("BATTLE_RESULT=timeout")
		_finish()
		return
	if _agent == null:
		return
	_agent.tick()
	if not _printed_open and _agent.get_session_id() != "":
		_printed_open = true
		print("BATTLE_OPEN=True")
	_track_tick()
	if _scenario == "paused":
		_track_paused()
		return
	if _scenario == "queue_ttl":
		# 只等排队超时，不看 orders（否则第一拍就退出）。
		_track_last_plan()
		return
	if _scenario == "fallback_410" or _scenario == "fallback_422":
		_track_fallback()
		return
	if _scenario == "no_units":
		if OS.get_ticks_msec() - _started_ms >= 3000:
			print("BATTLE_NO_OPEN=", _agent.get_session_id() == "")
			_finish()
		return
	if _bf.order_calls.size() > 0 and not _printed_orders:
		_printed_orders = true
		print("BATTLE_ORDER_CALLS=", to_json(_bf.order_calls))
	match _scenario:
		"orders":
			# 等到第二拍回包落地再退：差分成立（不再 set_unit_state）时落子数应停在 4。
			if _agent._tick >= 2 and not _agent.is_busy():
				_finish()
		"tactic":
			if FlowManager.flows.has("before_AI_tactic"):
				print("BATTLE_TACTIC_FLOW=before_AI_tactic")
				_finish()
		"tactic_applied":
			if _tactic_status() == "applied":
				print("BATTLE_TACTIC_APPLIED=applied")
				_finish()
		"flow_busy":
			if _agent._tactic_queue != null:
				print("BATTLE_FLOWS=", to_json(FlowManager.flows))
				print("BATTLE_FLOW_BUSY=queued")
				_finish()
	return

# 拍号变化时带上落子数；落子数后来变了（回包落地）也补打一次，便于断言差分。
func _track_tick():
	var count = _bf.order_calls.size()
	if int(_agent._tick) != _printed_tick:
		_printed_tick = int(_agent._tick)
		print("BATTLE_TICK=", _printed_tick)
		print("BATTLE_ORDER_COUNT=", count)
	elif count != _printed_count:
		print("BATTLE_ORDER_COUNT=", count)
	_printed_count = count
	return

# 暂停时第一拍落地后，剩余到下一拍的时长应≈PAUSED_TICK_INTERVAL_MS。
func _track_paused():
	if _printed_paused or _agent._tick < 1:
		return
	var left = int(_agent._next_tick_at) - OS.get_ticks_msec()
	if left <= 0:
		return
	_printed_paused = true
	print("BATTLE_NEXT_DELAY=", left)
	_finish()
	return

func _tactic_status() -> String:
	if _agent._last_plan == null:
		return ""
	return str(_agent._last_plan.get("tactic_status", ""))

# 用计排队超时：_last_plan 在到期那一帧被就地改写，逐帧比对即可第一时间看到。
func _track_last_plan():
	var plan = _agent._last_plan
	if plan == null:
		return
	var txt = to_json(plan)
	if txt == _last_plan_json:
		return
	_last_plan_json = txt
	print("BATTLE_LAST_PLAN=", txt)
	if str(plan.get("reason", "")).find("用计排队超时") >= 0:
		_finish()
	return

func _track_fallback():
	if not _agent.is_local():
		return
	if _local_at < 0:
		_local_at = OS.get_ticks_msec()
		print("BATTLE_LOCAL=True")
		return
	if OS.get_ticks_msec() - _local_at >= FALLBACK_LINGER_MS:
		_finish()
	return

func _finish():
	_done = true
	get_tree().quit()
	return
