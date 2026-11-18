extends Control

signal actor_ready

onready var nprFace = get_node("left/nprFace")
onready var lblArmyType = get_node("middle-up/lblArmyType")
onready var lblName = get_node("left/lblName")
onready var lblNick = get_node("middle-up/lblTypes")

onready var con_weapon = get_node("bottom/weapon");
onready var con_suit = get_node("bottom/suit");
onready var con_jewelry = get_node("bottom/jewelry");
onready var con_steed = get_node("bottom/steed");

export (int) var pre_actorId = - 1;

onready var property_label = {
	"体": get_node("right-up/gv/HP/Value"), 
	"武": get_node("right-up/gv/STR/Value"), 
	"知": get_node("right-up/gv/INT/Value"), 
	"忠": get_node("right-up/gv/LOY/Value"), 
	"德": get_node("right-up/gv/MOR/Value"), 
	"政": get_node("right-up/gv/POL/Value"), 
	"统": get_node("right-up/gv/COM/Value"), 
	"胆": get_node("right-up/gv/COU/Value"), 
	"经验": get_node("middle-up/EXP/Value"), 
	"兵力": get_node("middle-up/lblSodiers"), 
}


var switchMode: bool = true


func _ready() -> void :
	_load_base(pre_actorId)
	return


func _load_base(actorId: int, valueBounds: Dictionary = {}):
	pre_actorId = actorId
	if actorId >= 0:
		get_node("middle-up").show();
		get_node("right-up").show();
		get_node("bottom").show();
		get_node("left").show();
	else:
		get_node("middle-up").hide();
		get_node("right-up").hide();
		get_node("bottom").hide();
		nprFace.set_actor(actorId);
		if (actorId == - 1):
			lblName.text = "随机"
		else:
			lblName.text = ""
		return ;
	nprFace.set_actor(actorId);
	var actor = ActorHelper.actor(actorId);
	
	lblArmyType.text = actor.get_troops_type()
	lblName.text = actor.get_name()
	lblNick.text = actor.get_nick()
	for proname in property_label.keys():
		var label: Label = property_label[proname]
		var val = actor._get_attr_int(proname)
		var original = actor._get_attr_int_original(proname)
		var maxVal = original
		match proname:
			"体":
				original = actor.get_max_hp()
				maxVal = original
				val = int(ceil(actor.get_hp()))
			"忠":
				maxVal = 99
			"武":
				val = actor.get_power()
			"知":
				val = actor.get_wisdom()
			"兵力":
				lblArmyType.set("custom_colors/font_color", actor.get_troops_type_color())
				label.set("custom_colors/font_color", actor.get_troops_type_color())
			
			"经验":
				val = "{0}".format([
					str(actor.get_exp()).pad_zeros(5), 
				])
			_:
				if typeof(val) == TYPE_REAL:
					val = int(ceil(val))
		var damageStatus = label.get_parent().get_node_or_null("damage")
		if damageStatus != null:
			if val < original:
				damageStatus.visible = true
				damageStatus.set_flip_v(true)
			elif val > original:
				damageStatus.visible = true
				damageStatus.set_flip_v(false)
			else:
				damageStatus.visible = false
		if typeof(val) == TYPE_INT:
			if val > maxVal:
				label.set("custom_colors/font_color", StaticManager.COLOR_EXCEEDED)
			elif val * 10 < maxVal * 3:
				label.set("custom_colors/font_color", StaticManager.COLOR_LOW)

		label.text = str(val)
	
	
	for i in get_node("middle-up/Level/HBoxContainer").get_child_count():
		var con_star = get_node("middle-up/Level/HBoxContainer").get_child(i);
		if i < actor.get_level():
			con_star.show();
		else:
			con_star.hide();
	
	
	con_equip_show(con_weapon, actor.get_weapon())
	con_equip_show(con_suit, actor.get_suit())
	con_equip_show(con_jewelry, actor.get_jewelry())
	con_equip_show(con_steed, actor.get_steed())

	
	var lblloy = get_node("right-up/gv/LOY/Value")
	var spLoy100 = get_node("right-up/gv/LOY/Loy100")
	if actor.get_loyalty() == 100:
		spLoy100.visible = true
		lblloy.visible = false
	else:
		spLoy100.visible = false
		lblloy.visible = true

	for attr in valueBounds:
		if not attr in property_label:
			continue
		var bounds = Global.intarrval(valueBounds[attr])
		if bounds.size() != 2:
			continue
		var minVal = bounds[0]
		var maxVal = bounds[1]
		var label: Label = property_label[attr]
		var val = int(label.text)
		if val == maxVal:
			label.set("custom_colors/font_color", Color.red)
		elif val >= maxVal - 5:
			label.set("custom_colors/font_color", Color.blue)
		else:
			label.set("custom_colors/font_color", Color.black)
	switch_ap_pok()
	emit_signal("actor_ready")
	return

func _process(delta):
	switch_ap_pok()
	return

func get_str(value: int, length: int):
	var text = str(value);
	while (true):
		if (text.length() >= length):
			break;
		text = "0" + text;
	return text;


func con_equip_show(con: Control, equip: clEquip.EquipInfo):
	var icon = con.get_node("img")
	var setting = equip.image_setting()
	icon.texture = setting["img"]
	icon.region_enabled = true
	icon.region_rect = Rect2(setting["x"], setting["y"], setting["w"], setting["h"])
	icon.scale = Vector2(32.0 / int(setting["w"]), 32.0 / int(setting["h"]))
	icon.offset = Vector2(6, 12) / icon.scale.x

	var lbl: RichTextLabel = con.get_node("name")
	var text = equip.display_name()
	if text.split("\n")[0] != "":
		lbl.rect_position.y = 4
	else:
		lbl.rect_position.y = - 4
	var code = equip.get_name_color_code()
	if code != "":
		text = "[color={0}]{1}[/color]".format([
			code, text
		])
	lbl.bbcode_text = "[center]{0}[/center]".format([text])
	con.get_node("disabled").visible = equip.disabled
	con.get_node("deleted").visible = equip.disabled
	return


func switch_ap_pok():
	get_node("right-up/gv/AP").hide()
	get_node("right-up/gv/POK").hide()

	var sceneId = DataManager.get_current_scene_id()
	if sceneId < 20000:
		
		return

	var wa = DataManager.get_war_actor(pre_actorId)
	if wa == null or wa.disabled:
		return

	if DataManager.get_game_setting("技能系统") != "是":
		show_ap(wa)
		return

	if not switchMode:
		show_five_phases(wa)
		return

	
	var time = Time.get_datetime_dict_from_system()
	if int(time["second"]) % 2 == 0:
		show_ap(wa)
	else:
		show_five_phases(wa)
	return

func show_ap(wa: War_Actor) -> void :
	get_node("right-up/gv/POK").hide()
	get_node("right-up/gv/AP/Value").text = str(wa.action_point)
	get_node("right-up/gv/AP").show()
	return

func show_five_phases(wa: War_Actor) -> void :
	get_node("right-up/gv/AP").hide()
	var color = wa.get_five_phases_color_code()
	var text = wa.get_five_phases_str()
	var pok = get_node("right-up/gv/POK")
	var title = pok.get_node("Title")
	var pt = pok.get_node("Point2")
	title.set("custom_colors/font_color", Color(color))
	title.text = text
	pt.text = wa.get_poker_point_str()
	pt.set("custom_colors/font_color", Color(color))
	pok.show()
	return

func _on_faceButton_pressed():
	release_focus()
	var sceneId = DataManager.get_current_scene_id()
	if sceneId > 0:
		var actor = ActorHelper.actor(nprFace.actorId)
		actor.switch_avatar()
		nprFace.set_actor(actor.actorId)
		return
	if $Tween.is_active():
		$Tween.stop_all()
		nprFace.set_mood(2)
		return
	$Tween.interpolate_callback(nprFace, 0.2, "next_face")
	$Tween.repeat = true
	$Tween.start()
	return
