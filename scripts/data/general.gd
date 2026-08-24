class_name General
extends RefCounted
## 武将类（核心数值）

var generalId: int = 0
var generalName: String = ""
var debutYear: int = 0
var debutCity: int = 0
var phase: int = 0          # 相性 0-149
var status: int = 0         # 1=在职 0=在野
var level: int = 1          # 1-8
var army: Array = [0, 0, 0] # 平/山/水 适性 0-3
var health: int = 100
var maxHealth: int = 100
var lead: int = 0           # 统率
var force: int = 0          # 武力
var wisdom: int = 0         # 智谋
var govern: int = 0         # 行政
var charm: int = 0          # 魅力
var loyalty: int = 0
var maxAttribute: int = 120
var arm: int = 0            # 武器
var armor: int = 0          # 铠甲
var soldiers: int = 0       # 士兵
var followWho: int = 0      # 跟随武将ID
var experience: int = 0
var skills: Array = [0, 0, 0, 0, 0]  # 5 组 × 10bit 位掩码
var leadExp: int = 0
var forceExp: int = 0
var wisdomExp: int = 0
var charmExp: int = 0
var governExp: int = 0
var isDie: bool = false

const LEVEL_UP_EXP := [6000, 10000, 14000, 18000, 22000, 26000, 30000, 32767]


func is_king() -> bool:
	return CountryListCache.get_country_by_king_id(generalId) != null


func get_army_s() -> String:
	var suffixes := ["C", "B", "A", "S"]
	var prefixes := ["平", "山", "水"]
	var result := ""
	for i in range(mini(army.size(), prefixes.size())):
		var a: int = army[i]
		if a < suffixes.size():
			result += prefixes[i] + suffixes[a]
		else:
			result += "?"
	return result


func get_hp() -> int:
	return health


func set_hp(num: int) -> void:
	health = clampi(num, 0, maxHealth)


func add_hp(num: int) -> int:
	var new_hp := clampi(health + num, 0, maxHealth)
	var actual := new_hp - health
	health = new_hp
	return actual


## 返回是否归零
func sub_hp(num: int) -> bool:
	if health <= num:
		health = 0
		return true
	health -= num
	return false


func get_salary() -> int:
	return 1 + level * 2


func set_loyalty(num: int) -> void:
	loyalty = clampi(num, 0, 100)


func get_loyalty() -> int:
	return loyalty


func sub_loyalty(num: int) -> void:
	loyalty = clampi(loyalty - num, 0, 100)


func add_loyalty(num: int) -> void:
	if num + loyalty >= 100:
		var country := CountryListCache.get_country_by_king_id(generalId)
		loyalty = 100 if country != null else 99
	else:
		loyalty += num


func reward_add_loyalty(use_money: bool) -> int:
	var temp := loyalty
	if loyalty < 30:
		loyalty += randi_range(0, 10) + 20
	elif loyalty < 50:
		loyalty += randi_range(0, 10) + 10
	elif loyalty < 70:
		loyalty += randi_range(0, 10) + 5
	elif loyalty < 80:
		loyalty += randi_range(0, 7) + 3
	elif loyalty < 85:
		loyalty += randi_range(0, 6) + 1
	elif loyalty < 90:
		loyalty += randi_range(0, 4) + 1
	if not use_money:
		loyalty += randi_range(5, 14)
	if loyalty > 99:
		loyalty = 99
	return loyalty - temp


func get_max_exp() -> int:
	if level <= 0 or level > LEVEL_UP_EXP.size():
		return 32767
	return LEVEL_UP_EXP[level - 1]


func add_experience(exp: int) -> void:
	if exp <= 0:
		return
	experience += exp
	while experience >= get_max_exp():
		experience -= get_max_exp()
		_general_upgrade()
		if level >= LEVEL_UP_EXP.size():
			experience = 0
			break


func all_status() -> int:
	return lead + govern + force + charm + wisdom


func get_general_grade() -> int:
	var score := all_status()
	var grade := 0
	if score <= 196:
		grade = 0
	elif score <= 282:
		grade = 1
	elif score <= 345:
		grade = 2
	elif score <= 421:
		grade = 3
	else:
		grade = 4
	if lead >= 95 or govern >= 95 or force >= 95 or charm >= 95 or wisdom >= 95:
		if grade < 4:
			grade = 5
	return grade


func get_general_grade_s() -> String:
	match get_general_grade():
		0: return "愚钝"
		1: return "平庸"
		2: return "良才"
		3: return "精英"
		4: return "奇才"
		_: return "怪才"


func _general_upgrade() -> void:
	if level >= 8:
		return
	level += 1
	health = maxHealth
	var grade := get_general_grade()
	var total := randi_range(0, grade - 1) + 1
	for i in total:
		var index := randi_range(0, 4)
		add_general_attribute_value(index, 0)


func add_general_attribute_value(attribute_index: int, iteration_count: int) -> void:
	if iteration_count >= 5:
		return
	match attribute_index:
		0:
			if lead < maxAttribute: lead += 1
		1:
			if govern < maxAttribute: govern += 1
		2:
			if force < maxAttribute: force += 1
		3:
			if charm < maxAttribute: charm += 1
		4:
			if wisdom < maxAttribute: wisdom += 1
		_:
			attribute_index = 0
	if attribute_index != 0:
		attribute_index += 1
		iteration_count += 1
		add_general_attribute_value(attribute_index, iteration_count)


func _add_attr_exp(attr: String, exp: int, cap: int = 120) -> void:
	var value: int = get(attr)
	var attr_exp: int = get(attr + "Exp")
	if value >= cap:
		set(attr + "Exp", 100)
		return
	var total := attr_exp + exp
	var new_val := total / 100
	value += new_val
	if value >= cap:
		set(attr, cap)
		set(attr + "Exp", 100)
		return
	set(attr, value)
	set(attr + "Exp", total % 100)


func add_lead_exp(exp: int) -> void: _add_attr_exp("lead", exp)
func add_force_exp(exp: int) -> void: _add_attr_exp("force", exp)
func add_iq_exp(exp: int) -> void: _add_attr_exp("wisdom", exp)
func add_political_exp(exp: int) -> void: _add_attr_exp("govern", exp)
func add_moral_exp(exp: int) -> void: _add_attr_exp("charm", exp)


func get_school_need_exp() -> int:
	return 200 + wisdom * 50


func study_up() -> void:
	experience -= get_school_need_exp()
	wisdom += 1


func get_max_soldier_num() -> int:
	if (skills[4] >> (10 - 0)) & 0x1 == 1:
		return 3000
	return clampi(1000 + 12 * lead + 100 * level, 0, 3000)


func add_soldier(soldier: int) -> void:
	soldiers = clampi(soldiers + soldier, 0, get_max_soldier_num())


func sub_soldier(soldier: int) -> void:
	soldiers = clampi(soldiers - soldier, 0, get_max_soldier_num())


func calculate_war_value() -> int:
	return (force + wisdom + lead * 2) / 2 * (soldiers + 150)


func get_attack_power() -> int:
	var wp: int = WeaponListCache.get_weapon(arm).property
	return int(force * (1 + wp / 100.0) * (level + 19) / 20.0)


func get_defend_power() -> int:
	var ap: int = WeaponListCache.get_weapon(armor).property
	return int(force * (1 + ap / 100.0) * (level + 19) / 20.0)


func get_battle_power() -> float:
	var power := 0.0
	var weapon_obj := WeaponListCache.get_weapon(arm)
	if weapon_obj != null:
		power += weapon_obj.property * 1.3
	var armor_obj := WeaponListCache.get_weapon(armor)
	if armor_obj != null:
		power += armor_obj.property * 1.3
	power += force * 1.3 + wisdom * 1.2 + health * 1.1 + soldiers * 0.2
	return power


func get_war_value() -> int:
	return int(lead * 1.42 + wisdom * 0.25 + force * 0.33 + ((lead * 2 + force + wisdom) * (level - 1)) * 0.04)


func get_general_power() -> int:
	var power := 1
	var satrap_value := get_war_value()
	var adjusted: float = (1 + satrap_value * satrap_value * satrap_value / 100000.0)
	if soldiers < 100:
		adjusted = minf(100.0, adjusted)
		return 0
	if adjusted < 20.0:
		adjusted = maxf(soldiers / 150.0, adjusted)
	power += int(adjusted * (soldiers + 1))
	return power


func captured_general_to(city_id: int) -> void:
	var add_loyalty := 100 - get_loyalty()
	var base_loyalty := 60 + add_loyalty
	if base_loyalty >= 99 or base_loyalty <= 0:
		set_loyalty(99)
	else:
		set_loyalty(randi_range(70, 90))
	CityListCache.get_city_by_city_id(city_id).add_office_general_id(generalId)


func get_plan_num() -> int:
	if wisdom >= 100 and level >= 8: return 16
	if wisdom >= 95 and level >= 7: return 15
	if wisdom >= 93 and level >= 5: return 14
	if wisdom >= 90 and level >= 4: return 12
	if wisdom >= 85: return 10
	if wisdom >= 80: return 8
	if wisdom >= 60: return 6
	return 2 if wisdom < 40 else 4


func buy_new_weapon(weapon_id: int, city_id: int) -> bool:
	var new_weapon := WeaponListCache.get_weapon(weapon_id)
	var city := CityListCache.get_city_by_city_id(city_id)
	if new_weapon.isUnique:
		if new_weapon.weaponID == 15:  # 青龙偃月刀
			if force >= 95:
				get_new_weapon(weapon_id)
				city.sell_unique_weapon()
				return true
			return false
		elif new_weapon.weaponID == 21:  # 方天画戟
			if force >= 95:
				get_new_weapon(weapon_id)
				city.sell_unique_weapon()
				return true
			return false
		elif new_weapon.weaponID == 22:  # 狼牙棒
			if force >= 90:
				get_new_weapon(weapon_id)
				city.sell_unique_weapon()
				return true
			return false
		elif new_weapon.weaponID == 23:  # 丈八蛇矛
			if force >= 95:
				get_new_weapon(weapon_id)
				city.sell_unique_weapon()
				return true
			return false
		elif new_weapon.weaponID == 30:  # 圣者之衣
			if wisdom >= 90:
				get_new_weapon(weapon_id)
				city.sell_unique_weapon()
				return true
			return false
	get_new_weapon(weapon_id)
	return true


func get_new_weapon(weapon_id: int) -> void:
	var new_weapon := WeaponListCache.get_weapon(weapon_id)
	if new_weapon.kind == 3:
		armor = weapon_id
	else:
		arm = weapon_id


func get_active_skills() -> String:
	if skills == null or skills.size() != 5:
		return ""
	var active_skills: Array[String] = []
	for i in skills.size():
		var skill_value: int = skills[i]
		if skill_value == 0:
			continue
		for bit_position in 10:
			if (skill_value & (1 << (10 - bit_position))) != 0:
				var skill_index := i * 10 + bit_position
				if skill_index < TextLibrary.skill_names.size():
					active_skills.append(TextLibrary.skill_names[skill_index])
	return "  ".join(active_skills)


func get_skill_count() -> int:
	if skills == null or skills.size() != 5:
		return 0
	var skill_count := 0
	for i in skills.size():
		var skill_value: int = skills[i]
		if skill_value == 0:
			continue
		for bit_position in 10:
			if (skill_value & (1 << (10 - bit_position))) != 0:
				var skill_index := i * 10 + bit_position
				if skill_index < TextLibrary.skill_names.size():
					skill_count += 1
	return skill_count


func has_skill(kind: int, index: int) -> bool:
	return ((skills[kind - 1] >> (10 - index)) & 0x1) == 1


func has_skill_1(skill_id: int) -> bool: return has_skill(1, skill_id)
func has_skill_2(skill_id: int) -> bool: return has_skill(2, skill_id)
func has_skill_3(skill_id: int) -> bool: return has_skill(3, skill_id)
func has_skill_4(skill_id: int) -> bool: return has_skill(4, skill_id)
func has_skill_5(skill_id: int) -> bool: return has_skill(5, skill_id)


func get_need_money_of_interior(task: int) -> int:
	var gold := 0
	match task:
		GameInfo.TaskType.RECLAIM:
			gold = (force + govern) / 2
		GameInfo.TaskType.MERCANTILE:
			gold = (wisdom + govern) / 2
		GameInfo.TaskType.TAME:
			gold = (lead + govern) / 2
		GameInfo.TaskType.PATROL:
			gold = (charm + govern) / 2
	var need_money := 10
	need_money += gold / 10
	need_money += 2 * (randi_range(0, 4) + 1)
	return need_money


func get_office_gen_belong_king() -> int:
	var king_id := 0
	var debuted_city := CityListCache.get_city_by_city_id(debutCity)
	var office_array: Array = debuted_city.get_officer_ids()
	for gid in office_array:
		if gid == generalId:
			return debuted_city.ownerID
	var in_count := 0
	var city_info := ""
	for city_id in range(1, CityListCache.CITY_NUM):
		var city := CityListCache.get_city_by_city_id(city_id)
		var ids: Array = city.get_officer_ids()
		for i in city.get_city_officer_num():
			if ids[i] == generalId:
				king_id = city.ownerID
				in_count += 1
				city_info += city.cityName
				if debutCity != city_id:
					city.remove_officer_id(generalId)
					debutCity = city_id
	return king_id


static func from_dict(d: Dictionary) -> General:
	var g := General.new()
	g.generalId = int(d.get("generalId", 0))
	g.generalName = str(d.get("generalName", ""))
	g.debutYear = int(d.get("debutYear", 0))
	g.debutCity = int(d.get("debutCity", 0))
	g.phase = int(d.get("phase", 0))
	g.status = int(d.get("status", 0))
	g.level = int(d.get("level", 1))
	g.army = _to_int_array(d.get("army", []), 3)
	g.health = int(d.get("health", 100))
	g.lead = int(d.get("lead", 0))
	g.force = int(d.get("force", 0))
	g.wisdom = int(d.get("wisdom", 0))
	g.govern = int(d.get("govern", 0))
	g.charm = int(d.get("charm", 0))
	g.loyalty = int(d.get("loyalty", 0))
	g.arm = int(d.get("arm", 0))
	g.armor = int(d.get("armor", 0))
	g.soldiers = int(d.get("soldiers", 0))
	g.followWho = int(d.get("followWho", 0))
	g.experience = int(d.get("experience", 0))
	g.skills = _to_int_array(d.get("skills", []), 5)
	return g


func to_dict() -> Dictionary:
	return {
		"generalId": generalId, "generalName": generalName, "debutYear": debutYear,
		"debutCity": debutCity, "phase": phase, "status": status, "level": level,
		"army": army, "health": health, "lead": lead, "force": force,
		"wisdom": wisdom, "govern": govern, "charm": charm, "loyalty": loyalty,
		"arm": arm, "armor": armor, "soldiers": soldiers, "followWho": followWho,
		"experience": experience, "skills": skills,
		"leadExp": leadExp, "forceExp": forceExp, "wisdomExp": wisdomExp,
		"charmExp": charmExp, "governExp": governExp, "isDie": isDie,
	}


static func _to_int_array(data, size: int) -> Array:
	var arr := []
	if data is Array:
		for i in mini(data.size(), size):
			arr.append(int(data[i]))
	while arr.size() < size:
		arr.append(0)
	return arr
