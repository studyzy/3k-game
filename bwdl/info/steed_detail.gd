extends "equip_detail.gd"

func _ready():
	equipType = "坐骑"
	return

func reload_more(steed: clEquip.EquipInfo) -> void :
	attrs.get_node("马力").text = "马力：{0}".format([steed.get_attr_int("马力")])
	attrs.get_node("机动力").text = "机动力：{0}".format([steed.get_attr_int("机动力恢复")])
	return
