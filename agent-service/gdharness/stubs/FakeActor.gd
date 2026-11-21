extends Reference
var actorId = 0
var wvId = 0
var position = Vector2(0, 0)
var disabled = false
var action_point = 7
var poker_point = 3
var _info = null
var vstate = null
var _stratagems = []
func has_position(): return true
func can_move_to_position(p): return true
func get_soldiers(): return 1000
func get_troops_type(): return "平"
func actor(): return _info
func get_max_action_ap(): return 19
func get_buff(buff_name): return {"回合数": 3} if buff_name == "迟滞" else {"回合数": 0}
func is_puppet(): return false
func get_attack_distance(): return 3
func get_main_actor_id(): return -1 if vstate == null else vstate.main_actorId
func get_stratagems(): return _stratagems
func get_retreat_city_id(): return 5
