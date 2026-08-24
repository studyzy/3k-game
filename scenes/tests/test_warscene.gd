extends Control
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
	var scene: PackedScene = load("res://scenes/ui/war_scene.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	print("[WarScene] 战争场景构建成功，目标城=%d 我方单位=%d 敌方单位=%d" % [WarManager.curWarCityId, WarManager.hmUnits.size(), WarManager.aiUnits.size()])
	get_tree().quit()
