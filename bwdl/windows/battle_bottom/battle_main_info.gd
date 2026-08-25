# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/battle_bottom/battle_main_info.gd
# 说明：战斗底部-主信息 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const default_unit_types = ["将", "骑", "象", "弓", "步"]


func _ready() -> void :
	update_data();
	get_node("right_actor/conActor/nprFace/nprFace").rect_scale.x = - 1

	return

func update_data() -> void :
	var bf = DataManager.get_current_battle_fight()
	
	update_actor_data(bf, bf.get_attacker_id(), true)
	update_actor_data(bf, bf.get_defender_id(), false)
	return

func update_actor_data(bf: BattleFight, actorId: int, isAttacker: bool) -> void :
	var actor_con = get_node("right_actor")
	if isAttacker:
		actor_con = get_node("left_actor")

	var nprFace = actor_con.get_node("conActor/nprFace")
	nprFace.set_actor(actorId)

	var lblName: Label = actor_con.get_node("conActor/lblName");
	var actor = ActorHelper.actor(actorId)
	lblName.text = actor.get_name()

	var role: Sprite = actor_con.get_node("role")
	var wa = DataManager.get_war_actor(actorId)
	if wa.get_controlNo() >= 0:
		role.frame_coords = Vector2(0, 0)
	else:
		role.frame_coords = Vector2(2, 0)

	var con_info: Control = actor_con.get_node("info");
	var unit_types = bf.get_defender_unit_types()
	if isAttacker:
		unit_types = bf.get_attacker_unit_types()

	var unit_type_array = ["将", "骑", "弓", "步"];
	
	if unit_types.size() == 4:
		unit_type_array.clear()
		unit_type_array.append_array(unit_types)
	else:
		unit_type_array = default_unit_types.duplicate(true)
		
		if not "象" in unit_types:
			unit_type_array.erase("象")
		for ut in unit_types:
			var loc = unit_type_array.find(ut)
			if loc < 0 or loc >= 4:
				
				unit_type_array.erase(ut)
				unit_type_array.insert(1, ut)
	unit_type_array.resize(con_info.get_child_count())
		
	for i in unit_type_array.size():
		var type_name = str(unit_type_array[i])[0];
		var con_property: Control = con_info.get_child(i);
		var lblTitle: Label = con_property.get_node("Title");
		var lblValue: Label = con_property.get_node("Value");
		lblTitle.text = type_name;
		var hp = DataManager.battle_unit_type_hp(actorId, type_name);
		if (typeof(hp) == TYPE_REAL):
			hp = int(ceil(hp));
		lblValue.text = str(hp);
		if type_name == "将":
			var ac = con_property.get_node_or_null("ac")
			if ac != null:
				var bu = wa.battle_actor_unit()
				if bu != null and bu.extra_armor > 0:
					ac.text = "({0})".format([int(bu.extra_armor)])
					ac.visible = true
				else:
					ac.visible = false

	
	var extraNode = actor_con.get_node_or_null("extra")
	extraNode.hide()
	var extra = bf.get_env_str("战斗动态信息." + str(actorId))
	if extra != "":
		extraNode.get_node("info").text = extra
		extraNode.show()

	
	var con_tactic: Control = actor_con.get_node("tactic")
	con_tactic.hide()

	var buffs = []
	var i = - 1
	for buff in StaticManager.CONTINUOUS_TACTICS:
		i += 1
		var dic = wa.get_buff(buff)
		var turn = int(dic["回合数"])
		if turn <= 0:
			continue
		if turn == 999:
			turn = "--"
		buffs.append([i, turn])

	if buffs.empty():
		return

	var sp: Sprite = con_tactic.get_node("sp")
	var sp2: Sprite = con_tactic.get_node("sp2")
	var lblturn: Label = con_tactic.get_node("lblturn")

	sp2.hide()
	var buff = buffs[0]
	if buffs.size() > 1:
		sp2.show()
		
		var second = int(Time.get_ticks_msec() / 1000)
		buff = buffs[second % buffs.size()]
	var img = "res://resource/images/battle_character/tactics_{0}.png".format([buff[0]])
	sp.texture = Global.load_pic(img)
	lblturn.text = str(buff[1])
	con_tactic.show()

	return
