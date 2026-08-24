extends Control
## 战前布阵 + 战斗结算测试

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
	WarManager.war_prepare(false, target, pc.cityIDs[0], [pc.countryKingId], 500, 300)
	# 只留一个敌人
	if WarManager.aiUnits.size() > 1:
		for extra in WarManager.aiUnits.duplicate():
			if extra != WarManager.aiUnits[0]:
				WarManager.aiUnits.erase(extra)
	WarManager.start_player_turn()
	# 把玩家第一个单位移到敌人旁边
	var u: UnitData = WarManager.hmUnits[0]
	var e: UnitData = WarManager.aiUnits[0]
	var adjacent_cell := Vector2i(e.arrayPos.x - 1, e.arrayPos.y)
	if adjacent_cell.x < 0:
		adjacent_cell = Vector2i(e.arrayPos.x + 1, e.arrayPos.y)
	WarManager.move_unit_to_cell(u, adjacent_cell)
	print("[PreBattle] 玩家单位已移到敌人旁：%s 相邻 %s" % [str(u.arrayPos), str(e.arrayPos)])
	# 设置 pending 并加载布阵场景
	BattleManager.pendingPlayerUnit = u
	BattleManager.pendingEnemyUnit = e
	var scene: PackedScene = load("res://scenes/ui/pre_battle.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	print("[PreBattle] 布阵场景构建成功")
	# 触发开战
	inst._on_fight()
	# 检查战斗结果（场景切换在帧末执行，此刻状态已更新）
	var p_gen := GeneralListCache.get_general(u.genID)
	var e_gen := GeneralListCache.get_general(e.genID)
	print("[PreBattle] 战斗后：玩家兵=%d 敌兵=%d" % [p_gen.soldiers, e_gen.soldiers])
	print("[PreBattle] 战后我方单位=%d 敌方单位=%d" % [WarManager.hmUnits.size(), WarManager.aiUnits.size()])
	if WarManager.aiUnits.is_empty() or WarManager.hmUnits.is_empty():
		print("[PreBattle] 战争已结束（一方全灭）")
		print("[PreBattle] show_info: %s" % GameInfo.show_info)
	print("[PreBattle] 战前布阵流程测试完成")
	get_tree().quit()
