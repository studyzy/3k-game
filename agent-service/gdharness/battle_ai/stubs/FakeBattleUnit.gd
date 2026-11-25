# 假战场单位：只提供快照要读的字段。
extends Resource

var leaderId = 12
var disabled = false
var unit_position = Vector2(0, 0)
var _type = "将"
var _hp = 100
var _shoot = 0
var _attack = 1

func get_unit_type(): return _type
func get_hp(include_disabled: bool = false): return _hp
func get_shoot_distance(): return _shoot
func get_attack_distance(): return _attack
