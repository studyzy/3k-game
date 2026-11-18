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
