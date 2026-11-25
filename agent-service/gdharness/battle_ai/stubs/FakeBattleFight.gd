# 假 BattleFight：只保存各兵种命令，把每次变更记进 order_calls 供断言。
extends Resource

var order_calls = []
var lostType = 0
var _states = {"将": "待机", "骑": "待机", "弓": "待机", "步": "待机"}
var _turn = 1

func get_attacker_id(): return 12
func get_defender_id(): return 31
func get_attacker(): return DataManager.get_war_actor(12)
func get_defender(): return DataManager.get_war_actor(31)
func turns(): return _turn
func get_terrian(): return "plain"
func is_terrian_city(): return false
func solo_disabled(): return false

func get_attacker_unit_types(): return ["将", "骑", "弓", "步"]
func get_defender_unit_types(): return ["将", "弓"]
func get_battle_sodiers(actorId, a=false, b=true): return 1200 if actorId == 12 else 900
func get_units_states(actorId): return _states.duplicate(true)
func get_units_state(actorId, ut): return str(_states.get(ut, "前进"))

func set_unit_state(actorId, setting):
	for k in setting:
		_states[k] = setting[k]
		order_calls.append({"actor": actorId, "unit": k, "order": setting[k]})
	return

func battle_units(actorId):
	var ret = []
	for bu in DataManager.battle_units:
		if bu.leaderId == actorId and not bu.disabled:
			ret.append(bu)
	return ret

func bump_turn(): _turn += 1
