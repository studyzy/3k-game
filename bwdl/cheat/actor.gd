# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：cheat/actor.gd
# 说明：作弊面板-武将编辑。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

const GENDERS = ["男", "女", "无"]
const TROOPS = ["山", "水", "平", "仙"]


const EQUIP_COLS = 3

onready var basics = $basics
onready var attrs = $attrs
onready var equipSelector = $equip_selector
onready var equipBtn = $equip
onready var changeCity = get_node("出仕")

var actorId: int = - 1

var sbButtonHighlighted: StyleBoxFlat = StyleBoxFlat.new()

signal saved
signal cancel


func _ready():
	
	sbButtonHighlighted.bg_color = Color.white
	$avatar_selector.connect("avatar", self, "set_avatar")
	return

func reload_data(_actorId: int = - 1) -> void :
	changeCity.hide()
	equipSelector.hide()
	if _actorId >= 0:
		actorId = _actorId
	Global.load_actor_avatar(actorId, $avatar, 3)
	basics.get_node("avatar").hide()
	if actorId == StaticManager.ACTOR_ID_DIY:
		basics.get_node("avatar").show()
	var actor = ActorHelper.actor(actorId)
	basics.get_node("fn").text = actor.get_first_name()
	basics.get_node("name").text = actor.get_name()
	basics.get_node("nick").text = actor.get_nick()
	set_gender(actor.get_gender())
	set_troops(actor.get_troops_type())
	for attr in ["体", "武", "知", "统", "德", "政", "胆", "忠", "兵力", "等级"]:
		attrs.get_node(attr).text = str(actor._get_attr_int_original(attr))
	
	attrs.get_node("忠").readonly = false
	if actor.get_loyalty() == 100:
		attrs.get_node("忠").readonly = true
	
	attrs.get_node("经验").text = str(actor.get_exp())
	for type in ["武器", "防具", "道具", "坐骑"]:
		set_equip(type, str(actor.get_equip(type).id))
	if DataManager.get_current_scene_id() != 10000:
		get_node("status").text = "-"
		get_node("status").editor_description = "-1"
		get_node("status").disabled = true
		get_node("status").hide()
	else:
		var status = ""
		if actor.is_status_officed():
			status = "出仕："
			get_node("status").disabled = false
			if actor.get_loyalty() == 100:
				status = "君主："
				get_node("status").disabled = true
			var city = DataManager.get_office_city_by_actor(actor.actorId)
			if city == null:
				status += "-"
			else:
				status += city.get_name()
		elif actor.is_status_exiled():
			status = "流放："
			var cityId = actor.get_exiled_city_id()
			if cityId < 0:
				status += "-"
			else:
				status += clCity.city(cityId).get_name()
		elif actor.is_status_unofficed():
			for dic in DataManager.citys_unoffice:
				if int(dic["武将"]) == actor.actorId:
					if int(dic["登场年"]) < DataManager.year:
						status = "未登场："
					else:
						status = "在野："
					var cityId = int(dic["城池"])
					if cityId < 0:
						status += "-"
					else:
						status += clCity.city(cityId).get_name()
			for dic in DataManager.actor_follower:
				if int(dic["子将"]) == actor.actorId:
					status = "跟随："
					var parent = ActorHelper.actor(int(dic["父将"]))
					status += parent.get_name()
		else:
			status = actor.get_status()
		get_node("status").text = status
		
		get_node("status").editor_description = "-1"
		get_node("status").show()
	return

func set_gender(gender: String):
	for g in GENDERS:
		basics.get_node(g).disabled = false
	var checked = basics.get_node_or_null(gender)
	if checked is Button:
		checked.disabled = true
	return

func set_troops(troops):
	for t in TROOPS:
		attrs.get_node(t).disabled = false
	var checked = attrs.get_node_or_null(troops)
	if checked is Button:
		checked.disabled = true
	return

func set_equip(type: String, idStr: String) -> void :
	var id = int(idStr)
	if id >= 0:
		var equip = clEquip.equip(id, type)
		var name = equip.name()
		if id != ActorHelper.actor(actorId).get_equip(type).id:
			name += "*"
		attrs.get_node(type).text = name
		attrs.get_node(type).editor_description = str(equip.id)
	equipSelector.hide()
	return

func select_equip(type: String):
	var lst = equipSelector.get_node("sc/equips")
	lst.editor_description = type
	Global.clearNode(lst)
	var btn = equipBtn.duplicate()
	btn.text = "不换了"
	btn.editor_description = "-1"
	btn.show()
	lst.add_child(btn)
	var current = ActorHelper.actor(actorId).get_equip(type)
	var added = [btn]
	for equip in clEquip.all_equips(type, true):
		btn = equipBtn.duplicate()
		btn.text = equip.name()
		btn.editor_description = str(equip.id)
		if equip.id == current.id:
			btn.disabled = true
		btn.show()
		lst.add_child(btn)
		btn.rect_position = Vector2(added.size() % EQUIP_COLS * 150, int(added.size() / EQUIP_COLS) * 50)
		added.append(btn)
		lst.rect_min_size.y = max(200, 50 + int(added.size() / EQUIP_COLS) * 50)
	for b in added:
		b.connect("pressed", self, "set_equip", [type, b.editor_description])
	equipSelector.show()
	return

func cancel():
	hide()
	return

func save_data() -> void :
	var actor = ActorHelper.actor(actorId)
	var name = basics.get_node("name").text
	if name != actor.get_name():
		
		
		
		actor.set_name(basics.get_node("name").text)
	actor.set_first_name(basics.get_node("fn").text)
	actor.set_nick(basics.get_node("nick").text)
	for gender in GENDERS:
		if basics.get_node(gender).disabled:
			actor.set_gender(gender)
			break
	for troops in TROOPS:
		if attrs.get_node(troops).disabled:
			actor.set_troops_type(troops)
			break
	for attr in ["体", "武", "知", "统", "德", "政", "胆", "忠", "兵力", "等级"]:
		actor._set_attr_int(attr, int(attrs.get_node(attr).text))
	var limit = actor.get_max_hp()
	if actor._get_attr_int_original("体") > limit:
		actor._set_attr_int("原体力", actor._get_attr_int_original("体"))
		actor._set_attr_int("体上限", 0)
	
	actor.set_exp(int(attrs.get_node("经验").text))
	for type in ["武器", "防具", "道具", "坐骑"]:
		var id = int(attrs.get_node(type).editor_description)
		actor.set_equip(clEquip.equip(id, type))
	var newCityId = int(get_node("status").editor_description)
	if newCityId >= 0:
		actor.set_hp(max(1, actor.get_hp()))
		clCity.transfer_to(actor.actorId, newCityId)
	reload_data( - 1)
	emit_signal("saved")
	return

func reset():
	reload_data( - 1)
	return

func change_city():
	var actor = ActorHelper.actor(actorId)
	var citylist = changeCity.get_node("citylist")
	citylist.reload_list()
	citylist.bind_operation(self, "set_city", ["出仕"])
	changeCity.get_node("notice").text = "令{0}出仕于选中的城市：".format([actor.get_name()])
	changeCity.show()
	return

func set_city(cityId: int) -> void :
	get_node("status").text = "* 出仕：" + clCity.city(cityId).get_name()
	get_node("status").editor_description = str(cityId)
	changeCity.hide()
	return

func cancel_change_city():
	emit_signal("cancel")
	changeCity.hide()
	return

func avatar_pressed():
	$avatar_selector.start_for(actorId)
	return

func set_avatar(name: String, avatar: String) -> void :
	reload_data()
	return
