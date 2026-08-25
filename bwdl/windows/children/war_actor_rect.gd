# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/children/war_actor_rect.gd
# 说明：战争武将格子子控件。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var spUnknown = get_node("Control/unknown")
onready var spTop = get_node("Control/Top")
onready var spBottom = get_node("Control/Bottom")
onready var lblActorName = get_node("Control/lblActorName")
onready var stop = get_node("Control/stop")
onready var link_chain = get_node("Control/link_chain")
onready var lblAP = get_node("Control/lblAP")

var npcId = - 1
var actorId = - 1
var vstateId = - 1


const middle_side_color = 3


func _ready() -> void :
	spUnknown.hide()
	stop.hide()
	link_chain.hide()
	update_all()
	show_can_choose(false)
	show_actor_name(false)
	return

func _process(delta: float) -> void :
	update_view()
	return


func update_all():
	if actorId != - 1:
		_update_actor()
	elif npcId != - 1:
		_update_npc()
	return

func _update_npc():
	var color = middle_side_color;
	var top_path = "res://resource/images/vassalIcon/warRect/rectTop2x_" + str(color) + ".png"
	var bottom_path = "res://resource/images/vassalIcon/warRect/rectBottom_" + str(color) + ".png"
	spTop.texture = Global.load_pic(top_path)
	spBottom.texture = Global.load_pic(bottom_path)
	
	var war_npc = DataManager.get_war_npc(npcId)
	if not is_instance_valid(war_npc):
		return
	
	show_actor_name(true)
	var bottom_index = 0
	var found_idx = "山水平仙".find(war_npc.troops_type)
	if found_idx >= 0:
		bottom_index = found_idx
	spBottom.frame = bottom_index
	var sodiers_h = int(war_npc.sodiers / 100)
	var top_x_index = 0
	spTop.frame_coords = Vector2(top_x_index, sodiers_h)
	return

func _update_actor():
	var colors = [1, 0, 4]
	var color = 4
	var wf = DataManager.get_current_war_fight()
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return
	if wa.is_defender():
		color = 0
	if wa.is_attacker():
		
		if wa.vstate().id == wf.attackerWV.id:
			color = 1

	spUnknown.hide()
	if wa.get_controlNo() < 0 and wa.get_buff_label_turn(["潜行"]) > 0:
		spUnknown.show()
		return
	var top_path = "res://resource/images/vassalIcon/warRect/rectTop2x_" + str(color) + ".png"
	var bottom_path = "res://resource/images/vassalIcon/warRect/rectBottom_" + str(color) + ".png"
	spTop.texture = Global.load_pic(top_path)
	spBottom.texture = Global.load_pic(bottom_path)
	var actor = ActorHelper.actor(actorId)
	var bottom_index = 0
	var found_idx = "山水平仙".find(actor.get_troops_type())
	if found_idx >= 0:
		bottom_index = found_idx
	spBottom.frame = bottom_index;
	var sodiers_h = int(actor.get_soldiers() / 100)
	var category = 0
	var leader = wa.get_leader()
	if leader != null and leader.actorId == wa.actorId:
		category = 1
	if wa.is_reinforcement():
		category += 2
	if wa.wvId != wa.initWvId:
		
		category = 4
	spTop.frame_coords = Vector2(category, sodiers_h)

	update_buff()
	var c: Control = get_node("Control")
	if wa.is_concealed:
		c.modulate = Color("#000000")
	else:
		c.modulate = Color("#ffffff")
	link_chain.visible = wa.get_buff_label_turn(["铁索"]) > 0
	return


func update_view():
	var sceneId = DataManager.get_current_scene_id()
	if sceneId != 20000:
		return
	var map = SceneManager.current_scene().war_map
	if actorId >= 0:
		var wa = DataManager.get_war_actor(actorId);
		if wa == null:
			return
		rect_position = wa.position * 40
		if map.actorViewMode == 0:
			lblAP.hide()
			return
		lblAP.add_color_override("font_color", Color.white)
		if map.actorViewMode == 1:
			lblAP.text = wa.get_name()
			var font: Font = lblAP.get_font("font")
			lblAP.rect_position.x = - (lblAP.rect_size.x - 66) / 2 * lblAP.rect_scale.x
		else:
			var ap = wa.action_point
			lblAP.text = "机:{0}".format([min(99, ap)])
			lblAP.rect_size = Vector2(66, 33)
			lblAP.rect_position = Vector2(0, 20)
			if ap >= 10:
				lblAP.add_color_override("font_color", Color("#F2F909"))
		lblAP.show()
	elif npcId >= 0:
		var wn = DataManager.get_war_npc(npcId)
		if wn == null:
			return
		rect_position = wn.position * 40
	return

func set_rect_show(b: bool):
	if (b):
		modulate.a = 1.0;
	else:
		modulate.a = 0;
	
func is_rect_show() -> bool:
	return modulate.a > 0;

func show_can_choose(b: bool, color: String = "#A0004CFF"):
	var node = get_node("Control/war_can_choose")
	node.self_modulate = Color(color)
	node.visible = b
	lblActorName.set("custom_colors/font_color", Color("#FFFFFFFF"))
	return

func show_actor_name(b):
	lblActorName.visible = b
	if actorId != - 1:
		var actor = ActorHelper.actor(actorId)
		var name = actor.get_name()
		if name.length() > 2:
			name = name.insert(2, "\n")
		lblActorName.text = name
	elif npcId != - 1:
		var war_npc = DataManager.get_war_npc(npcId)
		lblActorName.text = war_npc.npc_name
	return

func update_buff() -> void :
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return
	var buffLabels = []
	for buff in StaticManager.WAR_BUFF_STATUSES:
		var buffTurns = wa.get_buff(buff)["回合数"]
		if buffTurns <= 0:
			continue
		var buffLabel = "{0}\n{1}".format([min(99, buffTurns), StaticManager.WAR_BUFF_STATUSES[buff]])
		buffLabels.append(buffLabel)
	if wa.is_puppet():
		buffLabels.append("\n偶")
	stop.text = ""
	stop.visible = false
	if not buffLabels.empty():
		stop.visible = true
		
		var second = int(Time.get_ticks_msec() / 1000)
		stop.text = buffLabels[second % buffLabels.size()]
	return
