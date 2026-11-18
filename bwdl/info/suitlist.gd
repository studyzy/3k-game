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
