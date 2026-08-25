# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/suitlist.gd
# 说明：信息面板-套装列表。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "equiplist.gd"

func init() -> void :
	equipType = "防具"
	return

func create_row(item: Object, idList: PoolIntArray) -> HBoxContainer:
	if not item is clEquip.EquipInfo:
		return null
	var suit: clEquip.EquipInfo = item
	var created = row.duplicate()
	load_icon(created, suit)
	for attr in ["名称", "品质", "防御力", "重量", "价格"]:
		created.get_node(attr).text = suit.get_attr_str(attr)
	var btn = created.get_node("operation/btn")
	btn.connect("pressed", self, "detail", [suit.id, idList])
	btn.editor_description = str(suit.id)
	return created
