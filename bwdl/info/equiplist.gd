# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/equiplist.gd
# 说明：信息面板-装备列表。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "basiclist.gd"

class EquipSorter extends Reference:

	func id(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.id < b.id

	func desc_id(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.id > b.id

	func type(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		if a.subtype() == b.subtype():
			return id(a, b)
		return a.subtype() > b.subtype()

	func desc_type(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		if a.subtype() == b.subtype():
			return id(a, b)
		return a.subtype() < b.subtype()

	func level(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.level_score() > b.level_score()

	func desc_level(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.level_score() < b.level_score()

	func attack(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("攻击力") > b.get_attr_int("攻击力")

	func desc_attack(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("攻击力") < b.get_attr_int("攻击力")

	func defence(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("防御力") > b.get_attr_int("防御力")

	func desc_defence(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("防御力") < b.get_attr_int("防御力")

	func weight(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.weight() > b.weight()

	func desc_weight(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.weight() < b.weight()

	func price(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("价格") > b.get_attr_int("价格")

	func desc_price(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("价格") < b.get_attr_int("价格")

	func ap(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("机动力恢复") > b.get_attr_int("机动力恢复")

	func desc_ap(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("机动力恢复") < b.get_attr_int("机动力恢复")

	func horsePower(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("马力") > b.get_attr_int("马力")

	func desc_horsePower(a: clEquip.EquipInfo, b: clEquip.EquipInfo) -> bool:
		return a.get_attr_int("马力") < b.get_attr_int("马力")

var equipType: String = "武器"

func _ready():
	sorter = EquipSorter.new()
	return

func reload_data() -> Array:
	var ret = []
	for equip in clEquip.all_equips(equipType):
		if keyword == "":
			ret.append(equip)
			continue
		if keyword == equip.get_attr_str("持法"):
			ret.append(equip)
			continue
		if StaticManager.RE_ALPHA.search(keyword) != null:
			var found = false
			for r in StaticManager.pinyin(equip.name()):
				if keyword in r:
					found = true
					ret.append(equip)
					break
			if found:
				continue
			for r in StaticManager.pinyin(equip.subtype()):
				if keyword in r:
					found = true
					ret.append(equip)
					break
			if found:
				continue
		if keyword in equip.name():
			ret.append(equip)
			continue
		if keyword in equip.subtype():
			ret.append(equip)
			continue
		if keyword in equip.get_attr_str("购买条件"):
			ret.append(equip)
			continue
		if keyword in equip.get_attr_str("描述"):
			ret.append(equip)
			continue
	return ret

func load_icon(row: HBoxContainer, equip: clEquip.EquipInfo):
	var icon: Sprite = row.get_node("ac/icon")
	var setting = equip.image_setting()
	icon.texture = setting["img"]
	var width = 32
	var height = 32
	icon.region_enabled = true
	icon.region_rect = Rect2(setting["x"], setting["y"], width, height)
	icon.scale = Vector2(48.0 / width, 48.0 / height)
	icon.centered = false
	icon.offset = Vector2(0, 0)
	return
