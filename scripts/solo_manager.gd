extends Node
## 单挑管理器（autoload: SoloManager，对应 Unity SoloManager）

var seizedWeapon: bool = false


func _general_atk_value(general: General, atk_power: int, def_power: int) -> int:
	var i := general.force
	i *= atk_power
	i /= maxi(def_power, 1)
	if i > 2 * general.force:
		i = 2 * general.force
	if i < general.force / 3:
		i = general.force / 3
	i += i / 5
	return i


func get_atk_dea(atk_general: General, atk: int, def: int) -> int:
	var dea := _general_atk_value(atk_general, atk, def) / 8
	if dea < 0:
		dea = 100
	return maxi(dea, 1)


func get_all_atk_dea(atk_general: General, atk: int, def: int) -> int:
	var dea := _general_atk_value(atk_general, atk, def) / 2
	if dea < 0:
		dea = 100
	return maxi(dea, 1)


func _weapon_effect(atk_general: General, def_general: General, sc: int, whack: bool) -> int:
	var a: int = atk_general.arm
	var b: int = def_general.armor
	if a == 5 and whack:
		sc += 20
	if (a == 6 or a == 7 or a == 14) and not whack:
		sc += 15
	if b == 30 and not whack:
		sc -= 15
	if b == 31 and not whack:
		sc -= 20
	elif b == 31 and whack:
		sc = 0
	return sc


## 武器命中率
func get_percentage(atk_general: General, def_general: General, whack: bool, hm_atk: bool) -> int:
	var sc := 0
	var atk_weapon_type := WeaponListCache.get_weapon(atk_general.arm).kind
	var def_weapon_type := WeaponListCache.get_weapon(def_general.arm).kind
	if atk_weapon_type == 0 and def_weapon_type == 0: sc = 70
	elif atk_weapon_type == 0 and def_weapon_type == 1: sc = 75
	elif atk_weapon_type == 0 and def_weapon_type == 2: sc = 60
	elif atk_weapon_type == 1 and def_weapon_type == 0: sc = 55
	elif atk_weapon_type == 1 and def_weapon_type == 1: sc = 60
	elif atk_weapon_type == 1 and def_weapon_type == 2: sc = 70
	elif atk_weapon_type == 2 and def_weapon_type == 0: sc = 80
	elif atk_weapon_type == 2 and def_weapon_type == 1: sc = 50
	elif atk_weapon_type == 2 and def_weapon_type == 2: sc = 60
	if hm_atk:
		sc -= 20
	if whack and hm_atk:
		sc = sc / 3
	elif whack and not hm_atk:
		sc = sc / 2
	sc = _weapon_effect(atk_general, def_general, sc, whack)
	return clampi(sc, 0, 100)


## 我方招降 AI 将领
func persuade(do_general: General, be_general: General) -> bool:
	if be_general.get_loyalty() > 99:
		return false
	var i1 := (do_general.charm * 7 + do_general.wisdom * 3) * 10 / 99
	i1 = (i1 - 70) / 5
	if i1 == 4:
		i1 = 6
	elif i1 == 5:
		i1 = 8
	i1 = be_general.get_hp() + be_general.get_loyalty() - i1 + randi_range(0, 4)
	return i1 < 100


## AI 招降我方将领
func ai_persuade(do_general: General, be_general: General) -> bool:
	if be_general.get_loyalty() > 99:
		return false
	var i1 := (do_general.charm * 7 + do_general.wisdom * 3) * 10 / 99
	i1 = (i1 - 70) / 5
	if i1 == 4:
		i1 = 6
	elif i1 == 5:
		i1 = 8
	i1 = be_general.get_hp() + be_general.get_loyalty() - i1 + randi_range(0, 4)
	return i1 < 110


## 单次攻击
func single_atk(atk_general: General, def_general: General, atk: int, def: int, hm_atk: bool) -> int:
	if get_percentage(atk_general, def_general, false, hm_atk) > randi_range(0, 100):
		return get_atk_dea(atk_general, atk, def)
	return 0
