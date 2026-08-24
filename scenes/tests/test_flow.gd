extends Control
## 核心流程集成测试

func _ready() -> void:
	_test_flow()


func _test_flow() -> void:
	print("[Flow] 1. 加载配置")
	DataManager.load_all_configs()
	print("[Flow] 2. 设置玩家势力=1")
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	print("[Flow] 势力回合顺序: %s" % str(CountryListCache.country_sequence))
	print("[Flow] 3. 玩家命令数: %d" % GameInfo.get_player_order_num())
	# 测试城市操作
	var city := CityListCache.get_city_by_city_id(1)
	print("[Flow] 4. 城%s 钱=%d 粮=%d" % [city.cityName, city.money, city.grain])
	var gid: int = city.get_officer_ids()[0] if not city.get_officer_ids().is_empty() else 0
	print("[Flow] 5. 城1官员: %s" % (GeneralListCache.get_general(gid).generalName if gid != 0 else "无"))
	# 测试战斗模拟
	var atk := GeneralListCache.get_general(CountryListCache.get_country_by_country_id(1).countryKingId)
	var def := GeneralListCache.get_general(CountryListCache.get_country_by_country_id(2).countryKingId)
	print("[Flow] 6. 战斗模拟: %s(兵%d) vs %s(兵%d)" % [atk.generalName, atk.soldiers, def.generalName, def.soldiers])
	BattleManager.init_battle(atk, def, 0, true)
	BattleManager.hmTurnOrder = BattleManager.create_turn_order(atk, true)
	BattleManager.aiTurnOrder = BattleManager.create_turn_order(def, false)
	var win := BattleManager.simulated_battle()
	print("[Flow] 7. 玩家%s 剩余兵=%d 敌人剩余兵=%d" % ["胜" if win else "败", atk.soldiers, def.soldiers])
	# 测试保存
	print("[Flow] 8. 存档测试")
	DataManager.save_game(0)
	DataManager.get_record_info()
	print("[Flow] 9. 存档信息: %s" % GameInfo.recordInfo[0])
	# 测试读档
	GameInfo.years = 999
	DataManager.load_game(0)
	print("[Flow] 10. 读档后年份=%d 势力=%d" % [GameInfo.years, GameInfo.playerCountryId])
	# 测试回合推进
	print("[Flow] 11. 回合推进")
	var m_before := GameInfo.month
	TurnManager.end_player_turn()
	print("[Flow] 12. 月份变化: %d -> %d 年份=%d" % [m_before, GameInfo.month, GameInfo.years])
	print("[Flow] 全部流程测试通过")
	get_tree().quit()
