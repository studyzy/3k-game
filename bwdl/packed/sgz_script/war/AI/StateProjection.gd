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
#
# 移动不由本文件出候选：地图与单位位置已全量下发，路径由 LLM 自己规划并直接
# 把 path 交给 Godot 逐格执行（War_AI_behavior_llm._move_stepwise）。
# legal_actions 只含 attack / stratagem / retreat / end。
# ==============================================================================
extends Resource

const CELL_COLUMNS: int = 32
const CELL_ROWS: int = 19
# 平原是默认地形：不列出，未出现的格子一律按平原理解
const DEFAULT_BLOCK: String = "平原"
# 引擎 is_valid_position 只认 y < 有效行数（cell_rows-1），最后一行永远不可进入。
# 不改引擎逻辑，而是在投影里把这一行标成不可进入，
# 避免 LLM 把「未列出 = 平原」误用到这行上。
const OUT_OF_BOUNDS: String = "不可进入"

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
# economy 含敌方粮草（economy.enemy），每次动作都重新投影，避免模型读到过期值。
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
			# 武将姓名：只给数字 id 模型无法判断谁是谁，必须随单位投影。
			"name": actor.get_name() if actor != null else "",
			# 军种（平/山/水/仙）：决定各行军地形的移动消耗。
			# 必须与 DataManager.get_move_cost 内部取军种的方式一致
			# （get_move_cost 用的是 actor().get_troops_type()，不含临时军种），
			# 否则提示词里的消耗表和实际扣费对不上。
			"troops": actor.get_troops_type() if actor != null else "",
			"hp": actor.get_hp() if actor != null else 0,
			"power": actor.get_power() if actor != null else 0,
			"wisdom": actor.get_wisdom() if actor != null else 0,
			"disabled": wa.disabled,
		}
		units.append(unit)
		if wa.wvId != controlled_id or wa.disabled or not wa.has_position():
			continue
		_append_attack_actions(legal, wa, wf)
		_append_stratagem_actions(legal, wa)
		_append_retreat_action(legal, wa)
		_append_move_hint(legal, wa, map)
		legal.append({
			"id": _next_id("e"), "tool": "end", "actor": wa.actorId, "cost": {},
		})

	# 兜底：至少给一个 end，避免 legal_actions 为空
	if legal.empty():
		legal.append({"id": "e0", "tool": "end", "actor": _controlled_leader_id(wv), "cost": {}})

	var main_city = map.get_position_by_buildCN("太守府")
	var enemy = wv.get_enemy_vstate()
	var side = "attacker" if wv.is_attacker() else "defender"
	var attacker_id = controlled_id
	if not wv.is_attacker():
		attacker_id = enemy.id if enemy != null else -1
	var economy = {
		"rice": wv.rice,
		"money": wv.money,
		"day": wf.date,
		"max_days": 30,
		"attacker_vstate": attacker_id,
		"main_city_pos": [int(main_city.x), int(main_city.y)],
	}
	# 敌方（玩家方）粮草：此前模型看不到「任一方粮尽即判负」的关键变量。
	# 敌方 vstate 缺失时不加该键，由提示词层按「未知」兜底。
	if enemy != null:
		economy["enemy"] = {"rice": enemy.rice, "money": enemy.money}

	return {
		"side": side,
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

# 移动不由 Godot 出候选（路径由 LLM 规划），但如果该武将还能走，
# 就在 legal_actions 里留一条 move 提示项，避免 LLM 看到「只剩 end」就判定无事可做。
# 提示项不带 path：真正的路径由 LLM 自己给出。
func _append_move_hint(legal: Array, wa, map) -> void:
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var pos = wa.position + dir
		if not map.is_valid_position(pos):
			continue
		if not wa.can_move_to_position(pos):
			continue
		var cost = DataManager.get_move_cost(wa.actorId, pos)
		if cost["机"] > wa.action_point or cost["点"] > wa.poker_point:
			continue
		legal.append({
			"id": _next_id("mv"), "tool": "move", "actor": wa.actorId,
			"cost": {"ap": cost["机"], "poker": cost["点"]},
			"hint": "可移动：path 由你自己规划（也可走远，本项只是提示还能动）",
		})
		return
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
# 地图 32x20，但引擎只允许进入前 CELL_ROWS(19) 行；
# 最后一行照常渲染、有地形，却不可进入，所以显式标成 OUT_OF_BOUNDS，
# 让「未列出 = 平原」这条约定对全图严格成立。
func _build_terrain(_units: Array, map) -> Array:
	var rows = []
	for y in range(CELL_ROWS + 1):
		for x in range(CELL_COLUMNS):
			var pos = Vector2(x, y)
			if y >= CELL_ROWS:
				rows.append([x, y, OUT_OF_BOUNDS])
				continue
			if not map.is_valid_position(pos):
				continue
			var kind = map.get_blockCN_by_position(pos)
			if kind == DEFAULT_BLOCK:
				continue
			rows.append([x, y, kind])
	return rows
