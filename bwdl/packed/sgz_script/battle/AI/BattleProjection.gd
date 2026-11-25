# 白兵战态势投影 v2：一场战斗每拍一份快照。
# 只读：不改战局、不触发技能、不消耗战术值。
extends Resource

const UNIT_TYPES = ["将", "骑", "象", "弓", "步"]

var _tactics = null

func _init() -> void:
	_tactics = null
	return

func _ensure_tactics():
	if _tactics == null:
		_tactics = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/TacticProjection.gd")
	return _tactics

func build(bf, actorId: int, tick: int, lastPlan, elapsedMs: int) -> Dictionary:
	if bf == null:
		return {}
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return {}
	var enemy = wa.get_battle_enemy_war_actor()
	if enemy == null:
		return {}
	var enemyId = enemy.actorId
	var payload = {
		"battle_version": 2,
		"battle_key": "b{0}-b{1}".format([bf.get_attacker_id(), bf.get_defender_id()]),
		"tick": int(tick),
		"elapsed_ms": int(elapsedMs),
		"diffculities": DataManager.diffculities,
		"side": "attacker" if actorId == bf.get_attacker_id() else "defender",
		"controlled_actor_id": actorId,
		"enemy_actor_id": enemyId,
		"turn": int(bf.turns()),
		"terrain": _terrain(bf),
		"controlled": _side_state(bf, actorId, enemyId),
		"enemy": _side_state(bf, enemyId, actorId),
		"legal_tactics": _legal_tactics(wa),
	}
	if lastPlan != null:
		payload["last_plan"] = lastPlan
	return payload

func _terrain(bf) -> Dictionary:
	return {
		"name": str(bf.get_terrian()),
		"is_city": bool(bf.is_terrian_city()),
	}

func _side_state(bf, actorId: int, otherId: int) -> Dictionary:
	var wa = DataManager.get_war_actor(actorId)
	var actor = wa.actor() if wa != null else null
	var otherMain = _main_unit(bf, otherId)
	var otherPos = otherMain.unit_position if otherMain != null else Vector2(-10, -10)
	var unitTypes = bf.get_defender_unit_types()
	if actorId == bf.get_attacker_id():
		unitTypes = bf.get_attacker_unit_types()
	var states = bf.get_units_states(actorId)
	var units = []
	for ut in unitTypes:
		units.append(_unit_info(bf, actorId, str(ut), otherPos, states))
	return {
		"name": actor.get_name() if actor != null else "",
		"hp": int(actor.get_hp()) if actor != null else 0,
		"soldiers": int(bf.get_battle_sodiers(actorId)),
		"tactic_point": int(wa.battle_tactic_point) if wa != null else 0,
		"buffs": _buffs(wa),
		"units": units,
	}

func _main_unit(bf, actorId: int):
	for bu in DataManager.battle_units:
		if bu == null or bu.disabled:
			continue
		if bu.leaderId != actorId:
			continue
		if bu.get_unit_type() == "将":
			return bu
	return null

func _unit_info(bf, actorId: int, ut: String, otherPos: Vector2, states: Dictionary) -> Dictionary:
	var count = 0
	var best = null
	var bestDist = 999999
	for bu in DataManager.battle_units:
		if bu == null or bu.disabled:
			continue
		if bu.leaderId != actorId or bu.get_unit_type() != ut:
			continue
		count += 1
		var d = Global.get_distance(bu.unit_position, otherPos)
		if d < bestDist:
			bestDist = d
			best = bu
	var pos = best.unit_position if best != null else Vector2(-10, -10)
	var shootRange = int(best.get_shoot_distance()) if best != null else 0
	var attackRange = int(best.get_attack_distance()) if best != null else 1
	var dist = Global.get_distance(pos, otherPos) if best != null else 999
	# 引擎的可选命令（windows/battle_bottom/battle_change_state.gd:3）是
	# 前进/包围/待机/战术/后退，比快照契约 BattleUnitV2.order 多两个；原样透传会让
	# 每次 /tick 都 422。这里规范化观察到的命令：包围 是混乱/死战时的进攻态，归入
	# 前进；战术 及其他任何未知值归入 待机。AI 自己下发的计划命令仍只用
	# BattlePlan 的 前进/待机/后退 三种，不经过这条路径。
	var order = str(states[ut]) if states.has(ut) else "前进"
	if order != "前进" and order != "待机" and order != "后退":
		order = "前进" if order == "包围" else "待机"
	return {
		"type": ut,
		"hp": int(DataManager.battle_unit_type_hp(actorId, ut)),
		"count": count,
		"order": order,
		"x": int(pos.x),
		"y": int(pos.y),
		"shoot_range": shootRange,
		"attack_range": attackRange,
		"dist_to_other_main": dist,
		"other_main_in_shoot_range": bool(best != null and shootRange > 0 and dist <= shootRange),
	}

func _buffs(wa) -> Array:
	var ret = []
	if wa == null:
		return ret
	for name in wa.dic_buffs.keys():
		var b = wa.dic_buffs[name]
		var turns = int(b.get("回合数", 0))
		if turns <= 0:
			continue
		var info = StaticManager.get_buff(str(name))
		if info == null or info.get_scene() != "小战场":
			continue
		ret.append({"name": str(name), "turns": turns})
	return ret

func _legal_tactics(wa) -> Array:
	var ret = []
	if wa == null:
		return ret
	var tp = _ensure_tactics()
	if tp == null:
		return ret
	for name in StaticManager.TACTICS.keys():
		# 每拍路径必须无随机：brief() 不碰 get_basic_attack_val / Global.get_random。
		var info = tp.brief(wa.actorId, str(name))
		if typeof(info) != TYPE_DICTIONARY or not info.get("available", false):
			continue
		ret.append({
			"name": str(name),
			"cost": int(info.get("cost", 0)),
			"rate": int(info.get("rate", 100)),
			"summary": str(info.get("summary", "")),
		})
	return ret