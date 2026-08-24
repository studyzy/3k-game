class_name Plan
extends RefCounted
## 计策系统（16 种计策，对应 Unity Plan.cs）

## 通用成功率公式
func _base_rate(do_gen: General, be_gen: General, d: float, extra_iq: float = -0.2, extra_stat: float = -0.05, extra_lead1: float = 0.0) -> int:
	var iq1 := do_gen.wisdom
	var iq2 := be_gen.wisdom
	var stat2 := be_gen.lead
	var lead1 := do_gen.lead
	var r1 := int(iq1 * 0.3 + iq1 * extra_iq + 70 - stat2 * extra_stat + lead1 * extra_lead1)
	var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / d - (100.0 - iq1) * 0.1 - stat2 * extra_stat + lead1 * extra_lead1)
	if iq1 < iq2:
		r2 -= int((iq2 - iq1) * 0.6)
	return mini(r1, r2)


func _rate_enhance(do_gen: General, rate: int) -> int:
	if do_gen.has_skill(1, 5):  # 神算
		rate += maxi(rate / 4, 15) if do_gen.generalName == "诸葛亮" else rate / 5
	return rate


func _rate_weaken(be_gen: General, rate: int) -> int:
	if be_gen.has_skill(1, 0):  # 冷静
		rate -= rate / 2
	elif be_gen.has_skill(1, 5):  # 神算
		rate -= maxi(rate / 4, 15) if be_gen.generalName == "诸葛亮" else rate / 5
	return rate


func _result_enhance(do_general: General, loss: int) -> int:
	if do_general.has_skill(1, 3):  # 军师 1.5倍
		loss += loss / 2
	return loss


func _add_plan_exp(do_general: General, exp: int) -> void:
	do_general.add_experience(exp / 3)
	do_general.add_iq_exp(exp / 100)


## 通用伤害公式（依据智力差）
func _iq_damage(do_gen: General, be_gen: General, base: int, iq_mult: int) -> int:
	var loss := base
	var diff := do_gen.wisdom - be_gen.wisdom
	if diff >= 0:
		loss += randi_range(0, diff * iq_mult + 1)
	else:
		loss += randi_range(diff * iq_mult - 2, -1)
	return loss


func _get_unit(general_id: int, is_player: bool) -> UnitData:
	if is_player:
		for u in WarManager.aiUnits:
			if u.genID == general_id:
				return u
	else:
		for u in WarManager.hmUnits:
			if u.genID == general_id:
				return u
	return null


func _set_trapped(general_id: int, is_player: bool, days: int) -> void:
	var u := _get_unit(general_id, is_player)
	if u != null:
		u.trappedDay = days
		u.unitState = UnitData.UnitState.TRAPPED


## 围杀损失
func _surrounding_loss(be_gen: General, surround_loss: int, is_player: bool) -> int:
	var unit_obj := _get_unit(be_gen.generalId, is_player)
	if unit_obj == null:
		return 0
	var units := WarManager.aiUnits if is_player else WarManager.hmUnits
	var total := 0
	for adjacent in units:
		if adjacent.unitState == UnitData.UnitState.CAPTIVE:
			continue
		if MapManager.is_adjacent(unit_obj.arrayPos, adjacent.arrayPos):
			var nearby := GeneralListCache.get_general(adjacent.genID)
			if nearby == null:
				continue
			nearby.sub_soldier(surround_loss)
			total = mini(total + surround_loss, total + nearby.soldiers)
	return total


## 需要实现的虚方法
func get_plan_id() -> int: return 0
func get_plan_name() -> String: return ""
func get_cost() -> int: return 0
func get_distance() -> int: return 0
func get_be_terrain() -> Array: return []
func get_do_terrain() -> Array: return []
func get_friend_minimum() -> int: return -1
func rate(_do_gen: General, _be_gen: General) -> int: return 0
func result(_do_gen: General, _be_gen: General, _is_player: bool) -> String: return ""


func use_cost(do_general: General) -> int:
	var base_cost := get_cost()
	if do_general.has_skill(1, 2):  # 百出
		base_cost -= 2
	return base_cost


func get_description() -> String:
	return TextLibrary.PLAN_EXPLAIN[get_plan_id()]


func in_distance(do_general: General) -> int:
	if do_general.has_skill(1, 1):  # 鬼谋
		return get_distance() + 1
	return get_distance()


func is_applicable(cur_terrain: int) -> bool:
	return (cur_terrain & 0x1F) in get_be_terrain()


func is_suitable(cur_terrain: int) -> bool:
	if get_do_terrain().is_empty():
		return true
	return (cur_terrain & 0x1F) in get_do_terrain()


func is_multiple_target(be_gen: General, is_player: bool) -> bool:
	if get_friend_minimum() < 0:
		return true
	var count := 0
	var unit_obj := _get_unit(be_gen.generalId, is_player)
	if unit_obj == null:
		return false
	var units := WarManager.aiUnits if is_player else WarManager.hmUnits
	for u in units:
		if u.unitState == UnitData.UnitState.CAPTIVE:
			continue
		if MapManager.is_adjacent(unit_obj.arrayPos, u.arrayPos):
			count += 1
	return count >= get_friend_minimum()


func is_commander_target(be_gen: General, is_player: bool) -> bool:
	if is_player:
		return not WarManager.aiUnits.is_empty() and be_gen.generalId == WarManager.aiUnits[0].genID
	return not WarManager.hmUnits.is_empty() and be_gen.generalId == WarManager.hmUnits[0].genID


func is_execute(do_gen: General, be_gen: General, is_player: bool) -> bool:
	WarManager.planResult = 0
	if be_gen.has_skill(1, 6):  # 反计
		if randi_range(0, 70) <= rate(be_gen, do_gen):
			WarManager.planResult = 1
			return true
	if randi_range(0, 70) <= rate(do_gen, be_gen):
		WarManager.planResult = 2
		return true
	return false


## 计策注册表
static func get_plan(plan_id: int) -> Plan:
	match plan_id:
		0: return HuoJiPlan.new()
		1: return XianJingPlan.new()
		2: return XuBingPlan.new()
		3: return YaoJiPlan.new()
		4: return LuanShuiPlan.new()
		5: return JieLiangPlan.new()
		6: return GongShaPlan.new()
		7: return WeiJiPlan.new()
		8: return ShaoLiangPlan.new()
		9: return LuoShiPlan.new()
		10: return LianHuanPlan.new()
		11: return FuBingPlan.new()
		12: return ShuiGongPlan.new()
		13: return JianYuPlan.new()
		14: return JieHuoPlan.new()
		15: return QiMenPlan.new()
	return null


# ============ 16 种计策 ============

class HuoJiPlan:
	extends Plan
	func get_plan_id() -> int: return 0
	func get_plan_name() -> String: return "火攻"
	func get_cost() -> int: return 6
	func get_distance() -> int: return 5
	func get_be_terrain() -> Array: return [1, 2, 3, 4, 10, 11]
	func rate(do_gen: General, be_gen: General) -> int:
		var r := _base_rate(do_gen, be_gen, 40.0)
		if do_gen.has_skill(1, 5):  # 神算
			r += maxi(r / 4, 15) if do_gen.generalName == "诸葛亮" else r / 5
		elif do_gen.has_skill(1, 4):  # 火攻
			r += r / 2 if do_gen.generalName == "周瑜" else r / 3
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, _is_player: bool) -> String:
		var loss := _iq_damage(do_gen, be_gen, 250, 2)
		if do_gen.has_skill(1, 4):  # 火攻
			loss *= 2
		elif do_gen.has_skill(1, 3):  # 军师
			loss += loss / 2
		loss = mini(loss, be_gen.soldiers)
		be_gen.sub_soldier(loss)
		_add_plan_exp(do_gen, loss)
		return "%s中了%s之计！折损：%d 兵马" % [be_gen.generalName, do_gen.generalName, loss]


class XianJingPlan:
	extends Plan
	func get_plan_id() -> int: return 1
	func get_plan_name() -> String: return "陷阱"
	func get_cost() -> int: return 5
	func get_distance() -> int: return 5
	func get_be_terrain() -> Array: return [10, 12]
	func rate(do_gen: General, be_gen: General) -> int:
		var r := _base_rate(do_gen, be_gen, 40.0)
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, _is_player: bool) -> String:
		var hurt := randi_range(10, 20)
		hurt = _result_enhance(do_gen, hurt)
		if be_gen.get_hp() - 1 < hurt:
			hurt = be_gen.get_hp() - 1
		be_gen.sub_hp(hurt)
		_add_plan_exp(do_gen, hurt * 15)
		return "%s中了%s之计！受到：%d伤害" % [be_gen.generalName, do_gen.generalName, hurt]


class XuBingPlan:
	extends Plan
	func get_plan_id() -> int: return 2
	func get_plan_name() -> String: return "虚兵"
	func get_cost() -> int: return 4
	func get_distance() -> int: return 5
	func get_be_terrain() -> Array: return [10, 12]
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var force2 := be_gen.force
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - force2 * 0.08)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 45 - (100.0 - iq1) * 0.1 - force2 * 0.08)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		var r := mini(r1, r2)
		r = _rate_enhance(do_gen, r)
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		var days := 2 if do_gen.has_skill(1, 3) else 1  # 军师
		_set_trapped(be_gen.generalId, is_player, days)
		_add_plan_exp(do_gen, days * 100)
		return "%s中了%s之计！动弹不得" % [be_gen.generalName, do_gen.generalName]


class YaoJiPlan:
	extends Plan
	func get_plan_id() -> int: return 3
	func get_plan_name() -> String: return "要击"
	func get_cost() -> int: return 6
	func get_distance() -> int: return 5
	func get_be_terrain() -> Array: return [10, 12]
	func rate(do_gen: General, be_gen: General) -> int:
		return XuBingPlan.new().rate(do_gen, be_gen)
	func result(do_gen: General, be_gen: General, _is_player: bool) -> String:
		var loss := _iq_damage(do_gen, be_gen, 250, 2)
		loss = _result_enhance(do_gen, loss)
		loss = mini(loss, be_gen.soldiers)
		be_gen.sub_soldier(loss)
		_add_plan_exp(do_gen, loss)
		return "%s中了%s之计！折损：%d 兵马" % [be_gen.generalName, do_gen.generalName, loss]


class LuanShuiPlan:
	extends Plan
	func get_plan_id() -> int: return 4
	func get_plan_name() -> String: return "乱水"
	func get_cost() -> int: return 6
	func get_distance() -> int: return 5
	func get_be_terrain() -> Array: return [9]
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var lead2 := be_gen.lead
		var type_a: int = be_gen.army[2]
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - lead2 * 0.05)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 40 - (100.0 - iq1) * 0.1 - lead2 * 0.05)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		if type_a > 0:
			r1 -= type_a * 3
			r2 -= type_a * 2
		var r := mini(r1, r2)
		r = _rate_enhance(do_gen, r)
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		return YaoJiPlan.new().result(do_gen, be_gen, is_player)


class JieLiangPlan:
	extends Plan
	func get_plan_id() -> int: return 5
	func get_plan_name() -> String: return "劫粮"
	func get_cost() -> int: return 8
	func get_distance() -> int: return 2
	func get_be_terrain() -> Array: return [1, 2, 3, 4, 5, 6, 7, 10, 11, 12]
	func in_distance(do_general: General) -> int:
		var base := get_distance()
		if do_general.has_skill(1, 1):  # 鬼谋
			base += 1
		elif do_general.has_skill(1, 8):  # 袭粮
			base += 1
		return base
	func rate(do_gen: General, be_gen: General) -> int:
		var r := _base_rate(do_gen, be_gen, 60.0)
		if do_gen.has_skill(1, 5):
			r += maxi(r / 4, 15) if do_gen.generalName == "诸葛亮" else r / 5
		elif be_gen.has_skill(1, 8):  # 袭粮
			r += r / 3
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		var target_food := WarManager.aiFood if is_player else WarManager.hmFood
		var gain_food := WarManager.hmFood if is_player else WarManager.aiFood
		var loss := target_food / 4
		loss = _result_enhance(do_gen, loss)
		if loss < 200:
			loss = target_food
		if is_player:
			WarManager.aiFood = target_food - loss
			WarManager.hmFood = mini(gain_food + loss, 30000)
		else:
			WarManager.hmFood = target_food - loss
			WarManager.aiFood = mini(gain_food + loss, 30000)
		_add_plan_exp(do_gen, loss)
		return "%s中了%s之计！被劫：%d军粮" % [be_gen.generalName, do_gen.generalName, loss]


class GongShaPlan:
	extends Plan
	func get_plan_id() -> int: return 6
	func get_plan_name() -> String: return "共杀"
	func get_cost() -> int: return 8
	func get_distance() -> int: return 2
	func get_be_terrain() -> Array: return [12]
	func get_friend_minimum() -> int: return 1
	func in_distance(do_general: General) -> int:
		var base := get_distance()
		if do_general.has_skill(1, 1):
			base += 1
		elif do_general.has_skill(1, 9):  # 内讧
			base += 1
		return base
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var moral2 := be_gen.charm
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - moral2 * 0.05)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 60 - (100.0 - iq1) * 0.1 - moral2 * 0.05)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		var r := mini(r1, r2)
		if do_gen.has_skill(1, 5):
			r += maxi(r / 4, 15) if do_gen.generalName == "诸葛亮" else r / 5
		elif be_gen.has_skill(1, 9):
			r += r / 3
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		var loss := _iq_damage(do_gen, be_gen, 450, 3)
		loss = _result_enhance(do_gen, loss)
		var surround_loss := loss
		loss = mini(loss, be_gen.soldiers)
		be_gen.sub_soldier(loss)
		var total := loss + _surrounding_loss(be_gen, surround_loss, is_player)
		_add_plan_exp(do_gen, total)
		return "%s等中了%s之计！总共折损：%d 兵马" % [be_gen.generalName, do_gen.generalName, total]


class WeiJiPlan:
	extends Plan
	func get_plan_id() -> int: return 7
	func get_plan_name() -> String: return "伪击转杀"
	func get_cost() -> int: return 8
	func get_distance() -> int: return 1
	func get_be_terrain() -> Array: return [8]
	func rate(do_gen: General, be_gen: General) -> int:
		if be_gen.soldiers <= 1800 + randi_range(0, 299):
			return 0
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var moral2 := be_gen.charm
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - moral2 * 0.05)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 60 - (100.0 - iq1) * 0.1 - moral2 * 0.05)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		var r := mini(r1, r2)
		r = _rate_enhance(do_gen, r)
		r = _rate_enhance(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		return YaoJiPlan.new().result(do_gen, be_gen, is_player)


class ShaoLiangPlan:
	extends Plan
	func get_plan_id() -> int: return 8
	func get_plan_name() -> String: return "烧粮"
	func get_cost() -> int: return 10
	func get_distance() -> int: return 2
	func get_be_terrain() -> Array: return [10, 11]
	func in_distance(do_general: General) -> int:
		return JieLiangPlan.new().in_distance(do_general)
	func rate(do_gen: General, be_gen: General) -> int:
		var r := _base_rate(do_gen, be_gen, 70.0)
		if do_gen.has_skill(1, 5):
			r += maxi(r / 4, 15) if do_gen.generalName == "诸葛亮" else r / 5
		elif be_gen.has_skill(1, 8):
			r += r / 3
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		var loss := 0
		if is_player:
			loss = WarManager.aiFood / 2
			loss = _result_enhance(do_gen, loss)
			if loss < 500:
				loss = WarManager.aiFood
			WarManager.aiFood -= loss
		else:
			loss = WarManager.hmFood / 2
			loss = _result_enhance(do_gen, loss)
			if loss < 500:
				loss = WarManager.hmFood
			WarManager.hmFood -= loss
		_add_plan_exp(do_gen, loss)
		return "%s中了%s之计！烧毁了：%d军粮" % [be_gen.generalName, do_gen.generalName, loss]


class LuoShiPlan:
	extends Plan
	func get_plan_id() -> int: return 9
	func get_plan_name() -> String: return "落石"
	func get_cost() -> int: return 9
	func get_distance() -> int: return 2
	func get_do_terrain() -> Array: return [8, 12]
	func get_be_terrain() -> Array: return [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12]
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var lead1 := do_gen.lead
		var lead2 := be_gen.lead
		var type_a: int = be_gen.army[1]
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - lead2 * 0.05 + lead1 * 0.05)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 40 - (100.0 - iq1) * 0.1 - lead2 * 0.05 + lead1 * 0.05)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		if type_a == 3:
			r1 -= 6
			r2 -= 3
		var r := mini(r1, r2)
		r = _rate_enhance(do_gen, r)
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, _is_player: bool) -> String:
		var loss := _iq_damage(do_gen, be_gen, 350, 3)
		loss = _result_enhance(do_gen, loss)
		loss = mini(loss, be_gen.soldiers)
		be_gen.sub_soldier(loss)
		var hurt := randi_range(10, 20)
		hurt = _result_enhance(do_gen, hurt)
		if be_gen.get_hp() - 1 < hurt:
			hurt = be_gen.get_hp() - 1
		be_gen.sub_hp(hurt)
		_add_plan_exp(do_gen, loss + hurt * 15)
		return "%s中了%s之计！受到%d伤害,折损%d 兵马" % [be_gen.generalName, do_gen.generalName, hurt, loss]


class LianHuanPlan:
	extends Plan
	func get_plan_id() -> int: return 10
	func get_plan_name() -> String: return "连环"
	func get_cost() -> int: return 10
	func get_distance() -> int: return 5
	func get_be_terrain() -> Array: return [9]
	func get_friend_minimum() -> int: return 1
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var lead1 := do_gen.lead
		var lead2 := be_gen.lead
		var type_a: int = be_gen.army[2]
		var r1 := int(iq1 * 0.3 - iq2 * 0.33 + 80 - lead2 * 0.1 + lead1 * 0.1)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 50 - (100.0 - iq1) * 0.1 - lead2 * 0.1 + lead1 * 0.1)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		if type_a == 3:
			r1 -= 6
			r2 -= 3
		var r := mini(r1, r2)
		if do_gen.has_skill(1, 5):
			r += maxi(r / 4, 15) if do_gen.generalName == "诸葛亮" else r / 5
		elif be_gen.has_skill(1, 9):
			r += r / 3
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		_set_trapped(do_gen.generalId, is_player, 3)
		var unit_obj := _get_unit(be_gen.generalId, is_player)
		if unit_obj == null:
			return "未找到%s等" % be_gen.generalName
		var units := WarManager.aiUnits if is_player else WarManager.hmUnits
		for adjacent in units:
			if adjacent.unitState == UnitData.UnitState.CAPTIVE:
				continue
			if MapManager.is_adjacent(unit_obj.arrayPos, adjacent.arrayPos):
				adjacent.trappedDay = 3
				adjacent.unitState = UnitData.UnitState.TRAPPED
		_add_plan_exp(do_gen, 900)
		return "%s等中了%s之计, 被困三天" % [be_gen.generalName, do_gen.generalName]


class FuBingPlan:
	extends Plan
	func get_plan_id() -> int: return 11
	func get_plan_name() -> String: return "伏兵"
	func get_cost() -> int: return 10
	func get_distance() -> int: return 5
	func get_do_terrain() -> Array: return [11, 12]
	func get_be_terrain() -> Array: return [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12]
	func in_distance(do_general: General) -> int:
		var base := get_distance()
		if do_general.has_skill(1, 1):
			base += 1
		elif do_general.has_skill(1, 7):  # 待伏
			base += 2
		return base
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var lead1 := do_gen.lead
		var lead2 := be_gen.lead
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - lead2 * 0.05 + lead1 * 0.08)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 60 - (100.0 - iq1) * 0.1 - lead2 * 0.05 + lead1 * 0.08)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		var r := mini(r1, r2)
		if do_gen.has_skill(1, 5):
			r += maxi(r / 4, 15) if do_gen.generalName == "诸葛亮" else r / 5
		elif be_gen.has_skill(1, 7):
			r += r / 3
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		var diff := do_gen.wisdom - be_gen.wisdom
		var loss := 600
		if diff >= 0:
			loss += randi_range(0, diff * 3 + 1)
		else:
			loss += randi_range(diff * 4 - 2, -1)
		loss = _result_enhance(do_gen, loss)
		loss = mini(loss, be_gen.soldiers)
		be_gen.sub_soldier(loss)
		_set_trapped(be_gen.generalId, is_player, 1)
		_add_plan_exp(do_gen, loss + 300)
		return "%s中了%s之计！折损：%d 兵马且动弹不得" % [be_gen.generalName, do_gen.generalName, loss]


class ShuiGongPlan:
	extends Plan
	func get_plan_id() -> int: return 12
	func get_plan_name() -> String: return "水攻"
	func get_cost() -> int: return 12
	func get_distance() -> int: return 3
	func get_be_terrain() -> Array: return [9]
	func get_friend_minimum() -> int: return 1
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var lead1 := do_gen.lead
		var lead2 := be_gen.lead
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - lead2 * 0.05 + lead1 * 0.08)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 60 - (100.0 - iq1) * 0.1 - lead2 * 0.05 + lead1 * 0.08)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		var r := mini(r1, r2)
		if do_gen.has_skill(1, 5):
			r += maxi(r / 4, 15) if do_gen.generalName == "诸葛亮" else r / 5
		elif be_gen.has_skill(1, 9):
			r += r / 3
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		return GongShaPlan.new().result(do_gen, be_gen, is_player)


class JianYuPlan:
	extends Plan
	func get_plan_id() -> int: return 13
	func get_plan_name() -> String: return "箭雨"
	func get_cost() -> int: return 10
	func get_distance() -> int: return 2
	func get_do_terrain() -> Array: return [8, 12]
	func get_be_terrain() -> Array: return [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12]
	func rate(do_gen: General, be_gen: General) -> int:
		var iq1 := do_gen.wisdom
		var iq2 := be_gen.wisdom
		var lead1 := do_gen.lead
		var lead2 := be_gen.lead
		var r1 := int(iq1 * 0.3 - iq2 * 0.2 + 70 - lead2 * 0.05 + lead1 * 0.08)
		var r2 := int(iq1 * iq1 * (100 - iq2 * 0.9) * 100 / (iq1 * iq1 + iq2 * iq2) / 60.0 - (100.0 - iq1) * 0.1 - lead2 * 0.05 + lead1 * 0.08)
		if iq1 < iq2:
			r2 -= int((iq2 - iq1) * 0.6)
		var r := mini(r1, r2)
		r = _rate_enhance(do_gen, r)
		r = _rate_weaken(be_gen, r)
		return clampi(r, 0, 99)
	func result(do_gen: General, be_gen: General, _is_player: bool) -> String:
		var loss := _iq_damage(do_gen, be_gen, 400, 3)
		loss = _result_enhance(do_gen, loss)
		loss = mini(loss, be_gen.soldiers)
		be_gen.sub_soldier(loss)
		_add_plan_exp(do_gen, loss)
		return "%s中了%s之计！折损：%d 兵马" % [be_gen.generalName, do_gen.generalName, loss]


class JieHuoPlan:
	extends Plan
	func get_plan_id() -> int: return 14
	func get_plan_name() -> String: return "劫火"
	func get_cost() -> int: return 12
	func get_distance() -> int: return 3
	func get_be_terrain() -> Array: return [10, 11]
	func get_friend_minimum() -> int: return 2
	func rate(do_gen: General, be_gen: General) -> int:
		return JianYuPlan.new().rate(do_gen, be_gen)
	func result(do_gen: General, be_gen: General, is_player: bool) -> String:
		var loss := _iq_damage(do_gen, be_gen, 550, 3)
		if do_gen.has_skill(1, 3):
			loss += loss / 2
		elif do_gen.has_skill(1, 4):
			loss *= 2
		var surround_loss := loss
		loss = mini(loss, be_gen.soldiers)
		be_gen.sub_soldier(loss)
		var total := loss
		var unit_obj := _get_unit(be_gen.generalId, is_player)
		if unit_obj != null:
			var units := WarManager.aiUnits if is_player else WarManager.hmUnits
			for adjacent in units:
				if adjacent.unitState == UnitData.UnitState.CAPTIVE:
					continue
				if MapManager.is_adjacent(unit_obj.arrayPos, adjacent.arrayPos):
					var nearby := GeneralListCache.get_general(adjacent.genID)
					if nearby == null:
						continue
					nearby.sub_soldier(surround_loss)
					total = mini(total + surround_loss, total + nearby.soldiers)
		_add_plan_exp(do_gen, total)
		return "%s等中了%s之计！总共折损：%d 兵马" % [be_gen.generalName, do_gen.generalName, total]


class QiMenPlan:
	extends Plan
	func get_plan_id() -> int: return 15
	func get_plan_name() -> String: return "奇门遁甲"
	func get_cost() -> int: return 10
	func get_distance() -> int: return 9
	func get_be_terrain() -> Array: return [10, 11, 12]
	func rate(_do_gen: General, _be_gen: General) -> int:
		return 99
	func result(do_gen: General, be_gen: General, _is_player: bool) -> String:
		var human := GeneralListCache.get_general(be_gen.generalId)
		if human == null:
			return ""
		var loss := 100 - randi_range(0, 149 - human.lead)
		human.sub_soldier(loss)
		_add_plan_exp(do_gen, 6 * loss)
		return "%s已布下奇门遁甲之阵" % do_gen.generalName
