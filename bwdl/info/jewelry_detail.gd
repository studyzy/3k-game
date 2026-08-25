# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/jewelry_detail.gd
# 说明：信息面板-宝物详情。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "equip_detail.gd"

func _ready():
	equipType = "道具"
	return

func reload_more(jewelry: clEquip.EquipInfo) -> void :
	header.get_node("类型").text = jewelry.subtype()
	return
