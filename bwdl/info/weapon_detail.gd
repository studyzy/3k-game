extends "equip_detail.gd"

func _ready():
	equipType = "武器"
	return

func reload_more(weapon: clEquip.EquipInfo) -> void :
	header.get_node("类型").text = "{0} - {1}".format([
		weapon.get_attr_str("持法"), 
		"、".join(weapon.get_all_types()), 
	])
	return
