extends Node
## 数据管理器（autoload: DataManager）

const MAX_SAVE_SLOTS := 4
const SAVE_DIR := "user://Saves"
const CUSTOM_DIR := "user://Custom"

var maps: Dictionary = {}           # cityId -> 2D Array(19x32)
var formations: Dictionary = {}     # name -> 2D Array(7x16)


## 确保配置已加载
func ensure_loaded() -> void:
	if GeneralListCache.general_dictionary.is_empty():
		load_all_configs()


## 加载全部配置（JSON + 初始化）
func load_all_configs() -> void:
	# 武将
	var generals := load_json_list("res://data/GeneralData.json")
	GeneralListCache.clear_all_total_generals()
	for item in generals:
		var g := General.from_dict(item)
		GeneralListCache.add_general(g)
		if g.debutYear <= GameInfo.years:
			GeneralListCache.add_debuted_general(g)
		else:
			GeneralListCache.add_no_debut_general(g)
	# 城市
	var cities := load_json_list("res://data/CityData.json")
	for item in cities:
		CityListCache.add_city(City.from_dict(item))
	# 势力
	var countries := load_json_list("res://data/CountryData.json")
	for item in countries:
		CountryListCache.add_country(Country.from_dict(item))
	# 武器
	var weapons := load_json_list("res://data/WeaponData.json")
	WeaponListCache.clear_all_weapons()
	for item in weapons:
		WeaponListCache.add_weapon(Weapon.from_dict(item))
	_initialize()


func load_json_list(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开配置文件: " + path)
		return []
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Array else []


func _initialize() -> void:
	_init_generals_in_cities()
	_init_cities()


func _init_generals_in_cities() -> void:
	for general in GeneralListCache.general_list:
		if general.generalId != 0:
			if general.debutYear > GameInfo.years or general.debutCity == 0:
				continue
			var city := CityListCache.get_city_by_city_id(general.debutCity)
			if city != null:
				if general.status == 1:
					city.add_office_general_id(general.generalId)
				else:
					city.add_not_found_general_id(general.generalId)


func _init_cities() -> void:
	for city_id in CityListCache.city_dictionary.keys():
		var city: City = CityListCache.city_dictionary[city_id]
		if city != null and city.ownerID > 0:
			var country := CountryListCache.get_country_by_king_id(city.ownerID)
			if country != null:
				if not country.cityIDs.has(city_id):
					city.auto_appoint_prefect()
					country.cityIDs.append(city_id)


# ---------- 地图 / 阵型 ----------

func read_map_data(city_id: int) -> Array:
	if maps.has(city_id):
		return maps[city_id]
	var path := "res://data/Map/%d.CSV" % city_id
	return _parse_csv_2d(path, 19, 32)


func load_all_formations() -> void:
	if not formations.is_empty():
		return
	# 读取 Formation 目录下所有 csv
	var dir := DirAccess.open("res://data/Formation")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".csv"):
			var name := file_name.get_basename()
			var path := "res://data/Formation/" + file_name
			formations[name] = _parse_csv_2d(path, 7, 16)
		file_name = dir.get_next()
	dir.list_dir_end()


func get_formation(name: String) -> Array:
	if formations.is_empty():
		load_all_formations()
	if formations.has(name):
		return formations[name]
	# 单个加载
	var path := "res://data/Formation/%s.csv" % name
	var arr := _parse_csv_2d(path, 7, 16)
	if not arr.is_empty():
		formations[name] = arr
	return arr


func _parse_csv_2d(path: String, rows: int, cols: int) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法打开地图/阵型文件: " + path)
		return []
	var text := file.get_as_text()
	var lines := text.split("\n")
	var result: Array = []
	for row in mini(rows, lines.size()):
		var values := lines[row].split(",")
		var line_arr: Array = []
		for col in mini(cols, values.size()):
			line_arr.append(int(values[col].strip_edges()))
		# 补齐到 cols
		while line_arr.size() < cols:
			line_arr.append(255)
		result.append(line_arr)
	return result


# ---------- 存档 ----------

func _get_save_paths() -> Array:
	var dir := DirAccess.open("user://")
	if dir == null:
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	elif not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var paths := []
	for i in MAX_SAVE_SLOTS:
		paths.append("%s/save%d.json" % [SAVE_DIR, i])
	return paths


func get_record_info() -> void:
	var paths := _get_save_paths()
	for i in MAX_SAVE_SLOTS:
		if FileAccess.file_exists(paths[i]):
			var data = _read_json_file(paths[i])
			if data is Dictionary and data.has("kingName") and str(data["kingName"]) != "":
				GameInfo.recordInfo[i] = "%s  %d年%d月" % [str(data["kingName"]), int(data["years"]), int(data["month"])]
			else:
				GameInfo.recordInfo[i] = "存档数据无效"
		else:
			GameInfo.recordInfo[i] = "尚无存档"


func save_game(index: int) -> void:
	var paths := _get_save_paths()
	var king := GeneralListCache.get_general(CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).countryKingId)
	var king_name := king.generalName if king != null else ""
	var data := {
		"kingName": king_name,
		"years": GameInfo.years,
		"month": GameInfo.month,
		"difficult": GameInfo.difficult,
		"playerCountryId": GameInfo.playerCountryId,
		"playerOrderNum": GameInfo.playerOrderNum,
		"doCityId": GameInfo.doCityId,
		"attackCount": GameInfo.attackCount,
		"countrySequence": CountryListCache.country_sequence,
		"weaponDictionary": _dict_to_array(WeaponListCache.weapon_dictionary),
		"generalDictionary": _dict_to_array(GeneralListCache.general_dictionary),
		"cityDictionary": _dict_to_array(CityListCache.city_dictionary),
		"countryDictionary": _dict_to_array(CountryListCache.country_dictionary),
	}
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(paths[index], FileAccess.WRITE)
	if file != null:
		file.store_string(json_text)
		file.close()


func load_game(index: int) -> void:
	var paths := _get_save_paths()
	if not FileAccess.file_exists(paths[index]):
		return
	var data = _read_json_file(paths[index])
	if data == null or not data is Dictionary:
		return
	GameInfo.month = int(data.get("month", 1))
	GameInfo.years = int(data.get("years", 251))
	GameInfo.difficult = int(data.get("difficult", 0))
	GameInfo.playerCountryId = int(data.get("playerCountryId", 0))
	GameInfo.playerOrderNum = int(data.get("playerOrderNum", 0))
	GameInfo.doCityId = int(data.get("doCityId", 0))
	GameInfo.attackCount = int(data.get("attackCount", 0))
	CountryListCache.country_sequence = _array_from(data.get("countrySequence", []))
	WeaponListCache.clear_all_weapons()
	for entry in data.get("weaponDictionary", []):
		WeaponListCache.add_weapon(Weapon.from_dict(entry["value"]))
	GeneralListCache.clear_all_total_generals()
	for entry in data.get("generalDictionary", []):
		var g := General.from_dict(entry["value"])
		GeneralListCache.general_dictionary[g.generalId] = g
		if g.debutYear <= GameInfo.years:
			GeneralListCache.add_debuted_general(g)
		else:
			GeneralListCache.add_no_debut_general(g)
	CityListCache.clear_all_cities()
	for entry in data.get("cityDictionary", []):
		CityListCache.add_city(City.from_dict(entry["value"]))
	CountryListCache.clear_all_countries()
	for entry in data.get("countryDictionary", []):
		CountryListCache.add_country(Country.from_dict(entry["value"]))
	GameInfo.playingState = GameInfo.GameState.PLAYER_TURN


func _read_json_file(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


## 把 Dictionary<id, obj> 转成 [{key, value}, ...]（Godot JSON 键必须是字符串）
func _dict_to_array(d: Dictionary) -> Array:
	var arr := []
	for key in d.keys():
		var obj = d[key]
		var value: Dictionary = {}
		if obj is Weapon:
			value = obj.to_dict()
		elif obj is General:
			value = obj.to_dict()
		elif obj is City:
			value = obj.to_dict()
		elif obj is Country:
			value = obj.to_dict()
		else:
			continue
		arr.append({"key": key, "value": value})
	return arr


func _array_from(data) -> Array:
	var arr := []
	if data is Array:
		for v in data:
			arr.append(int(v))
	return arr


# ---------- 自定义武将 ----------

func _get_custom_path() -> String:
	if not DirAccess.dir_exists_absolute(CUSTOM_DIR):
		DirAccess.make_dir_recursive_absolute(CUSTOM_DIR)
	return "%s/Custom.json" % CUSTOM_DIR


func read_custom_general_list() -> void:
	var path := _get_custom_path()
	var custom_list: Array = []
	if FileAccess.file_exists(path):
		var data = _read_json_file(path)
		if data is Array:
			for item in data:
				var g := General.from_dict(item)
				custom_list.append(g)
				GeneralListCache.add_general(g)
	GameInfo.customGeneralList = custom_list


func add_custom_general(general: General) -> void:
	GameInfo.customGeneralList.append(general)
	_general_to_file(GameInfo.customGeneralList)


func remove_custom_general(general_id: int) -> void:
	var idx := -1
	for i in GameInfo.customGeneralList.size():
		if GameInfo.customGeneralList[i].generalId == general_id:
			idx = i
			break
	if idx != -1:
		GameInfo.customGeneralList.remove_at(idx)
		_general_to_file(GameInfo.customGeneralList)


func _general_to_file(list: Array) -> void:
	var arr := []
	for g in list:
		arr.append(g.to_dict())
	var json_text := JSON.stringify(arr, "\t")
	var file := FileAccess.open(_get_custom_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(json_text)
		file.close()
