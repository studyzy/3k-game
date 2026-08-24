extends Control
## 多回合游戏循环压力测试

func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	print("[Loop] 开局：势力回合顺序=%s" % str(CountryListCache.country_sequence))

	for turn in range(1, 6):
		# 模拟玩家做几件事
		var city_id: int = CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).cityIDs[0]
		var city := CityListCache.get_city_by_city_id(city_id)
		# 搜索
		var search_ids := city.get_officer_ids()
		if not search_ids.is_empty():
			city.search(search_ids[0])
		# 内政
		var g := city.get_do_reclaim_mercantile_officer()
		if g != null and city.money > 100:
			city.reclaim(g, g.get_need_money_of_interior(GameInfo.TaskType.RECLAIM))
		# 征兵
		if city.money > 200:
			city.conscript(mini(city.get_max_conscript_soldier_num(), 300))
		print("[Loop] 第%d回合玩家操作完成：%s 钱=%d 粮=%d 兵=%d" % [turn, city.cityName, city.money, city.grain, city.get_city_all_soldier_num()])
		# 结束回合
		TurnManager.end_player_turn()
		print("[Loop] 第%d回合结束 -> %d年%d月" % [turn, GameInfo.years, GameInfo.month])
		# 检查游戏是否结束
		if GameInfo.playingState == GameInfo.GameState.GAME_OVER or GameInfo.playingState == GameInfo.GameState.GAME_WIN:
			print("[Loop] 游戏结束，状态=%d" % GameInfo.playingState)
			break

	print("[Loop] 5回合压力测试完成")
	get_tree().quit()
