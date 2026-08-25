extends Node
## 武将缓存（autoload: GeneralListCache）

var general_list: Array = []        # 已出场武将列表
var no_debut_general_list: Array = []  # 待年份出场武将
var general_dictionary: Dictionary = {}  # id -> General
var max_general_id: int = 0


func clear_all_generals() -> void:
	general_list.clear()


func clear_all_no_debut_generals() -> void:
	no_debut_general_list.clear()
	max_general_id = 0


func clear_all_total_generals() -> void:
	general_list.clear()
	no_debut_general_list.clear()
	general_dictionary.clear()


## 按年份登场
func debut_by_years(years: int) -> void:
	if no_debut_general_list.is_empty():
		return
	var i := 0
	while i < no_debut_general_list.size():
		var general: General = no_debut_general_list[i]
		if general.debutYear <= years:
			no_debut_general_list.remove_at(i)
			general_list.append(general)
			var city_id: int = general.debutCity
			if general.followWho != 0:
				var follow_general := get_general(general.followWho)
				if follow_general != null:
					city_id = follow_general.debutCity
					var city := CityListCache.get_city_by_city_id(city_id)
					if follow_general.status == 1:
						if city.get_city_officer_num() >= 10:
							if city.get_reserved_general_num() < 10:
								city.add_reserved_general_id(general.generalId)
						else:
							city.add_office_general_id(general.generalId)
					elif city != null:
						if city.get_reserved_general_num() < 10:
							city.add_reserved_general_id(general.generalId)
			elif general.debutCity == 0:
				city_id = randi_range(0, CityListCache.CITY_NUM - 1)
				var city2 := CityListCache.get_city_by_city_id(city_id)
				city2.add_not_found_general_id(general.generalId)
			else:
				var city3 := CityListCache.get_city_by_city_id(general.debutCity)
				city3.add_not_found_general_id(general.generalId)
			continue
		i += 1


func get_general(general_id: int) -> General:
	if general_dictionary.has(general_id):
		return general_dictionary[general_id]
	return null


## 获取武将头像贴图。
## 优先高清立绘 assets/portraits/{generalId}.jpg（sanguo 迁移，360x512），
## 缺失时回退原版像素头 assets/portraits_original/{generalId}.jpg（55x68）。
## 缓存已加载贴图，两者都缺时返回 null，调用方自行降级为占位。
var _portrait_cache: Dictionary = {}


func get_portrait(general_id: int) -> Texture2D:
	if _portrait_cache.has(general_id):
		return _portrait_cache[general_id]
	var tex: Texture2D = null
	var hd := "res://assets/portraits/%d.jpg" % general_id
	if ResourceLoader.exists(hd):
		tex = load(hd) as Texture2D
	else:
		var orig := "res://assets/portraits_original/%d.jpg" % general_id
		if ResourceLoader.exists(orig):
			tex = load(orig) as Texture2D
	_portrait_cache[general_id] = tex
	return tex


func get_no_debut_general_by_index(index_id: int) -> General:
	return no_debut_general_list[index_id]


func get_total_no_debut_general_num() -> int:
	var count := 0
	for general in no_debut_general_list:
		if general != null:
			count += 1
	return count


func get_debted_general_num() -> int:
	var count := 0
	for general in general_list:
		if general == null:
			break
		count += 1
	return count


func get_total_general_num() -> int:
	return general_dictionary.size()


func add_general(general: General) -> void:
	if general.generalId <= 0:
		general.generalId = 10000
	if general.generalId > max_general_id:
		max_general_id = general.generalId
	general_dictionary[general.generalId] = general


func remove_general(general_id: int) -> bool:
	return general_dictionary.erase(general_id)


func add_no_debut_general(general: General) -> void:
	if general.generalId > max_general_id:
		max_general_id = general.generalId
	no_debut_general_list.append(general)


func add_debuted_general(general: General) -> void:
	if general.generalId == -1:
		general.generalId = max_general_id + 1
	if general.generalId > max_general_id:
		max_general_id = general.generalId
	if not general.isDie:
		general_list.append(general)


## 武将死亡
func general_die(general_id: int) -> void:
	var general := get_general(general_id)
	if general == null:
		return
	GameInfo.chooseGeneralName = general.generalName
	var city_id: int = general.debutCity
	var city := CityListCache.get_city_by_city_id(city_id)
	city.remove_officer_id(general_id)
	city.remove_not_found_general_id(general_id)
	city.remove_reserved_general_id(general_id)
	general.status = 0
	var country := CountryListCache.get_country_by_king_id(general_id)
	if country != null:
		if GameInfo.playerCountryId == country.countryId:
			GameInfo.show_info = general.generalName + " 君主死亡!"
			if not country.is_destroyed():
				GameInfo.countryDieTips = 2
			else:
				GameInfo.countryDieTips = 4
				GameInfo.show_info = general.generalName + " 势力灭亡了!"
		else:
			if not country.is_destroyed():
				if country.is_endangered() and _war_manager() != null and _war_manager().cur_war_city_id == country.cityIDs[0]:
					GameInfo.countryDieTips = 3
					GameInfo.show_info = general.generalName + " 势力灭亡了!"
				else:
					GameInfo.countryDieTips = 1
					var new_king_general_id := country.inherit()
					GameInfo.show_info = general.generalName + "死亡,新君主 " + get_general(new_king_general_id).generalName + " 继位!"
			else:
				GameInfo.countryDieTips = 3
				GameInfo.show_info = general.generalName + " 势力灭亡了!"
	general.isDie = true


func _war_manager():
	return get_node_or_null("/root/WarManager")


## 玩家与 AI 对战时增加经验
func add_exp_p(atk_gen: General, def_gen: General, total_exp: int) -> void:
	var ratio := float(def_gen.get_war_value()) / float(atk_gen.get_war_value())
	ratio = clampf(ratio, 0.5, 1.5)
	var exp := int(total_exp * ratio)
	atk_gen.add_experience(exp / 3)


## AI 之间对战时增加经验
func ai_war_add_exp2(atk_gen: General, def_gen: General, total_exp: int) -> void:
	var ratio := float(def_gen.get_war_value()) / float(atk_gen.get_war_value())
	ratio = clampf(ratio, 0.5, 1.5)
	var exp := int(total_exp * ratio + 1.0)
	var iq_exp := 0
	if atk_gen.wisdom > def_gen.wisdom + 20:
		iq_exp = int(exp * 0.3)
	var lead_exp := exp - iq_exp
	atk_gen.add_iq_exp(iq_exp / 100)
	atk_gen.add_lead_exp(lead_exp / 300)


func get_skill_1(gen_id: int, skill_id: int) -> bool: return get_skill(0, gen_id, skill_id)
func get_skill_2(gen_id: int, skill_id: int) -> bool: return get_skill(1, gen_id, skill_id)
func get_skill_3(gen_id: int, skill_id: int) -> bool: return get_skill(2, gen_id, skill_id)
func get_skill_4(gen_id: int, skill_id: int) -> bool: return get_skill(3, gen_id, skill_id)
func get_skill_5(gen_id: int, skill_id: int) -> bool: return get_skill(4, gen_id, skill_id)


func get_skill(i: int, gen_id: int, skill_id: int) -> bool:
	var general := get_general(gen_id)
	return ((general.skills[i] >> (10 - skill_id)) & 0x1) == 1


## 相性差（按数值）
func get_d_phase(ph1: int, ph2: int) -> int:
	var total := absi(ph1 - ph2)
	if total >= 75:
		total = 150 - total
	return total


## 相性差（按武将）
func get_phase_difference(do_gen: General, be_gen: General) -> int:
	return get_d_phase(do_gen.phase, be_gen.phase)


func _get_office_gen_belong_king(general: General) -> int:
	var king_id := 0
	var debut_city := CityListCache.get_city_by_city_id(general.debutCity)
	var officer_ids: Array = debut_city.get_officer_ids()
	for id in officer_ids:
		if id == general.generalId:
			return debut_city.ownerID
	var in_count := 0
	for city in CityListCache.city_dictionary.values():
		var ids2: Array = city.get_officer_ids()
		for id in ids2:
			if id == general.generalId:
				king_id = city.ownerID
				in_count += 1
				if general.debutCity != city.cityID and in_count > 1:
					city.remove_officer_id(general.generalId)
					general.debutCity = city.cityID
	return king_id


## 离间判定
func is_alienate(do_gen_id: int, be_gen_id: int) -> bool:
	var do_general := get_general(do_gen_id)
	var be_general := get_general(be_gen_id)
	var i := 0
	if be_general.get_loyalty() > 95:
		return false
	if be_general.get_loyalty() > 87:
		if randi_range(0, 99) > (95 - be_general.get_loyalty()) * 2:
			return false
	else:
		i = (95 - be_general.get_loyalty()) * (95 - be_general.get_loyalty()) / 4
		if i > 90:
			i = 90
		if randi_range(0, 99) > i:
			return false
	var d1 := get_phase_difference(get_general(_get_office_gen_belong_king(be_general)), be_general)
	var d2 := get_phase_difference(get_general(_get_office_gen_belong_king(do_general)), be_general)
	var d3 := get_phase_difference(do_general, be_general)
	if d1 == 0:
		return false
	if d2 == 0:
		i = 10 + randi_range(0, 14)
	if d3 > d1 + 10:
		return false
	var val := d1 - d2 * 4 / 3 - d3 * 2 + 110 - be_general.get_loyalty()
	if val > 0:
		if randi_range(0, val - 1) > 5:
			i = 5 + randi_range(0, 9)
		if randi_range(0, 39) < 100 - be_general.get_loyalty():
			i = 2 + randi_range(0, 4)
		else:
			i = 1 + randi_range(0, 2)
	if randi_range(0, 119) < do_general.wisdom - be_general.wisdom:
		i = 1 + randi_range(0, 2)
	else:
		return false
	if i > 0:
		be_general.sub_loyalty(i)
		do_general.add_moral_exp(randi_range(5, 14))
		do_general.add_iq_exp(randi_range(2, 9))
		return true
	return false


func _can_bribe(do_general: General, be_general: General) -> bool:
	if be_general.get_loyalty() >= 95:
		return false
	var d1 := get_phase_difference(get_general(_get_office_gen_belong_king(do_general)), be_general)
	var d2 := get_phase_difference(get_general(_get_office_gen_belong_king(be_general)), be_general)
	var d3 := get_phase_difference(do_general, be_general)
	if d2 == 0:
		return false
	if d2 < 5:
		var val := d2 - d1 * 2 - d3 * 2 + (100 - be_general.get_loyalty()) / 2
		return val > 0
	elif d2 <= 10:
		var val := d2 - d1 * 3 / 2 - d3 * 2 + (100 - be_general.get_loyalty()) / 2
		return val > 0
	elif d2 <= 20:
		var val := d2 - d1 - d3 * 2 + (100 - be_general.get_loyalty()) / 2
		return val > 0
	else:
		var val := d2 - d1 - d3 * 2 + (100 - be_general.get_loyalty()) / 3
		return val > 0


## 招揽判定
func is_bribe(do_city_id: int, be_city_id: int, do_gen_id: int, be_gen_id: int) -> bool:
	var do_general := get_general(do_gen_id)
	var be_general := get_general(be_gen_id)
	var do_city := CityListCache.get_city_by_city_id(do_city_id)
	var be_city := CityListCache.get_city_by_city_id(be_city_id)
	if _can_bribe(do_general, be_general):
		be_general.set_loyalty(randi_range(40, 74))
		do_general.add_moral_exp(randi_range(10, 24))
		do_general.add_iq_exp(randi_range(4, 9))
		be_city.remove_officer_id(be_gen_id)
		do_city.add_office_general_id(be_gen_id)
		return true
	return false


## 雇佣判定
func employ_probability(gohire_id: int, behire_id: int) -> bool:
	var go_general := get_general(gohire_id)
	var city := CityListCache.get_city_by_city_id(go_general.debutCity)
	var king_general := get_general(city.ownerID)
	var be_general := get_general(behire_id)
	if be_general == null:
		return false
	var d1 := get_d_phase(king_general.phase, be_general.phase)
	var d2 := get_d_phase(go_general.phase, be_general.phase)
	var i := randi_range(0, 74)
	return (d1 + d2) / 2 < i
