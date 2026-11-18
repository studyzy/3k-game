extends "equiplist.gd"

func init() -> void :
	equipType = "道具"
	return

func create_row(item: Object, idList: PoolIntArray) -> HBoxContainer:
	if not item is clEquip.EquipInfo:
		return null
	var jewelry: clEquip.EquipInfo = item
	var created = row.duplicate()
	load_icon(created, jewelry)
	for attr in ["名称", "类型", "品质", "价格"]:
		created.get_node(attr).text = jewelry.get_attr_str(attr)
	var btn = created.get_node("operation/btn")
	btn.connect("pressed", self, "detail", [jewelry.id, idList])
	btn.editor_description = str(jewelry.id)
	return created
