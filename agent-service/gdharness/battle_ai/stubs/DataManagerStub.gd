# 假 DataManager：只实现白兵战 AI 用到的存取与查询。
extends Node

var diffculities = 4
var ai_agent_mode = true
var mod_path = ""
var battle = null
var war_actor = null
var war_actor_enemy = null
var battle_units = []
var battle_run = true
var env = {}
var traces = []

func get_current_battle_fight(): return battle

func get_war_actor(id):
	if war_actor != null and id == war_actor.actorId:
		return war_actor
	if war_actor_enemy != null and id == war_actor_enemy.actorId:
		return war_actor_enemy
	return null

func game_trace(msg): traces.append(str(msg))

func ai_debug_log(msg: String, always: bool = false): pass

func set_env(k, v): env[k] = v

func unset_env(k): env.erase(k)

func get_env_int(k, d=0): return int(env.get(k, d))

func get_env_str(k, d=""): return str(env.get(k, d))

func battle_unit_type_hp(actorId, type_name):
	var total = 0
	for bu in battle_units:
		if bu.disabled or bu.leaderId != actorId or bu.get_unit_type() != type_name:
			continue
		total += bu.get_hp()
	return total

func get_battle_unit_by_position(pos):
	for bu in battle_units:
		if bu.unit_position == pos:
			return bu
	return null

var ai_agent_base_url = ""

func resolve_ai_agent_url(path):
	var base = ai_agent_base_url
	if base == "":
		base = "http://127.0.0.1:8060"
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	return base + path
