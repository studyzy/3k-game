extends Control
## 手动网格战斗流程测试

func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	var pc := CountryListCache.get_country_by_country_id(1)
	var atk_city := CityListCache.get_city_by_city_id(pc.cityIDs[0])
	var target := 0
	for cid in pc.cityIDs:
		var c := CityListCache.get_city_by_city_id(cid)
		for adj in c.connectCityId:
			var ac := CityListCache.get_city_by_city_id(adj)
			if ac.ownerID != c.ownerID and ac.ownerID != 0:
				target = adj
				break
		if target != 0: break
	var atk_ids := atk_city.get_officer_ids()
	if atk_ids.is_empty(): atk_ids = [pc.countryKingId]
	WarManager.war_prepare(false, target, pc.cityIDs[0], atk_ids, 500, 300)
	print("[Grid] 战争开始：我方%d单位 vs 敌方%d单位" % [WarManager.hmUnits.size(), WarManager.aiUnits.size()])
	WarManager.start_player_turn()
	var bonuses := []
	for uu in WarManager.hmUnits:
		bonuses.append(uu.moveBonus)
	print("[Grid] 第1天 我方机动: %s" % str(bonuses))
	# 模拟玩家选择第一个单位并移动
	var u: UnitData = WarManager.hmUnits[0]
	var cells := MapManager.get_movable_cells_astar(u, WarManager.war_map)
	print("[Grid] 单位%d 可移动格数: %d" % [u.genID, cells.size()])
	if cells.is_empty():
		print("[Grid] 无可移动格，失败")
		get_tree().quit()
		return
	# 移动到离敌人最近的可达格
	var best_cell: Vector2i = cells.keys()[0]
	var best_d := 1e9
	for cell in cells.keys():
		var d := Vector2i(cell - WarManager.aiUnits[0].arrayPos).length_squared()
		if d < best_d:
			best_d = d
			best_cell = cell
	WarManager.move_unit_to_cell(u, best_cell)
	print("[Grid] 单位移动到 %s，剩余机动=%d" % [str(best_cell), u.moveBonus])
	# 结束回合 -> AI 行动 -> 下一天
	var day_before := WarManager.day
	WarManager.end_player_turn()
	WarManager.next_day()
	print("[Grid] 第%d天（原%d），我方单位=%d 敌方单位=%d" % [WarManager.day, day_before, WarManager.hmUnits.size(), WarManager.aiUnits.size()])
	# 检查相邻交战
	var adj := WarManager.find_adjacent_battle()
	print("[Grid] 相邻交战对: %s" % ("有" if not adj.is_empty() else "无"))
	# 模拟多次回合直到战争结束
	var guard := 0
	while WarManager.hmUnits.size() > 0 and WarManager.aiUnits.size() > 0 and guard < 20:
		guard += 1
		WarManager.start_player_turn()
		# 每个玩家单位向最近敌人移动
		for uu in WarManager.hmUnits.duplicate():
			if uu.isMoved:
				continue
			var ecells := MapManager.get_movable_cells_astar(uu, WarManager.war_map)
			if ecells.is_empty():
				continue
			var target_cell: Vector2i = ecells.keys()[0]
			var td := 1e9
			for cell in ecells.keys():
				var d := Vector2i(cell - WarManager.aiUnits[0].arrayPos).length_squared() if not WarManager.aiUnits.is_empty() else 0
				if d < td:
					td = d
					target_cell = cell
			WarManager.move_unit_to_cell(uu, target_cell)
		WarManager.end_player_turn()
		WarManager.next_day()
	print("[Grid] 战争结束于第%d天：我方剩%d 敌方剩%d" % [WarManager.day, WarManager.hmUnits.size(), WarManager.aiUnits.size()])
	get_tree().quit()
