extends Reference
var actorId = 0
var wvId = 0
var position = Vector2(0, 0)
var disabled = false
var action_point = 7
var poker_point = 3
var _info = null
func has_position(): return true
func can_move_to_position(p): return true
func get_soldiers(): return 1000
func actor(): return _info
func get_attack_distance(): return 3
func get_stratagems(): return []
func get_retreat_city_id(): return 5
