tool
extends Control

export (int) var vstateId = - 1;
export (float) var scale = 1;
export (String) var vstate_name = "";

onready var lbllordName = get_node("LordName");
onready var lblcityNums = get_node("cityNums");
onready var Big = get_node("Big");


func _ready() -> void :
	rect_scale.x = scale;
	rect_scale.y = scale;
	if (vstateId == - 1):
		Big.visible = false;
		lbllordName.text = vstate_name;
		lblcityNums.visible = false;
		return ;
	var vstate = clVState.vstate(vstateId)
	if (vstate_name == ""):
		vstate_name = vstate.get_lord_name()
	
	lbllordName.text = vstate_name;
	var citys = DataManager.get_city_num_by_vstate(vstateId)
	citys = max(citys, 1)
	lblcityNums.text = "×{0}".format([citys])
	Big.texture = Global.load_pic("res://resource/images/vassalIcon/{0}_BIG.png".format([vstateId]));
	return
