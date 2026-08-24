extends Node
## 势力缓存（autoload: CountryListCache）

var country_dictionary: Dictionary = {}  # id -> Country
var country_sequence: Array = []         # 回合顺序
var _country_colors := {}                # 已用颜色
var max_country_id: int = 0


func clear_all_countries() -> void:
	country_dictionary.clear()


## 自建新势力
func self_build_country(city_id: int, king_id: int, general_ids: Array) -> void:
	var country := Country.new()
	country.countryId = get_country_size() + 1
	country.countryKingId = king_id
	var city := CityListCache.get_city_by_city_id(city_id)
	city.ownerID = king_id
	for id in general_ids:
		city.add_office_general_id(id)
	city.appoint_prefect(king_id)
	country.add_city(city_id)
	var remaining := general_ids.duplicate()
	remaining.erase(king_id)
	country.inheritors = remaining
	add_country(country)
	GameInfo.playerCountryId = country.countryId


func _generate_unique_color() -> String:
	var color_str := ""
	var is_unique := false
	while not is_unique:
		var r := randf_range(0.2, 0.8)
		var g := randf_range(0.2, 0.8)
		var b := randf_range(0.2, 0.8)
		color_str = "#%02X%02X%02X" % [int(r * 255), int(g * 255), int(b * 255)]
		is_unique = not _country_colors.has(color_str)
	_country_colors[color_str] = true
	return color_str


func add_country(country: Country) -> void:
	if country.countryId == 0:
		return
	var king_id: int = country.countryKingId
	var general := GeneralListCache.get_general(king_id)
	if general != null:
		general.set_loyalty(100)
	if country.countryColor.is_empty():
		country.countryColor = _generate_unique_color()
	elif _country_colors.has(country.countryColor):
		country.countryColor = _generate_unique_color()
	country_dictionary[country.countryId] = country
	_country_colors[country.countryColor] = true


## 势力灭亡
func remove_country(country_id: int) -> void:
	var country := get_country_by_country_id(country_id)
	if country == null:
		return
	country.remove_all_alliance()
	if country.get_have_city_num() > 0:
		return
	var general := GeneralListCache.get_general(country.countryKingId)
	if general == null:
		pass
	else:
		GameInfo.chooseGeneralName = general.generalName
	remove_sequence(country_id)
	if GameInfo.playerCountryId == country_id:
		GameInfo.countryDieTips = 4
	else:
		GameInfo.countryDieTips = 3
		GameInfo.show_info = "%s 势力灭亡了!" % GameInfo.chooseGeneralName
	country_dictionary.erase(country_id)


func king_name(country_id: int) -> String:
	var country := get_country_by_country_id(country_id)
	if country == null:
		return ""
	var king := GeneralListCache.get_general(country.countryKingId)
	if king != null:
		return king.generalName
	return ""


func get_country_size() -> int:
	return country_dictionary.size()


func get_can_be_choose_country_size() -> int:
	var count := 0
	for country in country_dictionary.values():
		if country.canBeChoose:
			count += 1
	return count


func get_country_by_country_id(id: int) -> Country:
	if country_dictionary.has(id):
		return country_dictionary[id]
	return null


func get_can_be_choose_country_by_index(id: int) -> Country:
	var i := 0
	for country in country_dictionary.values():
		if country == null:
			break
		if country.canBeChoose:
			if i == id:
				return country
			i += 1
	return null


func get_country_by_king_id(king_id: int) -> Country:
	for country in country_dictionary.values():
		if country.countryKingId == king_id:
			return country
	return null


func turn_sort() -> void:
	var is_flush := false
	for key in country_dictionary.keys():
		var pair_key: int = key
		if pair_key <= 0:
			break
		var country: Country = country_dictionary[pair_key]
		if country.get_have_city_num() <= 0 and country_sequence.has(pair_key):
			country_sequence.erase(pair_key)
		elif not country_sequence.has(pair_key):
			is_flush = true
			country_sequence.append(pair_key)
	if is_flush:
		country_sequence.sort_custom(func(a, b): return get_country_by_country_id(a).get_have_city_num() < get_country_by_country_id(b).get_have_city_num())


func add_sequence(country_id: int, insert_after: int = -1) -> void:
	if country_sequence.has(country_id):
		return
	if insert_after >= 0:
		var insert_index := country_sequence.find(insert_after)
		if insert_index != -1:
			country_sequence.insert(insert_index + 1, country_id)
		else:
			country_sequence.append(country_id)
	else:
		country_sequence.append(country_id)


func remove_sequence(country_id: int) -> void:
	var index := country_sequence.find(country_id)
	if index != -1:
		country_sequence.remove_at(index)
		if index <= GameInfo.curTurnIndex:
			GameInfo.curTurnIndex = (GameInfo.curTurnIndex - 1 + country_sequence.size()) % country_sequence.size()


func get_current_execution_country_id() -> int:
	if country_sequence.is_empty():
		turn_sort()
		return country_sequence[0]
	GameInfo.curTurnIndex = (GameInfo.curTurnIndex + 1) % country_sequence.size()
	var seq_id: int = country_sequence[GameInfo.curTurnIndex]
	if seq_id != 0:
		var next_country := get_country_by_country_id(seq_id)
		if next_country != null and next_country.get_have_city_num() > 0:
			return seq_id
	return country_sequence[0]


func get_enemy_adjacent_city_defense_ability(def_city: City, atk_city: City) -> int:
	var atk_country := get_country_by_king_id(atk_city.ownerID)
	var max_defense_ability := def_city.get_defense_ability()
	var city_id_array: Array = def_city.connectCityId
	for temp_city_id in city_id_array:
		if temp_city_id != atk_city.cityID:
			var temp_city := CityListCache.get_city_by_city_id(temp_city_id)
			if temp_city.ownerID != 0:
				if temp_city.ownerID == atk_city.ownerID or atk_country.is_alliance(temp_city_id):
					max_defense_ability -= int(temp_city.get_max_atk_power() * 0.2)
				else:
					max_defense_ability += int(temp_city.get_max_atk_power() * 0.1)
	return max_defense_ability


func get_enemy_adjacent_city_id_array(country_id: int) -> Array:
	var result := []
	var country := get_country_by_country_id(country_id)
	for city_id in country.cityIDs:
		var connect_ids: Array = CityListCache.get_city_by_city_id(city_id).connectCityId
		var have_enemy := false
		for adj_city_id in connect_ids:
			var belong_king: int = CityListCache.get_city_by_city_id(adj_city_id).ownerID
			if belong_king != country.countryKingId:
				var other_country := get_country_by_king_id(belong_king)
				if other_country != null and other_country.get_alliance_by_id(country_id) == null:
					have_enemy = true
					break
		if have_enemy:
			result.append(city_id)
	return result


func get_no_enemy_adjacent_city_id_array(country_id: int) -> Array:
	var result := []
	var country := get_country_by_country_id(country_id)
	for city_id in country.cityIDs:
		var connect_ids: Array = CityListCache.get_city_by_city_id(city_id).connectCityId
		var no_have_enemy := true
		for adj_city_id in connect_ids:
			var belong_king: int = CityListCache.get_city_by_city_id(adj_city_id).ownerID
			if belong_king != country.countryKingId:
				var other_country := get_country_by_king_id(belong_king)
				if other_country != null and other_country.get_alliance_by_id(country_id) == null:
					no_have_enemy = false
					break
		if no_have_enemy:
			result.append(city_id)
	return result


func get_adjacent_enemy_city_ids(city_id: int) -> Array:
	var city := CityListCache.get_city_by_city_id(city_id)
	var king_id: int = city.ownerID
	var country := get_country_by_king_id(king_id)
	var connect_ids: Array = city.connectCityId
	var result := []
	for adj_city_id in connect_ids:
		var belong_king: int = CityListCache.get_city_by_city_id(adj_city_id).ownerID
		if belong_king != king_id:
			var other_country := get_country_by_king_id(belong_king)
			if other_country == null or other_country.get_alliance_by_id(country.countryId) == null:
				result.append(adj_city_id)
	return result


func get_enemy_city_id_array_new(city_id: int) -> Array:
	var king_id: int = CityListCache.get_city_by_city_id(city_id).ownerID
	var connect_ids: Array = CityListCache.get_city_by_city_id(city_id).connectCityId
	var result := []
	for temp_city_id in connect_ids:
		var belong_king: int = CityListCache.get_city_by_city_id(temp_city_id).ownerID
		if belong_king != king_id:
			result.append(temp_city_id)
	return result


func get_enemy_adjacent_max_atk_power(city_id: int) -> int:
	var city := CityListCache.get_city_by_city_id(city_id)
	var king_id: int = city.ownerID
	var country := get_country_by_king_id(king_id)
	var max_power := 0
	for adj_city_id in city.connectCityId:
		var other_city := CityListCache.get_city_by_city_id(adj_city_id)
		var belong_king: int = other_city.ownerID
		if belong_king != king_id:
			var other_country := get_country_by_king_id(belong_king)
			if other_country != null and other_country.get_alliance_by_id(country.countryId) == null:
				var power := other_city.get_max_atk_power()
				if power > max_power:
					max_power = power
	return max_power


func get_other_city_max_atk_power(city_id: int, be_city_id: int) -> int:
	var king_id: int = CityListCache.get_city_by_city_id(city_id).ownerID
	var country := get_country_by_king_id(king_id)
	var connect_ids: Array = CityListCache.get_city_by_city_id(city_id).connectCityId
	var powers: Array = []
	for i in connect_ids.size():
		if be_city_id != connect_ids[i]:
			var belong_king: int = CityListCache.get_city_by_city_id(connect_ids[i]).ownerID
			if belong_king != king_id:
				var other_country := get_country_by_king_id(belong_king)
				if other_country != null and other_country.get_alliance_by_id(country.countryId) == null:
					powers.append(CityListCache.get_city_by_city_id(connect_ids[i]).get_max_atk_power())
	if powers.is_empty():
		return 0
	var max_atk: int = powers[0]
	for p in powers:
		max_atk = maxi(max_atk, p)
	return max_atk


func get_max_atk_power_in_enemy_cities(city: City, exclude_city: City) -> int:
	if city == null:
		return 0
	var tar_king_id: int = city.ownerID
	var connect_ids: Array = city.connectCityId
	var result: Array = []
	for i in connect_ids.size():
		if connect_ids[i] == exclude_city.cityID:
			continue
		var connected_city := CityListCache.get_city_by_city_id(connect_ids[i])
		if connected_city == null:
			continue
		var belong_king: int = connected_city.ownerID
		if belong_king != 0 and belong_king != tar_king_id:
			var other_country := get_country_by_king_id(belong_king)
			if other_country == null:
				continue
			if other_country.get_alliance_by_id(get_country_by_king_id(exclude_city.ownerID).countryId) == null:
				result.append(connected_city.get_max_atk_power())
	if result.is_empty():
		return 0
	var max_atk: int = result[0]
	for p in result:
		max_atk = maxi(max_atk, p)
	return max_atk


func get_ai_order_num(cur_turns_country_id: int) -> int:
	var have_city_num := get_country_by_country_id(cur_turns_country_id).get_have_city_num()
	if have_city_num < 3:
		have_city_num = 3
	elif have_city_num > 8:
		have_city_num = 8
	return have_city_num
