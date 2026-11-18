extends VBoxContainer

var id: int = - 1
var idList: PoolIntArray = []

var equipType: String = "武器"

onready var header = $header
onready var attrs = $attr
onready var detail = $detail
onready var prevBtn = $nav / prev
onready var nextBtn = $nav / next

func _ready():
	return

func reload() -> void :
	if id < 0:
		return
	var equip: clEquip.EquipInfo = clEquip.equip(id, equipType)
	var icon: Sprite = header.get_node("ac/icon")
	var setting = equip.image_setting()
	icon.texture = setting["img"]
	var width = 32
	var height = 32
	icon.region_enabled = true
	icon.region_rect = Rect2(setting["x"], setting["y"], 32, 32)
	icon.scale = Vector2(64.0 / width, 64.0 / height)
	icon.offset = Vector2(8.0 * width / 64.0, 8.0 * height / 64.0)
	header.get_node("name").text = equip.name()
	for attr in ["品质", "攻击力", "重量", "价格", "防御力"]:
		var lbl = attrs.get_node_or_null(attr)
		if lbl == null:
			continue
		lbl.text = "{0}：{1}".format([
			attr, equip.get_attr_str(attr), 
		])

	var condition = equip.get_attr_str("购买条件描述")
	if condition == "":
		condition = equip.get_attr_str("购买条件")
		condition = condition.replace("a.", "武将")
		condition = condition.replace("||", "或")
		condition = condition.replace("==", "为")

	var features = detail.get_node("features/feature_list")
	var feature = detail.get_node("features/feature")
	Global.clearNode(features)
	var parsed = []
	for desc in equip.get_features_description():
		parsed.append(desc)
	var offY = 0
	for desc in parsed:
		var btn = feature.duplicate()
		Global.bind_button_tooltip(btn, desc)
		if desc.length() > 20:
			desc = desc.left(19) + "…"
		btn.text = " " + desc + " "
		btn.rect_position = Vector2(0, offY)
		btn.show()
		features.add_child(btn)
		offY += 60

	var prev = prev()
	var next = next()
	if prev == null:
		prevBtn.text = "< 没有了"
		prevBtn.disabled = true
	else:
		prevBtn.text = "< " + prev.name()
		prevBtn.disabled = false
	if next == null:
		nextBtn.text = "< 没有了"
		nextBtn.disabled = true
	else:
		nextBtn.text = next.name() + " >"
		nextBtn.disabled = false

	if condition == "":
		detail.get_node("condition").hide()
		detail.get_node("features").rect_position.y = 0
		detail.get_node("features").rect_min_size.y = 240
		detail.get_node("features").rect_size.y = 240
	else:
		detail.get_node("condition").show()
		detail.get_node("condition/购买条件").text = "购买条件：" + condition
		detail.get_node("features").rect_position.y = 60
		detail.get_node("features").rect_min_size.y = 180
		detail.get_node("features").rect_size.y = 180

	reload_more(equip)
	return

func reload_more(equip: clEquip.EquipInfo) -> void :
	return

func close() -> void :
	hide()
	return

func prev() -> clEquip.EquipInfo:
	var idx = idList.find(id)
	if idx < 0:
		return null
	var prevId = idList[(idx + idList.size() - 1) % idList.size()]
	return clEquip.equip(prevId, equipType)

func next() -> clEquip.EquipInfo:
	var idx = idList.find(id)
	if idx < 0:
		return null
	var nextId = idList[(idx + 1) % idList.size()]
	return clEquip.equip(nextId, equipType)

func nav_prev():
	var prev = prev()
	if prev == null:
		return
	id = prev.id
	reload()
	return

func nav_next():
	var next = next()
	if next == null:
		return
	id = next.id
	reload()
	return
