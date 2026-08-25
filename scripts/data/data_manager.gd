extends Node
## 数据管理器（autoload: DataManager）

const MAX_SAVE_SLOTS := 4
const SAVE_DIR := "user://Saves"
const CUSTOM_DIR := "user://Custom"

var maps: Dictionary = {}           # cityId -> 2D Array(19x32)
var formations: Dictionary = {}     # name -> 2D Array(7x16)
var chapters: Array = []            # 剧本列表 [{year, title, introduction}]


## 静态数据已由 NetClient.fetch_static() 从服务器下发填充，
## 此方法保留为空操作以兼容各场景的防御性调用。
func ensure_loaded() -> void:
	pass


## 应用服务器下发的静态渲染数据（GET /game/static 的 data 字段）。
## 服务器是唯一数据源，客户端不再读本地 data/*.json / Map / Formation。
func apply_static(data: Dictionary) -> void:
	# 武将
	GeneralListCache.clear_all_total_generals()
	for item in data.get("generals", []):
		var g := General.from_dict(item)
		GeneralListCache.add_general(g)
		if g.debutYear <= GameInfo.years:
			GeneralListCache.add_debuted_general(g)
		else:
			GeneralListCache.add_no_debut_general(g)
	# 城池
	CityListCache.clear_all_cities()
	for item in data.get("cities", []):
		CityListCache.add_city(City.from_dict(item))
	# 势力
	CountryListCache.clear_all_countries()
	for item in data.get("countries", []):
		CountryListCache.add_country(Country.from_dict(item))
	# 武器
	WeaponListCache.clear_all_weapons()
	for item in data.get("weapons", []):
		WeaponListCache.add_weapon(Weapon.from_dict(item))
	# 地图（cityId -> 19x32 网格）
	maps = {}
	for row in data.get("maps", []):
		maps[int(row.get("cityId", 0))] = row.get("grid", [])
	# 阵型（name -> 7x16 网格）
	formations = {}
	for row in data.get("formations", []):
		formations[str(row.get("name", ""))] = row.get("grid", [])
	# 剧本
	chapters = data.get("chapters", [])
	_initialize()


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
	return maps.get(city_id, [])


## 阵型已在 apply_static 中全部加载到内存，此方法保留为空操作。
func load_all_formations() -> void:
	pass


func get_formation(name: String) -> Array:
	return formations.get(name, [])


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
