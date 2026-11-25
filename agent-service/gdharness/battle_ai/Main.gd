# 白兵战契约 harness：真实 BattleAgent 跑在假引擎上，按 K3G_BATTLE_SCENARIO 打印可断言标记。
extends Node

const TIMEOUT_MS := 20000
# fallback 场景打印 BATTLE_LOCAL 后先留一会儿，让测试确认「回退后不再发请求」。
const FALLBACK_LINGER_MS := 1200

var _agent = null
var _bf = null
var _scenario = "orders"
var _done = false
var _printed_open = false
var _printed_orders = false
var _last_plan_json = ""
var _local_at = -1
var _started_ms = 0

func _ready():
	_started_ms = OS.get_ticks_msec()
	_scenario = OS.get_environment("K3G_BATTLE_SCENARIO")
	if _scenario == "":
		_scenario = "orders"
	if _scenario == "tactic":
		StaticManager.TACTICS = {"强弩": {"消耗": 7}}
		DataManager.env["白兵战-当前步骤"] = 4
	elif _scenario == "queue_ttl":
		StaticManager.TACTICS = {"强弩": {"消耗": 7}}
		# 步骤 2 不是用计安全点：计策会一直排队，直到 TTL 到期被拒。
		DataManager.env["白兵战-当前步骤"] = 2
	elif _scenario == "paused":
		SceneManager.current_scene().battle_state.visible = true

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

	# 允许测试通过环境变量指定服务地址，验证尾斜杠规范化
	var env_url = OS.get_environment("K3G_AI_URL")
	if env_url != "":
		DataManager.ai_agent_base_url = env_url
	print("BATTLE_BASE=", DataManager.resolve_ai_agent_url("/ai/battle"))

	var proj = load("res://BattleProjection.gd").new()
	print("BATTLE_PAYLOAD=", to_json(proj.build(_bf, 12, 1, null, 0)))

	_agent = load("res://BattleAgent.gd").new()
	_agent.attach(_bf)
	if _scenario == "paused":
		print("BATTLE_INTERVAL=", _agent._interval())
		_finish()
		return
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
	if _scenario == "queue_ttl":
		# 只等排队超时，不看 orders（否则第一拍就退出）。
		_track_last_plan()
		return
	if _scenario == "fallback_410" or _scenario == "fallback_422":
		_track_fallback()
		return
	if _bf.order_calls.size() > 0 and not _printed_orders:
		_printed_orders = true
		print("BATTLE_ORDER_CALLS=", to_json(_bf.order_calls))
	if _scenario == "tactic":
		if FlowManager.flows.has("before_AI_tactic"):
			print("BATTLE_TACTIC_FLOW=before_AI_tactic")
			_finish()
	elif _printed_orders:
		_finish()
	return

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
