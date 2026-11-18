extends Panel

const FACILITIES = ["武", "知", "医", "商"]
const DISASTERS = ["旱灾", "洪涝"]

onready var attrs = $attrs
onready var changeVstate = get_node("修改归属")
onready var changeConnection = get_node("修改连接城")

var cityId: int = - 1

var sbButtonHighlighted: StyleBoxFlat = StyleBoxFlat.new()

signal saved

func _ready():
	
	sbButtonHighlighted.bg_color = Color.white
	return

func reload_data(_cityId: int = - 1) -> void :
	changeVstate.hide()
	changeConnection.hide()
	if _cityId >= 0:
		cityId = _cityId
	var city = clCity.city(cityId)
	for attr in ["城池名", "金", "米", "宝", "后备兵", "土地", "产业", "人口", "防灾", "统治度"]:
		attrs.get_node(attr).text = str(city.get_property(attr))
	
	attrs.get_node("买米价").text = str(city.get_rice_buy_price())
	attrs.get_node("卖米价").text = str(city.get_rice_sell_price())
	var facilities = Global.strval(city.get_property("集市"))
	for f in FACILITIES:
		var btn = attrs.get_node(f)
		if f in facilities:
			btn.editor_description = "1"
		else:
			btn.editor_description = "0"
		update_button_status(btn)
	for d in DISASTERS:
		var btn = attrs.get_node(d)
		if Global.boolval(city.get_property(d)):
			btn.editor_description = "1"
		else:
			btn.editor_description = "0"
		update_button_status(btn)
	attrs.get_node("归属").text = city.get_lord_name()
	
	attrs.get_node("归属").editor_description = "-1"
	if city.get_leader_id() < 0:
		
		attrs.get_node("归属").disabled = true
	elif city.get_leader_id() >= 0 and city.get_leader_id() == city.get_lord_id():
		
		attrs.get_node("归属").disabled = true
	else:
		attrs.get_node("归属").disabled = false
	var attackConnected = city.get_connected_city_ids()
	var defendConnected = []
	for c in clCity.all_cities():
		if city.ID in c.get_connected_city_ids():
			defendConnected.erase(c.ID)
			defendConnected.append(c.ID)
	attrs.get_node("出城").text = "{0}攻".format([attackConnected.size()])
	attrs.get_node("出城").editor_description = ",".join(attackConnected)
	attrs.get_node("入城").text = "{0}守".format([defendConnected.size()])
	attrs.get_node("入城").editor_description = ",".join(defendConnected)
	return

func cancel():
	hide()
	return

func save_data() -> void :
	var city = clCity.city(cityId)
	for attr in ["城池名"]:
		city.set_property(attr, attrs.get_node(attr).text)
	for attr in ["金", "米", "宝", "后备兵", "土地", "产业", "人口", "防灾", "统治度", "买米价", "卖米价"]:
		city.set_property(attr, int(attrs.get_node(attr).text))
	var facilities = ""
	for f in FACILITIES:
		if attrs.get_node(f).editor_description == "1":
			facilities += f
	city.set_property("集市", facilities)
	for d in DISASTERS:
		if attrs.get_node(d).editor_description == "1":
			city.set_property(d, true)
		else:
			city.set_property(d, false)
	var newVstateId = int(attrs.get_node("归属").editor_description)
	if newVstateId >= 0:
		
		city.change_vstate(newVstateId)
	elif newVstateId == - 99:
		
		var newLordId = city.get_leader_id()
		newVstateId = clVState.create_new_vstate(newLordId)
		ActorHelper.actor(newLordId).set_loyalty(100)
		city.change_vstate(newVstateId)
	city.set_property("连接城", get_attack_connected())
	var defendConnected = get_defend_connected()
	for c in clCity.all_cities():
		var connected = c.get_connected_city_ids()
		connected.erase(city.ID)
		if c.ID in defendConnected:
			connected.append(city.ID)
		c.set_property("连接城", connected)
	reload_data( - 1)
	emit_signal("saved")
	return

func toggle_button_status(name: String) -> void :
	var btn = attrs.get_node(name)
	if btn == null or not btn is Button:
		return
	if btn.editor_description == "1":
		btn.editor_description = "0"
	else:
		btn.editor_description = "1"
	update_button_status(btn)
	return

func update_button_status(btn: Button) -> void :
	if btn.editor_description == "1":
		btn.add_stylebox_override("normal", sbButtonHighlighted)
		btn.add_stylebox_override("hover", sbButtonHighlighted)
		for t in ["", "_pressed", "_disabled", "_hover", "_normal", "_focus"]:
			btn.add_color_override("font_color" + t, Color.black)
	else:
		btn.remove_stylebox_override("normal")
		btn.remove_stylebox_override("hover")
		for t in ["", "_pressed", "_disabled", "_hover", "_normal", "_focus"]:
			btn.add_color_override("font_color" + t, Color.white)
	return

func reset():
	reload_data( - 1)
	return

func change_vstate():
	if DataManager.get_current_scene_id() != 10000:
		changeVstate.get_node("notice").text = "当前不在内政场景，不能修改城市归属！"
		changeVstate.get_node("rebell").hide()
		changeVstate.get_node("vstatelist").hide()
		changeVstate.show()
		return
	var city = clCity.city(cityId)
	changeVstate.get_node("notice").text = "令{0}归属于选中的势力：".format([city.get_name()])
	var vstatelist = changeVstate.get_node("vstatelist")
	var expected = []
	for vs in clVState.all_vstates():
		if not vs.is_alive():
			continue
		if vs.id == city.get_vstate_id():
			continue
		expected.append(vs.id)
	vstatelist.expected = expected
	vstatelist.reload_list()
	vstatelist.bind_operation(self, "set_vstate", ["归属"])
	vstatelist.show()
	changeVstate.get_node("rebell").show()
	changeVstate.show()
	return

func set_vstate(vstateId: int):
	var vs = clVState.vstate(vstateId)
	attrs.get_node("归属").text = "* " + vs.get_lord_name()
	attrs.get_node("归属").editor_description = str(vs.id)
	changeVstate.hide()
	return

func cancel_change_vstate():
	changeVstate.hide()
	return

func change_attack_connection():
	if DataManager.get_current_scene_id() != 10000:
		changeConnection.get_node("notice").text = "当前不在内政场景，不能修改城市连线！"
		changeConnection.get_node("citylist").hide()
		changeConnection.show()
		return
	var connected = get_attack_connected()
	var city = clCity.city(cityId)
	changeConnection.get_node("notice").text = "修改{0}可攻击的城市：".format([city.get_name()])
	var citylist = changeConnection.get_node("citylist")
	citylist.expected = city.get_property_static("连接城")
	var conditioner = "int(<ID> in [{0}])".format([",".join(connected)])
	citylist.bind_operation(self, "set_attack_city", ["恢复", "断开"], conditioner)
	citylist.reload_list()
	citylist.show()
	changeConnection.show()
	return

func set_attack_city(targetCityId: int, keep: int) -> void :
	var connected = get_attack_connected()
	connected.erase(targetCityId)
	if keep == 0:
		connected.append(targetCityId)
	attrs.get_node("出城").text = "* {0}攻".format([connected.size()])
	attrs.get_node("出城").editor_description = ",".join(connected)
	var citylist = changeConnection.get_node("citylist")
	var conditioner = "int(<ID> in [{0}])".format([",".join(connected)])
	citylist.bind_operation(self, "set_attack_city", ["恢复", "断开"], conditioner)
	citylist.reload_list(citylist.keyword, citylist.page)
	return

func change_defend_connection():
	if DataManager.get_current_scene_id() != 10000:
		changeConnection.get_node("notice").text = "当前不在内政场景，不能修改城市连线！"
		changeConnection.get_node("citylist").hide()
		changeConnection.show()
		return
	var connected = get_defend_connected()
	var city = clCity.city(cityId)
	changeConnection.get_node("notice").text = "修改可攻击{0}的城市：".format([city.get_name()])
	var citylist = changeConnection.get_node("citylist")
	
	citylist.expected = city.get_property_static("连接城")
	var conditioner = "int(<ID> in [{0}])".format([",".join(connected)])
	citylist.bind_operation(self, "set_defend_city", ["恢复", "断开"], conditioner)
	citylist.reload_list()
	citylist.show()
	changeConnection.show()
	return

func set_defend_city(targetCityId: int, keep: int) -> void :
	var connected = get_defend_connected()
	connected.erase(targetCityId)
	if keep == 0:
		connected.append(targetCityId)
	attrs.get_node("入城").text = "* {0}守".format([connected.size()])
	attrs.get_node("入城").editor_description = ",".join(connected)
	var citylist = changeConnection.get_node("citylist")
	var conditioner = "int(<ID> in [{0}])".format([",".join(connected)])
	citylist.bind_operation(self, "set_defend_city", ["恢复", "断开"], conditioner)
	citylist.reload_list(citylist.keyword, citylist.page)
	return

func cancel_change_connection():
	changeConnection.hide()
	return

func get_attack_connected() -> Array:
	var connected = []
	for piece in attrs.get_node("出城").editor_description.split(","):
		if piece == "":
			continue
		connected.append(int(piece))
	return connected

func get_defend_connected() -> Array:
	var connected = []
	for piece in attrs.get_node("入城").editor_description.split(","):
		if piece == "":
			continue
		connected.append(int(piece))
	return connected

func create_vstate():
	attrs.get_node("归属").text = "* 独立"
	attrs.get_node("归属").editor_description = "-99"
	changeVstate.hide()
	return

func max_attrs():
	for k in ["金", "米"]:
		attrs.get_node(k).text = "9999"
	for k in ["宝", "防灾"]:
		attrs.get_node(k).text = "99"
	for k in ["后备兵", "人口"]:
		attrs.get_node(k).text = "990000"
	for k in ["土地", "产业"]:
		attrs.get_node(k).text = "999"
	for k in ["统治度"]:
		attrs.get_node(k).text = "100"
	return

