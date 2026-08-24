extends Control
## 战争结算测试

func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	# 找一个相邻的敌方城
	var player_country := CountryListCache.get_country_by_country_id(1)
	var target_city_id := 0
	var target_city: City = null
	var attacker_city_id := 0
	for cid in player_country.cityIDs:
		var city := CityListCache.get_city_by_city_id(cid)
		for adj in city.connectCityId:
			var adj_city := CityListCache.get_city_by_city_id(adj)
			if adj_city.ownerID != city.ownerID and adj_city.ownerID != 0:
				target_city_id = adj
				target_city = adj_city
				attacker_city_id = cid
				break
		if target_city_id != 0:
			break
	print("[War] 目标城=%s(%d) 攻击城=%d" % [target_city.cityName if target_city != null else "?", target_city_id, attacker_city_id])
	# 玩家出兵
	var atk_ids := target_city.get_officer_ids()
	if atk_ids.is_empty():
		print("[War] 目标城无守军，直接占领测试")
		WarManager.war_prepare(false, target_city_id, attacker_city_id, [player_country.countryKingId], 500, 300)
		WarManager.after_war_settlement(true, true)
		print("[War] 无守军结算完成")
	else:
		# 用玩家自己的武将进攻
		var player_city := CityListCache.get_city_by_city_id(attacker_city_id)
		var player_attackers := player_city.get_officer_ids()
		if player_attackers.is_empty():
			player_attackers = [player_country.countryKingId]
		WarManager.war_prepare(false, target_city_id, attacker_city_id, player_attackers, 500, 300)
		var hm_gen := GeneralListCache.get_general(WarManager.hmUnits[0].genID)
		var ai_gen := GeneralListCache.get_general(WarManager.aiUnits[0].genID)
		hm_gen.soldiers = 3000
		for u2 in WarManager.aiUnits:
			GeneralListCache.get_general(u2.genID).soldiers = 100
		BattleManager.init_battle(hm_gen, ai_gen, 0, WarManager.isHmDef)
		BattleManager.hmTurnOrder = BattleManager.create_turn_order(hm_gen, true)
		BattleManager.aiTurnOrder = BattleManager.create_turn_order(ai_gen, false)
		var win := BattleManager.simulated_battle()
		print("[War] 战斗玩家%s" % ("胜" if win else "败"))
		WarManager.after_war_settlement(win, true)
		# 验证城市归属
		var new_city := CityListCache.get_city_by_city_id(target_city_id)
		var new_owner := CountryListCache.get_country_by_king_id(new_city.ownerID)
		print("[War] 结算后 %s 归属=%s" % [new_city.cityName, new_owner.king_name() if new_owner != null else "无"])
		var owner_city_ids: Array = new_owner.cityIDs if new_owner != null else []
		print("[War] 归属势力城市列表含该城: %s" % str(target_city_id in owner_city_ids))
	print("[War] 战争结算测试完成")
	get_tree().quit()
