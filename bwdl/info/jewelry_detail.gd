extends "equip_detail.gd"

func _ready():
	equipType = "道具"
	return

func reload_more(jewelry: clEquip.EquipInfo) -> void :
	header.get_node("类型").text = jewelry.subtype()
	return
