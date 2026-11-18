extends Node
var diffculities = 3
var ai_agent_mode = true
var war_control_sort_no = 0
var mod_path = ""
var current_war_fight = null
func get_current_war_fight(): return current_war_fight
func get_war_actor(id): return null
func get_move_cost(actorId, pos): return {"机":1, "点":0}
func game_trace(msg): pass
func set_env(k, v): pass
func unset_env(k): pass
func get_env_int(k, d=0): return d
func get_env_dict(k): return {}
