# ==============================================================================
# 新增：AI Agent 接入（白兵战）
# 文件：packed/sgz_script/battle/AI/TacticProjection.gd
# 说明：白兵战「战术预估」——模型用计前的只读查询。只读：不改状态、不触发技能。
#         - 消耗/是否可用：ITactic.get_tactic_cost、War_Actor.can_use_tactic
#         - 命中率：咒缚 = ITactic.get_stop_tactic_rate；挑衅 = War_Actor.get_solo_accept_rate
#         - 数值效果：浮动的取均值，交给 TacticalDamage 之类与引擎一致的计算
#       依据：player_tactic.gd 的 tactic_start / tactic_impact_*、
#             clBattleFight.reject_solo_request、Battle_Unit 的攻防与射程。
# ==============================================================================
extends Resource

# 战术 → 施加的 buff 名、回合数（player_tactic.tactic_impact_*）
const TACTIC_BUFF = {
	"咒缚": "咒缚", "强弩": "强弩", "士气向上": "士气向上", "火矢": "火矢",
}
const TACTIC_TURNS = {
	"咒缚": 3, "强弩": 3, "士气向上": 4, "火矢": 4,
}
# 会被战术状态覆盖的战术：同一时间只存在一个
const BUFF_TACTICS = ["咒缚", "强弩", "士气向上", "火矢"]
# 拒绝单挑的固定代价（clBattleFight.reject_solo_request）
const SOLO_REJECT_MORALE = - 4
const SOLO_REJECT_COURAGE = - 10
# 「士气向上」：基础攻击 +random(5,9)，士兵防御 ×1.2（get_basic_attack_val / get_defence_val）
const MORALE_ATTACK_MIN = 5
const MORALE_ATTACK_MAX = 9
const MORALE_ATTACK_AVG = (MORALE_ATTACK_MIN + MORALE_ATTACK_MAX) / 2.0
const MORALE_DEFENCE_RATE = 1.2
# 「火矢」：射箭基础攻击 +random(9,15)，受击士兵防御 -1/3（IBattle_Damage.calc_classic_damage）
const FIRE_ARROW_ATTACK_MIN = 9
const FIRE_ARROW_ATTACK_MAX = 15
const FIRE_ARROW_ATTACK_AVG = (FIRE_ARROW_ATTACK_MIN + FIRE_ARROW_ATTACK_MAX) / 2.0
const FIRE_ARROW_PIERCE = 1.0 / 3.0

var _itactic = null


func _init() -> void:
	_itactic = Global.load_script(DataManager.mod_path + "sgz_script/battle/ITactic.gd")
	return


# 入口：actorId 用 tactic 的预估。actorId < 0 时取 env「当前武将」（BattleAgent 施计同源）。
func estimate(actorId: int, tactic: String) -> Dictionary:
	if actorId < 0:
		actorId = DataManager.get_env_int("当前武将")
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return {"ok": false, "tactic": tactic, "reason": "当前不在白兵战中"}
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return {"ok": false, "tactic": tactic, "reason": "取不到施计武将 #{0}".format([actorId])}
	if not StaticManager.TACTICS.has(tactic):
		return {"ok": false, "tactic": tactic, "reason": "「{0}」不是白兵战战术".format([tactic])}
	if _itactic == null:
		return {"ok": false, "tactic": tactic, "reason": "战术脚本 ITactic 未加载"}
	var cost = int(_itactic.get_tactic_cost(wa, tactic))
	var ret = {
		"ok": true,
		"tactic": tactic,
		"cost": cost,
		"tactic_point": int(wa.battle_tactic_point),
		"affordable": cost <= int(wa.battle_tactic_point),
		"description": _itactic.get_tactic_description(actorId, tactic),
		"available": true,
		"unavailable_reason": "",
		"rate": 100,
		"rate_note": "",
		"impacts": [],
	}
	if not wa.can_use_tactic():
		ret["available"] = false
		ret["unavailable_reason"] = str(DataManager.get_env_str("战斗.战术禁用原因"))
	elif wa.continuous_tactic_on(true):
		ret["available"] = false
		ret["unavailable_reason"] = "已有战术状态生效，连续战术期间不能再发战术"
	if not ret["affordable"]:
		ret["available"] = false
		ret["unavailable_reason"] = "战术值不足：需要 {0}，当前 {1}".format([cost, int(wa.battle_tactic_point)])
	var enemy = wa.get_battle_enemy_war_actor()
	match tactic:
		"咒缚":
			var rate = int(_itactic.get_stop_tactic_rate(actorId))
			ret["rate"] = rate
			ret["rate_note"] = "使敌方主将无法移动的成功率（默认 50% + 装备加成，上限 100）"
			if enemy != null:
				ret["impacts"] = _stop_impacts(enemy)
		"挑衅":
			ret["rate_note"] = "敌方主将接受单挑的概率"
			if enemy != null:
				ret["rate"] = int(enemy.get_solo_accept_rate(wa))
				ret["impacts"] = _provoke_impacts(bf, wa, enemy)
		"强弩":
			ret["rate_note"] = "必然生效"
			ret["impacts"] = _strong_bow_impacts(bf, wa)
		"士气向上":
			ret["rate_note"] = "必然生效"
			ret["impacts"] = _morale_impacts(bf, wa)
		"火矢":
			ret["rate_note"] = "必然生效"
			ret["impacts"] = _fire_arrow_impacts(bf, wa)
	return ret


# 战术 buff 实际回合数：set_buff(…, TACTIC_TURNS)，连续战术再加装备特性「战术附加回合」
func _actual_turns(wa) -> int:
	var extra = 0
	if wa != null and wa.actor() != null:
		extra = int(wa.actor().get_equip_feature_total("战术附加回合"))
	return extra


func _buff_row(target: String, name: String, turns: int, note: String) -> Dictionary:
	return {
		"kind": "buff",
		"target": target,
		"name": name,
		"turns": turns,
		"same_slot": "同一时间只存在一个战术状态（后开者覆盖）",
		"note": note,
	}


func _stop_impacts(enemy) -> Array:
	var turns = int(TACTIC_TURNS["咒缚"]) + _actual_turns(enemy)
	return [_buff_row("enemy_main", "咒缚", turns,
		"命中后敌方主将 {0} 回合不能移动，其士兵照常行动".format([turns]))]


func _provoke_impacts(bf, wa, enemy) -> Array:
	var row = {
		"kind": "solo_request",
		"target": "enemy_main",
		"accepted_rate": int(enemy.get_solo_accept_rate(wa)),
		"on_accept": "接受后进入单挑（引擎 go_to_solo，胜负按单挑规则结算）",
		"on_reject": {
			"morale": SOLO_REJECT_MORALE,
			"courage": SOLO_REJECT_COURAGE,
			"note": "被拒绝时敌方主将士气 -4、胆 -10，主将攻击随之下降",
		},
		"disabled_in_this_battle": bool(bf.solo_disabled()),
	}
	# 单挑胜负的参考量：体力、武力、胆、单挑 dex。
	# get_solo_dex 内含随机项（+random(0,11)），这里按均值 5.5 取期望，不消耗随机数。
	if enemy.actor() != null and wa.actor() != null:
		row["compare"] = {
			"our_hp": int(wa.actor().get_hp()), "enemy_hp": int(enemy.actor().get_hp()),
			"our_power": int(wa.get_battle_power()), "enemy_power": int(enemy.get_battle_power()),
			"our_courage": int(wa.battle_courage), "enemy_courage": int(enemy.battle_courage),
			"our_dex_avg": _solo_dex_expect(wa), "enemy_dex_avg": _solo_dex_expect(enemy),
		}
	return [row]


# War_Actor.get_solo_dex 的期望值：(体+武)/10 + 20 - 装备重量 + 5.5
func _solo_dex_expect(wa) -> int:
	var actor = wa.actor()
	if actor == null:
		return 0
	var dex = (actor.get_hp() + actor.get_power()) / 10
	dex += 20 - actor.equip_total_weight() + 5.5
	return int(round(dex))


func _strong_bow_impacts(bf, wa) -> Array:
	var turns = int(TACTIC_TURNS["强弩"]) + _actual_turns(wa)
	var rows = [_buff_row("self", "强弩", turns,
		"射箭距离 +2、射箭必发；太守府守城时远距离伤害不再减半。射程为 0 的兵种不受益")]
	var units = []
	for bu in _my_units(bf, wa):
		if bu == null or bu.get_unit_type() == "将":
			continue
		var d0 = int(bu.get_shoot_distance())
		units.append({
			"type": bu.get_unit_type(), "hp": int(bu.get_hp()),
			"range_before": d0, "range_after": min(7, d0 + 2), "benefits": d0 > 0,
		})
	rows[0]["units"] = units
	return rows


func _morale_impacts(bf, wa) -> Array:
	var turns = int(TACTIC_TURNS["士气向上"]) + _actual_turns(wa)
	var rows = [_buff_row("self", "士气向上", turns,
		"全体基础攻击 +{0}~{1}，士兵防御 ×{2}".format([MORALE_ATTACK_MIN, MORALE_ATTACK_MAX, MORALE_DEFENCE_RATE]))]
	# 用「不带加成」的当前值做基数：get_basic_attack_val 在已生效时会带随机加成，仅用于参考
	for bu in _my_units(bf, wa):
		if bu == null:
			continue
		var a0 = float(bu.get_basic_attack_val())
		var d0 = float(bu.get_defence_val(false, false))
		rows.append({
			"kind": "unit",
			"type": bu.get_unit_type(),
			"hp": int(bu.get_hp()),
			"attack_before": round(a0),
			"attack_after_min": round(a0 + MORALE_ATTACK_MIN),
			"attack_after_max": round(a0 + MORALE_ATTACK_MAX),
			"attack_gain_avg": MORALE_ATTACK_AVG,
			"defence_before": _r1(d0),
			"defence_after": _r1(d0 * MORALE_DEFENCE_RATE),
		})
	return rows


func _fire_arrow_impacts(bf, wa) -> Array:
	var turns = int(TACTIC_TURNS["火矢"]) + _actual_turns(wa)
	var rows = [_buff_row("self", "火矢", turns,
		"所有攻击视为火矢：射箭基础攻击 +{0}~{1}，受击士兵防御无视 {2:.0f}%".format([
			FIRE_ARROW_ATTACK_MIN, FIRE_ARROW_ATTACK_MAX, FIRE_ARROW_PIERCE * 100]))]
	for bu in _my_units(bf, wa):
		if bu == null or bu.get_unit_type() == "将":
			continue
		var a0 = float(bu.get_basic_attack_val())
		rows.append({
			"kind": "unit",
			"type": bu.get_unit_type(),
			"hp": int(bu.get_hp()),
			"shoot_range": int(bu.get_shoot_distance()),
			"fire_attack_bonus_min": FIRE_ARROW_ATTACK_MIN,
			"fire_attack_bonus_max": FIRE_ARROW_ATTACK_MAX,
			"fire_attack_after_min": round(a0 + FIRE_ARROW_ATTACK_MIN),
			"fire_attack_after_max": round(a0 + FIRE_ARROW_ATTACK_MAX),
			"enemy_soldier_defence_ignored": _r2(FIRE_ARROW_PIERCE),
		})
	return rows


# 保留一位小数（Godot 3 没有 Vector2.snapped 的浮点重载）
func _r1(v: float) -> float:
	return round(v * 10.0) / 10.0


func _r2(v: float) -> float:
	return round(v * 100.0) / 100.0


func _my_units(bf, wa) -> Array:
	if bf == null or wa == null:
		return []
	return bf.battle_units(wa.actorId)

# 一行摘要：给快照用，避免把完整 impacts 塞进每拍请求。
func summary(est: Dictionary) -> String:
	var tactic = str(est.get("tactic", ""))
	var cost = int(est.get("cost", 0))
	var rate = int(est.get("rate", 100))
	match tactic:
		"咒缚":
			var turns = 3
			for row in est.get("impacts", []):
				if typeof(row) == TYPE_DICTIONARY and row.get("kind") == "buff":
					turns = int(row.get("turns", 3))
			return "命中率 {0}%；敌主将定止 {1} 回合".format([rate, turns])
		"挑衅":
			return "接受率 {0}%；拒绝则敌士气 -4、胆 -10".format([rate])
		"强弩":
			var n = 0
			for row in est.get("impacts", []):
				if typeof(row) != TYPE_DICTIONARY or row.get("kind") != "buff":
					continue
				for u in row.get("units", []):
					if typeof(u) == TYPE_DICTIONARY and u.get("benefits", false):
						n += 1
			return "射程 +2、射箭必发；{0} 个弓兵受益".format([n])
		"士气向上":
			return "全体攻击 +5~9、士兵防御 ×1.2"
		"火矢":
			return "射箭攻击 +9~15、无视 1/3 防御"
	return "消耗 {0}，命中率 {1}%".format([cost, rate])
