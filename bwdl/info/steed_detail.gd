# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/steed_detail.gd
# 说明：信息面板-坐骑详情。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "equip_detail.gd"

func _ready():
	equipType = "坐骑"
	return

func reload_more(steed: clEquip.EquipInfo) -> void :
	attrs.get_node("马力").text = "马力：{0}".format([steed.get_attr_int("马力")])
	attrs.get_node("机动力").text = "机动力：{0}".format([steed.get_attr_int("机动力恢复")])
	return
