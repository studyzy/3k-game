extends Reference
var id = 2
var rice = 420
var money = 1800
var main_actorId = 12
var side = "防守方"
var enemy_wv = null

func is_attacker() -> bool:
	return side == "攻击方"

func is_defender() -> bool:
	return side == "防守方"

func get_enemy_vstate():
	return enemy_wv
