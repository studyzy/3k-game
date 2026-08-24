extends Node
## 城池缓存（autoload: CityListCache）

const CITY_NUM: int = 49
var city_dictionary: Dictionary = {}  # id -> City


func clear_all_cities() -> void:
	city_dictionary.clear()


func get_city_by_city_id(id: int) -> City:
	if city_dictionary.has(id):
		return city_dictionary[id]
	return null


func add_city(city: City) -> void:
	city_dictionary[city.cityID] = city


func get_city_num() -> int:
	return city_dictionary.size()


## 移动武将/君主
func move_task(from_city_id: int, to_city_id: int, general_ids: Array) -> bool:
	var is_king_move := false
	var from_city := get_city_by_city_id(from_city_id)
	var to_city := get_city_by_city_id(to_city_id)
	for general_id in general_ids:
		if general_id == from_city.ownerID:
			from_city.remove_officer_id(general_id)
			to_city.add_office_general_id(general_id)
			to_city.appoint_prefect(general_id)
			is_king_move = true
		else:
			from_city.remove_officer_id(general_id)
			to_city.add_office_general_id(general_id)
	return is_king_move


## 输送钱粮宝物
func transport_between_citys(out_city_id: int, in_city_id: int, food: int, money: int, treasure_num: int) -> void:
	var out_city := get_city_by_city_id(out_city_id)
	var in_city := get_city_by_city_id(in_city_id)
	out_city.sub_gold(money)
	out_city.sub_food(food)
	out_city.sub_treasure_num(treasure_num)
	in_city.add_gold(money)
	in_city.add_food(food)
	in_city.add_treasure_num(treasure_num)
