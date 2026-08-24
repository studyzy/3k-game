extends Node
## 武器缓存（autoload: WeaponListCache）

var weapon_dictionary: Dictionary = {}  # id -> Weapon


func add_weapon(weapon: Weapon) -> void:
	weapon_dictionary[weapon.weaponID] = weapon


func get_weapon_size() -> int:
	return weapon_dictionary.size()


func get_weapon(weapon_id: int) -> Weapon:
	if weapon_dictionary.has(weapon_id):
		return weapon_dictionary[weapon_id]
	return null


## 根据城池商店值筛选武器
func get_weapons_by_smithy(city_smithy: int) -> Array:
	if city_smithy == 0:
		return []
	var bit_mask := 1 << (city_smithy - 1)
	var result := []
	for weapon in weapon_dictionary.values():
		if (weapon.smithy & bit_mask) != 0:
			result.append(weapon)
	return result


func clear_all_weapons() -> void:
	weapon_dictionary.clear()
