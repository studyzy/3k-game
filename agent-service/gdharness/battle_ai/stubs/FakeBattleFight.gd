extends Resource
var order_calls = []
var _states = {"将": "前进", "骑": "前进", "弓": "前进", "步": "前进"}
var _turn = 1
func get_attacker_id(): return 12
func get_defender_id(): return 31
func turns(): return _turn
func get_attacker_unit_types(): return ["将", "骑", "弓", "步"]
func get_defender_unit_types(): return ["将", "骑", "弓"]
func get_battle_sodiers(actorId, a=false, b=true): return 1200 if actorId == 12 else 900
func get_units_states(actorId): return _states.duplicate(true)
func set_unit_state(actorId, setting):
	for k in setting:
		_states[k] = setting[k]
		order_calls.append({"actor": actorId, "unit": k, "order": setting[k]})
	return
func bump_turn(): _turn += 1
