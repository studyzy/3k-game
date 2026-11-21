extends Reference
# 最小计策桩：只实现 StateProjection 用到的四个成员。
var name = "火计"
var ap_cost = 6
var targets = []
func is_area_targeting(): return false
func get_available_targets(_actor_id): return [targets, []]
func get_cost_ap(_actor_id): return ap_cost