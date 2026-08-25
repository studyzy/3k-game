# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/equip_patch.gd
# 说明：信息面板-装备补丁。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "basiclist.gd"

onready var create = $create
onready var featureItem = $featureItem

var created: CustomEquip

class EquipPatchSorter extends Reference:

	func id(a, b) -> bool:
		return a.id < b.id

	func desc_id(a, b) -> bool:
		return a.id > b.id

	func type(a, b) -> bool:
		return a.type > b.type

	func desc_type(a, b) -> bool:
		return a.type < b.type

	func features(a, b) -> bool:
		return a.features().size() < b.features().size()

	func desc_features(a, b) -> bool:
		return a.features().size() > b.features().size()


func init() -> void :
	created = CustomEquip.new()
	for btn in header.get_children():
		if not btn is Button:
			continue
		Global.clear_signals(btn, ["pressed"])
		btn.connect("pressed", self, "attr_sorting", [btn])
	sorter = EquipPatchSorter.new()
	return

func reload_data() -> Array:
	create.hide()
	var ret = []
	
	for ce in StaticManager.custom_equips:
		var equip = clEquip.equip(ce.id, ce.type)
		
		if keyword != "" and not keyword in equip.name():
			continue
		ret.append(equip)
	return ret

func create_row(item: Object, idList: PoolIntArray) -> HBoxContainer:
	if not item is clEquip.EquipInfo:
		return null
	var equip: clEquip.EquipInfo = item
	var createdRow = row.duplicate()
	createdRow.get_node("名称").text = equip.name()
	createdRow.get_node("装备类型").text = equip.type
	createdRow.get_node("属性").text = " " + equip.get_attrs_brief()
	createdRow.get_node("特性").text = str(equip.features().size())
	var modBtn = createdRow.get_node("operation/修改")
	modBtn.connect("pressed", self, "modify_patch", [equip.id, equip.type])
	var delBtn = createdRow.get_node("operation/删除")
	delBtn.connect("pressed", self, "remove_patch", [equip.id, equip.type])
	return createdRow

func attr_sorting(btn):
	if btn.editor_description == "":
		return
	sorting(btn.editor_description)
	return

func modify_patch(equipId: int, equipType: String) -> void :
	created = null
	for ce in StaticManager.custom_equips:
		if ce.id == equipId and ce.type == equipType:
			created = ce
	if created == null:
		return
	detail_reset()
	detail.popup_centered()
	detail.popup_exclusive = true
	return

func remove_patch(equipId: int, equipType: String) -> void :
	var dialog = ConfirmationDialog.new()
	dialog.window_title = "请确认"
	dialog.dialog_text = "\n确定要删除以下自制{0}吗？\n{1}（#{2}）".format([
		equipType, clEquip.equip(equipId, equipType).name(), equipId, 
	])
	dialog.rect_size = Vector2(350, 150)
	dialog.get_ok().text = "删！"
	dialog.get_cancel().text = "再想想"
	add_child(dialog)
	dialog.connect("confirmed", self, "remove_patch_confirmed", [equipId, equipType])
	dialog.popup_exclusive = true
	dialog.popup_centered()
	return

func remove_patch_confirmed(equipId: int, equipType: String) -> void :
	StaticManager.remove_equip_patch(equipId, equipType)
	nav.get_node("keyword").text = ""
	reload_list("", page)
	return

func create_reset() -> void :
	for t in StaticManager.EQUIPMENT_TYPES:
		var btn = create.get_node(t)
		if not btn is Button:
			continue
		btn.disabled = t == created.type
	create.get_node("name").text = created.name
	return

func create_equip():
	created = CustomEquip.new()
	create_reset()
	create.popup_centered()
	detail.popup_exclusive = true
	return

func detail_reset() -> void :
	if not created.type in StaticManager.EQUIPMENT_TYPES:
		detail.hide()
		return
	detail.get_node("feature_selector").hide()
	detail.get_node("random").hide()
	if created.id == 0:
		detail.get_node("random").show()
	detail.get_node("notice").text = "自制{0}：".format([created.type])
	detail.get_node("name").text = created.name
	for t in StaticManager.EQUIPMENT_TYPES:
		var pnl = detail.get_node_or_null(t)
		if not pnl is Panel:
			continue
		pnl.hide()
	var current = detail.get_node_or_null(created.type)
	if current == null:
		return
	for child in current.get_children():
		if not child is TextEdit:
			continue
		var rng = CustomEquip.get_equip_attr_range(created.type, child.name)
		var digits = 1
		if rng[1] > 9:
			digits = 2
		if rng[1] > 99:
			digits = 3
		if rng[1] > 999:
			digits = 4
		child.reset_range("1,{0},{1},{2}".format([
			digits, rng[1], rng[0]
		]))
		child.text = str(Global.dic_val(created.attrs, child.name, ""))
	detail_reset_subtype()
	detail_reset_category()
	detail_reset_features()
	current.show()
	return

func detail_reset_subtype() -> void :
	var current = detail.get_node_or_null(created.type)
	if current == null:
		return
	for child in current.get_children():
		if not child is Button:
			continue
		if not child.editor_description.begins_with("subtype:"):
			continue
		var subtype = child.editor_description.trim_prefix("subtype:")
		child.hint_tooltip = subtype
		Global.clear_signals(child, ["pressed"])
		child.connect("pressed", self, "set_subtype", [subtype])
		child.disabled = subtype == created.subtype
	return

func detail_reset_category() -> void :
	var current = detail.get_node_or_null(created.type)
	if current == null:
		return
	for t in StaticManager.EQUIPMENT_TYPES:
		var pnl = detail.get_node_or_null(t)
		if not pnl is Panel:
			continue
		if created.type == t:
			current = pnl
	if current == null:
		return
	for child in current.get_children():
		if not child is Button:
			continue
		if not child.editor_description.begins_with("category"):
			continue
		var cate = child.editor_description.trim_prefix("category:")
		Global.clear_signals(child, ["pressed"])
		child.connect("pressed", self, "set_category", [cate])
		child.disabled = cate == Global.strval(Global.dic_val(created.attrs, "持法", ""))
	return

func detail_reset_features() -> void :
	var current = detail.get_node_or_null(created.type)
	if current == null:
		return
	var featuresPanel = current.get_node_or_null("features")
	if featuresPanel == null:
		var featuresTemplate = detail.get_node("features")
		featuresPanel = featuresTemplate.duplicate(true)
		for node in featuresPanel.get_children():
			if node is TextEdit:
				var script_path = featuresTemplate.get_node(node.name).get_script().resource_path
				node.set_script(load(script_path))
		featuresPanel.name = "features"
		current.add_child(featuresPanel)
	featuresPanel.show()
	for i in 3:
		var featureBtn = featuresPanel.get_node("特性" + str(i))
		var featureInput = featuresPanel.get_node("特性值" + str(i))
		var featureSetting = created.get_feature(i)
		var feature = featureSetting[0]
		var featureValue = featureSetting[1]
		var featureText = featureSetting[2]
		featureBtn.editor_description = feature
		if featureText.length() > 9:
			featureBtn.text = featureText.left(8) + "…"
		else:
			featureBtn.text = featureText
		Global.bind_button_tooltip(featureBtn, "")
		featureInput.readonly = true
		if feature != "":
			featureInput.readonly = false
			var rng = CustomEquip.get_equip_feature_range(created.type, feature)
			var tooltip = "{0}。\n数值范围：X in [{1}, {2}]".format([
				featureText, rng[0], rng[1]
			])
			Global.bind_button_tooltip(featureBtn, tooltip)
			var digits = 1
			if rng[1] > 9:
				digits = 2
			if rng[1] > 99:
				digits = 3
			if rng[1] > 999:
				digits = 4
			featureInput.reset_range("1,{0},{1},{2}".format([
				digits, rng[1], rng[0]
			]))
		featureInput.text = str(featureValue)
	return

func set_subtype(subtype: String):
	created.subtype = subtype
	detail_reset_subtype()
	detail_reset_features()
	return

func set_category(cate: String):
	created.attrs["持法"] = cate
	detail_reset_category()
	return

func create_detail():
	var name = create.get_node("name").text
	if name == "":
		return
	if not created.type in StaticManager.EQUIPMENT_TYPES:
		return
	created.name = name
	create.hide()
	detail_reset()
	detail.popup_centered()
	detail.popup_exclusive = true
	return

func update_model() -> void :
	if not created.type in StaticManager.EQUIPMENT_TYPES:
		return
	var current = detail.get_node_or_null(created.type)
	if current == null:
		return
	created.name = detail.get_node("name").text
	var attrs = {}
	for child in current.get_children():
		if not child is TextEdit:
			continue
		attrs[child.name] = Global.intval(child.text)
	created.set_attrs(attrs)
	for i in 3:
		var feature = current.get_node("features/特性" + str(i)).editor_description
		var val = Global.intval(current.get_node("features/特性值" + str(i)).text)
		created.set_feature(i, feature, val)
	return

func save_patch() -> void :
	if not created.type in StaticManager.EQUIPMENT_TYPES:
		return
	var current = detail.get_node_or_null(created.type)
	if current == null:
		return
	update_model()
	if created.id >= StaticManager.CUSTOM_EQUIP_MIN_ID:
		
		var updated = []
		for ce in StaticManager.custom_equips:
			if ce.id == created.id:
				continue
			updated.append(ce)
		updated.append(created)
		StaticManager.custom_equips = updated
	else:
		created.id = StaticManager.CUSTOM_EQUIP_MIN_ID
		for ce in StaticManager.custom_equips:
			if created.id <= ce.id:
				created.id = ce.id + 1
		StaticManager.custom_equips.append(created)
	StaticManager.save_equip_patches()
	reload_list(keyword, page)
	return

func close_patch():
	create.hide()
	detail.hide()
	return

func set_equip_type(type: String) -> void :
	for t in StaticManager.EQUIPMENT_TYPES:
		var btn = create.get_node(t)
		if not btn is Button:
			continue
		btn.disabled = false
		if t == type:
			btn.disabled = true
			created.type = type
	return

func random_weapon():
	created.random_attrs()
	detail_reset()
	return

func change_feature(idx: int):
	update_model()
	var fs = detail.get_node("feature_selector")
	var lst = fs.get_node("sc/features")
	lst.editor_description = str(idx)
	Global.clearNode(lst)
	var added = []
	var preset = {"不换了": "-1", "--": "--"}
	for key in preset:
		var btn = featureItem.duplicate()
		btn.text = key
		btn.editor_description = preset[key]
		btn.rect_position = Vector2(20, added.size() * 50)
		btn.show()
		lst.add_child(btn)
		added.append(btn)
	var currentFeatures = []
	for feature in created.features:
		feature = Global.arrval(feature)
		if feature.size() != 2:
			continue
		currentFeatures.append(feature[0])
	for feature in CustomEquip.get_possible_features(created.type, created.subtype):
		var btn = featureItem.duplicate()
		btn.text = StaticManager.EQUIP_TAG_MAPPING[feature].format(["X", "X*100", "X*50"])
		btn.editor_description = feature
		if feature in currentFeatures:
			btn.disabled = true
		btn.show()
		lst.add_child(btn)
		btn.rect_position = Vector2(20, added.size() * 50)
		added.append(btn)
		lst.rect_min_size.y = max(250, 50 + added.size() * 50)
		lst.rect_size.y = lst.rect_min_size.y
	for b in added:
		b.connect("pressed", self, "set_feature", [idx, b.editor_description])
	fs.show()
	return

func set_feature(idx: int, feature: String) -> void :
	var fs = detail.get_node("feature_selector")
	fs.hide()
	if feature == "-1":
		return
	created.set_feature(idx, feature, 1)
	detail_reset()
	return

func reset_layout_landscape() -> void :
	pageSize = 6
	return

func reset_layout_portrait() -> void :
	pageSize = 15
	return
