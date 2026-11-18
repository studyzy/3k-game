extends Node
var diffculities = 4
var ai_agent_mode = true
var mod_path = ""
var battle = null
var war_actor = null
var traces = []
func get_current_battle_fight(): return battle
func get_war_actor(id): return war_actor
func game_trace(msg): traces.append(str(msg))
func set_env(k, v): pass
func unset_env(k): pass
func get_env_int(k, d=0): return d
func battle_unit_type_hp(actorId, type): return 300
