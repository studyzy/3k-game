# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/weapon_detail.gd
# 说明：信息面板-武器详情。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

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
