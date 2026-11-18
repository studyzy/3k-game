extends "equiplist.gd"

func init() -> void :
	equipType = "坐骑"
	return

func create_row(item: Object, idList: PoolIntArray) -> HBoxContainer:
	if not item is clEquip.EquipInfo:
		return null
	var steed: clEquip.EquipInfo = item
	var created = row.duplicate()
	load_icon(created, steed)
	for attr in ["名称", "品质", "马力", "机动力恢复", "价格"]:
		created.get_node(attr).text = steed.get_attr_str(attr)
	var btn = created.get_node("operation/btn")
	btn.connect("pressed", self, "detail", [steed.id, idList])
	btn.editor_description = str(steed.id)
	return created
