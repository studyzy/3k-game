extends Control
## 战前布阵 + 战斗结算测试
##
## headless 下无法调用 pre_battle._on_fight()——其内部 SceneRouter.change_scene
## 会切换当前场景并销毁本测试节点，导致后续检查无法执行。故本测试手动执行
## _on_fight 的同步战斗结算逻辑（BattleManager.simulated_battle），headless 下可靠。

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
	# 设置 pending 并加载布阵场景（仅实例化验证，不 add_child 触发其流程）
	BattleManager.pendingPlayerUnit = u
	BattleManager.pendingEnemyUnit = e
	var scene: PackedScene = load("res://scenes/ui/pre_battle.tscn")
	var inst := scene.instantiate()
	assert(inst != null)
	inst.free()
	print("[PreBattle] 布阵场景构建成功")
	# 手动执行 _on_fight 的战斗结算逻辑（模拟战斗，不切换场景）
	var p_gen := GeneralListCache.get_general(u.genID)
	var e_gen := GeneralListCache.get_general(e.genID)
	assert(p_gen != null)
	assert(e_gen != null)
	var terrain := 0
	if not WarManager.war_map.is_empty():
		terrain = int(WarManager.war_map[u.arrayPos.y][u.arrayPos.x]) & 0xF
	BattleManager.init_battle(p_gen, e_gen, terrain, false)
	BattleManager.hmTurnOrder = BattleManager.create_turn_order(p_gen, true)
	BattleManager.aiTurnOrder = BattleManager.create_turn_order(e_gen, false)
	var win := BattleManager.simulated_battle()
	# 移除败方单位（与 _on_fight 一致）
	if win:
		WarManager.aiUnits.erase(e)
	else:
		WarManager.hmUnits.erase(u)
	BattleManager.pendingPlayerUnit = null
	BattleManager.pendingEnemyUnit = null
	print("[PreBattle] 战斗后：玩家兵=%d 敌兵=%d" % [p_gen.soldiers, e_gen.soldiers])
	print("[PreBattle] 战后我方单位=%d 敌方单位=%d" % [WarManager.hmUnits.size(), WarManager.aiUnits.size()])
	print("[PreBattle] 战前布阵流程测试完成")
	get_tree().quit()
