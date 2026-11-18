extends Control

var actorId = - 1;
onready var nprFace = get_node("conActor/nprFace");
onready var lsc = get_node("lsc");

onready var lblName = get_node("conActor/lblName")
onready var lblHP = get_node("actorinfo/hp/Value")
onready var lblPower = get_node("actorinfo/str/Value")
onready var lblWisdom = get_node("actorinfo/int/Value")
onready var lblLoyalty = get_node("actorinfo/loy/Value")
onready var spLoy100 = get_node("actorinfo/loy/Loy100")

func init_data(_actorId: int):
	SceneManager.hide_all_tool()
	actorId = _actorId
	lsc.cursor_index = 0
	nprFace.set_actor(actorId)
	var actor = ActorHelper.actor(actorId)
	lblName.text = actor.get_name()
	lblHP.text = str(int(ceil(actor.get_hp())))
	lblPower.text = str(actor.get_power())
	lblWisdom.text = str(actor.get_wisdom())
	lblLoyalty.text = str(actor.get_loyalty())
	spLoy100.visible = false
	lblLoyalty.visible = true
	if actor.get_loyalty() == 100:
		spLoy100.visible = true
		lblLoyalty.visible = false
	return
