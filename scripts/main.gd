extends Control
## 数据层自测脚本（手动运行，需先启动服务器）：
## 从服务器拉取静态数据后，打印武将/城池/势力/武器/阵型/地图数量，校验数据层缓存。

func _ready() -> void:
	print("[Test] 拉取静态数据...")
	NetClient.static_done.connect(_run_tests)
	NetClient.static_failed.connect(func(msg: String): print("[Test] 拉取失败: " + msg))
	NetClient.fetch_static()


func _run_tests() -> void:
	print("[Test] 武将总数: %d" % GeneralListCache.get_total_general_num())
	print("[Test] 已登场: %d" % GeneralListCache.get_debted_general_num())
	print("[Test] 未登场: %d" % GeneralListCache.get_total_no_debut_general_num())
	print("[Test] 城市数: %d" % CityListCache.get_city_num())
	print("[Test] 势力数: %d" % CountryListCache.get_country_size())
	print("[Test] 武器数: %d" % WeaponListCache.get_weapon_size())
	print("[Test] 剧本数: %d" % DataManager.chapters.size())
	var king := GeneralListCache.get_general(CountryListCache.get_country_by_country_id(1).countryKingId)
	print("[Test] 势力1君主: %s" % king.generalName)
	var city := CityListCache.get_city_by_city_id(1)
	print("[Test] 城1: %s 农业=%d 商业=%d 人口=%d" % [city.cityName, city.agriculture, city.commerce, city.population])
	print("[Test] 城1收入: 钱=%d 粮=%d" % [city.money_income(), city.food_income()])
	print("[Test] 襄平官员数: %d" % city.get_city_officer_num())
	print("[Test] 阵型h0 行数: %d" % DataManager.get_formation("h0").size())
	print("[Test] 地图1 行数: %d" % DataManager.read_map_data(1).size())
	var total_office := 0
	for cid in CityListCache.city_dictionary.keys():
		var c: City = CityListCache.city_dictionary[cid]
		total_office += c.get_city_officer_num()
	print("[Test] 全图在职武将总数: %d" % total_office)
	print("[Test] 数据层验证完成")
