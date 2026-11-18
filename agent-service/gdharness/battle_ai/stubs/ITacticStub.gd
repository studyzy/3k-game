extends Resource
const COSTS = {"咒缚": 3, "挑衅": 5, "强弩": 7, "士气向上": 8, "火矢": 10}
func get_tactic_cost(wa, tactic):
	if COSTS.has(tactic):
		return COSTS[tactic]
	return 0
