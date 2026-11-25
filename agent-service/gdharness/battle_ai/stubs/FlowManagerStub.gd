# 假 FlowManager：记录用计流程，但永不认为有任务在跑。
extends Node

var flows = []

func bind_import_flow(name, obj): pass

# add_flow 的返回值被 BattleAgent 当作「是否成功入队」，必须返回 true。
func add_flow(flow, instant=false):
	flows.append(str(flow))
	return true

func has_task(): return false
