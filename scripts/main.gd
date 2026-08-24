extends Control

func _ready() -> void:
	print("[Test] 开始加载配置...")
	DataManager.load_all_configs()
	print("[Test] 武将总数: %d" % GeneralListCache.get_total_general_num())
	print("[Test] 已登场: %d" % GeneralListCache.get_debted_general_num())
	print("[Test] 未登场: %d" % GeneralListCache.get_total_no_debut_general_num())
	print("[Test] 城市数: %d" % CityListCache.get_city_num())
	print("[Test] 势力数: %d" % CountryListCache.get_country_size())
	print("[Test] 武器数: %d" % WeaponListCache.get_weapon_size())
	var king := GeneralListCache.get_general(CountryListCache.get_country_by_country_id(1).countryKingId)
	print("[Test] 势力1君主: %s" % king.generalName)
	var city := CityListCache.get_city_by_city_id(1)
	print("[Test] 城1: %s 农业=%d 商业=%d 人口=%d" % [city.cityName, city.agriculture, city.commerce, city.population])
	print("[Test] 城1收入: 钱=%d 粮=%d" % [city.money_income(), city.food_income()])
	print("[Test] 襄平官员数: %d" % city.get_city_officer_num())
	print("[Test] 阵型数: %d" % (DataManager.get_formation("h0").size() if DataManager.get_formation("h0").size() > 0 else 0))
	print("[Test] 阵型h0 行数: %d" % (DataManager.get_formation("h0").size() if DataManager.get_formation("h0").size() > 0 else 0))
	var m := DataManager.read_map_data(1)
	print("[Test] 地图1: %d 行" % m.size())
	var total_office := 0
	for cid in CityListCache.city_dictionary.keys():
		var c: City = CityListCache.city_dictionary[cid]
		total_office += c.get_city_officer_num()
	print("[Test] 全图在职武将总数: %d" % total_office)
	print("[Test] 数据层验证完成")
