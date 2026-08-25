# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/OrderHistory.gd
# 说明：指令历史（自动加载）。记录并回放玩家下达的指令序列。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Node

var history = {}

func _ready():
	return

func reset(vstateId: int):
	if str(vstateId) in history:
		history[str(vstateId)].clear()
	return

func record_order(vstateId: int, action: String, actorId: int):
	if not history.has(str(vstateId)):
		history[str(vstateId)] = {}
	if not history[str(vstateId)].has(action):
		history[str(vstateId)][action] = []
	history[str(vstateId)][action].append(actorId)
	return

func orders_executed(vstateId: int, actorId: int, actions: PoolStringArray) -> bool:
	if not history.has(str(vstateId)):
		return false
	for action in actions:
		if action in history[str(vstateId)] and actorId in history[str(vstateId)][action]:
			return true
	return false
