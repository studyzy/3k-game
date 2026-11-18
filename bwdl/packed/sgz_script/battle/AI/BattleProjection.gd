# ==============================================================================
# 新增：AI Agent 接入（白兵战）
# 文件：packed/sgz_script/battle/AI/BattleProjection.gd
# 说明：把白兵战态势投影成 /ai/battle 请求体，并把执行结果投影成回传体。
#       兵种/命令/计策模型来自 clBattleFight.gd 与 Static_Manager.TACTICS。
# ==============================================================================
extends Resource

# 与 War_AI_behavior_llm.gd 一致：白兵战命令取值
const ORDERS = ["前进", "待机", "后退"]

var _seq: int = 0

func _init() -> void:
	_seq = 0
	return

# 生成本场战斗的开场请求。actorId 为我方（受控）武将。
func build(bf, actorId: int) -> Dictionary:
	if bf == null:
		return {}
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return {}
	var enemy = wa.get_battle_enemy_war_actor()
	if enemy == null:
		return {}
	var side = "attacker" if actorId == bf.get_attacker_id() else "defender"
	return {
		"battle_version": 1,
		"visibility": "omniscient",
		"battle_key": "b{0}-t{1}".format([bf.get_attacker_id(), bf.get_defender_id()]),
		"diffculities": DataManager.diffculities,
		"controlled_actor_id": actorId,
		"enemy_actor_id": enemy.actorId,
		"side": side,
		"turn": int(bf.turns()),
		"controlled": _side_state(bf, actorId),
		"enemy": _side_state(bf, enemy.actorId),
		"legal_tactics": _legal_tactics(wa),
	}

# 执行某个指令后的最新态势（回传给服务端喂回 LLM）
func build_result(bf, actorId: int, ok: bool, outcome: String) -> Dictionary:
	var fresh = build(bf, actorId)
	if fresh.empty():
		return {"ok": ok, "outcome": outcome, "turn": 0,
			"controlled": {"soldiers": 0, "tactic_point": 0, "units": []},
			"enemy": {"soldiers": 0, "tactic_point": 0, "units": []},
			"legal_tactics": []}
	return {
		"ok": ok,
		"outcome": outcome,
		"turn": fresh["turn"],
		"controlled": fresh["controlled"],
		"enemy": fresh["enemy"],
		"legal_tactics": fresh["legal_tactics"],
	}

func _side_state(bf, actorId: int) -> Dictionary:
	var wa = DataManager.get_war_actor(actorId)
	var actor = null
	if wa != null:
		actor = wa.actor()
	var states = bf.get_units_states(actorId)
	var unit_types = bf.get_defender_unit_types()
	if actorId == bf.get_attacker_id():
		unit_types = bf.get_attacker_unit_types()
	var units = []
	for ut in unit_types:
		units.append({
			"type": str(ut),
			"hp": int(DataManager.battle_unit_type_hp(actorId, ut)),
			"order": str(states[ut]) if states.has(ut) else "前进",
		})
	return {
		"name": actor.get_name() if actor != null else "",
		"hp": actor.get_hp() if actor != null else 0,
		"soldiers": int(bf.get_battle_sodiers(actorId)),
		"tactic_point": wa.battle_tactic_point if wa != null else 0,
		"units": units,
	}

# 可用计策：从 Static_Manager.TACTICS 中筛出战术值足够且本场可用的
func _legal_tactics(wa) -> Array:
	var ret = []
	if wa == null:
		return ret
	var iTactic = Global.load_script(DataManager.mod_path + "sgz_script/battle/ITactic.gd")
	for name in StaticManager.TACTICS.keys():
		var cost = iTactic.get_tactic_cost(wa, name)
		if cost > wa.battle_tactic_point:
			continue
		ret.append({"name": str(name), "cost": int(cost)})
	return ret