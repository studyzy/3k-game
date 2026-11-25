# 假 War_Actor：白兵战里被查询的战术值与 buff。
extends Resource

var actorId = 12
var battle_tactic_point = 12
var dic_buffs = {}
var disabled = false
var _enemy = null
var _info = null

func get_battle_enemy_war_actor(): return _enemy

func actor(): return _info

func get_controlNo(): return -1

func get_buff(name): return dic_buffs.get(name, {"回合数": 0})

func can_use_tactic(): return true

func continuous_tactic_on(_basicOnly=false): return false

func get_solo_accept_rate(_from): return 0
