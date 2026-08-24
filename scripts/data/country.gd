class_name Country
extends RefCounted
## 势力类

var countryId: int = 0
var countryKingId: int = 0
var countryColor: String = ""
var canBeChoose: bool = false
var inheritors: Array = []           # 继承武将ID
var cityIDs: Array = []              # 势力所有城市ID
var allianceList: Array = []         # 盟友列表


func king_name() -> String:
	var king := GeneralListCache.get_general(countryKingId)
	if king != null:
		return king.generalName
	return ""


func find_city_of_general(general_id: int) -> int:
	for city_id in cityIDs:
		var city := CityListCache.get_city_by_city_id(city_id)
		if city == null:
			continue
		if general_id in city.get_officer_ids():
			return city_id
	return 0


func _inherit_score(general_id: int) -> int:
	var general := GeneralListCache.get_general(general_id)
	var score := general.wisdom + general.lead + general.charm
	if general.wisdom >= 95: score += 100
	elif general.wisdom >= 90: score += 70
	elif general.wisdom >= 80: score += 40
	elif general.wisdom >= 70: score += 20
	if general.lead >= 95: score += 50
	elif general.lead >= 90: score += 30
	elif general.lead >= 80: score += 20
	elif general.lead >= 70: score += 10
	if general.charm >= 95: score += 50
	elif general.charm >= 90: score += 40
	elif general.charm >= 80: score += 20
	elif general.charm >= 70: score += 10
	return score


func get_inherit_general_id() -> int:
	for id in inheritors:
		var general := GeneralListCache.get_general(id)
		if general != null and find_city_of_general(id) != 0:
			return id
	var max_value := 0
	var general_id := 0
	for city_id in cityIDs:
		var city := CityListCache.get_city_by_city_id(city_id)
		for id in city.get_officer_ids():
			var value := _inherit_score(id)
			if value > max_value:
				max_value = value
				general_id = id
	return general_id


func find_king_city() -> int:
	for city_id in cityIDs:
		var city := CityListCache.get_city_by_city_id(city_id)
		if city != null and city.prefectID == countryKingId:
			return city_id
	return 0


func find_vacant_city() -> Array:
	for id in cityIDs:
		var city := CityListCache.get_city_by_city_id(id)
		if city.get_city_officer_num() < 10:
			return [true, id]
	return [false, 0]


func get_vacant_officer_num() -> int:
	var num := 10 * cityIDs.size()
	for id in cityIDs:
		num -= CityListCache.get_city_by_city_id(id).get_city_officer_num()
	return num


func inherit() -> int:
	var inherit_general_id := get_inherit_general_id()
	if inherit_general_id != 0:
		inherit_id(inherit_general_id)
	return inherit_general_id


func inherit_id(inherit_general_id: int) -> void:
	var old_king := GeneralListCache.get_general(countryKingId).generalName
	for cur_city in cityIDs:
		var city := CityListCache.get_city_by_city_id(cur_city)
		city.ownerID = inherit_general_id
	var city_id := find_city_of_general(inherit_general_id)
	if city_id == 0:
		return
	var live_city := CityListCache.get_city_by_city_id(city_id)
	live_city.appoint_prefect(inherit_general_id)
	var general := GeneralListCache.get_general(inherit_general_id)
	general.set_loyalty(100)
	GameInfo.show_info = "原%s势力的%s继承了势力" % [old_king, general.generalName]
	countryKingId = inherit_general_id


func get_country_soldier_num() -> int:
	var total := 0
	for city_id in cityIDs:
		total += CityListCache.get_city_by_city_id(city_id).get_city_all_soldier_num()
	return total


func get_max_country_soldier_num() -> int:
	var total := 0
	for city_id in cityIDs:
		total += CityListCache.get_city_by_city_id(city_id).get_max_soldier_num()
	return total


func get_have_city_num() -> int:
	return cityIDs.size()


func is_endangered() -> bool:
	return cityIDs.size() <= 1


func is_destroyed() -> bool:
	return cityIDs.size() <= 0


func add_city(city_id: int) -> bool:
	if city_id == 0:
		return false
	if city_id in cityIDs:
		return true
	var city := CityListCache.get_city_by_city_id(city_id)
	city.ownerID = countryKingId
	cityIDs.append(city_id)
	return true


func remove_city(city_id: int) -> bool:
	if city_id == 0:
		return false
	if city_id not in cityIDs:
		return false
	var city := CityListCache.get_city_by_city_id(city_id)
	city.prefectID = 0
	city.ownerID = 0
	cityIDs.erase(city_id)
	return true


func truce(other_country_id: int) -> bool:
	var country_king := GeneralListCache.get_general(countryKingId)
	var other_country := CountryListCache.get_country_by_country_id(other_country_id)
	var other_country_king := GeneralListCache.get_general(other_country.countryKingId)
	var d := GeneralListCache.get_phase_difference(country_king, other_country_king)
	if d + other_country.get_have_city_num() <= randi_range(0, 74):
		add_alliance(other_country.countryId)
		return true
	return false


func is_alliance(city_id: int) -> bool:
	var city := CityListCache.get_city_by_city_id(city_id)
	var belong_king := city.ownerID
	if belong_king == 0:
		return false
	var other_country := CountryListCache.get_country_by_king_id(belong_king)
	if other_country == null:
		return false
	var alliance := get_alliance_by_id(other_country.countryId)
	return alliance != null


func get_alliance_size() -> int:
	return allianceList.size()


func get_alliance_by_id(country_id: int) -> Alliance:
	for alliance in allianceList:
		if alliance.countryId == country_id:
			return alliance
	return null


func add_alliance_by_obj(alliance: Alliance) -> void:
	if get_alliance_by_id(alliance.countryId) != null:
		return
	allianceList.append(alliance)
	var country := CountryListCache.get_country_by_country_id(alliance.countryId)
	if country == null:
		return
	var reverse := Alliance.new(countryId, alliance.months)
	country.add_alliance_by_obj(reverse)


func add_alliance(other_country_id: int) -> void:
	if get_alliance_by_id(other_country_id) != null:
		return
	var alliance := Alliance.new(other_country_id, 12)
	allianceList.append(alliance)
	var country := CountryListCache.get_country_by_country_id(other_country_id)
	var reverse := Alliance.new(countryId, 12)
	country.add_alliance_by_obj(reverse)


func remove_alliance(country_id: int) -> bool:
	var result := false
	for i in allianceList.size():
		var alliance: Alliance = allianceList[i]
		if alliance.countryId == country_id:
			allianceList.remove_at(i)
			var country := CountryListCache.get_country_by_country_id(country_id)
			if country == null:
				return false
			if country_id == GameInfo.playerCountryId:
				result = true
			country.remove_alliance(countryId)
			break
	return result


func remove_all_alliance() -> void:
	while allianceList.size() > 0:
		var alliance: Alliance = allianceList[0]
		allianceList.remove_at(0)
		var country := CountryListCache.get_country_by_country_id(alliance.countryId)
		if country != null:
			country.remove_alliance(countryId)


func get_no_country_id_alliance_country_id_array() -> Array:
	var country_id_list := []
	for country in CountryListCache.country_dictionary.values():
		if country != null and country.get_have_city_num() >= 1 and country.countryId != countryId:
			var have_alliance := false
			for alliance in allianceList:
				if alliance.countryId == country.countryId:
					have_alliance = true
					break
			if not have_alliance:
				country_id_list.append(country.countryId)
	return country_id_list


func get_no_alliance_country_size() -> int:
	return get_no_country_id_alliance_country_id_array().size()


func need_alms() -> void:
	for city_id in cityIDs:
		var city := CityListCache.get_city_by_city_id(city_id)
		if city.get_money() <= 100:
			city.add_gold(randi_range(0, 199))
		if city.get_food() <= 300:
			city.add_food(randi_range(0, 399))


func ai_retreat_add_resources_to_city(city_id: int, money: int, food: int) -> void:
	if city_id == 0 or city_id not in cityIDs:
		return
	var remaining_money := money
	var remaining_food := food
	var city := CityListCache.get_city_by_city_id(city_id)
	city.add_gold(remaining_money)
	city.add_food(remaining_food)
	remaining_money -= (city.get_money() - (city.get_money() - money))
	remaining_food -= (city.get_food() - (city.get_food() - food))
	for id in cityIDs:
		if id != city_id:
			var other_city := CityListCache.get_city_by_city_id(id)
			var add_money := mini(remaining_money, 30000 - other_city.get_money())
			var add_food := mini(remaining_food, 30000 - other_city.get_food())
			other_city.add_gold(add_money)
			other_city.add_food(add_food)
			remaining_money -= add_money
			remaining_food -= add_food
			if remaining_money <= 0 and remaining_food <= 0:
				break


func ai_retreat_general_to_city(general_id_array: Array, cur_city_id: int, food: int, money: int, commander_captured: bool) -> bool:
	var retreat := false
	var cur_city := CityListCache.get_city_by_city_id(cur_city_id)
	if is_destroyed():
		for general_id in general_id_array:
			var general := GeneralListCache.get_general(general_id)
			if general != null:
				if general_id == countryKingId:
					GeneralListCache.general_die(general_id)
				elif cur_city.add_reserved_general_id(general_id):
					pass
		return false
	var index := 0
	for i in general_id_array.size():
		var general_id: int = general_id_array[i]
		var general := GeneralListCache.get_general(general_id)
		if general != null:
			for t in cityIDs:
				var city_id: int = t
				if city_id != cur_city_id:
					var city := CityListCache.get_city_by_city_id(city_id)
					if city.get_city_officer_num() <= 9 or general_id == countryKingId:
						city.add_office_general_id(general_id)
						index += 1
						if i == 0 and not commander_captured:
							city.add_food(food)
							city.add_gold(money)
							retreat = true
							break
						break
	if index < general_id_array.size() - 1:
		for idx in range(index, general_id_array.size()):
			var general_id: int = general_id_array[idx]
			var general := GeneralListCache.get_general(general_id)
			if general != null and cur_city.add_reserved_general_id(general_id):
				pass
	return not commander_captured and retreat


static func from_dict(d: Dictionary) -> Country:
	var c := Country.new()
	c.countryId = int(d.get("countryId", 0))
	c.countryKingId = int(d.get("countryKingId", 0))
	c.countryColor = str(d.get("countryColor", ""))
	c.canBeChoose = bool(d.get("canBeChoose", false))
	c.inheritors = []
	for v in (d.get("inheritors", []) if d.get("inheritors", []) is Array else []):
		c.inheritors.append(int(v))
	return c


func to_dict() -> Dictionary:
	return {
		"countryId": countryId, "countryKingId": countryKingId,
		"countryColor": countryColor, "canBeChoose": canBeChoose,
		"inheritors": inheritors, "cityIDs": cityIDs,
	}
