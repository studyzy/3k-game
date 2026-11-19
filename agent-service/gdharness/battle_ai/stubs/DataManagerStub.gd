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
func ai_debug_log(msg: String, always: bool = false): pass
func set_env(k, v): pass
func unset_env(k): pass
func get_env_int(k, d=0): return d
func battle_unit_type_hp(actorId, type): return 300
var ai_agent_base_url = ""
func resolve_ai_agent_url(path):
	var base = ai_agent_base_url
	if base == "":
		base = "http://127.0.0.1:8060"
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	return base + path
