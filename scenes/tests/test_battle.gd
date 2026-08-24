extends Control
## 战术战斗场景测试

func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	var pc := CountryListCache.get_country_by_country_id(1)
	# 构造战争
	var target := 0
	var atk_city := CityListCache.get_city_by_city_id(pc.cityIDs[0])
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
	WarManager.start_player_turn()
	# 设置 pending 战斗
	var u: UnitData = WarManager.hmUnits[0]
	var e: UnitData = WarManager.aiUnits[0]
	BattleManager.pendingPlayerUnit = u
	BattleManager.pendingEnemyUnit = e
	# 加载战术战斗场景
	var scene: PackedScene = load("res://scenes/ui/battle_scene.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	print("[Battle] 战术战斗场景已加载，等待战斗推进...")
	# 等待战斗结束（场景内循环推进）
	await get_tree().create_timer(30.0).timeout
	print("[Battle] 30秒后：我方单位=%d 敌方单位=%d" % [WarManager.hmUnits.size(), WarManager.aiUnits.size()])
	print("[Battle] 战术战斗测试完成")
	get_tree().quit()
