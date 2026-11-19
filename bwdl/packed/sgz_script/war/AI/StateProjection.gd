# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：packed/sgz_script/war/AI/StateProjection.gd
# 说明：全知（不做视野裁剪）但去引擎噪声的状态投影，并生成 legal_actions。
#       依据设计文档 §3.5 / 附录 B。只投影 war/ 战争层状态，
#       不发送白兵战 / 内政 / 单挑状态。
#
# 地形投影：[[x, y, "地形名"], ...]，只列非平原格（平原是默认值，不列出）。
#   米屋 / 装备店 / 医馆 / 太守府 等地形名同样出现在这里，所以店面坐标不需要额外字段。
#   地图在一场战斗内不会变化，因此只在开场请求里下发一次，
#   动作执行后的 tool result 不再携带地形。
# ==============================================================================
extends Resource

const MOVE_RADIUS: int = 6
const MAX_MOVE_CANDIDATES: int = 24
const CELL_COLUMNS: int = 32
const CELL_ROWS: int = 19
# 平原是默认地形：不列出，未出现的格子一律按平原理解
const DEFAULT_BLOCK: String = "平原"

var _seq: int = 0

func _init() -> void:
	_seq = 0
	return

func _next_id(prefix: String) -> String:
	_seq += 1
	return "{0}{1}".format([prefix, _seq])

# 动作执行后重新投影工具结果（服务端驱动逐步交互的 D1/D2）：
# Godot 负责计算执行后的真实状态，沙盒返回给服务端喂回 LLM。
# 返回 {"ok", "outcome", "units", "legal_actions", "economy"}
# 地形不随战斗变化，这里不重复下发（开场请求已给过全量）。
func build_tool_result(wv, ok: bool, outcome: String) -> Dictionary:
	var fresh = build(wv)
	if fresh.empty():
		return {"ok": ok, "outcome": outcome, "units": [], "legal_actions": []}
	return {
		"ok": ok,
		"outcome": outcome,
		"units": fresh["units"],
		"legal_actions": fresh["legal_actions"],
		"economy": fresh["economy"],
	}

# 生成 /ai/turn 请求体。wv 为当前 AI 方 War_Vstate。
func build(wv) -> Dictionary:
	var wf = DataManager.get_current_war_fight()
	if wf == null or wv == null:
		return {}
	var map = SceneManager.current_scene().war_map
	_seq = 0
	var units = []
	var legal = []
	var controlled_id = wv.id

	for wa in wf.get_war_actors(false, true):
		if wa == null:
			continue
		var actor = wa.actor()
		var unit = {
			"id": wa.actorId,
			"vstate": wa.wvId,
			"pos": [int(wa.position.x), int(wa.position.y)],
			"ap": wa.action_point,
			"poker": wa.poker_point,
			"soldiers": wa.get_soldiers(),
			"hp": actor.get_hp() if actor != null else 0,
			"power": actor.get_power() if actor != null else 0,
			"wisdom": actor.get_wisdom() if actor != null else 0,
			"disabled": wa.disabled,
		}
		units.append(unit)
		if wa.wvId != controlled_id or wa.disabled or not wa.has_position():
			continue
		_append_move_actions(legal, wa, map)
		_append_attack_actions(legal, wa, wf)
		_append_stratagem_actions(legal, wa)
		_append_retreat_action(legal, wa)
		legal.append({
			"id": _next_id("e"), "tool": "end", "actor": wa.actorId, "cost": {},
		})

	# 兜底：至少给一个 end，避免 legal_actions 为空
	if legal.empty():
		legal.append({"id": "e0", "tool": "end", "actor": _controlled_leader_id(wv), "cost": {}})

	var main_city = map.get_position_by_buildCN("太守府")
	var economy = {
		"rice": wv.rice,
		"money": wv.money,
		"day": wf.date,
		"max_days": 30,
		"attacker_vstate": controlled_id,
		"main_city_pos": [int(main_city.x), int(main_city.y)],
	}

	return {
		"state_version": 1,
		"visibility": "omniscient",
		"static_bundle_id": "v1",
		"turn_key": "w{0}-d{1}-s{2}".format([wv.id, wf.date, DataManager.war_control_sort_no]),
		"controlled_vstate_id": controlled_id,
		"diffculities": DataManager.diffculities,
		# 修改：AI Agent 接入——标识本次请求来自「大模型」难度，便于服务端审计
		"ai_agent_mode": DataManager.ai_agent_mode,
		"session_id": "sgz-{0}".format([wv.id]),
		"units": units,
		"terrain": _build_terrain(units, map),
		"economy": economy,
		"legal_actions": legal,
		"memory": {},
		"budget": {},
	}

func _controlled_leader_id(wv) -> int:
	if wv == null:
		return -1
	return wv.main_actorId

func _append_move_actions(legal: Array, wa, map) -> void:
	var count = 0
	var origin = wa.position
	for dx in range(-MOVE_RADIUS, MOVE_RADIUS + 1):
		for dy in range(-MOVE_RADIUS, MOVE_RADIUS + 1):
			if dx == 0 and dy == 0:
				continue
			if abs(dx) + abs(dy) > MOVE_RADIUS:
				continue
			var pos = Vector2(origin.x + dx, origin.y + dy)
			if not map.is_valid_position(pos):
				continue
			if not wa.can_move_to_position(pos):
				continue
			var cost = DataManager.get_move_cost(wa.actorId, pos)
			if cost["机"] > wa.action_point or cost["点"] > wa.poker_point:
				continue
			# 路径必须逐格合法（只走上下左右，不能斜穿或飞越障碍）。
			# 与 War_AI_behavior_new.gd:287 的 AI 常规移动一致：aStar 给出完整路径。
			var path = _path_stepwise(wa, map, origin, pos)
			if path.empty():
				continue
			legal.append({
				"id": _next_id("m"), "tool": "move", "actor": wa.actorId,
				"pos": [int(pos.x), int(pos.y)],
				# 不含起点，路径的每一格都是合法的一步
				"path": path,
				"cost": {"ap": cost["机"], "poker": cost["点"]},
			})
			count += 1
			if count >= MAX_MOVE_CANDIDATES:
				return
	return

# 返回从 origin 到 target 的逐格路径（不含 origin，含 target）。
# 只接受 4 邻域单步，确保没有斜向移动；任一步不合法则整条路径作废。
func _path_stepwise(wa, map, origin: Vector2, target: Vector2) -> Array:
	var route = map.aStar.get_path(origin, target)
	if route.size() < 2:
		return []
	var out = []
	var prev = origin
	for i in range(1, route.size()):
		var step = route[i]
		var d = step - prev
		# 必须恰好是上下左右中的一步
		if abs(d.x) + abs(d.y) != 1:
			return []
		if not map.is_valid_position(step):
			return []
		if step != target and not wa.can_move_to_position(step):
			return []
		out.append([int(step.x), int(step.y)])
		prev = step
	if prev != target:
		return []
	return out

# 不调用 IWar_Attack.get_can_attack_actors（会触发技能 20030 等副作用），
# 只按攻击距离粗筛；最终合法性由 War_AI_behavior.gd:_attack 再次判定。
func _append_attack_actions(legal: Array, wa, wf) -> void:
	var max_dist = wa.get_attack_distance()
	for enemy in wf.get_war_actors(false, true):
		if enemy == null or enemy.wvId == wa.wvId or enemy.disabled or not enemy.has_position():
			continue
		if Global.get_distance(wa.position, enemy.position) > max_dist:
			continue
		legal.append({
			"id": _next_id("a"), "tool": "attack", "actor": wa.actorId,
			"target": enemy.actorId, "cost": {"ap": 4},
		})
	return

func _append_stratagem_actions(legal: Array, wa) -> void:
	for scheme in wa.get_stratagems():
		if scheme.is_area_targeting():
			continue
		var targets = scheme.get_available_targets(wa.actorId)[0]
		for tid in targets:
			legal.append({
				"id": _next_id("s"), "tool": "stratagem", "actor": wa.actorId,
				"target": int(tid), "skill": scheme.name,
				"cost": {"ap": 2, "poker": 1},
			})
	return

func _append_retreat_action(legal: Array, wa) -> void:
	var city = wa.get_retreat_city_id()
	if city >= 0:
		legal.append({
			"id": _next_id("r"), "tool": "retreat", "actor": wa.actorId,
			"city": city, "cost": {},
		})
	return

# 地形全量投影：[[x, y, "地形名"], ...]。
# 只列非平原格——平原是默认地形，不列出可以把 prompt 体积砍掉近一半；
# 米屋 / 装备店 / 医馆 / 太守府 是地形名，也会出现在这里。
# 整张地图 32x19，一场战斗内不变，所以只调用一次。
func _build_terrain(_units: Array, map) -> Array:
	var rows = []
	for y in range(CELL_ROWS):
		for x in range(CELL_COLUMNS):
			var pos = Vector2(x, y)
			if not map.is_valid_position(pos):
				continue
			var kind = map.get_blockCN_by_position(pos)
			if kind == DEFAULT_BLOCK:
				continue
			rows.append([x, y, kind])
	return rows
