extends Node
## 回合管理（autoload: TurnManager，简化版）


## 玩家结束回合
func end_player_turn() -> void:
	GameInfo.task = GameInfo.TaskType.NONE
	# AI 回合
	for cid in CountryListCache.country_sequence.duplicate():
		if cid == GameInfo.playerCountryId:
			continue
		var country := CountryListCache.get_country_by_country_id(cid)
		if country == null or country.get_have_city_num() <= 0:
			continue
		_ai_turn(country)
	# 月度推进
	add_month()
	# 胜负判定
	if _check_game_end():
		return
	# 开始玩家回合
	GameInfo.playerOrderNum = GameInfo.get_player_order_num()
	GameInfo.doCityId = CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).find_king_city()
	if GameInfo.doCityId == 0:
		GameInfo.doCityId = CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).cityIDs[0]
	GameInfo.playingState = GameInfo.GameState.PLAYER_TURN
	SceneRouter.change_scene("res://scenes/ui/city_scene.tscn")


## 胜负判定，返回 true 表示游戏结束
func _check_game_end() -> bool:
	var player_country := CountryListCache.get_country_by_country_id(GameInfo.playerCountryId)
	if player_country == null or player_country.get_have_city_num() <= 0:
		GameInfo.playingState = GameInfo.GameState.GAME_OVER
		SceneRouter.change_scene("res://scenes/ui/ui_end.tscn")
		return true
	# 判断是否只剩玩家
	var alive := 0
	for country in CountryListCache.country_dictionary.values():
		if country.get_have_city_num() > 0:
			alive += 1
	if alive <= 1:
		GameInfo.playingState = GameInfo.GameState.GAME_WIN
		SceneRouter.change_scene("res://scenes/ui/ui_end.tscn")
		return true
	return false


## AI 回合
func _ai_turn(country: Country) -> void:
	for city_id in country.cityIDs.duplicate():
		var city := CityListCache.get_city_by_city_id(city_id)
		if city == null:
			continue
		# 收入
		city.add_gold(city.money_income())
		city.add_food(city.food_income())
		# 内政：钱多时开垦/劝商/治水/巡查
		if city.money > 200:
			var g := city.get_do_reclaim_mercantile_officer()
			if g != null:
				var money := g.get_need_money_of_interior(GameInfo.TaskType.RECLAIM)
				if city.money >= money:
					city.reclaim(g, money)
				money = g.get_need_money_of_interior(GameInfo.TaskType.MERCANTILE)
				if city.money >= money:
					city.mercantile(g, money)
			if city.rule < 90:
				var patrol_officer := city.get_do_patrol_officer()
				if patrol_officer != null:
					var patrol_money := patrol_officer.get_need_money_of_interior(GameInfo.TaskType.PATROL)
					if city.money >= patrol_money:
						city.patrol(patrol_officer, patrol_money)
		# 搜索在野武将/登用
		if randf() < 0.4:
			var search_id := city.get_do_search_officer()
			city.search(search_id)
		# 登用在野武将
		if randf() < 0.3 and not city.get_talent_ids().is_empty():
			var talent: int = city.get_talent_ids()[0]
			var officer_ids := city.get_officer_ids()
			if not officer_ids.is_empty():
				city.is_employ(officer_ids[0], talent)
		# 奖赏忠诚度低的武将
		for gid in city.get_officer_ids().duplicate():
			var general := GeneralListCache.get_general(gid)
			if general != null and general.loyalty < 80 and city.money >= 100:
				city.reward(gid, false)
		# 简单征兵
		if city.money > 500:
			var n := city.get_max_conscript_soldier_num()
			if n > 0:
				var conscript_num := mini(n, 500)
				city.conscript(conscript_num)
		# 发薪
		city.pay_salaries()
	# 输送资源到前线（简化：把钱粮集中到第一城）
	if country.cityIDs.size() > 1:
		var first_city := CityListCache.get_city_by_city_id(country.cityIDs[0])
		for city_id in country.cityIDs.duplicate():
			if city_id == country.cityIDs[0]:
				continue
			var city := CityListCache.get_city_by_city_id(city_id)
			if city != null and city.money > 1000:
				var transfer := (city.money - 1000) / 2
				var transfer_food := (city.grain - 1000) / 2
				CityListCache.transport_between_citys(city_id, country.cityIDs[0], maxi(transfer_food, 0), maxi(transfer, 0), 0)
	# 可能发动战争（简化）
	_ai_maybe_attack(country)


func _ai_maybe_attack(country: Country) -> void:
	if randf() > 0.3:
		return
	var enemies := CountryListCache.get_enemy_adjacent_city_id_array(country.countryId)
	if enemies.is_empty():
		return
	var target_city_id: int = enemies[randi() % enemies.size()]
	var target_city := CityListCache.get_city_by_city_id(target_city_id)
	var attacker_generals := target_city.get_officer_ids()
	if attacker_generals.is_empty():
		return
	# 简化为兵力对比决定是否进攻
	var atk_power := _city_battle_power(target_city)
	var def_power := _city_battle_power(target_city)
	if atk_power > def_power * 1.1:
		WarManager.war_prepare(true, target_city_id, target_city_id, attacker_generals, 500, 1000, country.countryId)
		var player_country := CountryListCache.get_country_by_country_id(GameInfo.playerCountryId)
		if target_city.ownerID == player_country.countryKingId:
			# 攻打玩家：进入战争场景让玩家防守
			GameInfo.show_info = "%s 势力正在攻打 %s！" % [country.king_name(), target_city.cityName]
			SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")
		else:
			# AI vs AI：自动结算
			var hm_gen := GeneralListCache.get_general(WarManager.hmUnits[0].genID) if not WarManager.hmUnits.is_empty() else null
			var ai_gen := GeneralListCache.get_general(WarManager.aiUnits[0].genID) if not WarManager.aiUnits.is_empty() else null
			if hm_gen != null and ai_gen != null:
				BattleManager.init_battle(hm_gen, ai_gen, 0, WarManager.isHmDef)
				BattleManager.hmTurnOrder = BattleManager.create_turn_order(hm_gen, true)
				BattleManager.aiTurnOrder = BattleManager.create_turn_order(ai_gen, false)
				var hm_win := BattleManager.simulated_battle()
				WarManager.after_war_settlement(hm_win, true)


func _city_battle_power(city: City) -> int:
	return city.get_max_atk_power()


## 月度推进
func add_month() -> void:
	GameInfo.month += 1
	if GameInfo.month > 12:
		GameInfo.month = 1
		GameInfo.years += 1
		GeneralListCache.debut_by_years(GameInfo.years)
	# 月度事件
	_monthly_income()
	_uprising()
	_check_disasters()
	_handle_city_generals()
	_update_alliances()
	_talent_gen_move()


func _monthly_income() -> void:
	for country in CountryListCache.country_dictionary.values():
		if country.get_have_city_num() <= 0:
			continue
		for city_id in country.cityIDs:
			var city := CityListCache.get_city_by_city_id(city_id)
			if city == null:
				continue
			city.add_gold(city.money_income())
			city.add_food(city.food_income())
			city.soldier_eat_food()
			city.pay_salaries()


func _update_alliances() -> void:
	for country in CountryListCache.country_dictionary.values():
		for alliance in country.allianceList.duplicate():
			alliance.months -= 1
			if alliance.months <= 0:
				country.allianceList.erase(alliance)
				var other := CountryListCache.get_country_by_country_id(alliance.countryId)
				if other != null:
					other.remove_alliance(country.countryId)


## 起义
func _uprising() -> void:
	for city in CityListCache.city_dictionary.values():
		if city.is_rebel():
			var general := GeneralListCache.get_general(city.prefectID)
			var old_country := CountryListCache.get_country_by_king_id(city.ownerID)
			if old_country != null:
				old_country.remove_city(city.cityID)
			var new_country := Country.new()
			new_country.countryId = CountryListCache.get_country_size() + 1
			new_country.countryKingId = general.generalId
			city.prefectID = general.generalId
			new_country.add_city(city.cityID)
			CountryListCache.add_country(new_country)
			CountryListCache.country_sequence.insert(0, new_country.countryId)
			GameInfo.show_info = "%s在%s起义！" % [general.generalName, city.cityName]
			return


## 灾难判定
func _check_disasters() -> void:
	for cid in range(1, CityListCache.CITY_NUM):
		var city := CityListCache.get_city_by_city_id(cid)
		if city == null:
			continue
		if _natural_disaster_rate(city):
			continue
		if _plague_rate(city):
			continue
		if city.ownerID > 0:
			_turmoil_rate(city)


func _natural_disaster_rate(city: City) -> bool:
	if randi_range(0, 499) < 5:
		_handle_natural_disaster(city)
		var kinds := ["旱灾", "洪涝", "蝗灾"]
		GameInfo.show_info = "%s发生%s" % [city.cityName, kinds[randi_range(0, 2)]]
		return true
	return false


func _plague_rate(city: City) -> bool:
	if randi_range(0, 499) <= 2:
		_handle_plague(city)
		GameInfo.show_info = "%s发生瘟疫" % city.cityName
		return true
	return false


func _turmoil_rate(city: City) -> bool:
	var rule := city.get_rule()
	var chance := 1000
	if rule < 15:
		chance = rule * 10 / 15 + 80
	elif rule < 30:
		chance = (rule - 15) / 3 + 90
	elif rule < 40:
		chance = (rule - 30) / 5 + 98
	elif rule < 60:
		chance = (rule - 40) / 5 + 998
	var random := randi_range(0, 100) if rule < 60 else randi_range(0, 1000)
	if random >= chance:
		_handle_turmoil(city)
		GameInfo.show_info = "%s发生骚乱" % city.cityName
		return true
	return false


func _disaster_loss(param: int, flood_control: int, cap: int) -> int:
	param /= 2
	return flood_control * param / cap


func _handle_natural_disaster(city: City) -> void:
	var flood_control := city.get_flood_control()
	if flood_control < 90:
		city.sub_gold(_disaster_loss(city.get_money(), flood_control, 90))
		city.sub_food(_disaster_loss(city.get_food(), flood_control, 90))
		city.sub_rule(_disaster_loss(city.get_rule(), flood_control, 90))
	if flood_control < 99:
		city.sub_trade(_disaster_loss(city.get_trade(), flood_control, 99))
		city.sub_agro(_disaster_loss(city.get_agro(), flood_control, 99))
	if flood_control > 0:
		city.sub_flood_control(flood_control / 10 + 1)


func _handle_plague(city: City) -> void:
	var flood_control := city.get_flood_control()
	if flood_control < 90:
		for gid in city.get_officer_ids():
			var general := GeneralListCache.get_general(gid)
			general.soldiers -= _disaster_loss(general.soldiers, flood_control, 90)
		city.reserveSoldiers -= _disaster_loss(city.reserveSoldiers, flood_control, 90)
		city.sub_rule(_disaster_loss(city.get_rule(), flood_control, 90))
	if flood_control < 99:
		city.sub_population(_disaster_loss(city.get_population(), flood_control, 99))
	if flood_control > 0:
		city.sub_flood_control(flood_control / 10 + 1)


func _handle_turmoil(city: City) -> void:
	var rule := city.get_rule()
	var gold := city.get_money()
	var food := city.get_food()
	var agro := city.get_agro()
	var trade := city.get_trade()
	var population := city.get_population()
	var officers := city.get_officer_ids()
	if rule < 15:
		city.set_population(population / 3)
		city.set_agro(agro / 3)
		city.set_trade(trade / 3)
		city.set_money(gold / 2)
		city.set_food(food / 2)
		city.sub_rule(randi_range(0, 14))
		for gid in officers:
			var general := GeneralListCache.get_general(gid)
			general.soldiers -= randi_range(general.soldiers * 1 / 3, general.soldiers * 2 / 3)
	elif rule < 30:
		city.set_population(population / 2)
		city.set_agro(agro / 2)
		city.set_trade(trade / 2)
		city.set_money(gold * 3 / 7)
		city.set_food(food * 3 / 7)
		city.sub_rule(randi_range(10, 19))
		for gid in officers:
			var general := GeneralListCache.get_general(gid)
			general.soldiers -= randi_range(general.soldiers * 1 / 4, general.soldiers * 1 / 2)
	else:
		city.set_population(population * 2 / 3)
		city.set_agro(agro * 2 / 3)
		city.set_trade(trade * 2 / 3)
		city.set_money(gold * 1 / 7)
		city.set_food(food * 1 / 7)
		city.sub_rule(randi_range(15, 24))
		for gid in officers:
			var general := GeneralListCache.get_general(gid)
			general.soldiers -= randi_range(general.soldiers * 1 / 5, general.soldiers * 1 / 4)


## 月度武将处理（伤病恢复/下野/士气）
func _handle_city_generals() -> void:
	for city in CityListCache.city_dictionary.values():
		for gid in city.get_officer_ids().duplicate():
			var general := GeneralListCache.get_general(gid)
			if general == null:
				continue
			# 体力恢复
			if general.health < general.maxHealth:
				general.add_hp(2)
			# 监狱处理
		for gid in city.get_capture_list().duplicate():
			var general := GeneralListCache.get_general(gid)
			if general != null and general.loyalty >= 80:
				city.remove_capture(gid)
				city.add_office_general_id(gid)


## 在野武将流动
func _talent_gen_move() -> void:
	for city in CityListCache.city_dictionary.values():
		var talents: Array = city.get_talent_ids()
		if talents.is_empty():
			continue
		var gid: int = talents[0]
		var general := GeneralListCache.get_general(gid)
		# 有势力的城市有时招募在野武将
		if city.ownerID != 0 and randf() < 0.15:
			if city.is_employ(city.get_officer_ids()[0] if not city.get_officer_ids().is_empty() else city.ownerID, gid):
				city.remove_reserved_general_id(gid)
