extends Control
## 结束回合测试（月度推进 + 命令数）
##
## headless 下无法调用 end_player_turn()（其内部 SceneRouter.change_scene 切换
## 当前场景会销毁本测试节点，导致后续逻辑无法恢复）。故直接调用其核心的
## TurnManager.add_month() 验证月度推进与命令数重置，headless 下可靠。

func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	var month_before := GameInfo.month
	var order_before := GameInfo.get_player_order_num()
	print("[EndTurn] 结束前月份=%d 命令=%d" % [month_before, order_before])
	# 月度推进（结束回合的核心逻辑，不触发场景切换）
	TurnManager.add_month()
	var month_delta := GameInfo.month - month_before
	if month_delta == 1 or month_delta == -11:
		print("[EndTurn] 月份推进正确：%d -> %d" % [month_before, GameInfo.month])
	else:
		print("[EndTurn] 月份推进异常：%d -> %d" % [month_before, GameInfo.month])
	# 命令数重置（新回合开始）
	GameInfo.playerOrderNum = GameInfo.get_player_order_num()
	print("[EndTurn] 新回合命令=%d" % GameInfo.get_player_order_num())
	print("[EndTurn] 结束回合测试完成")
	get_tree().quit()
