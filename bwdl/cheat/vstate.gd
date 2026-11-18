extends Panel

onready var icon = $icon
onready var changeLord = get_node("更换君主")
onready var changeAlly = get_node("修改同盟")

var vstateId: int = - 1

signal saved

func _ready():
	return

func reload_data(_vstateId: int = - 1) -> void :
	changeLord.hide()
	changeAlly.hide()
	if _vstateId >= 0:
		vstateId = _vstateId
	var vs = clVState.vstate(vstateId)
	var colors = vs.get_color()
	icon.border_color = Color(colors[0])
	icon.fill_color = Color(colors[1])
	icon.update()
	get_node("边框颜色").color = Color(colors[0])
	get_node("填充颜色").color = Color(colors[1])
	get_node("君主").text = vs.get_lord_name()
	get_node("君主").editor_description = str(vs.get_lord_id())
	var allied = get_allied_vstate_ids()
	get_node("同盟").text = "{0}个势力".format([allied.size()])
	get_node("同盟").editor_description = ",".join(allied)
	var capital = clCity.get_capital_city(vs.id)
	if capital == null:
		get_node("首都").text = "-"
	else:
		get_node("首都").text = capital.get_name()
	return

func cancel():
	hide()
	return

func save_data() -> void :
	var vs = clVState.vstate(vstateId)
	
	var colors = []
	for c in ["边框颜色", "填充颜色"]:
		colors.append("#" + get_node(c).color.to_html(false))
	vs.set_color(colors)
	
	var lordId = vs.get_lord_id()
	var newLordId = int(get_node("君主").editor_description)
	if newLordId >= 0 and newLordId != lordId:
		var newCapital = DataManager.get_office_city_by_actor(newLordId)
		if newCapital != null:
			ActorHelper.actor(lordId).set_loyalty(99)
			ActorHelper.actor(newLordId).set_loyalty(100)
			
			newCapital.remove_actor(newLordId)
			newCapital.insert_actor(0, newLordId)
			
			vs.set_lord(newLordId)
			
			for p in DataManager.players:
				if p.actorId == lordId:
					p.actorId = newLordId
	
	var allied = get_modified_allied_vstate_ids()
	for v in clVState.all_vstates():
		if v.id == vs.id:
			continue
		if v.id in allied:
			if not DataManager.is_alliance(v.id, vs.id):
				clVState.set_alliance(v.id, vs.id, 12)
		else:
			clVState.set_alliance(v.id, vs.id, 0)
	reload_data( - 1)
	emit_signal("saved")
	return

func reset():
	reload_data( - 1)
	return

func change_color():
	icon.border_color = get_node("边框颜色").color
	icon.fill_color = get_node("填充颜色").color
	icon.update()
	return

func change_lord():
	if DataManager.get_current_scene_id() != 10000:
		changeLord.get_node("notice").text = "当前不在内政场景，不能修改君主！"
		changeLord.get_node("actorlist").hide()
		changeLord.show()
		return
	var actorlist = changeLord.get_node("actorlist")
	actorlist.vstateId = vstateId
	actorlist.excepted = [int(get_node("君主").editor_description)]
	actorlist.reload_list()
	actorlist.bind_operation(self, "set_lord", "选他")
	actorlist.show()
	changeLord.show()
	return

func set_lord(actorId: int) -> void :
	var actor = ActorHelper.actor(actorId)
	get_node("君主").text = "* " + actor.get_name()
	get_node("君主").editor_description = str(actor.actorId)
	var city = DataManager.get_office_city_by_actor(actor.actorId)
	if city == null:
		get_node("首都").text = "* -"
	else:
		get_node("首都").text = "* " + city.get_name()
	changeLord.hide()
	return

func cancel_change_lord():
	changeLord.hide()
	return

func get_allied_vstate_ids() -> PoolIntArray:
	var ret = []
	for vs in clVState.all_vstates():
		if vs.id == vstateId:
			continue
		if DataManager.is_alliance(vs.id, vstateId):
			ret.append(vs.id)
	return ret

func get_modified_allied_vstate_ids() -> PoolIntArray:
	var ret = []
	for piece in get_node("同盟").editor_description.split(","):
		if piece == "":
			continue
		ret.append(int(piece))
	return ret

func change_ally():
	if DataManager.get_current_scene_id() != 10000:
		changeAlly.get_node("notice").text = "当前不在内政场景，不能修改同盟！"
		changeAlly.get_node("vstatelist").hide()
		changeAlly.show()
		return
	var vs = clVState.vstate(vstateId)
	changeAlly.get_node("notice").text = "调整{0}的同盟关系（结盟默认一年）：".format([vs.get_lord_name()])
	var vstatelist = changeAlly.get_node("vstatelist")
	vstatelist.excepted = [vstateId]
	var allied = get_modified_allied_vstate_ids()
	var conditioner = "int(<ID> in [{0}])".format([",".join(allied)])
	vstatelist.bind_operation(self, "set_ally", ["结盟", "毁约"], conditioner)
	vstatelist.reload_list()
	vstatelist.show()
	changeAlly.show()
	return

func set_ally(targetVstateId: int, idx: int) -> void :
	var modified = get_modified_allied_vstate_ids()
	modified.erase(targetVstateId)
	if idx == 0:
		modified.append(targetVstateId)
	get_node("同盟").text = "* {0}个势力".format([modified.size()])
	get_node("同盟").editor_description = ",".join(modified)
	var allied = get_modified_allied_vstate_ids()
	var conditioner = "int(<ID> in [{0}])".format([",".join(allied)])
	var vstatelist = changeAlly.get_node("vstatelist")
	vstatelist.bind_operation(self, "set_ally", ["结盟", "毁约"], conditioner)
	vstatelist.reload_list(vstatelist.keyword, vstatelist.page)
	return

func cancel_change_ally():
	changeAlly.hide()
	return
