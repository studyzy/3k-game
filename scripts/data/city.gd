class_name City
extends RefCounted
## 城池类

var cityID: int = 0
var cityName: String = ""
var ownerID: int = 0       # 所属君主ID
var prefectID: int = 0     # 太守ID
var rule: int = 0          # 统治度 0-99
var money: int = 0         # 金钱
var grain: int = 0         # 粮食
var treasures: int = 0     # 宝物 0-100
var prevention: int = 0    # 防灾 0-99
var agriculture: int = 0   # 农业
var commerce: int = 0      # 商业
var population: int = 0    # 人口
var reserveSoldiers: int = 0
var cityGrainShop: bool = false
var citySchool: bool = false
var cityHospital: bool = false
var cityWeaponShop: int = 0
var warWeaponShop: int = 0

var cityOfficeGeneralId: Array = []      # 官职武将ID
var cityReservedGeneralId: Array = []    # 在野武将ID
var cityNotFoundGeneralId: Array = []    # 隐居武将ID（上限10）
var cityJailGeneralId: Array = []        # 监狱武将ID
var connectCityId: Array = []            # 连接城池
var mapPosition: Array = []              # 地图坐标

const MAX_RULE := 99
const MAX_MONEY := 30000
const MAX_GRAIN := 30000
const MAX_AGRO := 30000
const MAX_TRADE := 30000
const MAX_POP := 999999
const MAX_OFFICER := 10


func get_rule() -> int: return rule
func set_rule(num: int) -> void: rule = clampi(num, 0, MAX_RULE)
func add_rule(num: int) -> void: rule = clampi(rule + num, 0, MAX_RULE)
func sub_rule(num: int) -> void: rule = clampi(rule - num, 0, MAX_RULE)

func set_money(num: int) -> void:
	money = MAX_MONEY if (num > MAX_MONEY or num < 0) else num

func get_money() -> int: return money

func add_gold(num: int) -> int:
	if money + num > MAX_MONEY or money + num < 0:
		num = MAX_MONEY - money
		money = MAX_MONEY
	else:
		money += num
	return num

func sub_gold(num: int) -> int:
	if money - num > MAX_MONEY or money - num < 0:
		num = money
		money = 0
	else:
		money -= num
	return num

func money_income() -> int:
	var l1 := population / 400 + 1
	var i2 := l1 * commerce * 3 / 5 / 125
	l1 += i2
	i2 = 0
	if rule > 90: i2 += l1 * 4 / 5
	elif rule > 80: i2 += l1 * 3 / 5
	elif rule > 70: i2 += l1 * 2 / 5
	elif rule > 50: i2 += l1 / 5
	l1 += i2
	return l1

func food_income() -> int:
	var l1 := population / 100
	var i2 := l1 * agriculture * 4 / 5 / 125
	l1 += i2
	i2 = 0
	if rule > 90: i2 += l1 * 4 / 5
	elif rule > 80: i2 += l1 * 3 / 5
	elif rule > 70: i2 += l1 * 2 / 5
	elif rule > 50: i2 += l1 / 5
	l1 += i2
	return l1

func set_food(num: int) -> void:
	grain = MAX_GRAIN if (num > MAX_GRAIN or num < 0) else num

func get_food() -> int: return grain

func add_food(num: int) -> int:
	if grain + num > MAX_GRAIN or grain + num < 0:
		num = MAX_GRAIN - grain
		grain = MAX_GRAIN
	else:
		grain += num
	return num

func sub_food(num: int) -> int:
	if grain - num > MAX_GRAIN or grain - num < 0:
		num = grain
		grain = 0
	else:
		grain -= num
	return num

func get_treasure_num() -> int: return treasures
func set_treasure_num(num: int) -> void: treasures = clampi(num, 0, 100)

func add_treasure_num(num: int) -> int:
	if treasures + num > 100 or treasures + num < 0:
		num = 100 - treasures
		treasures = 100
	else:
		treasures += num
	return num

func sub_treasure_num(num: int) -> int:
	if treasures - num > 100 or treasures - num < 0:
		num = treasures
		treasures = 0
	else:
		treasures -= num
	return num

func get_agro() -> int: return agriculture
func set_agro(num: int) -> void: agriculture = clampi(num, 0, MAX_AGRO)
func add_agro(num: int) -> void: agriculture = clampi(agriculture + num, 0, MAX_AGRO)
func sub_agro(num: int) -> void: agriculture = clampi(agriculture - num, 0, MAX_AGRO)

func get_trade() -> int: return commerce
func set_trade(num: int) -> void: commerce = clampi(num, 0, MAX_TRADE)
func add_trade(num: int) -> void: commerce = clampi(commerce + num, 0, MAX_TRADE)
func sub_trade(num: int) -> void: commerce = clampi(commerce - num, 0, MAX_TRADE)

func get_flood_control() -> int: return prevention
func set_flood_control(num: int) -> void: prevention = clampi(num, 0, MAX_RULE)
func add_flood_control(num: int) -> void: prevention = clampi(prevention + num, 0, MAX_RULE)
func sub_flood_control(num: int) -> void: prevention = clampi(prevention - num, 0, MAX_RULE)

func get_population() -> int: return population
func set_population(num: int) -> void: population = clampi(num, 0, MAX_POP)

func add_population(num: int) -> int:
	if population + num > MAX_POP or population + num < 0:
		num = MAX_POP - population
		population = MAX_POP
	else:
		population += num
	return num

func sub_population(num: int) -> int:
	if population - num > MAX_POP or population - num < 0:
		num = population
		population = 0
	else:
		population -= num
	return num

func soldier_eat_food() -> void:
	var need_food := get_already_soldier_num() / 100 + reserveSoldiers / 300
	if need_food > grain:
		grain = 0
		reserveSoldiers = maxi(reserveSoldiers - 100, 0)
		for gid in cityOfficeGeneralId:
			var general := GeneralListCache.get_general(gid)
			general.soldiers = maxi(general.soldiers - 100, 0)
	else:
		grain -= need_food

func pay_salaries() -> void:
	for gid in cityOfficeGeneralId:
		var general := GeneralListCache.get_general(gid)
		if money <= 0:
			if general.generalId != ownerID:
				general.sub_loyalty(randi_range(0, 3) + 1)
		else:
			sub_gold(general.get_salary())

func get_prefect_id() -> int: return prefectID
func get_city_belong_king() -> int: return ownerID

func get_city_not_found_general_num() -> int:
	var n := 0
	for gid in cityNotFoundGeneralId:
		if gid > 0: n += 1
	return n

func get_city_not_found_general_id_array() -> Array:
	var result := []
	for gid in cityNotFoundGeneralId:
		if gid > 0: result.append(gid)
	return result

func get_not_found_general_id(index: int) -> int:
	return cityNotFoundGeneralId[index]

## 添加隐居（未搜索到）武将
func add_not_found_general_id(general_id: int) -> bool:
	if general_id <= 0:
		return false
	var general := GeneralListCache.get_general(general_id)
	if general == null:
		return false
	for b in range(1, CityListCache.get_city_num()):
		var city := CityListCache.get_city_by_city_id(b)
		if city.get_officer_ids() != null:
			for gid in city.get_officer_ids():
				if gid == general_id:
					city.remove_officer_id(general_id)
					break
	general.status = 0
	general.debutCity = cityID
	if cityNotFoundGeneralId.size() >= 10:
		GeneralListCache.general_die(general_id)
		return false
	cityNotFoundGeneralId.append(general_id)
	return true

func remove_not_found_general_id(general_id: int) -> void:
	if general_id not in cityNotFoundGeneralId:
		return
	cityNotFoundGeneralId.erase(general_id)

func assign_soldier() -> void:
	if reserveSoldiers <= 0:
		return
	var office_array := get_officer_ids()
	office_array.sort_custom(func(a, b): return GeneralListCache.get_general(a).get_war_value() > GeneralListCache.get_general(b).get_war_value())
	for gid in office_array:
		if reserveSoldiers <= 0:
			break
		var general := GeneralListCache.get_general(gid)
		if general.soldiers < general.get_max_soldier_num():
			var need := general.get_max_soldier_num() - general.soldiers
			if need <= reserveSoldiers:
				reserveSoldiers -= need
				general.soldiers = general.get_max_soldier_num()
			else:
				general.soldiers += reserveSoldiers
				reserveSoldiers = 0

func get_officer_ids() -> Array:
	var result := []
	for gid in cityOfficeGeneralId:
		if gid > 0: result.append(gid)
	return result

func get_city_subjects_general_id_array() -> Array:
	var result := []
	for gid in cityOfficeGeneralId:
		if gid > 0 and gid != ownerID:
			result.append(gid)
	return result

func get_reserved_general_num() -> int:
	var n := 0
	for gid in cityReservedGeneralId:
		if gid > 0: n += 1
	return n

func get_reserved_general_id(index: int) -> int:
	return cityReservedGeneralId[index]

func get_recluse_ids() -> Array:
	var result := []
	for gid in cityNotFoundGeneralId:
		if gid > 0: result.append(gid)
	return result

func get_talent_ids() -> Array:
	var result := []
	for gid in cityReservedGeneralId:
		if gid > 0: result.append(gid)
	return result

func add_reserved_general_id(general_id: int) -> bool:
	if get_reserved_general_num() > 9:
		return false
	for gid in cityOfficeGeneralId:
		if gid == general_id:
			remove_officer_id(general_id)
	var general := GeneralListCache.get_general(general_id)
	if general == null:
		return false
	general.status = 0
	general.debutCity = cityID
	cityReservedGeneralId.append(general_id)
	return true

func remove_reserved_general_id(general_id: int) -> void:
	if general_id not in cityReservedGeneralId:
		return
	cityReservedGeneralId.erase(general_id)

func clear_all_office_general() -> void:
	cityOfficeGeneralId = []

func add_office_general_id(general_id: int) -> bool:
	if general_id == 0:
		return false
	var general := GeneralListCache.get_general(general_id)
	if general == null:
		remove_officer_id(general_id)
		return false
	if cityOfficeGeneralId.is_empty():
		cityOfficeGeneralId = [general_id]
		prefectID = general_id
		general.status = 1
		general.debutCity = cityID
		return true
	if general_id in cityOfficeGeneralId:
		return true
	general.status = 1
	general.debutCity = cityID
	var general_num := get_city_officer_num()
	if general_num > 9:
		var min_general_id := get_min_battle_power_general_id()
		if CountryListCache.get_country_by_king_id(general_id) != null:
			for i in cityOfficeGeneralId.size():
				if cityOfficeGeneralId[i] == min_general_id:
					cityOfficeGeneralId[i] = cityOfficeGeneralId[0]
					cityOfficeGeneralId[0] = general_id
					prefectID = general_id
					add_not_found_general_id(min_general_id)
					return true
		else:
			var general_score := general.all_status()
			var min_general := GeneralListCache.get_general(min_general_id)
			if general_score > min_general.all_status():
				for i in cityOfficeGeneralId.size():
					if cityOfficeGeneralId[i] == min_general_id:
						cityOfficeGeneralId[i] = general_id
						if i == 0:
							prefectID = general_id
						add_not_found_general_id(min_general_id)
						return true
			else:
				add_not_found_general_id(general_id)
				return false
	else:
		if CountryListCache.get_country_by_king_id(general_id) != null:
			if general_num != 0:
				var temp: int = cityOfficeGeneralId[0]
				cityOfficeGeneralId.append(temp)
			cityOfficeGeneralId[0] = general_id
			prefectID = general_id
			return true
		cityOfficeGeneralId.append(general_id)
		if cityOfficeGeneralId.size() == 1:
			prefectID = general_id
		return true
	return false

func remove_officer_id(general_id: int) -> bool:
	if general_id not in cityOfficeGeneralId:
		return false
	cityOfficeGeneralId.erase(general_id)
	if get_city_officer_num() < 1:
		var country := CountryListCache.get_country_by_king_id(ownerID)
		if country != null:
			country.remove_city(cityID)
		ownerID = 0
		prefectID = 0
	elif prefectID == general_id:
		auto_appoint_prefect()
	return true

func get_capture_list() -> Array:
	return cityJailGeneralId

func add_capture(general_id: int) -> bool:
	if general_id == 0:
		return false
	if general_id in cityJailGeneralId:
		return false
	var general := GeneralListCache.get_general(general_id)
	general.set_loyalty(randi_range(45, 69))
	cityJailGeneralId.append(general_id)
	return true

func remove_capture(general_id: int) -> bool:
	if general_id == 0:
		return false
	if general_id not in cityJailGeneralId:
		return false
	cityJailGeneralId.erase(general_id)
	return true

func get_city_all_soldier_num() -> int:
	return get_already_soldier_num() + reserveSoldiers

func get_max_soldier_num() -> int:
	var count := 0
	for gid in cityOfficeGeneralId:
		if gid > 0:
			count += GeneralListCache.get_general(gid).get_max_soldier_num()
	return count

func get_already_soldier_num() -> int:
	var count := 0
	for gid in cityOfficeGeneralId:
		if gid > 0:
			count += GeneralListCache.get_general(gid).soldiers
	return count

func get_max_conscript_soldier_num() -> int:
	var gold_limit := money * 5
	var rule_limit := rule * 500
	var population_limit := population * 2 / 3
	var diff := get_max_soldier_num() - get_city_all_soldier_num()
	return mini(mini(mini(gold_limit, rule_limit), mini(population_limit, diff)), 30000)

func conscript(soldier_num: int) -> void:
	reserveSoldiers += soldier_num
	sub_gold((soldier_num + 4) / 5)
	sub_rule(soldier_num / 500)
	if population * 2 < soldier_num * 3:
		population = 0
	else:
		population -= soldier_num * 3 / 2

func get_city_officer_num() -> int:
	var n := 0
	for gid in cityOfficeGeneralId:
		if gid > 0: n += 1
	return n

func appoint_prefect(general_id: int) -> void:
	if general_id == 0:
		return
	var found := -1
	for i in cityOfficeGeneralId.size():
		if cityOfficeGeneralId[i] == general_id:
			found = i
			break
	if found == -1:
		return
	if found == 0:
		return
	var t: int = cityOfficeGeneralId[0]
	cityOfficeGeneralId[0] = cityOfficeGeneralId[found]
	cityOfficeGeneralId[found] = t
	prefectID = general_id

func auto_appoint_prefect() -> void:
	var arr := get_officer_ids()
	if arr.is_empty():
		return
	if arr.size() == 1:
		prefectID = arr[0]
		return
	var prefect_value := 0
	var id := 0
	var i1 := 0
	for i in arr.size():
		var general_id: int = arr[i]
		var general := GeneralListCache.get_general(general_id)
		if general_id == ownerID:
			prefect_value = 1000
			id = general_id
			i1 = i
			break
		if general.get_loyalty() >= 60 and general.get_war_value() > prefect_value:
			prefect_value = general.get_war_value()
			id = arr[i]
			i1 = i
	if prefect_value == 0:
		i1 = 0
		id = arr[0]
		for i in range(1, arr.size()):
			if GeneralListCache.get_general(id).get_loyalty() < GeneralListCache.get_general(arr[i]).get_loyalty():
				id = arr[i]
				i1 = i
	prefectID = id
	arr.remove_at(i1)
	arr.insert(0, id)
	cityOfficeGeneralId = arr

func get_max_atk_power() -> int:
	var officer_ids := get_officer_ids()
	if officer_ids.is_empty():
		return 0
	var power: Array = []
	for gid in officer_ids:
		power.append(GeneralListCache.get_general(gid).get_battle_power())
	var total_power := 0.0
	for p in power:
		total_power += p
	if ownerID != CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).countryKingId:
		var min_power: float = power[0]
		for p in power:
			min_power = mini(min_power, p)
		total_power -= min_power
	else:
		total_power *= 1.2
	var need_food := get_already_soldier_num() / 8 + 1
	if grain < need_food:
		total_power = total_power * grain / need_food
	var need_money := get_max_soldier_num() / 10
	if money > need_money:
		total_power = total_power * 5.0 / 3.0
	return int(total_power)

func get_defense_ability() -> int:
	if ownerID == CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).countryKingId:
		return int(get_city_def_power() * 1.2)
	return int(get_city_def_power())

func get_city_def_power() -> float:
	var power := 0.0
	var arr := get_officer_ids()
	for gid in arr:
		var general := GeneralListCache.get_general(gid)
		if gid == prefectID:
			power += general.get_battle_power() * 1.2
		else:
			power += general.get_battle_power()
	var need_food := arr.size() / 8 + 1
	if grain < need_food:
		power = power * grain / need_food
	return power

func get_do_reclaim_mercantile_officer() -> General:
	var arr := get_officer_ids()
	var best := GeneralListCache.get_general(prefectID)
	var best_score := best.wisdom + best.govern * 2
	for i in range(1, arr.size()):
		var general := GeneralListCache.get_general(arr[i])
		var score := general.wisdom + general.govern * 2
		if general.has_skill(3, 2) or general.has_skill(3, 3):
			score = int(score * 1.33)
		elif general.has_skill(3, 0):
			score = int(score * 1.25)
		if score > best_score:
			best_score = score
			best = general
	return best

func get_do_patrol_officer() -> General:
	var arr := get_officer_ids()
	var best := GeneralListCache.get_general(prefectID)
	var best_score := best.wisdom + best.govern * 2 + best.charm * 2
	for i in range(1, arr.size()):
		var general := GeneralListCache.get_general(arr[i])
		var score := general.wisdom + general.govern * 2 + general.charm * 2
		if general.has_skill(3, 1):
			score = int(score * 1.33)
		elif general.has_skill(3, 0):
			score = int(score * 1.25)
		if score > best_score:
			best_score = score
			best = general
	return best

func get_do_search_officer() -> int:
	var arr := get_officer_ids()
	var general_id: int = arr[0]
	var best := GeneralListCache.get_general(general_id)
	var best_score := best.wisdom + best.charm / 2
	for i in range(1, arr.size()):
		var general := GeneralListCache.get_general(arr[i])
		var score := general.wisdom + general.charm / 2
		if best_score < score:
			general_id = arr[i]
			best_score = score
	return general_id

func get_do_employ_officer(be_gen_id: int) -> int:
	var arr := get_officer_ids()
	var general_id: int = arr[0]
	var d := 100
	for b in range(1, get_city_officer_num()):
		var cur_id: int = arr[b]
		var cur_d := GeneralListCache.get_d_phase(cur_id, be_gen_id)
		if cur_d < d:
			general_id = arr[b]
			d = cur_d
	return general_id

func get_war_office_general_ids(power: int) -> Array:
	var result := get_officer_ids()
	if result.size() < 2:
		return []
	while power > 0 and result.size() > 1:
		var min_id := get_min_battle_power_general_id()
		result.erase(min_id)
		power -= int(GeneralListCache.get_general(min_id).get_battle_power())
	for i in result.size():
		var gid: int = result[i]
		if gid == ownerID or gid == prefectID:
			if i != 0:
				result.remove_at(i)
				result.insert(0, gid)
			break
	return result

func get_min_battle_power_general_id() -> int:
	var ids := get_officer_ids()
	var min_id := 0
	var min_p := 1e18
	for gid in ids:
		var p := GeneralListCache.get_general(gid).get_battle_power()
		if p < min_p:
			min_p = p
			min_id = gid
	return min_id

func get_max_battle_power_general_id() -> int:
	var ids := get_officer_ids()
	var max_id := 0
	var max_p := -1.0
	for gid in ids:
		var p := GeneralListCache.get_general(gid).get_battle_power()
		if p > max_p:
			max_p = p
			max_id = gid
	return max_id

func _get_satrap_gen_power() -> int:
	var general := GeneralListCache.get_general(prefectID)
	var power := 1
	var gjl := int(general.get_war_value() * 1.3)
	var attack_value: float = (1 + gjl * gjl * gjl / 100000.0)
	if general.soldiers < 500:
		attack_value = minf(150.0, attack_value)
	if attack_value < 20.0:
		attack_value = maxf(general.soldiers / 150.0, attack_value)
	power += int(attack_value * (general.soldiers + 1))
	return power

func need_food_to_harvest() -> int:
	var need := get_already_soldier_num() / 100 + reserveSoldiers / 300
	if GameInfo.month >= 5 and GameInfo.month < 10:
		need = (10 - GameInfo.month) * need
	elif GameInfo.month < 5:
		need = (5 - GameInfo.month) * need
	else:
		need = (12 - GameInfo.month - 5) * need
	return need

func need_all_salaries_money() -> int:
	var result := 0
	for gid in cityOfficeGeneralId:
		result += GeneralListCache.get_general(gid).get_salary()
	return result

func need_food_war_a_month() -> int:
	return get_already_soldier_num() / 8 + 1

func search(general_id: int) -> String:
	var general := GeneralListCache.get_general(general_id)
	general.sub_hp(2)
	var task_type := _determine_search_result(general)
	var reward_value := 0
	var result := ""
	match task_type:
		GameInfo.TaskType.SEARCH_FOOD:
			reward_value = randi_range(0, 39) + (general.wisdom + general.charm * 3) / 4
			if general.has_skill(4, 4): reward_value += reward_value / 2
			add_food(reward_value)
			result = "%s%d石" % [TextLibrary.do_things_result_info[6][1], reward_value]
		GameInfo.TaskType.SEARCH_MONEY:
			reward_value = randi_range(0, 29) + (general.wisdom + general.charm * 2) / 4
			if general.has_skill(4, 4): reward_value += reward_value / 2
			add_gold(reward_value)
			result = "%s%d两" % [TextLibrary.do_things_result_info[6][2], reward_value]
		GameInfo.TaskType.SEARCH_GENERAL:
			var found_general_id := get_not_found_general_id(randi_range(0, get_city_not_found_general_num() - 1))
			var found_general := GeneralListCache.get_general(found_general_id)
			remove_not_found_general_id(found_general_id)
			add_reserved_general_id(found_general_id)
			result = "%s%s" % [TextLibrary.do_things_result_info[6][3], found_general.generalName]
		GameInfo.TaskType.SEARCH_TREASURE:
			reward_value = 2 if general.has_skill(4, 4) else 1
			add_treasure_num(reward_value)
			result = "%s%d件" % [TextLibrary.do_things_result_info[6][4], reward_value]
		_:
			result = TextLibrary.do_things_result_info[6][0]
	return result

func _determine_search_result(general: General) -> int:
	var random_value := randi_range(0, 99)
	var not_found_num := get_city_not_found_general_num()
	if not_found_num > 0:
		if general.has_skill(4, 4):
			return GameInfo.TaskType.SEARCH_GENERAL
		if general.wisdom >= 60 and general.charm >= 70:
			return GameInfo.TaskType.SEARCH_GENERAL
		if random_value >= 60:
			return GameInfo.TaskType.SEARCH_GENERAL
	if random_value > general.wisdom and not general.has_skill(3, 4):
		return GameInfo.TaskType.SEARCH_NOTHING
	if general.has_skill(4, 4):
		if random_value <= 40 and money < 30000: return GameInfo.TaskType.SEARCH_MONEY
		if random_value <= 80 and grain < 30000: return GameInfo.TaskType.SEARCH_FOOD
		return GameInfo.TaskType.SEARCH_TREASURE
	if random_value < 10: return GameInfo.TaskType.SEARCH_TREASURE
	if random_value < 50 and money < 30000: return GameInfo.TaskType.SEARCH_MONEY
	if random_value < 90 and grain < 30000: return GameInfo.TaskType.SEARCH_FOOD
	return GameInfo.TaskType.SEARCH_NOTHING

func is_employ(do_general_id: int, be_general_id: int) -> bool:
	var do_general := GeneralListCache.get_general(do_general_id)
	var king_general := GeneralListCache.get_general(ownerID)
	var be_general := GeneralListCache.get_general(be_general_id)
	if be_general == null:
		return false
	var d1 := GeneralListCache.get_phase_difference(king_general, be_general)
	var d2 := GeneralListCache.get_phase_difference(do_general, be_general)
	var i := randi_range(0, 74)
	if (d1 + d2) / 2 < i:
		do_general.add_moral_exp(randi_range(10, 24))
		do_general.add_iq_exp(randi_range(4, 9))
		add_office_general_id(be_general_id)
		remove_reserved_general_id(be_general_id)
		return true
	return false

func reward(general_id: int, use_treasure: bool) -> void:
	var general := GeneralListCache.get_general(general_id)
	if use_treasure:
		treasures -= 1
		general.reward_add_loyalty(false)
	else:
		sub_gold(100)
		general.reward_add_loyalty(true)

func reclaim(general: General, use_money: int) -> int:
	var contribution := (general.force + general.govern * 2) / 3
	general.sub_hp(2)
	general.add_experience(randi_range(0, 49) + 10)
	general.add_political_exp(10)
	var val := 1 if contribution < 12 else (contribution * use_money / 100) / 2
	val += randi_range(0, val) / 2
	if general.has_skill(4, 0):
		val += val / 4
	elif general.has_skill(4, 2):
		val += val / 3
	sub_gold(use_money)
	var actual := clampi(val, 0, 999 - agriculture)
	agriculture += actual
	return actual

func mercantile(general: General, use_money: int) -> int:
	var contribution := (general.wisdom + general.govern * 2) / 3
	general.sub_hp(2)
	general.add_experience(randi_range(0, 49) + 10)
	general.add_political_exp(10)
	var val := 1 if contribution < 12 else (contribution * use_money / 100) / 2
	val += randi_range(0, val) / 2
	if general.has_skill(4, 0):
		val += val / 4
	elif general.has_skill(4, 3):
		val += val / 3
	sub_gold(use_money)
	var actual := clampi(val, 0, 999 - commerce)
	commerce += actual
	return actual

func tame(general: General, use_money: int) -> int:
	var contribution := (general.lead + general.govern * 2) / 4
	general.sub_hp(2)
	general.add_experience(randi_range(0, 49) + 10)
	general.add_political_exp(10)
	var val := 1 if contribution < 10 else (contribution * use_money / 100) / 2
	val += randi_range(0, val) / 3
	if general.has_skill(4, 0):
		val += val / 4
	sub_gold(use_money)
	var actual := clampi(val, 0, 99 - prevention)
	if rule < 99:
		add_rule(2 if actual >= 5 else 1)
	prevention += actual
	return actual

func patrol(general: General, use_money: int) -> int:
	var contribution := (general.wisdom + general.charm * 2 + general.govern * 2) / 5
	general.sub_hp(2)
	general.add_experience(randi_range(0, 49) + 10)
	general.add_political_exp(10)
	general.add_moral_exp(10)
	var val := 500 if contribution < 50 else contribution * use_money
	if general.has_skill(4, 0):
		val += val / 4
	elif general.has_skill(4, 1):
		val += val / 3
	sub_gold(use_money)
	var actual := clampi(val, 0, 999999 - population)
	if rule < 99:
		add_rule(3 if actual >= 2500 else (2 if actual >= 1500 else 1))
	population += actual
	return actual

func have_city_smithy() -> bool: return cityWeaponShop != 0
func has_war_smithy() -> bool: return warWeaponShop != 0

func sell_unique_weapon() -> void:
	warWeaponShop = 2

func get_threshold_general_ids(hp_limit: int) -> Array:
	var result := []
	for gid in get_officer_ids():
		if GeneralListCache.get_general(gid).health < hp_limit:
			result.append(gid)
	return result

func get_can_study_general_ids() -> Array:
	var result := []
	for gid in get_officer_ids():
		var general := GeneralListCache.get_general(gid)
		if general.wisdom < 120 and general.experience >= general.get_learn_need_exp():
			result.append(gid)
	return result

func is_connected_to(be_city_id: int) -> bool:
	return be_city_id in connectCityId

func is_rebel() -> bool:
	if ownerID == 0 or prefectID == 0:
		return false
	var prefect_general := GeneralListCache.get_general(prefectID)
	var old_country := CountryListCache.get_country_by_king_id(ownerID)
	if prefect_general.get_loyalty() > 90 or ownerID == prefectID:
		return false
	var loyalty := 100 - prefect_general.get_loyalty()
	var king_general := GeneralListCache.get_general(ownerID)
	var phase_difference := GeneralListCache.get_d_phase(prefect_general.phase, king_general.phase)
	if loyalty < 10 or phase_difference < 5:
		return false
	var threshold := loyalty - 5 + phase_difference / 2 - old_country.get_have_city_num() - ((king_general.charm - 80) / 9) - CountryListCache.get_country_size() / 2
	threshold /= 2
	if threshold <= 0:
		return false
	var random_value := randi_range(0, 99) / threshold
	if random_value > 0:
		return false
	var max_attack_power := 0
	for temp_city_id in connectCityId:
		var temp_city := CityListCache.get_city_by_city_id(temp_city_id)
		var attack_power := temp_city.get_max_atk_power()
		if attack_power > max_attack_power:
			max_attack_power = attack_power
	if get_defense_ability() < max_attack_power * 0.7:
		return false
	return true


static func from_dict(d: Dictionary) -> City:
	var c := City.new()
	c.cityID = int(d.get("cityID", 0))
	c.cityName = str(d.get("cityName", ""))
	c.ownerID = int(d.get("ownerID", 0))
	c.prefectID = int(d.get("prefectID", 0))
	c.rule = int(d.get("rule", 0))
	c.money = int(d.get("money", 0))
	c.grain = int(d.get("grain", 0))
	c.treasures = int(d.get("treasures", 0))
	c.agriculture = int(d.get("agriculture", 0))
	c.commerce = int(d.get("commerce", 0))
	c.population = int(d.get("population", 0))
	c.prevention = int(d.get("prevention", 0))
	c.reserveSoldiers = int(d.get("reserveSoldiers", 0))
	c.citySchool = bool(d.get("citySchool", false))
	c.cityGrainShop = bool(d.get("cityGrainShop", false))
	c.cityHospital = bool(d.get("cityHospital", false))
	c.cityWeaponShop = int(d.get("cityWeaponShop", 0))
	c.warWeaponShop = int(d.get("warWeaponShop", 0))
	c.connectCityId = _to_int_array(d.get("connectCityId", []))
	c.mapPosition = _to_int_array(d.get("mapPosition", []))
	return c


func to_dict() -> Dictionary:
	return {
		"cityID": cityID, "cityName": cityName, "ownerID": ownerID, "prefectID": prefectID,
		"rule": rule, "money": money, "grain": grain, "treasures": treasures,
		"agriculture": agriculture, "commerce": commerce, "population": population,
		"prevention": prevention, "reserveSoldiers": reserveSoldiers,
		"citySchool": citySchool, "cityGrainShop": cityGrainShop, "cityHospital": cityHospital,
		"cityWeaponShop": cityWeaponShop, "warWeaponShop": warWeaponShop,
		"connectCityId": connectCityId, "mapPosition": mapPosition,
	}


static func _to_int_array(data) -> Array:
	var arr := []
	if data is Array:
		for v in data:
			arr.append(int(v))
	return arr
