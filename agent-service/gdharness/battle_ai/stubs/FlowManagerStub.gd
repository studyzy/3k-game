# 假 FlowManager：记录用计流程，可模拟「有任务在跑」与「流程真的把计策执行了」。
extends Node

var flows = []
# 模拟引擎里已有流程占用：true 时 BattleAgent 不能再用 FlowManager。
var busy = false
# add_flow("before_AI_tactic") 时模拟引擎副作用（扣战术值、挂 buff），
# 用来覆盖 BattleAgent 里「施计后核对是否真的生效」的分支。
var apply_tactic = false

func bind_import_flow(name, obj): pass

# add_flow 的返回值被 BattleAgent 当作「是否成功入队」，必须返回 true。
func add_flow(flow, instant=false):
	var name = str(flow)
	flows.append(name)
	if apply_tactic and name == "before_AI_tactic":
		var wa = DataManager.war_actor
		if wa != null:
			wa.battle_tactic_point = int(wa.battle_tactic_point) - 7
			wa.dic_buffs["强弩"] = {"回合数": 3}
	return true

func has_task(): return busy
